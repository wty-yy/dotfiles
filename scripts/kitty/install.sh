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
FONT_VERSION=3.5.1
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v$FONT_VERSION/CascadiaCode.zip"
PLUGIN_VERSION=0.8.3
PLUGIN_SCHEMA=com.github.stunkymonkey.nautilus-open-any-terminal
STEP_IDS=(download desktop path shortcut context config)
STEP_LABELS=('Download / update the latest stable Kitty release' 'Register menu icons and launchers' 'Add kitty and kitten to PATH' 'Set Ctrl+Alt+T and the default terminal' 'Add the Open Kitty Here context menu' 'Replace Kitty config and install the bundled font (with backup)')
UNINSTALL_LABEL='Uninstall Kitty and revert the changes made by this script'
SELECTED=(1 1 1 1 1 1)
MODE=tui
DRY_RUN=0
WORK_DIR=''
BACKUP_DIR=''
BACKUP_DIRS=()
UNINSTALL=0
ASSUME_YES=0
CURRENT_STEP=preflight

log() { printf '\n%s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }
cleanup() { [[ -z "$WORK_DIR" ]] || rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT
trap 'printf "\nStep %s failed at line %s. Resolve the error and rerun the script.\n" "$CURRENT_STEP" "$LINENO" >&2' ERR

usage() {
    cat <<'EOF'
Usage: ./install.sh [--all | --steps download,desktop,path,shortcut,context,config] [--dry-run]
       ./install.sh --uninstall [--yes]

The TUI selects all six steps by default. Toggle by number; Enter starts; q exits.
Option 7 selects uninstall instead of the installation steps.
  --all          Select all steps without opening the selection screen
  --steps LIST   Run only the listed steps in dependency order
  --uninstall    Remove Kitty and revert this script's changes
  --yes, -y      Skip the uninstall confirmation prompt
  --dry-run      Preview the plan without downloads, installation, or changes
  -h, --help     Show this help

Run as your Ubuntu GNOME desktop user. Do not run the entire script with sudo.
EOF
}

parse_args() {
    while (($#)); do
        case "$1" in
            --all)
                ((UNINSTALL)) && die '--uninstall cannot be combined with --all or --steps'
                MODE=all; SELECTED=(1 1 1 1 1 1) ;;
            --steps)
                ((UNINSTALL)) && die '--uninstall cannot be combined with --all or --steps'
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
            --uninstall)
                [[ "$MODE" == tui ]] || die '--uninstall cannot be combined with --all or --steps'
                UNINSTALL=1; MODE=uninstall ;;
            --yes|-y) ASSUME_YES=1 ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown argument: $1" ;;
        esac
        shift
    done
    ((ASSUME_YES && !UNINSTALL)) && die '--yes is only valid with --uninstall'
    return 0
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
        mark=' '; ((UNINSTALL)) && mark=x
        printf '  %s. [%s] %s\n' "$((${#STEP_IDS[@]} + 1))" "$mark" "$UNINSTALL_LABEL"
        printf '\n  1-7 toggle | a select all | n clear all | Enter start | q quit\n'
        printf '  Existing files are backed up; dependencies follow the selected steps.\n\n> '
        IFS= read -r input || exit 0
        case "$input" in
            [1-6]) index=$((input - 1)); SELECTED[index]=$((1 - SELECTED[index])); UNINSTALL=0 ;;
            7) UNINSTALL=$((1 - UNINSTALL)); ((UNINSTALL)) && SELECTED=(0 0 0 0 0 0) ;;
            a|A) SELECTED=(1 1 1 1 1 1); UNINSTALL=0 ;;
            n|N) SELECTED=(0 0 0 0 0 0); UNINSTALL=0 ;;
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
        [[ -f "$SCRIPT_DIR/kitty.conf" ]] || die 'Missing kitty.conf. Keep it next to install.sh.'
    fi
}

