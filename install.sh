#!/usr/bin/env bash
# ==============================================================================
# quickshell-lyricbar - One-line & Standalone Installer
# Floating Lyric Bar with Apple Liquid Glass for Hyprland / Quickshell
# ==============================================================================

set -euo pipefail

# Visual styling
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_BLUE="\033[1;34m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_CYAN="\033[1;36m"
C_MAGENTA="\033[1;35m"

info()    { printf "${C_BLUE}[INFO]${C_RESET} %s\n" "$1"; }
success() { printf "${C_GREEN}[DONE]${C_RESET} %s\n" "$1"; }
warn()    { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$1"; }
error()   { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$1" >&2; }
step()    { printf "\n${C_CYAN}::${C_BOLD} %s${C_RESET}\n" "$1"; }

REPO_URL="${LYRICBAR_REPO_URL:-https://github.com/DX4GREY/quickshell-lyricbar.git}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET_DIR="${XDG_CONFIG_HOME}/quickshell/lyricbar"
BIN_DIR="${HOME}/.local/bin"

# ------------------------------------------------------------------------------
# 1. Pipe / One-Liner Detection & Self-Bootstrap
# ------------------------------------------------------------------------------
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""

if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
fi

if [[ -z "$SCRIPT_DIR" || ! -f "${SCRIPT_DIR}/FloatingLyricBar.qml" ]]; then
    info "Running via one-liner / curl pipe. Bootstrapping repository to temporary directory..."
    TEMP_DIR="$(mktemp -d -t qs-lyricbar-XXXXXX)"
    
    if ! command -v git >/dev/null 2>&1; then
        error "git is required to download repository."
        exit 1
    fi
    
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR/quickshell-lyricbar"
    cd "$TEMP_DIR/quickshell-lyricbar"
    exec bash install.sh "$@"
fi

# ------------------------------------------------------------------------------
# 2. Helper Functions
# ------------------------------------------------------------------------------
USER_CHOICE=""
read_input() {
    local prompt_msg="$1"
    local default_val="$2"
    USER_CHOICE=""

    if [[ -t 0 ]]; then
        read -r -p "$prompt_msg" USER_CHOICE || true
    elif read -t 0 2>/dev/null; then
        read -r USER_CHOICE || true
    elif [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]]; then
        printf "%b" "$prompt_msg" > /dev/tty 2>/dev/null || true
        read -r USER_CHOICE < /dev/tty 2>/dev/null || true
    else
        USER_CHOICE="$default_val"
    fi

    USER_CHOICE="$(echo "$USER_CHOICE" | tr -d '\r' | xargs)"
    if [[ -z "$USER_CHOICE" ]]; then
        USER_CHOICE="$default_val"
    fi
}

# ------------------------------------------------------------------------------
# 3. Parse Arguments
# ------------------------------------------------------------------------------
UNINSTALL=0
REPAIR=0
AUTO_START=1

for arg in "$@"; do
    case "$arg" in
        --uninstall|-u)
            UNINSTALL=1
            ;;
        --repair|-r|--reinstall)
            REPAIR=1
            ;;
        --no-start)
            AUTO_START=0
            ;;
        --start|-s)
            AUTO_START=1
            ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --repair, -r, --reinstall  Repair or update existing installation"
            echo "  --uninstall, -u            Uninstall LyricBar from system"
            echo "  --no-start                 Do not launch LyricBar daemon after installation"
            echo "  --help, -h                 Show this help message"
            exit 0
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 4. Uninstallation Handler
# ------------------------------------------------------------------------------
do_uninstall() {
    step "Uninstalling Quickshell LyricBar..."
    pkill -f "qs -c lyricbar" 2>/dev/null || true
    pkill -f "qs.*lyricbar" 2>/dev/null || true
    pkill -f "lyric_listener.py" 2>/dev/null || true
    pkill -f "quickshell-lyricbar" 2>/dev/null || true
    
    if [[ -d "$TARGET_DIR" ]]; then
        rm -rf "$TARGET_DIR"
        success "Removed config directory: $TARGET_DIR"
    fi
    
    if [[ -f "${BIN_DIR}/quickshell-lyricbar" ]]; then
        rm -f "${BIN_DIR}/quickshell-lyricbar"
        success "Removed binary wrapper: ${BIN_DIR}/quickshell-lyricbar"
    fi

    # Clean up autostart configurations
    HYPR_CUSTOM_EXECS="${XDG_CONFIG_HOME}/hypr/custom/execs.lua"
    if [[ -f "$HYPR_CUSTOM_EXECS" ]]; then
        sed -i '/-- Autostart Quickshell LyricBar/,/end)/d' "$HYPR_CUSTOM_EXECS" 2>/dev/null || true
        sed -i '/quickshell-lyricbar/d' "$HYPR_CUSTOM_EXECS" 2>/dev/null || true
        success "Cleaned up Hyprland autostart entry in $HYPR_CUSTOM_EXECS"
    fi
    XDG_AUTOSTART="${XDG_CONFIG_HOME}/autostart/quickshell-lyricbar.desktop"
    if [[ -f "$XDG_AUTOSTART" ]]; then
        rm -f "$XDG_AUTOSTART"
        success "Removed XDG desktop autostart entry: $XDG_AUTOSTART"
    fi
    
    printf "\n${C_GREEN}${C_BOLD}Quickshell LyricBar successfully uninstalled.${C_RESET}\n"
    exit 0
}

