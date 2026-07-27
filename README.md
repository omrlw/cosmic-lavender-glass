# COSMIC Lavender Glass

A bright, calm COSMIC desktop built around Catppuccin Latte Lavender, soft
glass surfaces, readable opaque application windows, and a floating dock that
stays compact when windows are maximized.

<p align="center">
  <a href="../../releases/download/v1.0.0/cosmic-lavender-glass-v1.0.0.zip">Complete ZIP</a>
  ·
  <a href="../../releases/download/v1.0.0/cosmic-lavender-glass.ron">RON theme</a>
  ·
  <a href="../../releases/download/v1.0.0/cosmic-lavender-glass-5120x1440.png">5120×1440 wallpaper</a>
  ·
  <a href="../../releases/download/v1.0.0/SHA256SUMS">Checksums</a>
</p>

> [!NOTE]
> This is an independent community project, not an official System76,
> Catppuccin, or MacTahoe release.

## Gallery

| Application library | Floating dock |
| --- | --- |
| ![COSMIC Lavender Glass application library](assets/desktop-preview.webp) | ![COSMIC Lavender Glass floating dock](assets/dock-preview.webp) |

The screenshots demonstrate the interface style on the author's working
desktop. The only wallpaper distributed by this repository is the original
lavender image included in `wallpapers/`.

## The look

- Catppuccin Latte Lavender color direction.
- Medium blur on the panel, applets, and system interface.
- Opaque application windows for comfortable reading and focused work.
- Rounded surfaces, 8 px inner window gaps, and a 3 px lavender active-window
  hint.
- Bottom floating dock at medium size and 90% opacity.
- A 4 px dock margin and padding with fully rounded corners.
- The dock never auto-hides, never expands to the screen edges, and keeps its
  floating style when a window is maximized.
- COSMIC's application list remains in the center of the dock.
- An original 5120×1440 lavender glass wallpaper suitable for dual 1440p
  displays.

## Palette

