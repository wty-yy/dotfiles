#!/usr/bin/env bash
set -Eeuo pipefail

# Configuration: edit the values in this section directly.
# Use a plain URL here. Markdown syntax such as [URL](URL) is not valid Bash.
SUBSCRIPTION_URL="https://your/url"
MIXED_PORT=7890
CONTROLLER_IP="127.0.0.1"
CONTROLLER_PORT=9009
SECRET="123456"
# Automatic update interval in hours. Set to -1 to disable automatic updates.
UPDATE_INTERVAL_HOURS=1

SUBSCRIPTION_USER_AGENT="clash.meta"
CURL_INSECURE=1
MIHOMO_REPO="MetaCubeX/mihomo"
MIHOMO_RELEASE_API="https://api.github.com/repos/${MIHOMO_REPO}/releases/latest"
MIHOMO_RELEASE_PAGE="https://github.com/${MIHOMO_REPO}/releases/latest"
MIHOMO_DOWNLOAD_URL=""
MIHOMO_CPU_LEVEL="auto"

CONFIG_FILE="config.yaml"
CLASH_BIN="./clash"
WORK_DIR="."
EXTERNAL_UI="ui"

LOG_FILE="clash-update.log"
CLASH_LOG_FILE="clash.log"
UPDATER_PID_FILE="clash-updater.pid"
CLASH_PID_FILE="clash.pid"
BACKUP_KEEP=5
SKIP_RELOAD=0

CONTROLLER_ADDR="${CONTROLLER_IP}:${CONTROLLER_PORT}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$ROOT_DIR" "$1" ;;
  esac
}

CONFIG_PATH="$(abs_path "$CONFIG_FILE")"
CLASH_PATH="$(abs_path "$CLASH_BIN")"
WORK_PATH="$(abs_path "$WORK_DIR")"
LOG_PATH="$(abs_path "$LOG_FILE")"
CLASH_LOG_PATH="$(abs_path "$CLASH_LOG_FILE")"
UPDATER_PID_PATH="$(abs_path "$UPDATER_PID_FILE")"
CLASH_PID_PATH="$(abs_path "$CLASH_PID_FILE")"
PREVIOUS_CONTROLLER_ADDR=""
PREVIOUS_SECRET=""

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

die() {
  log "ERROR: $*" >&2
  exit 1
}

validate_port() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < 1 || value > 65535 )); then
    die "$name must be an integer from 1 to 65535: $value"
  fi
}

validate_settings() {
  validate_port "MIXED_PORT" "$MIXED_PORT"
  validate_port "CONTROLLER_PORT" "$CONTROLLER_PORT"

  if [[ ! "$UPDATE_INTERVAL_HOURS" =~ ^-?[0-9]+$ ]] \
    || (( UPDATE_INTERVAL_HOURS == 0 || UPDATE_INTERVAL_HOURS < -1 )); then
    die "UPDATE_INTERVAL_HOURS must be -1 or a positive integer: $UPDATE_INTERVAL_HOURS"
  fi
}

auto_update_enabled() {
  [[ "$UPDATE_INTERVAL_HOURS" != "-1" ]]
}

detect_mihomo_os() {
  case "$(uname -s)" in
    Linux) printf 'linux\n' ;;
    Darwin) printf 'darwin\n' ;;
    FreeBSD) printf 'freebsd\n' ;;
    *) return 1 ;;
  esac
}

detect_mihomo_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'amd64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    armv7l|armv7) printf 'armv7\n' ;;
    armv6l|armv6) printf 'armv6\n' ;;
    i386|i686) printf '386\n' ;;
    *) return 1 ;;
  esac
}

cpu_flags() {
  if [[ -r /proc/cpuinfo ]]; then
    awk -F: '/flags|Features/ {print tolower($2); exit}' /proc/cpuinfo
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n machdep.cpu.features machdep.cpu.leaf7_features 2>/dev/null | tr '\n' ' ' | tr '[:upper:]' '[:lower:]'
  fi
}

has_cpu_flags() {
  local flags="$1"
  shift

  for flag in "$@"; do
    [[ " $flags " == *" $flag "* ]] || return 1
  done
}

has_any_cpu_flag() {
  local flags="$1"
  shift

  for flag in "$@"; do
    [[ " $flags " == *" $flag "* ]] && return 0
  done

  return 1
}