if [[ "$UNINSTALL" -eq 1 ]]; then
    do_uninstall
fi

# ------------------------------------------------------------------------------
# 5. Check for Existing Installation
# ------------------------------------------------------------------------------
IS_INSTALLED=0
if [[ -f "${TARGET_DIR}/FloatingLyricBar.qml" || -f "${BIN_DIR}/quickshell-lyricbar" ]]; then
    IS_INSTALLED=1
fi

if [[ "$IS_INSTALLED" -eq 1 && "$REPAIR" -eq 0 ]]; then
    printf "\n${C_YELLOW}${C_BOLD}Quickshell LyricBar is already installed on this system!${C_RESET}\n"
    printf "Detected installation at: ${C_CYAN}%s${C_RESET}\n\n" "$TARGET_DIR"
    printf "Please select an option:\n"
    printf "  ${C_BOLD}1)${C_RESET} ${C_GREEN}Repair / Update${C_RESET}  (Reinstall files, update wrapper & autostart, preserve config)\n"
    printf "  ${C_BOLD}2)${C_RESET} ${C_RED}Uninstall${C_RESET}        (Completely remove LyricBar from system)\n"
    printf "  ${C_BOLD}3)${C_RESET} Cancel / Exit\n\n"

    read_input "${C_BOLD}Enter choice [1-3] (Default: 1): ${C_RESET}" "1"
    case "$USER_CHOICE" in
        1)
            info "Proceeding with Repair / Update..."
            REPAIR=1
            ;;
        2)
            do_uninstall
            ;;
        3|[qQ]|[eE]xit|[cC]ancel)
            info "Installation cancelled by user."
            exit 0
            ;;
        *)
            warn "Unrecognized selection '$USER_CHOICE'. Defaulting to Repair / Update..."
            REPAIR=1
            ;;
    esac
fi

# Stop running instances during repair/update to ensure clean file replacement
WAS_RUNNING=0
if pgrep -f "qs.*lyricbar" >/dev/null 2>&1; then
    WAS_RUNNING=1
    info "Existing LyricBar instance is active. Halting temporarily for update..."
    pkill -f "qs.*lyricbar" 2>/dev/null || true
    pkill -f "lyric_listener.py" 2>/dev/null || true
    sleep 0.5
fi

# ------------------------------------------------------------------------------
# 6. Dependency Checks
# ------------------------------------------------------------------------------
step "Checking System Dependencies..."

MISSING_DEPS=()
for cmd in qs python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    error "Missing required dependencies: ${MISSING_DEPS[*]}"
    error "Please install quickshell (AUR: quickshell-git) and python3."
    exit 1
fi
success "Core dependencies found (Quickshell, Python 3)."

