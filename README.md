# Quickshell Floating LyricBar (Liquid Glass)

An elegant, modern floating synced lyric bar built with **Quickshell** for Wayland / Hyprland desktops. Features **Apple Liquid Glass** (`hyprglass`) hardware refraction effects, dynamic content-driven auto-resizing per second, fluid spring/cubic easing transitions, instant real-time theme & color synchronization, comprehensive YouTube Music & browser support, and a built-in Settings & Keybinds configuration modal.

---

## Preview

![Quickshell Floating LyricBar Preview](assets/preview.png)

*Floating liquid glass lyric capsule displaying live synchronized lyrics with artist pill, playback controls, and synced pulse indicator.*

![Settings and Keybindings Modal](assets/settings.png)

*Interactive Liquid Glass Settings & Keybinds modal with quick behavior toggles, keybinds reference, and Hyprland bind synchronization.*

![Compact Mini Pill Mode](assets/compact.png)

*Compact mini-pill mode with music note icon and fluid expanding/compressing bounce animation.*

---

## One-Line Installer

Install directly into your Quickshell environment with a single command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/DX4GREY/quickshell-lyricbar/main/install.sh)"
```

### Or Install Locally:

```bash
git clone https://github.com/DX4GREY/quickshell-lyricbar.git
cd quickshell-lyricbar
./install.sh
```

The installer will:
1. Verify system dependencies (`quickshell`, `python3`, `dbus` / `playerctl`).
2. Install component files to `~/.config/quickshell/lyricbar/`.
3. Create the `quickshell-lyricbar` executable wrapper in `~/.local/bin/`.
4. Automatically configure the `hyprglass` composition layer rule in `~/.config/hypr/custom/general.lua`.
5. Preserve custom settings in `config.json`.

---

## Features

- **Liquid Glass Integration (`hyprglass`):**
  - Fully mapped to the `quickshell:lyricbar` layer shell namespace using the Apple Liquid Glass `pomme` preset.
  - Realistic frosted translucency, specular rim highlight at the top edge, and interactive 3D parallax tilt on mouse hover.
- **Dynamic Content-Driven Auto-Resize:**
  - Connects to any MPRIS media player: Spotify, YouTube Music, Amberol, MPD, VLC, Chrome, Firefox, Cider, etc.
  - Fetches synchronized `.lrc` timestamps via [LRCLIB.net](https://lrclib.net) or local audio folders.
  - Container width smoothly expands and contracts based on the exact character width of each active lyric line.
- **YouTube Music & Browser Media Support:**
  - Full support for YouTube Music and YouTube running in Google Chrome, Chromium, Mozilla Firefox, Brave, and Zen Browser.
  - Automatic metadata cleaning: strips video suffixes (`Official Music Video`, `Lyric Video`, `Visualizer`, `4K`, `MV`, etc.), YouTube Topic tags (`- Topic`), `VEVO` channel suffixes, and browser headers.
  - Splits compound video titles (`Artist - Song Title`) into exact artist and track parameters to query synchronized LRC timestamps accurately.
  - Safe MPRIS position querying prevents browser DBus exceptions from interrupting playback tracking.
- **Fluid Dimension & Text Transitions:**
  - **Fluid Resize:** Card width smoothly glides with `Easing.OutCubic` curve without abrupt resizing or snapping.
  - **Subtitle-style Transition:** Lyric text changes using a delicate cross-fade (`opacity 0.0 -> 1.0`) combined with a vertical slide (`y: -7px -> 0px`).
- **High Text Legibility & Click-Through Mask:**
  - Crisp native rendering (`Text.NativeRendering`), bold weights, and contrast outline protection to ensure readability over any bright or dark wallpaper.
  - Transparent click mask (`Region`) ensures that only the visible capsule and open modal capture mouse clicks, while all surrounding areas remain 100% click-through.
- **Real-Time Reactive Theme Sync:**
  - Re-evaluates live colors from `~/.cache/43pr/quickshell-theme.json` and `~/.local/state/quickshell/user/generated/colors.json`.
  - When you switch wallpapers or generate new palettes via Matugen / 43PR, all colors smoothly cross-fade to the new palette without restarting.
- **Interactive Settings & Keybinds Modal:**
  - Open the settings card directly via the gear icon or pressing `SUPER + CTRL + Y`.
  - Toggle behavior options (Auto-Hide on playback stop, Demo mode simulation).
  - Sync recommended keybindings directly to Hyprland with one click.
  - Non-conflicting shortcut scheme (`SUPER + Y` family) preserves system shortcuts like screen locking (`SUPER + L`).
  - Persistent user preferences saved in `~/.config/quickshell/lyricbar/config.json`.
- **Interactive Media Controls:**
  - **Play / Pause**: Click the disc / play-pause button (`playerctl play-pause`).
  - **Volume Control**: Scroll the mouse wheel over the capsule (`playerctl volume +/-`).
  - **Next / Previous Track**: Right-click for Next track; Middle-click for Previous track.
  - **Mini Pill Mode**: Minimize into a compact glass disc with music icon; click to expand back.
  - **Lyric Pulse Dot**: Subtle pulsing dot indicates active real-time synchronized lyrics.

---

## Settings & Keybindings

### 1. Opening Settings
You can open or close the settings modal in multiple ways:
- Click the gear icon on the right side of the floating bar.
- Press `SUPER + CTRL + Y` (configured in Hyprland).
- Run IPC command: `qs -c lyricbar ipc call lyricbar toggleSettings`.

### 2. Recommended Keybindings Scheme
To avoid conflicting with Hyprland default desktop shortcuts (such as `SUPER + L` which is assigned to `loginctl lock-session`), LyricBar uses the `Y` key series:

- **`SUPER + Y`** : Toggle LyricBar visibility
- **`SUPER + ALT + Y`** : Toggle Compact Mini-Pill mode
- **`SUPER + CTRL + Y`** : Toggle Settings & Keybinds modal

### 3. Available Settings
- **Auto-Hide (ON / OFF):** Automatically conceals the lyric bar when music is stopped or paused, reappearing immediately when playback resumes.
- **Demo Mode (ON / OFF):** Toggles between live MPRIS media listening and the internal synchronized demo player for testing.
- **Sync Hyprland Binds:** Appends recommended hotkeys into `~/.config/hypr/custom/keybinds.lua` if not already present.

### 4. Persistent Configuration
Settings are saved to `~/.config/quickshell/lyricbar/config.json`:

```json
{
  "autoHideOnStop": false,
  "anchorTop": false,
  "demoMode": false
}
```

---

## How to Run

After installation, you can launch LyricBar from anywhere:

```bash
# Run in foreground (interactive)
quickshell-lyricbar

