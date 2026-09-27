#!/usr/bin/env bash
# Ubuntu/GNOME Kitty setup. Run as the desktop user; sudo is used only when needed.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
KITTY_APP="$HOME/.local/kitty.app"
BIN_DIR="$HOME/.local/bin"
FONT_FILE="$SCRIPT_DIR/../../fonts/Caskaydia Cove Nerd Font Complete.ttf"
PLUGIN_VERSION=0.8.3
PLUGIN_SCHEMA=com.github.stunkymonkey.nautilus-open-any-terminal
STEP_IDS=(download desktop path shortcut context config)
STEP_LABELS=('Download / update the latest stable Kitty release' 'Register menu icons and launchers' 'Add kitty and kitten to PATH' 'Set Ctrl+Alt+T and the default terminal' 'Add the Open Kitty Here context menu' 'Replace Kitty config and install the bundled font (with backup)')
SELECTED=(1 1 1 1 1 1)
MODE=tui
DRY_RUN=0
WORK_DIR=''
BACKUP_DIR=''
CURRENT_STEP=preflight

log() { printf '\n%s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }
cleanup() { [[ -z "$WORK_DIR" ]] || rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT
trap 'printf "\nStep %s failed at line %s. Resolve the error and rerun the script.\n" "$CURRENT_STEP" "$LINENO" >&2' ERR

usage() {
    cat <<'EOF'
Usage: ./install.sh [--all | --steps download,desktop,path,shortcut,context,config] [--dry-run]

The TUI selects all six steps by default. Toggle by number; Enter starts; q exits.
  --all          Select all steps without opening the selection screen
  --steps LIST   Run only the listed steps in dependency order
  --dry-run      Preview the plan without downloads, installation, or changes
  -h, --help     Show this help

Run as your Ubuntu GNOME desktop user. Do not run the entire script with sudo.
EOF
}

parse_args() {
    while (($#)); do
        case "$1" in
            --all) MODE=all; SELECTED=(1 1 1 1 1 1) ;;
            --steps)
                (($# >= 2)) && [[ -n "$2" ]] || die '--steps requires a comma-separated list of step names'
                MODE=steps; SELECTED=(0 0 0 0 0 0)
                local items item index found
                IFS=, read -r -a items <<< "$2"
                for item in "${items[@]}"; do
                    found=0
                    for index in "${!STEP_IDS[@]}"; do
                        if [[ "$item" == "${STEP_IDS[index]}" ]]; then
                            SELECTED[index]=1; found=1
                        fi
                    done
                    ((found)) || die "Unknown step: $item"
                done
                shift ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown argument: $1" ;;
        esac
        shift
    done
}

select_steps() {
    [[ -t 0 && -t 1 ]] || die 'No interactive terminal available. Use --all or --steps.'
    local input index mark
    while true; do
        [[ "${TERM:-dumb}" == dumb ]] || printf '\033[2J\033[H'
        printf '╔══════════════════════════════════════════════════════╗\n'
        printf '║              Kitty Installation & Setup              ║\n'
        printf '╚══════════════════════════════════════════════════════╝\n\n'
        for index in "${!STEP_IDS[@]}"; do
            mark=' '; ((SELECTED[index])) && mark=x
            printf '  %s. [%s] %s\n' "$((index + 1))" "$mark" "${STEP_LABELS[index]}"
        done
        printf '\n  1-6 toggle | a select all | n clear all | Enter start | q quit\n'
        printf '  Existing files are backed up; dependencies follow the selected steps.\n\n> '
        IFS= read -r input || exit 0
        case "$input" in
            [1-6]) index=$((input - 1)); SELECTED[index]=$((1 - SELECTED[index])) ;;
            a|A) SELECTED=(1 1 1 1 1 1) ;;
            n|N) SELECTED=(0 0 0 0 0 0) ;;
            '') return ;;
            q|Q) exit 0 ;;
        esac
    done
}

ensure_backup_dir() {
    if [[ -z "$BACKUP_DIR" ]]; then
        mkdir -p -- "$STATE_HOME/kitty-setup/backups"
        BACKUP_DIR="$(mktemp -d "$STATE_HOME/kitty-setup/backups/$(date +%Y%m%d-%H%M%S).XXXXXX")"
        printf 'Backup directory: %s\n' "$BACKUP_DIR"
    fi
}

backup_file() {
    local file="$1"
    if [[ -e "$file" || -L "$file" ]]; then
        ensure_backup_dir
        mkdir -p -- "$BACKUP_DIR/files$(dirname -- "$file")"
        cp -a -- "$file" "$BACKUP_DIR/files$file"
        if [[ -L "$file" && -f "$file" ]]; then
            mkdir -p -- "$BACKUP_DIR/symlink-contents$(dirname -- "$file")"
            cp -L -- "$file" "$BACKUP_DIR/symlink-contents$file"
        fi
    fi
}

