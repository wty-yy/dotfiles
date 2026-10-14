#!/bin/bash
# macOS Kitty setup. Compatible with the system Bash 3.2; run without sudo.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/Applications"
KITTY_APP="$APP_DIR/kitty.app"
BIN_DIR="$HOME/.local/bin"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
FONT_DIR="$HOME/Library/Fonts"
FONT_FILE="$SCRIPT_DIR/../../fonts/Caskaydia Cove Nerd Font Complete.ttf"
FONT_VERSION=3.5.1
WORK_DIR=''
BACKUP_DIR=''
DRY_RUN=0

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
cleanup() { [[ -z "$WORK_DIR" ]] || rm -rf "$WORK_DIR"; }
trap cleanup EXIT
trap 'printf "Installation failed at line %s.\n" "$LINENO" >&2' ERR

usage() {
    cat <<'EOF'
Usage: ./install-macos.sh [--all] [--dry-run]

Install/update Kitty using the official installer, without Homebrew or sudo.
  --all       Install everything (the default)
  --dry-run   Show the plan without downloads or filesystem changes
  -h, --help  Show this help

Application: ~/Applications/kitty.app
Commands:    ~/.local/bin/kitty and ~/.local/bin/kitten
Config:      ${XDG_CONFIG_HOME:-~/.config}/kitty/kitty.conf
Fonts:       ~/Library/Fonts
Backups:     ~/Library/Application Support/kitty-setup/backups

Existing application/configuration/font files and replaced command links are
backed up. PATH is added to ~/.zprofile (or $ZDOTDIR/.zprofile) and
~/.bash_profile. Restart your terminal after installation.
EOF
}

backup() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -z "$BACKUP_DIR" ]]; then
            mkdir -p "$HOME/Library/Application Support/kitty-setup/backups"
            BACKUP_DIR="$(mktemp -d "$HOME/Library/Application Support/kitty-setup/backups/$(date +%Y%m%d-%H%M%S).XXXXXX")"
            printf 'Backup directory: %s\n' "$BACKUP_DIR"
        fi
        mkdir -p "$BACKUP_DIR$(dirname "$target")"
        cp -pPR "$target" "$BACKUP_DIR$target"
    fi
}

install_file() {
    local source="$1" target="$2"
    [[ ! -d "$target" ]] || die "Cannot replace directory: $target"
    if [[ -f "$target" && ! -L "$target" ]] && cmp -s "$source" "$target"; then return; fi
    backup "$target"
    mkdir -p "$(dirname "$target")"
    [[ ! -L "$target" ]] || rm "$target"
    install -m 644 "$source" "$target"
}

configure_path() {
    local rc="$1" snippet
    snippet='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
    if ! grep -Fqx "$snippet" "$rc" 2>/dev/null; then
        backup "$rc"
        mkdir -p "$(dirname "$rc")"
        printf '\n# Kitty setup: user executables\n%s\n' "$snippet" >> "$rc"
    fi
}

main() {
    while (($#)); do
        case "$1" in
            --all) ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; return ;;
            *) die "Unknown argument: $1" ;;
        esac
        shift
    done
    printf 'Install/update: %s\nCommands: %s\nConfig: %s/kitty/kitty.conf\nFonts: %s\n' \
        "$KITTY_APP" "$BIN_DIR" "$CONFIG_HOME" "$FONT_DIR"
    if ((DRY_RUN)); then
        printf 'Back up existing files; configure zsh/bash login PATH. No changes made.\n'
        return
    fi
    [[ "$(uname -s)" == Darwin ]] || die 'Only macOS is supported.'
    ((EUID != 0)) || die 'Run as a regular user, without sudo.'
    [[ "$CONFIG_HOME" == /* && "${ZDOTDIR:-$HOME}" == /* ]] || die 'XDG_CONFIG_HOME and ZDOTDIR must be absolute paths.'
    [[ -f "$SCRIPT_DIR/kitty.conf" ]] || die 'Keep kitty.conf next to this script.'
    local executable font
    for executable in curl unzip; do
        command -v "$executable" >/dev/null || die "Missing command: $executable"
    done
    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kitty-setup.XXXXXX")"
    printf 'Downloading the latest stable Kitty release...\n'
    curl -fL --retry 3 https://sw.kovidgoyal.net/kitty/installer.sh -o "$WORK_DIR/installer.sh"
    # Stage and check the download before replacing an existing application.
    sh "$WORK_DIR/installer.sh" "dest=$WORK_DIR" launch=n
    for executable in kitty kitten; do
        [[ -x "$WORK_DIR/kitty.app/Contents/MacOS/$executable" ]] || die "Missing executable: $executable"
    done
    "$WORK_DIR/kitty.app/Contents/MacOS/kitty" --version
    backup "$KITTY_APP"
    mkdir -p "$APP_DIR" "$BIN_DIR"
    if [[ -e "$KITTY_APP" || -L "$KITTY_APP" ]]; then rm -rf "$KITTY_APP"; fi
    mv "$WORK_DIR/kitty.app" "$KITTY_APP"
    for executable in kitty kitten; do
        if [[ "$(readlink "$BIN_DIR/$executable" 2>/dev/null || true)" != "$KITTY_APP/Contents/MacOS/$executable" ]]; then
            [[ ! -d "$BIN_DIR/$executable" ]] || die "Cannot replace directory: $BIN_DIR/$executable"
            backup "$BIN_DIR/$executable"
            ln -sfn "$KITTY_APP/Contents/MacOS/$executable" "$BIN_DIR/$executable"
        fi
    done
    configure_path "${ZDOTDIR:-$HOME}/.zprofile"
    configure_path "$HOME/.bash_profile"
    install_file "$SCRIPT_DIR/kitty.conf" "$CONFIG_HOME/kitty/kitty.conf"
    if [[ -f "$FONT_FILE" ]]; then
        install_file "$FONT_FILE" "$FONT_DIR/$(basename "$FONT_FILE")"
    else
        curl -fL --retry 3 "https://github.com/ryanoasis/nerd-fonts/releases/download/v$FONT_VERSION/CascadiaCode.zip" -o "$WORK_DIR/font.zip"
        unzip -qo "$WORK_DIR/font.zip" 'CaskaydiaCoveNerdFont-*.ttf' -d "$WORK_DIR/fonts"
        for font in "$WORK_DIR"/fonts/CaskaydiaCoveNerdFont-*.ttf; do
            install_file "$font" "$FONT_DIR/$(basename "$font")"
        done
    fi
    printf 'Installation complete. Open ~/Applications/kitty.app; restart your terminal to load PATH.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