detect_amd64_cpu_level() {
  local flags

  if [[ "$MIHOMO_CPU_LEVEL" != "auto" ]]; then
    case "$MIHOMO_CPU_LEVEL" in
      compatible|v1|v2|v3) printf '%s\n' "$MIHOMO_CPU_LEVEL"; return 0 ;;
      *) die "Invalid MIHOMO_CPU_LEVEL: $MIHOMO_CPU_LEVEL. Use auto, compatible, v1, v2, or v3." ;;
    esac
  fi

  flags="$(cpu_flags || true)"
  if [[ -z "$flags" ]]; then
    printf 'compatible\n'
    return 0
  fi

  if has_cpu_flags "$flags" avx avx2 fma bmi1 bmi2 f16c movbe xsave \
    && has_any_cpu_flag "$flags" lzcnt abm; then
    printf 'v3\n'
  elif has_any_cpu_flag "$flags" sse3 pni \
    && has_cpu_flags "$flags" ssse3 sse4_1 sse4_2 popcnt cx16 lahf_lm; then
    printf 'v2\n'
  elif has_cpu_flags "$flags" sse2; then
    printf 'v1\n'
  else
    printf 'compatible\n'
  fi
}

is_mihomo_binary() {
  local binary="$1"
  local version_output

  [[ -f "$binary" ]] || return 1
  [[ -x "$binary" ]] || chmod +x "$binary" 2>/dev/null || return 1

  version_output="$("$binary" -v 2>/dev/null | head -n 1 || true)"
  [[ "$version_output" == *Mihomo* || "$version_output" == *mihomo* ]]
}

backup_existing_core() {
  local backup_path

  if [[ ! -e "$CLASH_PATH" && ! -L "$CLASH_PATH" ]]; then
    return 0
  fi

  backup_path="$CLASH_PATH.bak.$(date '+%Y%m%d%H%M%S')"
  mv "$CLASH_PATH" "$backup_path"
  log "Existing non-Mihomo core backed up: $backup_path"
}

install_mihomo_binary() {
  local source_path="$1"

  if [[ "$source_path" != "$CLASH_PATH" ]]; then
    backup_existing_core
    mv "$source_path" "$CLASH_PATH"
  fi

  chmod +x "$CLASH_PATH"
  log "Mihomo core is ready: $CLASH_PATH"
}

adopt_local_mihomo_core() {
  local candidate tmp_dir extracted
  local -a candidates

  shopt -s nullglob
  candidates=(
    "$ROOT_DIR/mihomo"
    "$ROOT_DIR"/mihomo-*
    "$ROOT_DIR"/mihomo_*
  )
  shopt -u nullglob

  for candidate in "${candidates[@]}"; do
    [[ "$candidate" == "$CLASH_PATH" ]] && continue
    [[ -f "$candidate" ]] || continue

    if [[ "$candidate" == *.gz ]]; then
      command -v gzip >/dev/null 2>&1 || die "gzip is required to extract local Mihomo archive: $candidate"
      tmp_dir="$(mktemp -d)"
      extracted="$tmp_dir/mihomo"
      if gzip -dc "$candidate" > "$extracted" && is_mihomo_binary "$extracted"; then
        log "Found local Mihomo archive: $candidate"
        install_mihomo_binary "$extracted"
        rm -rf "$tmp_dir"
        return 0
      fi
      rm -rf "$tmp_dir"
      continue
    fi

    if is_mihomo_binary "$candidate"; then
      log "Found local Mihomo core: $candidate"
      install_mihomo_binary "$candidate"
      return 0
    fi
  done

  return 1
}