install_file() {
    local source="$1" target="$2"
    if [[ -f "$target" && ! -L "$target" ]] && cmp -s -- "$source" "$target"; then return; fi
    backup_file "$target"
    mkdir -p -- "$(dirname -- "$target")"
    # Replace a symlink instead of overwriting the file it points to.
    [[ ! -L "$target" ]] || rm -- "$target"
    install -m 644 -- "$source" "$target"
}

save_settings() {
    ensure_backup_dir
    gsettings list-recursively "$1" > "$BACKUP_DIR/$1.txt"
}

preflight() {
    ((EUID != 0)) || die 'Run as a regular desktop user; the script uses sudo when needed.'
    [[ "$(uname -s)" == Linux && -f /etc/os-release ]] || die 'Only Ubuntu GNOME is supported.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "$ID" == ubuntu ]] || die 'This script requires Ubuntu GNOME.'
    if ((SELECTED[1] || SELECTED[2] || SELECTED[3] || SELECTED[4])); then
        if ((!SELECTED[0])); then
            [[ -x "$KITTY_APP/bin/kitty" ]] || die 'Kitty was not found in the official installation directory. Select download too.'
        fi
    fi
    if ((SELECTED[4] && !SELECTED[2])); then
        command -v kitty >/dev/null || die 'The context menu requires the kitty command. Select path too.'
    fi
    if ((SELECTED[3] || SELECTED[4])); then
        [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || die 'Shortcut and context menu setup require a GNOME desktop session.'
        [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || die 'No desktop D-Bus session found. Run this script in a desktop terminal.'
        command -v gsettings >/dev/null || die 'gsettings was not found.'
    fi
    if ((SELECTED[3])); then
        gsettings get org.gnome.settings-daemon.plugins.media-keys terminal >/dev/null
        gsettings get org.gnome.desktop.default-applications.terminal exec >/dev/null
    fi
    if ((SELECTED[5])); then
        [[ -f "$SCRIPT_DIR/kitty.conf" && -f "$FONT_FILE" ]] || die 'Missing kitty.conf or the repository font. Keep the complete dotfiles directory structure.'
    fi
}

install_dependencies() {
    local packages=() missing=() package
    ((SELECTED[0] || SELECTED[4])) && packages+=(curl ca-certificates xz-utils)
    ((SELECTED[1])) && packages+=(python3 desktop-file-utils)
    ((SELECTED[3])) && packages+=(libglib2.0-bin)
    ((SELECTED[4])) && packages+=(python3-nautilus gir1.2-gtk-4.0 libglib2.0-bin gettext make)
    ((SELECTED[5])) && packages+=(fontconfig)
    for package in "${packages[@]}"; do
        if [[ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)" != 'install ok installed' ]]; then
            missing+=("$package")
        fi
    done
    if ((${#missing[@]})); then
        log "Installing dependencies: ${missing[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
    fi
}

download() {
    curl -fL --retry 3 https://sw.kovidgoyal.net/kitty/installer.sh -o "$WORK_DIR/installer.sh"
    sh "$WORK_DIR/installer.sh" "dest=$HOME/.local" launch=n
    "$KITTY_APP/bin/kitty" --version
}

desktop() {
    local filename
    for filename in kitty.desktop kitty-open.desktop; do
        python3 - "$KITTY_APP" "$filename" "$WORK_DIR/$filename" <<'PY'
import pathlib
import sys

app, name, output = sys.argv[1:]
# Desktop Entry Exec quoting differs from shell quoting.
binary = app + '/bin/kitty'
escaped = ''.join('\\' + c if c in '\\"`$' else c for c in binary)
escaped = escaped.replace('%', '%%').replace('\\', '\\\\')
lines = (pathlib.Path(app) / 'share/applications' / name).read_text().splitlines()
for index, line in enumerate(lines):
    if line.startswith('Exec=kitty'):
        lines[index] = 'Exec="' + escaped + '"' + line[len('Exec=kitty'):]
    elif line.startswith('TryExec='):
        lines[index] = 'TryExec=' + binary.replace('\\', '\\\\')
    elif line.startswith('Icon='):
        lines[index] = 'Icon=' + app.replace('\\', '\\\\') + '/share/icons/hicolor/256x256/apps/kitty.png'
pathlib.Path(output).write_text('\n'.join(lines) + '\n')
PY
        desktop-file-validate "$WORK_DIR/$filename"
        install_file "$WORK_DIR/$filename" "$DATA_HOME/applications/$filename"
    done
    update-desktop-database "$DATA_HOME/applications"
}

path() {
    local executable rc
    mkdir -p -- "$BIN_DIR"
    for executable in kitty kitten; do
        [[ -x "$KITTY_APP/bin/$executable" ]] || die "$executable was not found. Select download first."
        if [[ "$(readlink -- "$BIN_DIR/$executable" 2>/dev/null || true)" != "$KITTY_APP/bin/$executable" ]]; then
            [[ ! -d "$BIN_DIR/$executable" ]] || die "$BIN_DIR/$executable is a directory and cannot be replaced."
            backup_file "$BIN_DIR/$executable"
            ln -sfn -- "$KITTY_APP/bin/$executable" "$BIN_DIR/$executable"
        fi
    done
    for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.zshrc"; do
        configure_shell_path "$rc"
    done
    export PATH="$BIN_DIR:$PATH"
}

configure_shell_path() {
    local rc="$1" snippet
    snippet='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
    if ! grep -Fqx "$snippet" "$rc" 2>/dev/null; then
        backup_file "$rc"
        printf '\n# Kitty setup: user executables\n%s\n' "$snippet" >> "$rc"
    fi
}

shortcut() {
    save_settings org.gnome.settings-daemon.plugins.media-keys
    save_settings org.gnome.desktop.default-applications.terminal
    update-alternatives --query x-terminal-emulator > "$BACKUP_DIR/x-terminal-emulator.txt" 2>/dev/null || true
    sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$KITTY_APP/bin/kitty" 50
    sudo update-alternatives --set x-terminal-emulator "$KITTY_APP/bin/kitty"
    gsettings set org.gnome.desktop.default-applications.terminal exec x-terminal-emulator
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e'
    gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "['<Primary><Alt>t']"
    # Preserve other terminal fallbacks, but put Kitty first.
    { printf 'kitty.desktop\n'; grep -vxF 'kitty.desktop' "$CONFIG_HOME/xdg-terminals.list" 2>/dev/null || true; } > "$WORK_DIR/xdg-terminals.list"
    install_file "$WORK_DIR/xdg-terminals.list" "$CONFIG_HOME/xdg-terminals.list"
}

context() {
    local source="$WORK_DIR/nautilus-open-any-terminal-$PLUGIN_VERSION"
    local schemas="$DATA_HOME/glib-2.0/schemas"
    local staged="$WORK_DIR/plugin/share" file relative
    curl -fL --retry 3 "https://github.com/Stunkymonkey/nautilus-open-any-terminal/archive/refs/tags/$PLUGIN_VERSION.tar.gz" -o "$WORK_DIR/context.tar.gz"
    tar -xzf "$WORK_DIR/context.tar.gz" -C "$WORK_DIR"
    make -C "$source"
    make -C "$source" install-nautilus "DESTDIR=$WORK_DIR/plugin" PREFIX=
    while IFS= read -r -d '' file; do
        relative="${file#"$staged/"}"
        install_file "$file" "$DATA_HOME/$relative"
    done < <(find "$staged" -type f -print0)
    glib-compile-schemas "$schemas"
    GSETTINGS_SCHEMA_DIR="$schemas" save_settings "$PLUGIN_SCHEMA"
    local key value
    while read -r key value; do
        GSETTINGS_SCHEMA_DIR="$schemas" gsettings set "$PLUGIN_SCHEMA" "$key" "$value"
    done <<'EOF'
terminal kitty
use-generic-terminal-name false
new-tab false
flatpak off
keybindings <Ctrl><Alt>t
EOF
    printf 'Context menu installed. Log out and back in to load the extension and updated PATH.\n'
}

config() {
    install_file "$SCRIPT_DIR/kitty.conf" "$CONFIG_HOME/kitty/kitty.conf"
    install_file "$FONT_FILE" "$DATA_HOME/fonts/$(basename -- "$FONT_FILE")"
    fc-cache -f "$DATA_HOME/fonts"
}

main() {
    parse_args "$@"
    if [[ "$MODE" == tui ]] && ((!DRY_RUN)); then select_steps; fi
    local index count=0 total=0
    for index in "${!STEP_IDS[@]}"; do
        if ((SELECTED[index])); then
            total=$((total + 1))
            printf '  [%s] %s\n' "${STEP_IDS[index]}" "${STEP_LABELS[index]}"
        fi
    done
    ((total)) || { log 'No steps selected.'; return; }
    if ((DRY_RUN)); then log 'Preview complete. No installation or configuration changes were made.'; return; fi
    preflight
    WORK_DIR="$(mktemp -d)"
    install_dependencies
    # PATH comes before desktop integrations regardless of the menu order.
    for index in 0 2 1 3 4 5; do
        if ((SELECTED[index])); then
            count=$((count + 1)); CURRENT_STEP="${STEP_IDS[index]}"
            log "[$count/$total] ${STEP_LABELS[index]}"
            "${STEP_IDS[index]}"
        fi
    done
    log 'All selected steps completed. New terminals load the updated config. Log out and back in to activate the desktop PATH and context menu.'
    [[ -z "$BACKUP_DIR" ]] || printf 'Original configuration backup: %s\n' "$BACKUP_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