install_dependencies() {
    local packages=() missing=() package
    ((SELECTED[0] || SELECTED[4])) && packages+=(curl ca-certificates xz-utils)
    ((SELECTED[1])) && packages+=(python3 desktop-file-utils)
    ((SELECTED[3])) && packages+=(libglib2.0-bin)
    ((SELECTED[4])) && packages+=(python3-nautilus gir1.2-gtk-4.0 libglib2.0-bin gettext make)
    if ((SELECTED[5])); then
        packages+=(fontconfig)
        [[ -f "$FONT_FILE" ]] || packages+=(curl ca-certificates unzip)
    fi
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
    if [[ -f "$FONT_FILE" ]]; then
        install_file "$FONT_FILE" "$DATA_HOME/fonts/$(basename -- "$FONT_FILE")"
    else
        log "Repository font not found. Downloading CaskaydiaCove Nerd Font v$FONT_VERSION."
        curl -fL --retry 3 "$FONT_URL" -o "$WORK_DIR/font.zip"
        unzip -qo "$WORK_DIR/font.zip" 'CaskaydiaCoveNerdFont-*.ttf' -d "$WORK_DIR/font"
        local font
        for font in "$WORK_DIR"/font/CaskaydiaCoveNerdFont-*.ttf; do
            install_file "$font" "$DATA_HOME/fonts/$(basename -- "$font")"
        done
    fi
    fc-cache -f "$DATA_HOME/fonts"
}

load_backup_dirs() {
    local dir
    for dir in "$STATE_HOME/kitty-setup/backups"/*/; do
        if [[ -d "$dir" ]]; then
            BACKUP_DIRS+=("$dir")
        fi
    done
}

find_backup_entry() {
    local relative="$1" dir found=''
    for dir in "${BACKUP_DIRS[@]}"; do
        if [[ -e "$dir$relative" || -L "$dir$relative" ]]; then
            found="$dir$relative"
        fi
    done
    printf '%s' "$found"
}

restore_or_remove() {
    local target="$1" entry mode
    entry="$(find_backup_entry "files$target")"
    if [[ -n "$entry" ]]; then
        backup_file "$target"
        mode="$(stat -c %a -- "$entry")"
        install -Dm "$mode" -- "$entry" "$target"
        printf 'Restored %s\n' "$target"
    elif [[ -e "$target" || -L "$target" ]]; then
        backup_file "$target"
        rm -f -- "$target"
        printf 'Removed %s\n' "$target"
    fi
}

remove_bin_link() {
    local link="$1" expected="$2" entry
    if [[ -L "$link" && "$(readlink -- "$link")" == "$expected" ]]; then
        entry="$(find_backup_entry "files$link")"
        backup_file "$link"
        rm -f -- "$link"
        if [[ -n "$entry" ]]; then
            cp -a -- "$entry" "$link"
            printf 'Restored %s\n' "$link"
        else
            printf 'Removed %s\n' "$link"
        fi
    fi
}

remove_shell_path() {
    local rc="$1" snippet tmp
    [[ -f "$rc" ]] || return 0
    snippet='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
    grep -qF -- "$snippet" "$rc" || return 0
    backup_file "$rc"
    tmp="$(mktemp)"
    grep -vxF -e "$snippet" -e '# Kitty setup: user executables' -- "$rc" > "$tmp" || true
    install -m "$(stat -c %a -- "$rc")" -- "$tmp" "$rc"
    rm -f -- "$tmp"
    printf 'Cleaned PATH setup in %s\n' "$rc"
}

restore_gsettings() {
    local schema="$1" entry
    entry="$(find_backup_entry "$schema.txt")"
    if [[ -n "$entry" ]]; then
        while read -r name key value; do
            gsettings set "$name" "$key" "$value" || true
        done < "$entry"
        printf 'Restored GNOME settings: %s\n' "$schema"
        return 0
    fi
    case "$schema" in
        org.gnome.desktop.default-applications.terminal)
            gsettings reset "$schema" exec || true
            gsettings reset "$schema" exec-arg || true ;;
        org.gnome.settings-daemon.plugins.media-keys)
            gsettings reset "$schema" terminal || true ;;
    esac
    return 0
}

uninstall_context() {
    local schemas="$DATA_HOME/glib-2.0/schemas" mo
    if [[ -f "$schemas/$PLUGIN_SCHEMA.gschema.xml" ]] && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && command -v gsettings >/dev/null; then
        GSETTINGS_SCHEMA_DIR="$schemas" gsettings reset-recursively "$PLUGIN_SCHEMA" 2>/dev/null || true
    fi
    restore_or_remove "$DATA_HOME/nautilus-python/extensions/nautilus_open_any_terminal.py"
    restore_or_remove "$schemas/$PLUGIN_SCHEMA.gschema.xml"
    for mo in "$DATA_HOME"/locale/*/LC_MESSAGES/nautilus-open-any-terminal.mo; do
        if [[ -e "$mo" ]]; then
            restore_or_remove "$mo"
        fi
    done
    if [[ -d "$schemas" ]] && command -v glib-compile-schemas >/dev/null; then
        glib-compile-schemas "$schemas"
    fi
    rmdir -- "$DATA_HOME/nautilus-python/extensions" "$DATA_HOME/nautilus-python" 2>/dev/null || true
    printf 'Context menu integration removed.\n'
}