# Check Python DBus / playerctl
if ! python3 -c "import dbus" >/dev/null 2>&1; then
    if ! command -v playerctl >/dev/null 2>&1; then
        warn "Neither python-dbus nor playerctl was detected. Install python-dbus or playerctl for MPRIS monitoring."
    else
        info "playerctl detected (will be used as MPRIS fallback)."
    fi
else
    success "Python DBus module detected."
fi

# ------------------------------------------------------------------------------
# 7. Install Component Files
# ------------------------------------------------------------------------------
step "Installing Component Files to: ${TARGET_DIR}..."

mkdir -p "$TARGET_DIR"
mkdir -p "$BIN_DIR"

# Copy required QML and helper files
cp -f "${SCRIPT_DIR}/FloatingLyricBar.qml" "$TARGET_DIR/"
cp -f "${SCRIPT_DIR}/LyricTheme.qml" "$TARGET_DIR/"
cp -f "${SCRIPT_DIR}/lyric_listener.py" "$TARGET_DIR/"
cp -f "${SCRIPT_DIR}/shell.qml" "$TARGET_DIR/"
cp -f "${SCRIPT_DIR}/run.sh" "$TARGET_DIR/"

# Configure user preferences (set autoHideOnStop to true on install/repair)
if [[ -f "${TARGET_DIR}/config.json" ]]; then
    python3 -c "
import json
cfg_path = '${TARGET_DIR}/config.json'
try:
    with open(cfg_path, 'r') as f:
        data = json.load(f)
except Exception:
    data = {}