resolve_mihomo_download_url() {
  local os_name arch cpu_level release_json status

  if [[ -n "$MIHOMO_DOWNLOAD_URL" ]]; then
    printf '%s\n' "$MIHOMO_DOWNLOAD_URL"
    return 0
  fi

  os_name="$(detect_mihomo_os)" || return 1
  arch="$(detect_mihomo_arch)" || return 1
  cpu_level="generic"
  if [[ "$arch" == "amd64" ]]; then
    cpu_level="$(detect_amd64_cpu_level)"
  fi
  release_json="$(mktemp)"

  if ! curl -fsSL --connect-timeout 15 --max-time 60 --retry 2 -o "$release_json" "$MIHOMO_RELEASE_API"; then
    rm -f "$release_json"
    return 1
  fi

  python3 - "$release_json" "$os_name" "$arch" "$cpu_level" <<'PY'
import json
import pathlib
import re
import sys

release_path, os_name, arch, cpu_level = sys.argv[1:]

try:
    data = json.loads(pathlib.Path(release_path).read_text(encoding="utf-8"))
except Exception:
    sys.exit(1)

prefix = f"mihomo-{os_name}-{arch}"
candidates = []

if arch == "amd64":
    preferred_variants = {
        "v3": ["v3", "v2", "v1", "base", "compatible"],
        "v2": ["v2", "v1", "base", "compatible"],
        "v1": ["v1", "base", "compatible"],
        "compatible": ["compatible", "base"],
    }.get(cpu_level, ["base", "compatible"])
else:
    preferred_variants = ["base", "compatible"]

def variant_of(name: str) -> str | None:
    if arch == "amd64" and re.fullmatch(rf"{re.escape(prefix)}-compatible-v[0-9][0-9A-Za-z._-]*\.gz", name):
        return "compatible"
    if arch == "amd64":
        match = re.fullmatch(rf"{re.escape(prefix)}-(v[123])-v[0-9][0-9A-Za-z._-]*\.gz", name)
        if match:
            return match.group(1)
    if re.fullmatch(rf"{re.escape(prefix)}-v[0-9][0-9A-Za-z._-]*\.gz", name):
        return "base"
    return None

for asset in data.get("assets", []):
    name = asset.get("name", "")
    url = asset.get("browser_download_url", "")
    if not name.startswith(prefix) or not name.endswith(".gz") or not url:
        continue

    variant = variant_of(name)
    if variant not in preferred_variants:
        continue

    score = (len(preferred_variants) - preferred_variants.index(variant)) * 100
    if "compatible" not in name:
        score += 10
    if "go" not in name.lower():
        score += 5
    candidates.append((score, variant, name, url))

if not candidates:
    sys.exit(1)

candidates.sort(reverse=True)
print(candidates[0][3])
PY
  status=$?
  rm -f "$release_json"
  return "$status"
}

download_mihomo_core() {
  local download_url tmp_dir archive binary status

  command -v gzip >/dev/null 2>&1 || die "gzip is required to extract Mihomo release archives."

  if ! download_url="$(resolve_mihomo_download_url)"; then
    log "Mihomo core is missing and automatic download URL could not be resolved."
    log "Download page: $MIHOMO_RELEASE_PAGE"
    log "After downloading, put the Linux binary or .gz archive in this directory as 'mihomo', then run this script again."
    return 1
  fi

  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/mihomo.gz"
  binary="$tmp_dir/mihomo"

  log "Downloading Mihomo core: $download_url"
  if curl -fL --connect-timeout 20 --max-time 300 --retry 2 --retry-delay 2 -o "$archive" "$download_url"; then
    :
  else
    status=$?
    rm -rf "$tmp_dir"
    log "Mihomo core download failed."
    log "Direct download URL: $download_url"
    log "Release page: $MIHOMO_RELEASE_PAGE"
    log "Please download it manually, place it in this directory as 'mihomo', then run this script again."
    return "$status"
  fi

  if gzip -dc "$archive" > "$binary"; then
    :
  else
    status=$?
    rm -rf "$tmp_dir"
    log "Downloaded Mihomo archive could not be extracted."
    return "$status"
  fi

  if ! is_mihomo_binary "$binary"; then
    rm -rf "$tmp_dir"
    log "Downloaded file is not a valid Mihomo binary."
    log "Direct download URL: $download_url"
    return 1
  fi

  install_mihomo_binary "$binary"
  rm -rf "$tmp_dir"
}

ensure_mihomo_core() {
  if is_mihomo_binary "$CLASH_PATH"; then
    log "Found Mihomo core: $CLASH_PATH"
    return 0
  fi

  if adopt_local_mihomo_core; then
    return 0
  fi

  download_mihomo_core || die "Mihomo core is required. Manual download: $MIHOMO_RELEASE_PAGE"
}

require_deps() {
  validate_settings
  command -v curl >/dev/null 2>&1 || die "curl is required."
  command -v python3 >/dev/null 2>&1 || die "python3 is required."
  ensure_mihomo_core
}

