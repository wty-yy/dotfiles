<div align="center">
  <h1>Kitty Setup</h1>
  <p><strong>Kitty installation and desktop integration for Ubuntu GNOME</strong></p>
  <p><strong>🌎 English</strong>&nbsp;&nbsp;·&nbsp;&nbsp;<a href="README.zh-CN.md">🇨🇳 中文</a></p>
</div>

## Usage

Clone the complete dotfiles repository on the new machine. Run as a regular user in an Ubuntu GNOME desktop terminal. System dependencies and the default terminal setting use `sudo` when needed.

```bash
cd ~/Coding/GitHub/dotfiles/scripts/kitty
./install.sh
# Toggle 1–6; a selects all; n clears all; Enter starts; q exits

./install.sh --all --dry-run  # Preview all steps without changes
./install.sh --all           # Install everything without the selection screen
./install.sh --steps desktop,path,shortcut
./install.sh --steps config  # Only replace the configuration and install the font
```

## Installation steps

All six options are selected by default. Required dependencies are installed first, followed by download, PATH, menu entries, shortcut, context menu, and configuration.

| Step | Action |
| --- | --- |
| `download` | Install or update the latest stable release in `~/.local/kitty.app` using the official installer, without opening a window |
| `desktop` | Register `kitty.desktop` and `kitty-open.desktop`, set icons and absolute executable paths, and refresh the menu cache |
| `path` | Link `kitty` and `kitten` into `~/.local/bin`; add deduplicated PATH setup to `.profile`, `.bashrc`, `.zprofile`, and `.zshrc` |
| `shortcut` | Set Kitty as `x-terminal-emulator`, configure GNOME's `Ctrl+Alt+T`, and put `kitty.desktop` first in `xdg-terminals.list` |
| `context` | Install `nautilus-open-any-terminal` 0.8.3 and dependencies; configure Open Kitty Here to open a new window in the current directory |
| `config` | Replace the configuration with the bundled `kitty.conf` and install CaskaydiaCove Nerd Font from the repository's `fonts/` directory |

When `download` is unchecked, desktop integration steps require Kitty in the official installation directory. Installing the context menu alone requires an existing `kitty` command or selecting `path` too. The shortcut and context menu steps require a running GNOME desktop session.

Menu registration adds an application launcher; pinning it to the Dock is a manual GNOME action. `kitty-open.desktop` also registers file and URL handling capabilities. `shortcut` changes the system default terminal and may affect other users. Remove any conflicting custom `Ctrl+Alt+T` binding in GNOME Settings.

## Configuration and backups

- `kitty.conf` contains the current machine's complete configuration and can be edited in the repository.
- Settings include a 15-point font, copy on selection, a top tab bar, tab switching, and a fullscreen shortcut.
- Existing files are backed up before replacement to `${XDG_STATE_HOME:-~/.local/state}/kitty-setup/backups/timestamp.random-suffix/`; identical files are left untouched.
- `files/` preserves original absolute paths; GNOME settings and the previous default terminal are saved separately as text snapshots.
- User configuration and data follow `XDG_CONFIG_HOME` and `XDG_DATA_HOME`. The application always installs in `~/.local/kitty.app`.
- Log out and back in to activate the desktop PATH and Nautilus extension. New Kitty windows load the new configuration.
- Run `download` again to update Kitty. No background auto-update is configured.

References: [Kitty installation and desktop integration](https://sw.kovidgoyal.net/kitty/binary/), [Nautilus extension](https://github.com/Stunkymonkey/nautilus-open-any-terminal).
