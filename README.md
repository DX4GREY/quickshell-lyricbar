# Quickshell Floating LyricBar 🎵 (Liquid Glass)

An elegant, modern floating synced lyric bar built with **Quickshell** for Wayland / Hyprland desktops. Features **Apple Liquid Glass** (`hyprglass`) hardware refraction effects, dynamic content-driven auto-resizing per second, fluid spring/cubic easing transitions, and instant real-time theme & color synchronization.

---

## 📸 Preview

![Quickshell Floating LyricBar Preview](assets/preview.png)

*Floating liquid glass lyric capsule displaying live synced lyrics with artist pill, playback controls, and synced pulse indicator.*

![Compact Mini Pill Mode](assets/compact.png)

*Compact mini-pill mode with music note icon and fluid expanding/compressing bounce animation.*

---

## ⚡ One-Line Installer

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

---

## ✨ Features

- **Liquid Glass Integration (`hyprglass`):**
  - Fully mapped to the `quickshell:lyricbar` layer shell namespace using the Apple Liquid Glass `pomme` preset.
  - Realistic frosted translucency, specular rim highlight at the top edge, and interactive 3D parallax tilt on mouse hover.
- **Dynamic Content-Driven Auto-Resize:**
  - Connects to any MPRIS media player (Spotify, Amberol, MPD, VLC, Chrome, Firefox, Cider, etc.).
  - Fetches synchronized `.lrc` timestamps via [LRCLIB.net](https://lrclib.net) or local audio folders.
  - Container width smoothly expands and contracts based on the exact character width of each active lyric line.
- **Fluid Dimension & Text Transitions:**
  - **Fluid Resize:** Card width smoothly glides with `Easing.OutCubic` curve — zero abrupt resizing or snapping.
  - **Subtitle-style Transition:** Lyric text changes using a delicate cross-fade (`opacity 0.0 → 1.0`) combined with a vertical slide (`y: -7px → 0px`).
- **High Text Legibility:**
  - Crisp native rendering (`Text.NativeRendering`), bold weights, and contrast outline protection to ensure readability over any bright or dark wallpaper.
  - Transparent click mask (`Region`) ensures that only the visible capsule captures mouse clicks, while all surrounding areas remain 100% click-through.
- **Real-Time Reactive Theme Sync:**
  - Re-evaluates live colors from `~/.cache/43pr/quickshell-theme.json` and `~/.local/state/quickshell/user/generated/colors.json`.
  - When you switch wallpapers or generate new palettes via Matugen / 43PR, all colors smoothly cross-fade to the new palette without restarting.
- **Interactive Media Controls:**
  - **Play / Pause**: Click the disc / play-pause button (`playerctl play-pause`).
  - **Volume Control**: Scroll the mouse wheel over the capsule (`playerctl volume +/-`).
  - **Next / Previous Track**: Right-click for Next track; Middle-click for Previous track.
  - **Mini Pill Mode**: Minimize into a compact glass disc with music icon; click to expand back.
  - **Lyric Pulse Dot**: Subtle pulsing dot indicates active real-time synchronized lyrics.

---

## 🚀 How to Run

After installation, you can launch the LyricBar from anywhere:

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

## ⌨️ Hyprland Integration

### 1. Autostart on Login
Add this line to your `~/.config/hypr/hyprland/execs.lua` or `hyprland.conf`:

```lua
-- Autostart Quickshell LyricBar
exec-once = quickshell-lyricbar --background
```

### 2. Keybindings & IPC Controls
Control the LyricBar using Quickshell IPC in your `hyprland.conf` or `custom/keybinds.lua`:

```lua
-- Toggle LyricBar visibility (Super + L)
bind = SUPER, L, exec, qs -c lyricbar ipc call lyricbar toggle

-- Toggle Compact Mini-Pill mode (Super + Alt + L)
bind = SUPER ALT, L, exec, qs -c lyricbar ipc call lyricbar toggleMini

-- Media controls
bind = , XF86AudioPlay, exec, qs -c lyricbar ipc call lyricbar playPause
```

### 3. IPC Commands Reference
| Command | Action |
| :--- | :--- |
| `qs -c lyricbar ipc call lyricbar toggle` | Toggle visibility of the LyricBar |
| `qs -c lyricbar ipc call lyricbar show` | Show LyricBar |
| `qs -c lyricbar ipc call lyricbar hide` | Hide LyricBar |
| `qs -c lyricbar ipc call lyricbar toggleMini` | Toggle between full bar and compact mini pill |
| `qs -c lyricbar ipc call lyricbar playPause` | Toggle play / pause |
| `qs -c lyricbar ipc call lyricbar next` | Skip to next track |
| `qs -c lyricbar ipc call lyricbar prev` | Return to previous track |
| `qs -c lyricbar ipc call lyrictheme reload` | Force immediate theme re-read |

---

## 🪟 HyprGlass Configuration

The installer automatically ensures this rule is registered in `~/.config/hypr/custom/general.lua`:

```lua
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass
    -- Quickshell Floating LyricBar (Apple Liquid Glass)
    hg.layer("quickshell:lyricbar", { preset = "pomme", mask_threshold = 0.01, mask_feather = 0.45 })
end
```

---

## 🗑️ Uninstallation

To remove Quickshell LyricBar:

```bash
quickshell-lyricbar --kill
./install.sh --uninstall
```

---

## 📄 License

MIT License. Designed for Quickshell & Hyprland.