controller_base_url_for() {
  local address="$1"
  local host port
  host="${address%:*}"
  port="${address##*:}"

  case "$host" in
    ""|"*"|"0.0.0.0"|"::")
      host="127.0.0.1"
      ;;
  esac

  printf 'http://%s:%s' "$host" "$port"
}

controller_base_url() {
  controller_base_url_for "$CONTROLLER_ADDR"
}

read_config_scalar() {
  local config_file="$1"
  local wanted_key="$2"

  [[ -f "$config_file" ]] || return 1
  python3 - "$config_file" "$wanted_key" <<'PY'
import pathlib
import re
import sys

path, wanted_key = sys.argv[1:]
for line in pathlib.Path(path).read_text(encoding="utf-8").splitlines():
    if not line or line[0].isspace() or line.startswith("#"):
        continue
    key, separator, value = line.partition(":")
    if not separator or key != wanted_key:
        continue
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == "'":
        value = value[1:-1].replace("''", "'")
    elif len(value) >= 2 and value[0] == value[-1] == '"':
        value = bytes(value[1:-1], "utf-8").decode("unicode_escape")
    print(value)
    sys.exit(0)
sys.exit(1)
PY
}

remember_current_controller() {
  PREVIOUS_CONTROLLER_ADDR="$(read_config_scalar "$CONFIG_PATH" "external-controller" || true)"
  PREVIOUS_SECRET="$(read_config_scalar "$CONFIG_PATH" "secret" || true)"
}

json_string() {
  python3 - "$1" <<'PY'
import json
import sys

print(json.dumps(sys.argv[1]))
PY
}

curl_tls_args() {
  if [[ "$CURL_INSECURE" == "1" ]]; then
    printf '%s\n' "-k"
  fi
}

looks_like_clash_yaml() {
  local file="$1"
  grep -Eq '^(mixed-port|port|socks-port|proxies|proxy-groups|rules):' "$file" \
    && grep -Eq '^proxy-groups:' "$file" \
    && grep -Eq '^rules:' "$file"
}

normalize_subscription() {
  local raw_file="$1"
  local yaml_file="$2"
  local decoded_file

  decoded_file="${raw_file}.decoded"
  python3 - "$raw_file" "$decoded_file" <<'PY' || true
import base64
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
data = b''.join(source.read_bytes().split())
data += b'=' * ((4 - len(data) % 4) % 4)

try:
    target.write_bytes(base64.b64decode(data, validate=False))
except Exception:
    sys.exit(1)
PY

  if looks_like_clash_yaml "$raw_file"; then
    python3 - "$raw_file" "$yaml_file" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
text = source.read_bytes().decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
target.write_text(text, encoding="utf-8")
PY
    return 0
  fi

  if [[ -s "$decoded_file" ]] && looks_like_clash_yaml "$decoded_file"; then
    python3 - "$decoded_file" "$yaml_file" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
text = source.read_bytes().decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
target.write_text(text, encoding="utf-8")
PY
    return 0
  fi

  die "Subscription did not return Clash YAML. Try keeping SUBSCRIPTION_USER_AGENT=clash.meta or use a converter service."
}

inject_runtime_settings() {
  local source_file="$1"
  local target_file="$2"

  python3 - "$source_file" "$target_file" "$MIXED_PORT" "$CONTROLLER_ADDR" "$SECRET" "$EXTERNAL_UI" <<'PY'
import pathlib
import re
import sys

source, target, mixed_port, controller, secret, external_ui = sys.argv[1:]

def quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"

def top_key(line: str):
    if not line or line[0].isspace() or line.startswith("#") or ":" not in line:
        return None
    key = line.split(":", 1)[0]
    if re.fullmatch(r"[A-Za-z0-9_-]+", key):
        return key
    return None

remove_keys = {"mixed-port", "external-controller", "secret", "external-ui", "geox-url"}
injected_lines = [
    f"mixed-port: {mixed_port}",
    f"external-controller: {quote(controller)}",
    f"secret: {quote(secret)}",
    f"external-ui: {quote(external_ui)}",
    "geox-url:",
    '  geoip: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"',
    '  geosite: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"',
    '  mmdb: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb"',
]

lines = pathlib.Path(source).read_text(encoding="utf-8").splitlines()
output = []
inserted = False
skip_removed_block = False

for line in lines:
    key = top_key(line)

    if key is not None:
        skip_removed_block = key in remove_keys
        if skip_removed_block:
            continue

    if skip_removed_block:
        continue

    if key in remove_keys:
        continue

    output.append(line)
    if not inserted and key == "log-level":
        output.extend(injected_lines)
        inserted = True

if not inserted:
    for index, line in enumerate(output):
        if top_key(line) in {"dns", "rule-providers", "proxies", "proxy-groups", "rules"}:
            output[index:index] = injected_lines
            inserted = True
            break

if not inserted:
    output.extend(injected_lines)

pathlib.Path(target).write_text("\n".join(output).rstrip() + "\n", encoding="utf-8")
PY
}