| Role | Color | Preview |
| --- | --- | --- |
| Background | `#EFF1F5` | ![#EFF1F5](https://placehold.co/24x24/EFF1F5/EFF1F5.png) |
| Lavender accent | `#7287FD` | ![#7287FD](https://placehold.co/24x24/7287FD/7287FD.png) |
| Text | `#202239` | ![#202239](https://placehold.co/24x24/202239/202239.png) |
| Neutral | `#ACB0BE` | ![#ACB0BE](https://placehold.co/24x24/ACB0BE/ACB0BE.png) |
| Success | `#40A02B` | ![#40A02B](https://placehold.co/24x24/40A02B/40A02B.png) |
| Warning | `#DF8E1D` | ![#DF8E1D](https://placehold.co/24x24/DF8E1D/DF8E1D.png) |
| Destructive | `#D20F39` | ![#D20F39](https://placehold.co/24x24/D20F39/D20F39.png) |

## Requirements

- COSMIC Desktop 1.4.0 or newer.
- `cosmic-settings`.
- Bash 4 or newer.
- Git and internet access only when MacTahoe is not already installed. Use
  `--skip-icons` for an offline installation.

The installer is user-scoped: it never calls `sudo`.

## Install

Download and extract the
[complete release ZIP](../../releases/download/v1.0.0/cosmic-lavender-glass-v1.0.0.zip),
then run:

```bash
chmod +x install.sh uninstall.sh
./install.sh
```

The default dock output is `all`, which is portable across single- and
multi-monitor systems. To pin it to one connector:

```bash
./install.sh --output DP-1
```

Available options:

```text
./install.sh [--output all|NAME] [--skip-icons] [--dry-run]
```

- `--skip-icons` preserves the current icon theme and avoids network access.
- `--dry-run` prints the operations without creating a backup or changing
  files.

Before writing anything, the installer creates a timestamped restore point in:

```text
~/.local/state/cosmic-lavender-glass/backups/
```

If a step fails, the installer restores that backup automatically. When
MacTahoe is needed, it is downloaded from the official repository at the
pinned commit listed in [third-party notices](THIRD_PARTY_NOTICES.md); its
large icon files are not bundled in this repository.

## Restore or uninstall

Restore the most recent active backup:

```bash
./uninstall.sh
```

List restore points or choose one:

```bash
./uninstall.sh --list-backups
./uninstall.sh --backup 20260727T120000Z
```

Preview the restoration:

```bash
./uninstall.sh --dry-run
```

The uninstaller restores only the COSMIC keys backed up by this project,
removes the project wallpaper copy, and removes MacTahoe only when that exact
installation was created by the selected install run. A pre-existing MacTahoe
installation is preserved.

## Manual setup

If you prefer to apply individual pieces:

1. Open **COSMIC Settings → Desktop → Appearance**.
2. Select **Import** and choose
   [`theme/cosmic-lavender-glass.ron`](theme/cosmic-lavender-glass.ron).
3. Copy
   [`wallpapers/cosmic-lavender-glass-5120x1440.png`](wallpapers/cosmic-lavender-glass-5120x1440.png)
   to your preferred user wallpaper directory and select it in COSMIC
   Settings.
4. In **Desktop → Panel**, configure the dock at the bottom with medium size,
   90% opacity, 4 px margin and padding, fully rounded corners, and **Never**
   auto-hide.
5. Disable **Expand to screen edges** and enable **Keep style when a window is
   maximized**.
6. Optionally install
   [MacTahoe](https://github.com/vinceliuice/MacTahoe-icon-theme) from its
   official repository and select `MacTahoe` as the COSMIC icon theme.

The installer intentionally leaves the top-panel layout and applet selection
untouched. Its glass appearance comes from the imported theme.

## What changes

The installer backs up and may update only these user configuration scopes:

```text
com.system76.CosmicTheme.Light.Builder
com.system76.CosmicTheme.Light
com.system76.CosmicTheme.Mode
com.system76.CosmicTk/v1/icon_theme
com.system76.CosmicPanel.Dock/v1
com.system76.CosmicBackground/v1/all
```

The wallpaper is copied to the XDG user data directory. When running inside a
COSMIC session, only `cosmic-panel` is restarted so the dock change appears
immediately.

## Troubleshooting

**The dock still stretches when a window is maximized**

Confirm these files contain `false` and `true`, respectively:

```bash
cat ~/.config/cosmic/com.system76.CosmicPanel.Dock/v1/expand_to_edges
cat ~/.config/cosmic/com.system76.CosmicPanel.Dock/v1/keep_style_on_maximize
```

Then restart only the panel:

```bash
pkill -TERM -x cosmic-panel
```

COSMIC Session should start it again automatically.

**The dock appears on the wrong monitor**

Find the connector name in **COSMIC Settings → Displays**, then reinstall with
`./install.sh --output NAME`. Use `--output all` to return to the portable
default.

**The wallpaper does not load**

Make sure the installed PNG still exists under
`${XDG_DATA_HOME:-$HOME/.local/share}/backgrounds/cosmic-lavender-glass/`.
Running the installer again creates a fresh backup before repairing it.

**MacTahoe download fails**

Check the network connection, retry later, or run `./install.sh --skip-icons`.
The remaining theme, wallpaper, and dock configuration work without MacTahoe.

**I want my exact old desktop back**

Use `./uninstall.sh --list-backups`, then restore the wanted ID with
`./uninstall.sh --backup ID`.

## Development and verification

```bash
bash -n install.sh uninstall.sh lib/common.sh tests/integration.sh
shellcheck install.sh uninstall.sh lib/common.sh tests/integration.sh
tests/integration.sh
```

CI runs syntax checks, ShellCheck, and isolated temporary-HOME integration
tests for clean installation, preinstalled icons, offline mode, custom output,
dry run, failure rollback, and uninstall restoration.

## Credits and licenses

The palette and theme workflow credit
[Catppuccin for COSMIC](https://github.com/catppuccin/cosmic-desktop) at commit
[`95e8109`](https://github.com/catppuccin/cosmic-desktop/commit/95e81098042dd2102f0b258f6990f886c5759692).
Optional icons come from
[MacTahoe](https://github.com/vinceliuice/MacTahoe-icon-theme) at commit
[`77eebfc`](https://github.com/vinceliuice/MacTahoe-icon-theme/commit/77eebfcdb5bf7074a2877eaee63f1bf48a994d5e).

- Scripts and configuration: [MIT](LICENSE)
- Original wallpaper: [CC BY 4.0](LICENSE-WALLPAPER)
- Dependencies and attribution: [Third-party notices](THIRD_PARTY_NOTICES.md)
