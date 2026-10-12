import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Paths to system active Quickshell theme configs
    readonly property string cacheThemePath: Quickshell.env("HOME") + "/.cache/43pr/quickshell-theme.json"
    readonly property string m3ThemePath: Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/colors.json"

    // Base color properties with fallbacks
    property color bg: "#0f0d13"
    property real bgAlpha: 0.55
    property color bgCard: "#1c1b20"
    property color text: "#f5f0f7"
    property color textDim: "#cac4cf"
    property color textFaint: "#938f99"
    property color accent: "#cdbdff"
    property color accent2: "#cbc3dc"
    property color border: "#48454e"
    property color borderAccent: "#6b6280"
    property color danger: "#ffb4ab"
    property color ok: "#eeb8ca"

    // Liquid Glass specific colors & effects
    readonly property color glassBg: Qt.rgba(bg.r, bg.g, bg.b, 0.42)
    readonly property color glassBgHover: Qt.rgba(bg.r, bg.g, bg.b, 0.56)
    readonly property color glassCard: Qt.rgba(bgCard.r, bgCard.g, bgCard.b, 0.48)
    readonly property color glassBorder: Qt.rgba(1.0, 1.0, 1.0, 0.16)
    readonly property color glassBorderHover: Qt.rgba(accent.r, accent.g, accent.b, 0.65)
    readonly property color glassHighlight: Qt.rgba(1.0, 1.0, 1.0, 0.22)
    readonly property color glassHighlightFaint: Qt.rgba(1.0, 1.0, 1.0, 0.08)
    readonly property color glassShadow: Qt.rgba(0.0, 0.0, 0.0, 0.45)

    // Typography
    property string fontFamily: "JetBrainsMono Nerd Font"
    property string iconFont: "JetBrainsMono Nerd Font"
    property int fontSizeMain: 12
    property int fontSizeSmall: 10
    property int fontSizeIcon: 13

    // Dimensions & Rounding
    property int cornerRadius: 20
    property int barHeight: 44
    property int pillHeight: 34

    // Animation Durations & Curves (Fluid Liquid Glass Dynamics)
    property int animFast: 150
    property int animMed: 350
    property int animSlow: 520

    // Reactive FileView for active theme in ~/.cache/43pr/quickshell-theme.json
    FileView {
        id: cacheView
        path: Qt.resolvedUrl(root.cacheThemePath)
        watchChanges: true
        onFileChanged: reload()
        onLoadedChanged: {
            if (cacheView.loaded) {
                root.parseTheme(cacheView.text());
            }
        }
    }

    // Secondary FileView for Material3 theme in ~/.local/state/quickshell/user/generated/colors.json
    FileView {
        id: m3View
        path: Qt.resolvedUrl(root.m3ThemePath)
        watchChanges: true
        onFileChanged: reload()
        onLoadedChanged: {
            if (m3View.loaded && !cacheView.loaded) {
                root.parseM3(m3View.text());
            }
        }
    }

    function parseTheme(jsonText) {
        if (!jsonText) return;
        try {
            const data = JSON.parse(jsonText);
            if (data.bg) root.bg = data.bg;
            if (data.bgAlpha !== undefined) root.bgAlpha = data.bgAlpha;
            if (data.bgCard) root.bgCard = data.bgCard;
            if (data.text) root.text = data.text;
            if (data.textDim) root.textDim = data.textDim;
            if (data.textFaint) root.textFaint = data.textFaint;
            if (data.accent) root.accent = data.accent;
            if (data.accent2) root.accent2 = data.accent2;
            if (data.border) root.border = data.border;
            if (data.borderAccent) root.borderAccent = data.borderAccent;
            if (data.danger) root.danger = data.danger;
        } catch (e) {
            console.warn("[LyricTheme] JSON parse error:", e);
        }
    }

    function parseM3(jsonText) {
        if (!jsonText) return;
        try {
            const data = JSON.parse(jsonText);
            if (data.background) root.bg = data.background;
            if (data.primary) root.accent = data.primary;
            if (data.on_surface) root.text = data.on_surface;
            if (data.on_surface_variant) root.textDim = data.on_surface_variant;
            if (data.outline) root.border = data.outline;
        } catch (e) {
            console.warn("[LyricTheme] M3 parse error:", e);
        }
    }

    Component.onCompleted: {
        cacheView.reload();
        m3View.reload();
    }
}