download_candidate_config() {
  local tmp_dir="$1"
  local raw_config="$tmp_dir/subscription.raw"
  local yaml_config="$tmp_dir/subscription.yaml"
  local final_config="$tmp_dir/config.yaml"
  local curl_args

  curl_args=(-L --fail --connect-timeout 15 --max-time 90 --retry 2 --retry-delay 2)
  if [[ "$CURL_INSECURE" == "1" ]]; then
    curl_args+=(-k)
  fi

  log "Downloading subscription with User-Agent: $SUBSCRIPTION_USER_AGENT"
  if ! curl "${curl_args[@]}" \
      -A "$SUBSCRIPTION_USER_AGENT" \
      -o "$raw_config" \
      "$SUBSCRIPTION_URL"; then
    log "Subscription download through the current system proxy failed; retrying directly."
    if ! curl "${curl_args[@]}" --noproxy '*' \
        -A "$SUBSCRIPTION_USER_AGENT" \
        -o "$raw_config" \
        "$SUBSCRIPTION_URL"; then
      log "Subscription download failed through both the system proxy and a direct connection."
      return 1
    fi
  fi

  normalize_subscription "$raw_config" "$yaml_config"
  inject_runtime_settings "$yaml_config" "$final_config"
  printf '%s\n' "$final_config"
}

validate_config() {
  local candidate="$1"

  log "Validating generated config with Mihomo."
  "$CLASH_PATH" -t -d "$WORK_PATH" -f "$candidate"
}

prune_backups() {
  local backup_count index
  mapfile -t backups < <(ls -1t "$CONFIG_PATH".bak.* 2>/dev/null || true)
  backup_count="${#backups[@]}"

  if (( backup_count <= BACKUP_KEEP )); then
    return 0
  fi

  for (( index = BACKUP_KEEP; index < backup_count; index++ )); do
    rm -f "${backups[$index]}"
  done
}

install_config() {
  local candidate="$1"
  local backup_path

  chmod 0644 "$candidate"
  mkdir -p "$(dirname "$CONFIG_PATH")"

  if [[ -f "$CONFIG_PATH" ]] && cmp -s "$candidate" "$CONFIG_PATH"; then
    log "Config unchanged: $CONFIG_PATH"
    return 0
  fi

  if [[ -f "$CONFIG_PATH" ]]; then
    backup_path="$CONFIG_PATH.bak.$(date '+%Y%m%d%H%M%S')"
    cp -p "$CONFIG_PATH" "$backup_path"
    log "Backup saved: $backup_path"
  fi

  mv "$candidate" "$CONFIG_PATH"
  log "Config written: $CONFIG_PATH"
  prune_backups
}

controller_alive_at() {
  local address="$1"
  local controller_secret="$2"
  local curl_args
  curl_args=(-sS --connect-timeout 2 --max-time 5)
  if [[ -n "$controller_secret" ]]; then
    curl_args+=(-H "Authorization: Bearer $controller_secret")
  fi

  curl "${curl_args[@]}" "$(controller_base_url_for "$address")/version" >/dev/null 2>&1
}

controller_alive() {
  controller_alive_at "$CONTROLLER_ADDR" "$SECRET"
}