data['autoHideOnStop'] = True
with open(cfg_path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
    info "Set autoHideOnStop to true and preserved other preferences in ${TARGET_DIR}/config.json"
else
    if [[ -f "${SCRIPT_DIR}/config.json" ]]; then
        cp "${SCRIPT_DIR}/config.json" "$TARGET_DIR/"
        info "Installed default config.json with autoHideOnStop enabled"
    fi
fi

chmod +x "${TARGET_DIR}/lyric_listener.py"
chmod +x "${TARGET_DIR}/run.sh"

success "Installed files to ${TARGET_DIR}."

# ------------------------------------------------------------------------------
# 8. Create Convenient Binary Wrapper
# ------------------------------------------------------------------------------
step "Creating Executable Wrapper in ${BIN_DIR}/quickshell-lyricbar..."

cat << 'EOF' > "${BIN_DIR}/quickshell-lyricbar"
#!/usr/bin/env bash
if [[ "${1:-}" == "ipc" ]]; then
    shift
    exec qs -c lyricbar ipc --any-display "$@"
fi
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/lyricbar"
if [[ -f "${CONFIG_DIR}/run.sh" ]]; then
    exec "${CONFIG_DIR}/run.sh" "$@"
else
    exec qs -c lyricbar "$@"
fi
EOF

chmod +x "${BIN_DIR}/quickshell-lyricbar"
success "Created ${BIN_DIR}/quickshell-lyricbar"

# ------------------------------------------------------------------------------
# 9. Configure HyprGlass (Liquid Glass Integration)
# ------------------------------------------------------------------------------
step "Checking HyprGlass Composition Layer Settings..."

HYPR_GENERAL_CONF="${XDG_CONFIG_HOME}/hypr/custom/general.lua"

if [[ -f "$HYPR_GENERAL_CONF" ]]; then
    if grep -q 'quickshell:lyricbar' "$HYPR_GENERAL_CONF"; then
        success "HyprGlass layer rule for 'quickshell:lyricbar' is already configured."
    else
        info "Adding 'quickshell:lyricbar' to HyprGlass configuration..."
        sed -i '/quickshell:reloadPopup/a \    hg.layer("quickshell:lyricbar", { preset = "pomme", mask_threshold = 0.01, mask_feather = 0.45 })' "$HYPR_GENERAL_CONF" 2>/dev/null || true
        success "Configured HyprGlass 'pomme' preset for LyricBar."
        
        # Reload Hyprland if active
        if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
            hyprctl reload >/dev/null 2>&1 || true
            info "Hyprland configuration reloaded."
        fi
    fi
else
    info "No custom HyprGlass general.lua detected at $HYPR_GENERAL_CONF (Skipping)."
fi

# ------------------------------------------------------------------------------
# 10. Configure Autostart on Boot / Login
# ------------------------------------------------------------------------------
step "Configuring Autostart on Boot..."

HYPR_CUSTOM_EXECS="${XDG_CONFIG_HOME}/hypr/custom/execs.lua"

if [[ -f "$HYPR_CUSTOM_EXECS" ]]; then
    if grep -q "quickshell-lyricbar" "$HYPR_CUSTOM_EXECS"; then
        success "Autostart is already configured in $HYPR_CUSTOM_EXECS."
    else
        info "Adding LyricBar to $HYPR_CUSTOM_EXECS..."
        if grep -q 'hl.on("hyprland.start"' "$HYPR_CUSTOM_EXECS"; then
            sed -i '/hl.on("hyprland.start"/a \    hl.exec_cmd("sleep 1 && quickshell-lyricbar --background")' "$HYPR_CUSTOM_EXECS"
        else
            cat << 'EOF' >> "$HYPR_CUSTOM_EXECS"

-- Autostart Quickshell LyricBar
hl.on("hyprland.start", function ()
    hl.exec_cmd("sleep 1 && quickshell-lyricbar --background")
end)
EOF
        fi
        success "Configured autostart in $HYPR_CUSTOM_EXECS."
    fi
fi

# Configure XDG desktop autostart entry for system compatibility
AUTOSTART_DIR="${XDG_CONFIG_HOME}/autostart"
mkdir -p "$AUTOSTART_DIR"
cat << EOF > "${AUTOSTART_DIR}/quickshell-lyricbar.desktop"
[Desktop Entry]
Type=Application
Name=Quickshell LyricBar
Comment=Floating synchronized Liquid Glass lyric bar for Quickshell
Exec=${BIN_DIR}/quickshell-lyricbar --background
Terminal=false
Categories=AudioVideo;Audio;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
success "Configured XDG desktop autostart entry."

# ------------------------------------------------------------------------------
# 11. Finished & Next Steps
# ------------------------------------------------------------------------------
if [[ "$IS_INSTALLED" -eq 1 || "$REPAIR" -eq 1 ]]; then
    printf "\n${C_GREEN}${C_BOLD}======================================================${C_RESET}\n"
    printf "${C_GREEN}${C_BOLD}   Quickshell Floating LyricBar Successfully Repaired / Updated! ${C_RESET}\n"
    printf "${C_GREEN}${C_BOLD}======================================================${C_RESET}\n\n"
else
    printf "\n${C_GREEN}${C_BOLD}======================================================${C_RESET}\n"
    printf "${C_GREEN}${C_BOLD}   Quickshell Floating LyricBar Successfully Installed! ${C_RESET}\n"
    printf "${C_GREEN}${C_BOLD}======================================================${C_RESET}\n\n"
fi

info "How to run:"
printf "  • Run directly:       ${C_BOLD}quickshell-lyricbar${C_RESET}  (or ${C_BOLD}qs -c lyricbar${C_RESET})\n"
printf "  • Run in Demo mode:   ${C_BOLD}quickshell-lyricbar --demo${C_RESET}\n"
printf "  • Run in Background:  ${C_BOLD}quickshell-lyricbar --background${C_RESET}\n"
printf "  • Stop instance:      ${C_BOLD}quickshell-lyricbar --kill${C_RESET}\n\n"

info "Autostart in Hyprland:"
printf "  Add the following line to your ${C_CYAN}~/.config/hypr/hyprland/execs.lua${C_RESET} or ${C_CYAN}hyprland.conf${C_RESET}:\n"
printf "  ${C_BOLD}exec-once = quickshell-lyricbar --background${C_RESET}\n\n"

info "Hyprland Keybinding Example:"
printf "  ${C_BOLD}bind = SUPER, Y, exec, qs -c lyricbar ipc call lyricbar toggle${C_RESET}\n\n"

if [[ "$AUTO_START" -eq 1 ]]; then
    step "Starting Quickshell LyricBar Daemon..."
    "${BIN_DIR}/quickshell-lyricbar" --background
    success "LyricBar daemon running in background."
fi