# Run in background (daemon)
quickshell-lyricbar --background

# Run in Demo mode (test animations with sample synchronized song)
quickshell-lyricbar --demo

# Stop any running instances
quickshell-lyricbar --kill
```

You can also run it directly via the standard Quickshell CLI:
```bash
qs -c lyricbar
```

---

## Hyprland Integration

### 1. Autostart on Login
Add this line to your `~/.config/hypr/hyprland/execs.lua` or `hyprland.conf`:

```lua
-- Autostart Quickshell LyricBar
exec-once = quickshell-lyricbar --background
```

### 2. Keybindings & IPC Controls
Add hotkeys to your `~/.config/hypr/custom/keybinds.lua` (or use the "Sync Hyprland Binds" button in Settings):

```lua
-- Toggle LyricBar visibility (Super + Y)
hl.bind("SUPER + Y", hl.dsp.exec_cmd("qs -c lyricbar ipc --any-display call lyricbar toggle"), { description = "LyricBar: Toggle visibility" })

-- Toggle Compact Mini-Pill mode (Super + Alt + Y)
hl.bind("SUPER + ALT + Y", hl.dsp.exec_cmd("qs -c lyricbar ipc --any-display call lyricbar toggleMini"), { description = "LyricBar: Toggle mini pill" })

-- Toggle Settings Modal (Super + Ctrl + Y)
hl.bind("SUPER + CTRL + Y", hl.dsp.exec_cmd("qs -c lyricbar ipc --any-display call lyricbar toggleSettings"), { description = "LyricBar: Toggle settings" })
```

For standard `hyprland.conf` syntax without Lua:

```ini
bind = SUPER, Y, exec, qs -c lyricbar ipc --any-display call lyricbar toggle
bind = SUPER ALT, Y, exec, qs -c lyricbar ipc --any-display call lyricbar toggleMini
bind = SUPER CTRL, Y, exec, qs -c lyricbar ipc --any-display call lyricbar toggleSettings
bind = , XF86AudioPlay, exec, qs -c lyricbar ipc --any-display call lyricbar playPause
```

### 3. IPC Commands Reference
| Command | Action |
| :--- | :--- |
| `qs -c lyricbar ipc call lyricbar toggle` | Toggle visibility of the LyricBar |
| `qs -c lyricbar ipc call lyricbar show` | Show LyricBar |
| `qs -c lyricbar ipc call lyricbar hide` | Hide LyricBar |
| `qs -c lyricbar ipc call lyricbar toggleMini` | Toggle between full bar and compact mini pill |
| `qs -c lyricbar ipc call lyricbar toggleSettings` | Toggle Settings and Keybinds modal |
| `qs -c lyricbar ipc call lyricbar openSettings` | Open Settings modal |
| `qs -c lyricbar ipc call lyricbar closeSettings` | Close Settings modal |
| `qs -c lyricbar ipc call lyricbar playPause` | Toggle play / pause |
| `qs -c lyricbar ipc call lyricbar next` | Skip to next track |
| `qs -c lyricbar ipc call lyricbar prev` | Return to previous track |
| `qs -c lyricbar ipc call lyricbar applyHyprlandKeybinds` | Sync keybinds to Hyprland |
| `qs -c lyricbar ipc call lyrictheme reload` | Force immediate theme re-read |

---

## HyprGlass Configuration

The installer automatically ensures this rule is registered in `~/.config/hypr/custom/general.lua`:

```lua
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass
    -- Quickshell Floating LyricBar (Apple Liquid Glass)
    hg.layer("quickshell:lyricbar", { preset = "pomme", mask_threshold = 0.01, mask_feather = 0.45 })
end
```

---

## Uninstallation

To remove Quickshell LyricBar:

```bash
quickshell-lyricbar --kill
./install.sh --uninstall
```

---

## License

MIT License. Designed for Quickshell & Hyprland.