reload_config_at() {
  local address="$1"
  local controller_secret="$2"
  local curl_args payload response_file error_file

  response_file="$(mktemp)"
  error_file="$(mktemp)"
  payload="{\"path\":$(json_string "$CONFIG_PATH")}"
  curl_args=(-sS --connect-timeout 3 --max-time 15 -X PUT)
  if [[ -n "$controller_secret" ]]; then
    curl_args+=(-H "Authorization: Bearer $controller_secret")
  fi
  curl_args+=(-H "Content-Type: application/json" --data-binary "$payload")

  if curl "${curl_args[@]}" "$(controller_base_url_for "$address")/configs?force=true" >"$response_file" 2>"$error_file"; then
    rm -f "$response_file" "$error_file"
    return 0
  fi

  log "Config reload failed; see response below."
  sed -n '1,20p' "$error_file" >&2 || true
  sed -n '1,20p' "$response_file" >&2 || true
  rm -f "$response_file" "$error_file"
  return 1
}

reload_config() {
  if [[ "$SKIP_RELOAD" == "1" ]]; then
    log "Reload skipped because SKIP_RELOAD=1."
    return 0
  fi

  if controller_alive; then
    if reload_config_at "$CONTROLLER_ADDR" "$SECRET"; then
      log "Running Clash reloaded the new config."
      return 0
    fi
    return 1
  fi

  if [[ -n "$PREVIOUS_CONTROLLER_ADDR" ]] \
    && controller_alive_at "$PREVIOUS_CONTROLLER_ADDR" "$PREVIOUS_SECRET"; then
    log "Reloading through previous controller: $(controller_base_url_for "$PREVIOUS_CONTROLLER_ADDR")."
    if reload_config_at "$PREVIOUS_CONTROLLER_ADDR" "$PREVIOUS_SECRET"; then
      log "Running Clash switched to the new controller settings."
      return 0
    fi
    return 1
  fi

  log "Controller is not reachable; Clash will load the new config on next start."
}

update_once() {
  local tmp_dir candidate
  local status

  remember_current_controller
  tmp_dir="$(mktemp -d)"

  if candidate="$(download_candidate_config "$tmp_dir")"; then
    :
  else
    status=$?
    rm -rf "$tmp_dir"
    return "$status"
  fi

  if validate_config "$candidate"; then
    :
  else
    status=$?
    rm -rf "$tmp_dir"
    return "$status"
  fi

  if install_config "$candidate"; then
    :
  else
    status=$?
    rm -rf "$tmp_dir"
    return "$status"
  fi

  rm -rf "$tmp_dir"
}

run_clash_foreground() {
  if controller_alive; then
    die "Clash is already running at $(controller_base_url). Stop the existing process before starting foreground mode."
  fi

  log "Starting Clash in the foreground. Press Ctrl+C to stop."
  "$CLASH_PATH" -d "$WORK_PATH"
}

start_updater() {
  local pid
  local -a updater_cmd

  if ! auto_update_enabled; then
    log "Automatic config updates are disabled."
    return 0
  fi

  if [[ -f "$UPDATER_PID_PATH" ]]; then
    pid="$(tr -d '[:space:]' < "$UPDATER_PID_PATH" || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      log "Updater is already running with PID $pid."
      return 0
    fi
  fi

  log "Starting updater loop every ${UPDATE_INTERVAL_HOURS} hour(s)."
  updater_cmd=("$ROOT_DIR/$(basename "$0")" loop)

  if command -v setsid >/dev/null 2>&1; then
    setsid "${updater_cmd[@]}" >> "$LOG_PATH" 2>&1 < /dev/null &
  else
    nohup "${updater_cmd[@]}" >> "$LOG_PATH" 2>&1 < /dev/null &
  fi

  pid="$!"
  printf '%s\n' "$pid" > "$UPDATER_PID_PATH"
  sleep 1

  if kill -0 "$pid" >/dev/null 2>&1; then
    log "Updater started with PID $pid."
  else
    log "Updater failed to stay running. Check $LOG_PATH"
    return 1
  fi
}

stop_updater() {
  local pid

  if [[ ! -f "$UPDATER_PID_PATH" ]]; then
    log "Updater is not running."
    return 0
  fi

  pid="$(tr -d '[:space:]' < "$UPDATER_PID_PATH" || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    kill -- "-$pid" >/dev/null 2>&1 || kill "$pid"
    log "Updater stopped: PID $pid."
  else
    log "Removing stale updater PID file."
  fi
  rm -f "$UPDATER_PID_PATH"
}

