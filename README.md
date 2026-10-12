# Quickshell Floating LyricBar (Liquid Glass)

Komponen floating lyric bar modern berbasis **Quickshell** untuk Wayland / Hyprland dengan integrasi efek visual **Apple Liquid Glass** (`hyprglass`), layout dinamis auto-resize berbasis timestamp lirik aktif, animasi transisi fluida, dan sinkronisasi palet tema sistem secara otomatis.

---

## Fitur Utama

1. **Integrasi Plugin Liquid Glass (`hyprglass`):**
   - Menggunakan namespace layer shell `quickshell:lyricbar` yang terhubung langsung dengan plugin compositor HyprGlass (`preset = "pomme"`).
   - Efek visual kaca berlapis: frosted glass background translucent, garis specular highlight di bibir atas, efek pembiasan (refraction), dan bayangan elevasi.
   - Efek 3D Parallax Tilt interaktif saat kursor mouse bergerak di atas kapsul.

2. **Perilaku Layout Dinamis (Content-Driven Auto-Resize):**
   - Terkoneksi ke MPRIS media player (Spotify, Amberol, MPD, VLC, Browser, dll.) dan API lirik tersinkronisasi (LRCLIB & local `.lrc`).
   - Lebar container menyesuaikan secara dinamis mengikuti panjang teks lirik aktif detik tersebut secara presisi.
   - Dilengkapi batas minimum dan maksimum yang proporsional serta text eliding aman.

3. **Animasi & Transisi Fluida:**
   - **Resize Halus:** Saat panjang lirik berubah, dimensi lebar kapsul melebar/menyusut dengan kurva animasi `Easing.OutCubic` khas dinamika fluida, tanpa patah-patah atau resize instan.
   - **Transisi Teks Mulus:** Pergantian baris lirik menggunakan kombinasi *subtle vertical slide* (-7px ke 0) dan *cross-fade* (opacity 0.0 ke 1.0).

4. **Karakteristik Tampilan Floating & High Legibility:**
   - Mengambang bebas di layar (`WlrLayershell.layer: WlrLayer.Overlay`).
   - Fitur **Click Mask (`Region`)**: Hanya area kapsul aktif yang menerima interaksi klik mouse; area transparan di sekitarnya tembus pandang dan tembus klik (*click-through*) 100% ke jendela di bawahnya.
   - Teks lirik sangat kontras dan tajam dengan rendering native (`Text.NativeRendering`), tipografi tegas, dan outline pelindung kontras di atas latar belakang kaca terang maupun gelap.

5. **Sinkronisasi Tema Real-Time:**
   - Membaca konfigurasi palet aktif dari `~/.cache/43pr/quickshell-theme.json` dan `~/.local/state/quickshell/user/generated/colors.json` secara reaktif via `FileView`.
   - Warna teks, aksen, border, dan kaca otomatis berubah seketika saat wallpaper atau tema diganti tanpa perlu me-restart Quickshell.

6. **Interaktivitas & Kontrol Media:**
   - **Klik Tombol Play/Pause**: Memulai / menjeda musik (`playerctl play-pause`).
   - **Scroll Wheel**: Menaikkan / menurunkan volume (`playerctl volume +/-`).
   - **Klik Tengah (Middle Click)**: Lagu sebelumnya (`previous`).
   - **Klik Kanan**: Lagu berikutnya (`next`).
   - **Tombol Minimize / Compact**: Mengecilkan bar menjadi mini pill kapsul mungil dengan ikon nada musik.
   - **Indikator Pulsa Lirik**: Titik aksen berdenyut halus menandakan lirik aktif tersinkronisasi per detik.

---

## Struktur File

```text
quickshell-lyricbar/
├── shell.qml             # Entry point utama Quickshell ShellRoot
├── FloatingLyricBar.qml  # Komponen PanelWindow Floating LyricBar
├── LyricTheme.qml        # Service tema & Liquid Glass palette loader
├── lyric_listener.py     # Daemon pemantau MPRIS & sync timestamp LRCLIB / local LRC
├── run.sh                # Skrip peluncur interaktif (normal, demo, daemon, kill)
└── README.md             # Dokumentasi
```

---

## Cara Menjalankan

### 1. Menjalankan secara Langsung (Mode Normal MPRIS)
Pastikan media player Anda sedang memutar lagu:
```bash
./run.sh
```
Atau melalui Quickshell CLI:
```bash
qs -p /home/dx4white/MyProject/quickshell-lyricbar
```

### 2. Mode Demo (Pengujian Animasi & Auto-Resize Tanpa Player)
Jika tidak ada lagu yang sedang diputar dan Anda ingin menguji transisi animasi & efek Liquid Glass:
```bash
./run.sh --demo
```

### 3. Menjalankan di Latar Belakang (Background Daemon)
```bash
./run.sh --background
```

### 4. Menghentikan LyricBar yang Sedang Berjalan
```bash
./run.sh --kill
```

---

## Kontrol Melalui IPC (Terminal / Keybinding Hyprland)

Anda dapat mengirimkan perintah kontrol ke LyricBar secara langsung melalui Quickshell IPC:

```bash
# Toggle tampilkan / sembunyikan LyricBar
qs ipc call lyricbar toggle

# Sembunyikan LyricBar
qs ipc call lyricbar hide

# Tampilkan LyricBar
qs ipc call lyricbar show

# Toggle antara mode bar penuh dan mode mini pill
qs ipc call lyricbar toggleMini

# Kontrol media playback
qs ipc call lyricbar playPause
qs ipc call lyricbar next
qs ipc call lyricbar prev
```

### Contoh Integrasi Keybind Hyprland (`hyprland.conf` atau `custom/keybinds.lua`):
```lua
-- Toggle Lyric Bar dengan SUPER + L
bind = SUPER, L, exec, qs ipc call lyricbar toggle
-- Toggle Mini Pill dengan SUPER + ALT + L
bind = SUPER ALT, L, exec, qs ipc call lyricbar toggleMini
```

---

## Konfigurasi HyprGlass

Aturan HyprGlass untuk `quickshell:lyricbar` sudah terdaftar di `~/.config/hypr/custom/general.lua`:
```lua
hg.layer("quickshell:lyricbar", { preset = "pomme", mask_threshold = 0.01, mask_feather = 0.45 })
```
Preset `pomme` memberikan refraksi optik cair (liquid glass) khas macOS/iOS dengan blur transmisi tinggi di balik jendela floating.
