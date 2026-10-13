pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    // ==========================================
    // 1. Theme & Liquid Glass Variables
    // ==========================================
    LyricTheme {
        id: theme
    }

    // ==========================================
    // 2. State & Media Properties
    // ==========================================
    property bool showing: true
    property bool compact: false
    property bool autoHideOnStop: true
    property bool demoMode: Quickshell.env("QS_LYRIC_DEMO") === "1"
    property bool settingsOpen: false
    property bool anchorTop: false
    property string keybindStatusMsg: ""

    // 3D Parallax Tilt
    property real tiltX: 0.0
    property real tiltY: 0.0

    // MPRIS & Lyric Data
    property string activePlayer: ""
    property string activeLyric: ""
    property string displayedLyric: targetLyric
    property string nextLyric: ""
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string playbackStatus: "Stopped"
    property bool hasLyrics: false
    property real progress: 0.0
    property real position: 0.0
    property real duration: 0.0

    readonly property bool isPlaying: playbackStatus === "Playing"
    readonly property bool hasMedia: trackTitle !== "" && playbackStatus !== "Stopped"
    readonly property bool effectiveVisible: showing && (!autoHideOnStop || hasMedia)

    // Compute target text for dynamic measurement
    readonly property string targetLyric: {
        if (activeLyric !== "") return activeLyric;
        if (trackTitle !== "") {
            return trackArtist !== "" ? (trackArtist + " — " + trackTitle) : trackTitle;
        }
        return isPlaying ? "♪ ♪ ♪" : "LyricBar (No media playing)";
    }

    // ==========================================
    // 3. Layer Shell Window Positioning & Click Mask
    // ==========================================
    anchors {
        top: root.anchorTop
        bottom: !root.anchorTop
        left: true
        right: true
    }
    margins {
        top: root.anchorTop ? 28 : 0
        bottom: !root.anchorTop ? 28 : 0
    }
    implicitHeight: root.settingsOpen ? 370 : (theme.barHeight + 20)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    // HyprGlass layer integration
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:lyricbar"

    // Click mask: Hanya area card aktif yang menangkap input mouse
    mask: Region {
        item: (cardWrapper.opacity > 0.02) ? cardWrapper : null
    }

    // ==========================================
    // 4. Global Shortcuts & IPC Handlers
    // ==========================================
    GlobalShortcut {
        name: "lyricBarToggle"
        description: "Toggle Quickshell Floating LyricBar"
        onPressed: root.showing = !root.showing
    }

    GlobalShortcut {
        name: "lyricBarToggleMini"
        description: "Toggle LyricBar compact mini-pill"
        onPressed: root.compact = !root.compact
    }

    GlobalShortcut {
        name: "lyricBarToggleSettings"
        description: "Toggle LyricBar settings modal"
        onPressed: root.settingsOpen = !root.settingsOpen
    }

    IpcHandler {
        target: "lyricbar"
        function toggle(): void { root.showing = !root.showing; }
        function show(): void { root.showing = true; }
        function hide(): void { root.showing = false; }
        function toggleMini(): void { root.compact = !root.compact; }
        function openSettings(): void { root.settingsOpen = true; }
        function closeSettings(): void { root.settingsOpen = false; }
        function toggleSettings(): void { root.settingsOpen = !root.settingsOpen; }
        function playPause(): void {
            if (root.activePlayer) {
                mediaProcess.run(["playerctl", "-p", root.activePlayer, "play-pause"]);
            } else {
                mediaProcess.run(["playerctl", "play-pause"]);
            }
        }
        function next(): void {
            if (root.activePlayer) {
                mediaProcess.run(["playerctl", "-p", root.activePlayer, "next"]);
            } else {
                mediaProcess.run(["playerctl", "next"]);
            }
        }
        function prev(): void {
            if (root.activePlayer) {
                mediaProcess.run(["playerctl", "-p", root.activePlayer, "previous"]);
            } else {
                mediaProcess.run(["playerctl", "previous"]);
            }
        }
        function applyHyprlandKeybinds(): void { root.syncKeybinds(); }
    }

    Process {
        id: mediaProcess
        function run(args) {
            command = args;
            running = true;
        }
    }

    // Process to apply keybindings to Hyprland custom keybinds file
    Process {
        id: syncProcess
        function run(args) {
            command = args;
            running = true;
        }
        onExited: {
            root.keybindStatusMsg = "Keybinds Synced!";
            statusClearTimer.restart();
        }
    }

    Timer {
        id: statusClearTimer
        interval: 2800
        repeat: false
        onTriggered: root.keybindStatusMsg = ""
    }

    function syncKeybinds() {
        const cmdScript = `
        KEYBIND_FILE="$HOME/.config/hypr/custom/keybinds.lua"
        mkdir -p "$(dirname "$KEYBIND_FILE")"
        touch "$KEYBIND_FILE"
        if ! grep -q "lyricbar" "$KEYBIND_FILE"; then
            cat << 'EOF' >> "$KEYBIND_FILE"

-- Quickshell LyricBar Keybindings
hl.bind("SUPER + Y", hl.dsp.exec_cmd("qs -c lyricbar ipc --any-display call lyricbar toggle"), { description = "LyricBar: Toggle visibility" })
hl.bind("SUPER + ALT + Y", hl.dsp.exec_cmd("qs -c lyricbar ipc --any-display call lyricbar toggleMini"), { description = "LyricBar: Toggle mini pill" })
hl.bind("SUPER + CTRL + Y", hl.dsp.exec_cmd("qs -c lyricbar ipc --any-display call lyricbar toggleSettings"), { description = "LyricBar: Toggle settings" })
EOF
        fi
        SIG=$(basename /run/user/$(id -u)/hypr/*_* 2>/dev/null || echo "")
        if [ -n "$SIG" ]; then
            HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl reload >/dev/null 2>&1 || true
        fi
        `;
        syncProcess.run(["bash", "-c", cmdScript]);
    }

    // ==========================================
    // 5. Config Persistence
    // ==========================================
    readonly property string userConfigPath: Quickshell.env("HOME") + "/.config/quickshell/lyricbar/config.json"

    FileView {
        id: userConfigFile
        path: root.userConfigPath
        watchChanges: true
        onLoadFailed: (error) => {}
        onLoadedChanged: {
            if (loaded) {
                try {
                    const cfg = JSON.parse(userConfigFile.text());
                    if (cfg.autoHideOnStop !== undefined) root.autoHideOnStop = cfg.autoHideOnStop;
                    if (cfg.anchorTop !== undefined) root.anchorTop = cfg.anchorTop;
                    if (cfg.demoMode !== undefined && Quickshell.env("QS_LYRIC_DEMO") !== "1") root.demoMode = cfg.demoMode;
                } catch(e) {}
            }
        }
    }

    function saveConfig() {
        const cfg = {
            "autoHideOnStop": root.autoHideOnStop,
            "anchorTop": root.anchorTop,
            "demoMode": root.demoMode
        };
        try {
            userConfigFile.setText(JSON.stringify(cfg, null, 2));
        } catch(e) {}
    }

    // ==========================================
    // 6. Lyric Listener Process (MPRIS & LRCLIB)
    // ==========================================
    readonly property string listenerScript: Quickshell.env("HOME") + "/.config/quickshell/lyricbar/lyric_listener.py"

    Process {
        id: lyricProcess
        command: [
            root.listenerScript,
            root.demoMode ? "--demo" : ""
        ].filter(arg => arg !== "")

        running: true

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line) return;
                try {
                    const info = JSON.parse(line);
                    root.activePlayer = info.player || "";
                    root.activeLyric = info.text || "";
                    root.nextLyric = info.next || "";
                    root.trackTitle = info.title || "";
                    root.trackArtist = info.artist || "";
                    root.trackAlbum = info.album || "";
                    root.playbackStatus = info.status || "Stopped";
                    root.hasLyrics = !!info.hasLyrics;
                    root.progress = info.progress || 0.0;
                    root.position = info.position || 0.0;
                    root.duration = info.duration || 0.0;
                } catch (e) {
                    root.activeLyric = line;
                }
            }
        }

        onExited: {
            if (root.showing) restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (!lyricProcess.running) lyricProcess.running = true;
        }
    }

    // ==========================================
    // 7. Apple-Style Lyric Text Transition (Scale, Fade & Slide)
    // ==========================================
    onTargetLyricChanged: {
        if (targetLyric === displayedLyric) return;
        lyricTransition.restart();
    }

    SequentialAnimation {
        id: lyricTransition
        ParallelAnimation {
            NumberAnimation {
                target: lyricLabel
                property: "opacity"
                to: 0.0
                duration: 140
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lyricLabel
                property: "y"
                to: -9
                duration: 140
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lyricLabel
                property: "scale"
                to: 0.95
                duration: 140
                easing.type: Easing.InQuad
            }
        }
        ScriptAction {
            script: {
                root.displayedLyric = root.targetLyric;
                lyricLabel.y = 9;
                lyricLabel.scale = 0.95;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: lyricLabel
                property: "opacity"
                to: 1.0
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lyricLabel
                property: "y"
                to: 0
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lyricLabel
                property: "scale"
                to: 1.0
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.06
            }
        }
    }

    // Offscreen Text Measure for Dynamic Width Calculation
    Text {
        id: lyricMeasure
        visible: false
        font.family: theme.fontFamily
        font.pixelSize: theme.fontSizeMain
        font.bold: true
        renderType: Text.NativeRendering
        text: root.targetLyric
    }

    // Apple-style Glass Action Button with tactile micro-interaction
    component GlassActionBtn: Rectangle {
        id: gbtn
        property string icon: ""
        property color iconColor: theme.textDim
        property color hoverColor: theme.accent
        signal clicked()

        implicitWidth: 26
        implicitHeight: 26
        radius: 7
        color: gbtnMouse.pressed
               ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.22)
               : (gbtnMouse.containsMouse ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.12) : "transparent")

        scale: gbtnMouse.pressed ? 0.88 : (gbtnMouse.containsMouse ? 1.08 : 1.0)

        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 1.35
            }
        }

        Text {
            anchors.centerIn: parent
            text: gbtn.icon
            font.family: theme.iconFont
            font.pixelSize: 12
            renderType: Text.NativeRendering
            color: gbtnMouse.containsMouse ? gbtn.hoverColor : gbtn.iconColor
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        MouseArea {
            id: gbtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: gbtn.clicked()
        }
    }

    // Keyboard Key badge component for Settings Modal
    component KeyBadge: Rectangle {
        id: kbadge
        property string keyText: ""
        implicitWidth: klabel.implicitWidth + 14
        implicitHeight: 22
        radius: 6
        color: Qt.rgba(theme.bgCard.r, theme.bgCard.g, theme.bgCard.b, 0.6)
        border.color: theme.glassBorder
        border.width: 1

        Text {
            id: klabel
            anchors.centerIn: parent
            text: kbadge.keyText
            font.family: theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            renderType: Text.NativeRendering
            color: theme.accent
        }
    }

    // ==========================================
    // 8. UNIFIED CONTAINER (Card Wrapper)
    // Apple-Style Entrance, Exit & Morphology Engine
    // ==========================================
    Item {
        id: cardWrapper
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: !root.anchorTop ? parent.bottom : undefined
        anchors.top: root.anchorTop ? parent.top : undefined

        width: Math.max(lyricCard.width, root.settingsOpen ? settingsCard.width : 0)
        height: lyricCard.height + (root.settingsOpen ? (settingsCard.height + 12) : 0)

        readonly property bool isShown: root.effectiveVisible

        // Apple-style entrance / exit fluid spring state
        property real animY: isShown ? 0 : (root.anchorTop ? -50 : 50)
        property real animScale: isShown ? 1.0 : 0.86
        property real animOpacity: isShown ? 1.0 : 0.0

        y: animY
        scale: animScale
        opacity: animOpacity

        visible: opacity > 0.001

        Behavior on animY {
            NumberAnimation {
                duration: cardWrapper.isShown ? 480 : 280
                easing.type: cardWrapper.isShown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.18
            }
        }
        Behavior on animScale {
            NumberAnimation {
                duration: cardWrapper.isShown ? 480 : 280
                easing.type: cardWrapper.isShown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.14
            }
        }
        Behavior on animOpacity {
            NumberAnimation {
                duration: cardWrapper.isShown ? 360 : 220
                easing.type: cardWrapper.isShown ? Easing.OutCubic : Easing.InQuad
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 440
                easing.type: Easing.OutBack
                easing.overshoot: 1.08
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }
        }

        // ==========================================
        // 9. Settings Modal (Keybinds & Preferences)
        // ==========================================
        Rectangle {
            id: settingsCard
            visible: opacity > 0.001
            opacity: root.settingsOpen ? 1.0 : 0.0
            scale: root.settingsOpen ? 1.0 : 0.90
            y: root.settingsOpen ? 0 : 18

            anchors.horizontalCenter: lyricCard.horizontalCenter
            anchors.bottom: !root.anchorTop ? lyricCard.top : undefined
            anchors.top: root.anchorTop ? lyricCard.bottom : undefined
            anchors.margins: 10

            width: 480
            height: 270
            radius: 18
            color: theme.glassBg
            border.color: theme.glassBorder
            border.width: 1
            clip: true

            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on scale {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.14
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.10
                }
            }
            Behavior on color { ColorAnimation { duration: theme.animMed } }
            Behavior on border.color { ColorAnimation { duration: theme.animMed } }

            // Top Specular Highlight line
            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 1
                }
                height: 1
                color: theme.glassHighlight
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰒓"
                        font.family: theme.iconFont
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        color: theme.accent
                    }

                    Text {
                        text: "LyricBar Settings & Keybinds"
                        font.family: theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        renderType: Text.NativeRendering
                        color: theme.text
                    }

                    Item { Layout.fillWidth: true }

                    GlassActionBtn {
                        icon: "󰅖"
                        onClicked: root.settingsOpen = false
                    }
                }

                // Keybindings Section Table
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    // Row: Toggle Visibility
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Toggle LyricBar"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            color: theme.textDim
                            renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        KeyBadge { keyText: "SUPER + Y" }
                    }

                    // Row: Mini Pill Mode
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Compact Mini-Pill"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            color: theme.textDim
                            renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        KeyBadge { keyText: "SUPER + ALT + Y" }
                    }

                    // Row: Settings Modal
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Open / Close Settings"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            color: theme.textDim
                            renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        KeyBadge { keyText: "SUPER + CTRL + Y" }
                    }

                    // Row: Media controls
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Media Shortcuts"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            color: theme.textDim
                            renderType: Text.NativeRendering
                        }
                        Item { Layout.fillWidth: true }
                        KeyBadge { keyText: "Wheel: Volume  •  R-Click: Next  •  Mid-Click: Prev" }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.4)
                }

                // Behavior Toggles & Action Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Auto-Hide Switch Button
                    Rectangle {
                        implicitWidth: autoHideLabel.implicitWidth + 18
                        implicitHeight: 26
                        radius: 6
                        color: root.autoHideOnStop ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.25) : theme.glassCard
                        border.color: root.autoHideOnStop ? theme.accent : theme.border
                        border.width: 1

                        Text {
                            id: autoHideLabel
                            anchors.centerIn: parent
                            text: "Auto-Hide: " + (root.autoHideOnStop ? "ON" : "OFF")
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            renderType: Text.NativeRendering
                            color: root.autoHideOnStop ? theme.accent : theme.textDim
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.autoHideOnStop = !root.autoHideOnStop;
                                root.saveConfig();
                            }
                        }
                    }

                    // Demo Mode Switch Button
                    Rectangle {
                        implicitWidth: demoLabel.implicitWidth + 18
                        implicitHeight: 26
                        radius: 6
                        color: root.demoMode ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.25) : theme.glassCard
                        border.color: root.demoMode ? theme.accent : theme.border
                        border.width: 1

                        Text {
                            id: demoLabel
                            anchors.centerIn: parent
                            text: "Demo: " + (root.demoMode ? "ON" : "OFF")
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            renderType: Text.NativeRendering
                            color: root.demoMode ? theme.accent : theme.textDim
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.demoMode = !root.demoMode;
                                lyricProcess.running = false;
                                restartTimer.restart();
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Action: Apply Keybinds to Hyprland
                    Rectangle {
                        implicitWidth: syncLabel.implicitWidth + 18
                        implicitHeight: 26
                        radius: 6
                        color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, syncArea.containsMouse ? 0.35 : 0.18)
                        border.color: theme.accent
                        border.width: 1

                        Text {
                            id: syncLabel
                            anchors.centerIn: parent
                            text: root.keybindStatusMsg !== "" ? root.keybindStatusMsg : "Sync Hyprland Binds"
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            renderType: Text.NativeRendering
                            color: theme.accent
                        }

                        MouseArea {
                            id: syncArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.syncKeybinds()
                        }
                    }
                }
            }
        }

        // ==========================================
        // 10. UNIFIED MORPHING CAPSULE (Liquid Glass Card)
        // Seamlessly morphs between Full Lyric Bar and Compact Mini-Pill
        // ==========================================
        Rectangle {
            id: lyricCard
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: !root.anchorTop ? parent.bottom : undefined
            anchors.top: root.anchorTop ? parent.top : undefined

            // Computed content width for dynamic content-driven sizing
            readonly property real fullContentWidth: {
                const padding = 28;
                const playWidth = 28 + cardLayout.spacing;
                const artistWidth = (root.trackArtist !== "" ? (artistBadge.implicitWidth + cardLayout.spacing) : 0);
                const textWidth = Math.max(120, Math.min(460, lyricMeasure.implicitWidth + 12));
                const pulseWidth = (root.hasLyrics && root.isPlaying ? (8 + cardLayout.spacing) : 0);
                const actionsWidth = 74 + cardLayout.spacing;
                return padding + playWidth + artistWidth + textWidth + pulseWidth + actionsWidth;
            }

            readonly property real targetWidth: root.compact ? (theme.pillHeight + 10) : Math.max(300, Math.min(780, fullContentWidth))
            readonly property real targetHeight: root.compact ? theme.pillHeight : theme.barHeight
            readonly property real targetRadius: root.compact ? (targetHeight / 2) : theme.cornerRadius

            implicitWidth: targetWidth
            height: targetHeight
            radius: targetRadius

            // Apple Dynamic Island fluid spring morphology
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 460
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.08
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.12
                }
            }
            Behavior on radius {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            // ==========================================
            // LIQUID GLASS VISUAL STYLING
            // ==========================================
            color: (cardMouseArea.containsMouse || miniArea.containsMouse) ? theme.glassBgHover : theme.glassBg
            clip: true

            Behavior on color { ColorAnimation { duration: theme.animMed } }

            // Dual Border: Subtle glass rim + Accent hover glow
            border.color: (cardMouseArea.containsMouse || miniArea.containsMouse) ? theme.glassBorderHover : theme.glassBorder
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: theme.animMed } }

            // Top Specular Highlight (Physical Glass Refraction Edge)
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, parent.width - (root.compact ? 12 : 24))
                height: 1
                radius: 1
                color: (cardMouseArea.containsMouse || miniArea.containsMouse) ? theme.glassHighlight : theme.glassHighlightFaint
                Behavior on color { ColorAnimation { duration: theme.animMed } }
                Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
            }

            // 3D Parallax Tilt Effect on Hover
            transform: [
                Rotation {
                    origin.x: lyricCard.width / 2
                    origin.y: lyricCard.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: root.tiltX
                    Behavior on angle { NumberAnimation { duration: theme.animMed; easing.type: Easing.OutCubic } }
                },
                Rotation {
                    origin.x: lyricCard.width / 2
                    origin.y: lyricCard.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: root.tiltY
                    Behavior on angle { NumberAnimation { duration: theme.animMed; easing.type: Easing.OutCubic } }
                }
            ]

            // ==========================================
            // LAYER A: COMPACT MODE CONTENT (Music Note Disc)
            // ==========================================
            Item {
                id: compactLayer
                anchors.fill: parent
                opacity: root.compact ? 1.0 : 0.0
                scale: root.compact ? 1.0 : 0.65
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.compact ? 280 : 160
                        easing.type: root.compact ? Easing.OutCubic : Easing.InQuad
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 380
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.25
                    }
                }

                Text {
                    anchors.centerIn: parent
                    font.family: theme.iconFont
                    font.pixelSize: theme.fontSizeIcon
                    renderType: Text.NativeRendering
                    color: root.isPlaying ? theme.accent : theme.textDim
                    text: "󰎆" // Music note icon
                    Behavior on color { ColorAnimation { duration: theme.animFast } }

                    // Subtle breathing pulse when music is playing
                    SequentialAnimation on scale {
                        running: root.compact && root.isPlaying
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 1.12; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.12; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }
                }

                MouseArea {
                    id: miniArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.compact = false
                }
            }

            // ==========================================
            // LAYER B: FULL BAR CONTENT (Lyrics & Controls)
            // ==========================================
            Item {
                id: fullLayer
                anchors.fill: parent
                opacity: root.compact ? 0.0 : 1.0
                scale: root.compact ? 0.85 : 1.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.compact ? 180 : 300
                        easing.type: root.compact ? Easing.InQuad : Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.12
                    }
                }

                // Mini Progress Bar at bottom
                Rectangle {
                    id: progressBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    height: 2
                    radius: 1
                    color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45)
                    width: Math.max(0, (lyricCard.width - 24) * Math.min(1.0, Math.max(0.0, root.progress)))
                    visible: root.isPlaying && root.duration > 0

                    Behavior on width { NumberAnimation { duration: 180 } }
                    Behavior on color { ColorAnimation { duration: theme.animMed } }
                }

                // MouseArea for interactivity, parallax, and playerctl shortcuts
                MouseArea {
                    id: cardMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.compact
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onPositionChanged: mouse => {
                        const nx = (mouse.x / lyricCard.width) - 0.5;
                        const ny = (mouse.y / lyricCard.height) - 0.5;
                        root.tiltX = -ny * 7;
                        root.tiltY = nx * 7;
                    }

                    onExited: {
                        root.tiltX = 0;
                        root.tiltY = 0;
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            root.prev();
                        } else if (mouse.button === Qt.RightButton) {
                            root.next();
                        }
                    }

                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) {
                            mediaProcess.run(root.activePlayer ? ["playerctl", "-p", root.activePlayer, "volume", "0.05+"] : ["playerctl", "volume", "0.05+"]);
                        } else if (wheel.angleDelta.y < 0) {
                            mediaProcess.run(root.activePlayer ? ["playerctl", "-p", root.activePlayer, "volume", "0.05-"] : ["playerctl", "volume", "0.05-"]);
                        }
                    }
                }

                // Card Content Row Layout
                RowLayout {
                    id: cardLayout
                    anchors.centerIn: parent
                    spacing: 8

                    // 1. Play / Pause & Disc Button with Apple-style tactile spring
                    Rectangle {
                        id: playBtn
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, playArea.containsMouse ? 0.32 : 0.16)

                        scale: playArea.pressed ? 0.90 : (playArea.containsMouse ? 1.08 : 1.0)

                        Behavior on color { ColorAnimation { duration: theme.animFast } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.30
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            font.family: theme.iconFont
                            font.pixelSize: theme.fontSizeIcon
                            renderType: Text.NativeRendering
                            color: theme.accent
                            text: root.isPlaying ? "󰏤" : "󰐊" // Pause / Play icon
                            Behavior on color { ColorAnimation { duration: theme.animFast } }
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.playPause()
                        }
                    }

                    // 2. Artist Badge (Themed Glass Pill)
                    Rectangle {
                        id: artistBadge
                        visible: root.trackArtist !== ""
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 22
                        implicitWidth: artistText.implicitWidth + 14
                        radius: 6
                        color: theme.glassCard
                        border.color: theme.border
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: theme.animMed } }
                        Behavior on border.color { ColorAnimation { duration: theme.animMed } }

                        Text {
                            id: artistText
                            anchors.centerIn: parent
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeSmall
                            font.bold: true
                            renderType: Text.NativeRendering
                            color: theme.textDim
                            text: root.trackArtist
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Behavior on color { ColorAnimation { duration: theme.animMed } }
                        }
                    }

                    // 3. Divider Dot
                    Rectangle {
                        visible: root.trackArtist !== ""
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 3
                        implicitHeight: 3
                        radius: 1.5
                        color: theme.textFaint
                    }

                    // 4. Live Lyric Line Container (High Legibility & Smooth Transition)
                    Item {
                        id: lyricContainer
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        implicitHeight: 24
                        implicitWidth: Math.min(460, lyricLabel.implicitWidth)
                        clip: true

                        Text {
                            id: lyricLabel
                            anchors.centerIn: parent
                            renderType: Text.NativeRendering
                            font.family: theme.fontFamily
                            font.pixelSize: theme.fontSizeMain
                            font.bold: true
                            // Contrast outline shadow for crisp legibility over any wallpaper
                            style: Text.Outline
                            styleColor: Qt.rgba(0.0, 0.0, 0.0, 0.55)
                            color: root.activeLyric !== "" ? theme.text : theme.accent2
                            text: root.displayedLyric
                            elide: Text.ElideRight
                            maximumLineCount: 1

                            Behavior on color { ColorAnimation { duration: theme.animMed } }
                        }
                    }

                    // 5. Synced Lyrics Pulse Indicator
                    Rectangle {
                        visible: root.hasLyrics && root.isPlaying
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: theme.accent

                        Behavior on color { ColorAnimation { duration: theme.animFast } }

                        SequentialAnimation on opacity {
                            running: root.hasLyrics && root.isPlaying
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.35; to: 1.0; duration: 650; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.0; to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                        }
                    }

                    // 6. Action Buttons (Settings, Minimize & Close)
                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        GlassActionBtn {
                            icon: "󰒓" // Settings
                            hoverColor: theme.accent
                            onClicked: root.settingsOpen = !root.settingsOpen
                        }

                        GlassActionBtn {
                            icon: "󰍹" // Compress / Pill
                            onClicked: root.compact = true
                        }

                        GlassActionBtn {
                            icon: "󰅖" // Close / X
                            hoverColor: theme.danger
                            onClicked: root.showing = false
                        }
                    }
                }
            }
        }
    }
}