loop_forever() {
  local sleep_pid interval_seconds

  if ! auto_update_enabled; then
    log "Automatic config updates are disabled; updater loop will not start."
    return 0
  fi

  interval_seconds="$((UPDATE_INTERVAL_HOURS * 3600))"

  trap '[[ -n "${sleep_pid:-}" ]] && kill "$sleep_pid" >/dev/null 2>&1 || true; log "Updater loop stopped."; exit 0' INT TERM
  log "Updater loop active. Interval: ${UPDATE_INTERVAL_HOURS} hour(s)."

  while true; do
    sleep "$interval_seconds" &
    sleep_pid="$!"
    wait "$sleep_pid" || exit 0
    sleep_pid=""

    if update_once; then
      reload_config
    else
      log "Update failed; keeping current config."
    fi
  done
}

print_access_info() {
  local base host port lan_ip
  base="$(controller_base_url)"
  host="${CONTROLLER_ADDR%:*}"
  port="${CONTROLLER_ADDR##*:}"

  log "Dashboard URL: ${base}/ui/"
  log "Controller API: ${base}"
  log "Secret: $SECRET"

  if [[ "$host" == "0.0.0.0" || "$host" == "*" || "$host" == "::" ]]; then
    lan_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    if [[ -n "$lan_ip" ]]; then
      log "LAN dashboard URL: http://${lan_ip}:${port}/ui/"
    fi
  fi
}

show_status() {
  require_deps

  if controller_alive; then
    log "Controller: reachable at $(controller_base_url)."
  else
    log "Controller: not reachable at $(controller_base_url)."
  fi

  if [[ -f "$UPDATER_PID_PATH" ]]; then
    local pid
    pid="$(tr -d '[:space:]' < "$UPDATER_PID_PATH" || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      log "Updater: running with PID $pid."
    else
      log "Updater: PID file exists but process is not running."
    fi
  else
    log "Updater: not running."
  fi

  [[ -f "$CONFIG_PATH" ]] && log "Config: $CONFIG_PATH"
}

systemd_user_home() {
  local passwd_home

  passwd_home="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6 || true)"
  if [[ -n "$passwd_home" ]]; then
    printf '%s\n' "$passwd_home"
  elif [[ -n "${HOME-}" ]]; then
    printf '%s\n' "$HOME"
  else
    die "Could not determine the current user's home directory."
  fi
}

require_systemd_user() {
  command -v systemctl >/dev/null 2>&1 || die "systemctl is required to manage the user service."
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    die "The systemd user manager is unavailable. Log in with a systemd user session and try again."
  fi
}

show_systemd_service_status() {
  local service_name="$1"
  local enabled_state active_state

  enabled_state="$(systemctl --user is-enabled "$service_name" 2>/dev/null || true)"
  active_state="$(systemctl --user is-active "$service_name" 2>/dev/null || true)"
  log "Service enabled: ${enabled_state:-unknown}"
  log "Service active: ${active_state:-unknown}"
  systemctl --user status "$service_name" --no-pager --full || true
}

