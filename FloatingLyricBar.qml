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
    property bool autoHideOnStop: false
    property bool demoMode: Quickshell.env("QS_LYRIC_DEMO") === "1"

    // 3D Parallax Tilt
    property real tiltX: 0.0
    property real tiltY: 0.0

    // MPRIS & Lyric Data
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
        bottom: true
        left: true
        right: true
    }
    margins {
        bottom: 28
    }
    implicitHeight: theme.barHeight + 16
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // HyprGlass layer integration
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:lyricbar"

    // Click mask: Hanya area card yang menangkap mouse click
    mask: Region {
        item: root.effectiveVisible ? (root.compact ? miniPill : lyricCard) : null
    }

    // ==========================================
    // 4. IPC Handler (CLI & Keybind Controls)
    // ==========================================
    IpcHandler {
        target: "lyricbar"
        function toggle(): void { root.showing = !root.showing; }
        function show(): void { root.showing = true; }
        function hide(): void { root.showing = false; }
        function toggleMini(): void { root.compact = !root.compact; }
        function playPause(): void { mediaProcess.run(["playerctl", "play-pause"]); }
        function next(): void { mediaProcess.run(["playerctl", "next"]); }
        function prev(): void { mediaProcess.run(["playerctl", "previous"]); }
    }

    Process {
        id: mediaProcess
        function run(args) {
            command = args;
            running = true;
        }
    }

    // ==========================================
    // 5. Lyric Listener Process (MPRIS & LRCLIB)
    // ==========================================
    readonly property string listenerScriptPath: {
        const localPath = String(Qt.resolvedUrl("lyric_listener.py")).replace(/^file:\/\//, "");
        return localPath;
    }

    Process {
        id: lyricProcess
        command: {
            const cmd = ["python3", root.listenerScriptPath];
            if (root.demoMode) cmd.push("--demo");
            return cmd;
        }
        running: true

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line) return;
                try {
                    const info = JSON.parse(line);
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
    // 6. Smooth Text Transition (Fade & Slide)
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
                duration: Math.round(theme.animFast * 0.8)
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lyricLabel
                property: "y"
                to: -7
                duration: Math.round(theme.animFast * 0.8)
                easing.type: Easing.InQuad
            }
        }
        ScriptAction {
            script: {
                root.displayedLyric = root.targetLyric;
                lyricLabel.y = 7;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: lyricLabel
                property: "opacity"
                to: 1.0
                duration: theme.animMed
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lyricLabel
                property: "y"
                to: 0
                duration: theme.animMed
                easing.type: Easing.OutCubic
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

    // Action button component
    component GlassActionBtn: Rectangle {
        id: gbtn
        property string icon: ""
        property color iconColor: theme.textDim
        property color hoverColor: theme.accent
        signal clicked()

        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: gbtnMouse.containsMouse ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.12) : "transparent"

        Behavior on color { ColorAnimation { duration: theme.animFast } }

        Text {
            anchors.centerIn: parent
            text: gbtn.icon
            font.family: theme.iconFont
            font.pixelSize: 12
            renderType: Text.NativeRendering
            color: gbtnMouse.containsMouse ? gbtn.hoverColor : gbtn.iconColor
            Behavior on color { ColorAnimation { duration: theme.animFast } }
        }

        MouseArea {
            id: gbtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: gbtn.clicked()
        }
    }

    // ==========================================
    // 7. Main Floating Liquid Glass Card
    // ==========================================
    Rectangle {
        id: lyricCard
        visible: root.effectiveVisible && !root.compact
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.90

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: theme.barHeight

        // ==========================================
        // AUTO-RESIZE: Fluid Dynamic Width Animation
        // ==========================================
        readonly property real computedContentWidth: {
            const padding = 28;
            const playWidth = 28 + cardLayout.spacing;
            const artistWidth = (root.trackArtist !== "" ? (artistBadge.implicitWidth + cardLayout.spacing) : 0);
            const textWidth = Math.max(120, Math.min(460, lyricMeasure.implicitWidth + 12));
            const pulseWidth = (root.hasLyrics && root.isPlaying ? (8 + cardLayout.spacing) : 0);
            const actionsWidth = 50 + cardLayout.spacing;
            return padding + playWidth + artistWidth + textWidth + pulseWidth + actionsWidth;
        }

        implicitWidth: Math.max(280, Math.min(760, computedContentWidth))

        Behavior on implicitWidth {
            NumberAnimation {
                duration: theme.animMed
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: theme.animMed; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: theme.animSlow; easing.type: Easing.OutBack }
        }

        // ==========================================
        // LIQUID GLASS VISUAL STYLING
        // ==========================================
        color: cardMouseArea.containsMouse ? theme.glassBgHover : theme.glassBg
        radius: theme.cornerRadius
        clip: true

        Behavior on color { ColorAnimation { duration: theme.animMed } }

        // Dual Border: Subtle glass rim + Accent hover glow
        border.color: cardMouseArea.containsMouse ? theme.glassBorderHover : theme.glassBorder
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: theme.animMed } }

        // Top Specular Highlight (Physical Glass Refraction Edge)
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 12
                rightMargin: 12
                topMargin: 1
            }
            height: 1
            radius: 1
            color: cardMouseArea.containsMouse ? theme.glassHighlight : theme.glassHighlightFaint
            Behavior on color { ColorAnimation { duration: theme.animMed } }
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

        // Progress bar mini at the bottom
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 12
            height: 2
            radius: 1
            width: (parent.width - 24) * Math.max(0.0, Math.min(1.0, root.progress))
            color: theme.accent
            opacity: 0.85

            Behavior on width { NumberAnimation { duration: 140 } }
        }

        // MouseArea for interactivity, parallax, and playerctl shortcuts
        MouseArea {
            id: cardMouseArea
            anchors.fill: parent
            hoverEnabled: true
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
                    mediaProcess.run(["playerctl", "previous"]);
                } else if (mouse.button === Qt.RightButton) {
                    mediaProcess.run(["playerctl", "next"]);
                }
            }

            onWheel: wheel => {
                if (wheel.angleDelta.y > 0) {
                    mediaProcess.run(["playerctl", "volume", "0.05+"]);
                } else if (wheel.angleDelta.y < 0) {
                    mediaProcess.run(["playerctl", "volume", "0.05-"]);
                }
            }
        }

        // ==========================================
        // Card Content Row Layout
        // ==========================================
        RowLayout {
            id: cardLayout
            anchors.centerIn: parent
            spacing: 8

            // 1. Play / Pause & Disc Button
            Rectangle {
                id: playBtn
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, playArea.containsMouse ? 0.32 : 0.16)

                Behavior on color { ColorAnimation { duration: theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    font.family: theme.iconFont
                    font.pixelSize: theme.fontSizeIcon
                    renderType: Text.NativeRendering
                    color: theme.accent
                    text: root.isPlaying ? "󰏤" : "󰐊" // Nerd Font: Pause or Play
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mediaProcess.run(["playerctl", "play-pause"])
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
                    // Subtle dark outline/shadow for high legibility over any glass backdrop
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

                SequentialAnimation on opacity {
                    running: root.hasLyrics && root.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.35; to: 1.0; duration: 650; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                }
            }

            // 6. Action Buttons (Minimize & Close)
            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                GlassActionBtn {
                    icon: "󰍹" // Nerd Font: Compress / Pill
                    onClicked: root.compact = true
                }

                GlassActionBtn {
                    icon: "󰅖" // Nerd Font: Close / X
                    hoverColor: theme.danger
                    onClicked: root.showing = false
                }
            }
        }
    }

    // ==========================================
    // 8. Compact Mode: Mini Liquid Glass Pill
    // ==========================================
    Rectangle {
        id: miniPill
        visible: root.effectiveVisible && root.compact
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.85

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: theme.pillHeight
        implicitWidth: 42

        radius: theme.pillHeight / 2
        color: miniArea.containsMouse ? theme.glassBgHover : theme.glassBg
        border.color: miniArea.containsMouse ? theme.glassBorderHover : theme.glassBorder
        border.width: 1

        Behavior on opacity { NumberAnimation { duration: theme.animFast } }
        Behavior on scale { NumberAnimation { duration: theme.animMed; easing.type: Easing.OutBack } }
        Behavior on border.color { ColorAnimation { duration: theme.animFast } }

        Text {
            anchors.centerIn: parent
            font.family: theme.iconFont
            font.pixelSize: theme.fontSizeIcon
            renderType: Text.NativeRendering
            color: root.isPlaying ? theme.accent : theme.textDim
            text: "󰎆" // Nerd Font: Music Note
        }

        MouseArea {
            id: miniArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.compact = false
        }
    }
}