uninstall_shortcut() {
    local file="$CONFIG_HOME/xdg-terminals.list" tmp entry previous=''
    if [[ -f "$file" ]]; then
        backup_file "$file"
        tmp="$(mktemp)"
        grep -vxF 'kitty.desktop' -- "$file" > "$tmp" || true
        if grep -q '[^[:space:]]' -- "$tmp"; then
            install -m "$(stat -c %a -- "$file")" -- "$tmp" "$file"
        else
            rm -f -- "$file"
        fi
        rm -f -- "$tmp"
    fi
    entry="$(find_backup_entry 'x-terminal-emulator.txt')"
    if [[ -n "$entry" ]]; then
        previous="$(sed -n 's/^Value: //p' "$entry" | head -n 1)"
    fi
    sudo update-alternatives --remove x-terminal-emulator "$KITTY_APP/bin/kitty" || true
    if [[ -n "$previous" && "$previous" != "$KITTY_APP/bin/kitty" && -x "$previous" ]]; then
        sudo update-alternatives --set x-terminal-emulator "$previous"
    fi
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && command -v gsettings >/dev/null; then
        restore_gsettings org.gnome.desktop.default-applications.terminal
        restore_gsettings org.gnome.settings-daemon.plugins.media-keys
    else
        printf 'No desktop session detected; skipped GNOME terminal settings.\n'
    fi
}

uninstall_path() {
    local executable rc
    for executable in kitty kitten; do
        remove_bin_link "$BIN_DIR/$executable" "$KITTY_APP/bin/$executable"
    done
    for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zprofile" "$HOME/.zshrc"; do
        remove_shell_path "$rc"
    done
}

uninstall_desktop() {
    local filename
    for filename in kitty.desktop kitty-open.desktop; do
        restore_or_remove "$DATA_HOME/applications/$filename"
    done
    if command -v update-desktop-database >/dev/null; then
        update-desktop-database "$DATA_HOME/applications" 2>/dev/null || true
    fi
}

uninstall_config() {
    local bundled font
    restore_or_remove "$CONFIG_HOME/kitty/kitty.conf"
    rmdir -- "$CONFIG_HOME/kitty" 2>/dev/null || true
    bundled="$DATA_HOME/fonts/$(basename -- "$FONT_FILE")"
    restore_or_remove "$bundled"
    for font in "$DATA_HOME"/fonts/CaskaydiaCoveNerdFont-*.ttf; do
        if [[ -e "$font" ]]; then
            restore_or_remove "$font"
        fi
    done
    if [[ -d "$DATA_HOME/fonts" ]] && command -v fc-cache >/dev/null; then
        fc-cache -f "$DATA_HOME/fonts" >/dev/null
    fi
}

uninstall_download() {
    if [[ -d "$KITTY_APP" ]]; then
        rm -rf -- "$KITTY_APP"
        printf 'Removed %s\n' "$KITTY_APP"
    fi
}

preflight_uninstall() {
    ((EUID != 0)) || die 'Run as a regular desktop user; the script uses sudo when needed.'
    [[ "$(uname -s)" == Linux && -f /etc/os-release ]] || die 'Only Ubuntu GNOME is supported.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "$ID" == ubuntu ]] || die 'This script requires Ubuntu GNOME.'
}

confirm_uninstall() {
    local answer
    printf "This removes Kitty and reverts this script's changes. Type yes to continue: "
    IFS= read -r answer || true
    [[ "$answer" == yes ]] || die 'Uninstall cancelled.'
}

uninstall() {
    CURRENT_STEP=uninstall
    load_backup_dirs
    uninstall_context
    uninstall_shortcut
    uninstall_path
    uninstall_desktop
    uninstall_config
    uninstall_download
    log 'Uninstall complete. Log out and back in to finish removing the desktop integration.'
    [[ -z "$BACKUP_DIR" ]] || printf 'Safety backup of removed files: %s\n' "$BACKUP_DIR"
}

uninstall_main() {
    if ((DRY_RUN)); then
        printf '  [uninstall] %s\n' "$UNINSTALL_LABEL"
        log 'Preview complete. No installation or configuration changes were made.'
        return 0
    fi
    preflight_uninstall
    ((ASSUME_YES)) || confirm_uninstall
    uninstall
}

main() {
    parse_args "$@"
    if [[ "$MODE" == tui ]] && ((!DRY_RUN)); then select_steps; fi
    if ((UNINSTALL)); then uninstall_main; return; fi
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