install_systemd_service() {
  local user_home start_script service_dir service_file service_name
  local escaped_start_script

  require_deps
  require_systemd_user

  user_home="$(systemd_user_home)"
  start_script="$user_home/.local/bin/start-clash"
  service_dir="$user_home/.config/systemd/user"
  service_file="$service_dir/clash.service"
  service_name="clash.service"

  if [[ -f "$start_script" && -f "$service_file" ]]; then
    log "Clash systemd user service is already installed."
    systemctl --user daemon-reload
    show_systemd_service_status "$service_name"
    if systemctl --user is-active --quiet "$service_name"; then
      log "Clash systemd user service is running."
    elif pgrep -u "$(id -u)" -x clash >/dev/null 2>&1; then
      log "Clash is running outside systemd; the installed service is inactive because start-clash skipped a duplicate process."
    else
      log "Clash systemd user service is installed but not running."
    fi
    return 0
  fi

  mkdir -p "$(dirname "$start_script")" "$service_dir"
  printf '#!/bin/bash\ncd %q || exit 1\nif pgrep -u "$(id -u)" -x clash > /dev/null; then\n    echo "clash is running, skip starting"\nelse\n    exec %q\nfi\n' \
    "$ROOT_DIR" "$ROOT_DIR/$(basename "$0")" > "$start_script"
  chmod 0755 "$start_script"

  escaped_start_script="${start_script//\\/\\\\}"
  escaped_start_script="${escaped_start_script//\"/\\\"}"
  escaped_start_script="${escaped_start_script//%/%%}"
  printf '%s\n' \
    '[Unit]' \
    'Description=Clash Core Service' \
    'After=network.target' \
    '' \
    '[Service]' \
    'Type=simple' \
    "ExecStart=\"$escaped_start_script\"" \
    'Restart=on-failure' \
    'RestartSec=5s' \
    '' \
    '[Install]' \
    'WantedBy=default.target' > "$service_file"
  chmod 0644 "$service_file"

  log "Installed startup script: $start_script"
  log "Installed systemd user service: $service_file"

  systemctl --user daemon-reload
  systemctl --user enable "$service_name"
  systemctl --user start "$service_name" || true
  sleep 2

  show_systemd_service_status "$service_name"
  if systemctl --user is-active --quiet "$service_name"; then
    log "Clash systemd user service is installed, enabled, and running."
    log "Run directly in a terminal with: $start_script"
    return 0
  fi

  if pgrep -u "$(id -u)" -x clash >/dev/null 2>&1; then
    log "Clash is already running outside systemd, so start-clash skipped a duplicate process."
    log "The service is installed and enabled, but currently inactive."
    log "To transfer control to systemd, stop the manual Clash process and run: systemctl --user start $service_name"
    return 0
  fi
  die "Clash systemd user service is installed but failed to start. Check: journalctl --user -u $service_name -n 50"
}

uninstall_systemd_service() {
  local user_home start_script service_dir service_file service_name

  require_systemd_user

  user_home="$(systemd_user_home)"
  start_script="$user_home/.local/bin/start-clash"
  service_dir="$user_home/.config/systemd/user"
  service_file="$service_dir/clash.service"
  service_name="clash.service"

  if [[ ! -e "$start_script" && ! -e "$service_file" ]]; then
    log "Clash systemd user service is not installed."
    return 0
  fi

  systemctl --user stop "$service_name" >/dev/null 2>&1 || true
  systemctl --user disable "$service_name" >/dev/null 2>&1 || true
  rm -f "$service_file" "$start_script"
  systemctl --user daemon-reload
  systemctl --user reset-failed "$service_name" >/dev/null 2>&1 || true

  if systemctl --user is-active --quiet "$service_name"; then
    die "The service files were removed, but $service_name is still active."
  fi

  log "Stopped and removed Clash systemd user service."
  log "Removed startup script: $start_script"
  log "Removed service file: $service_file"
}

usage() {
  cat <<'EOF'
Usage:
  ./setup_clash.sh              Update config and run Clash in the foreground
  ./setup_clash.sh update       Update config once and reload running Clash
  ./setup_clash.sh status       Show controller/updater status
  ./setup_clash.sh stop         Stop the background updater
  ./setup_clash.sh install-systemd    Install, enable, start, and check the user service
  ./setup_clash.sh uninstall-systemd  Stop, disable, and remove the user service

Edit the configuration section at the top of this script:
  MIXED_PORT=7890               HTTP/SOCKS mixed proxy port
  CONTROLLER_IP="0.0.0.0"       Allow dashboard/API access from LAN
  CONTROLLER_PORT=9100          Dashboard/API port
  SECRET="your-secret"          External controller secret
  UPDATE_INTERVAL_HOURS=1       Update interval in hours; -1 disables auto-update
  MIHOMO_CPU_LEVEL="auto"       auto, compatible, v1, v2, or v3
EOF
}

main() {
  local command_name
  command_name="${1:-setup}"

  case "$command_name" in
    setup|start)
      require_deps
      if controller_alive; then
        die "Clash is already running at $(controller_base_url). Stop the existing process before starting foreground mode."
      fi
      update_once
      reload_config
      stop_updater
      start_updater
      trap 'stop_updater' EXIT
      print_access_info
      run_clash_foreground
      ;;
    update)
      require_deps
      update_once
      reload_config
      print_access_info
      ;;
    loop)
      require_deps
      loop_forever
      ;;
    status)
      show_status
      ;;
    stop)
      stop_updater
      ;;
    install-systemd)
      install_systemd_service
      ;;
    uninstall-systemd)
      uninstall_systemd_service
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
