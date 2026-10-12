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
# 2. Parse Arguments
# ------------------------------------------------------------------------------
UNINSTALL=0
START_NOW=0

for arg in "$@"; do
    case "$arg" in
        --uninstall|-u)
            UNINSTALL=1
            ;;
        --start|-s)
            START_NOW=1
            ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --start, -s        Automatically start LyricBar after installation"
            echo "  --uninstall, -u    Uninstall LyricBar from quickshell config"
            echo "  --help, -h         Show this help message"
            exit 0
            ;;
    esac
done

# ------------------------------------------------------------------------------
# 3. Handle Uninstallation
# ------------------------------------------------------------------------------
if [[ "$UNINSTALL" -eq 1 ]]; then
    step "Uninstalling Quickshell LyricBar..."
    pkill -f "qs -c lyricbar" 2>/dev/null || true
    pkill -f "${TARGET_DIR}/lyric_listener.py" 2>/dev/null || true
    
    if [[ -d "$TARGET_DIR" ]]; then
        rm -rf "$TARGET_DIR"
        success "Removed config directory: $TARGET_DIR"
    fi
    
    if [[ -f "${BIN_DIR}/quickshell-lyricbar" ]]; then
        rm -f "${BIN_DIR}/quickshell-lyricbar"
        success "Removed binary link: ${BIN_DIR}/quickshell-lyricbar"
    fi
    
    success "Quickshell LyricBar successfully uninstalled."
    exit 0
fi

# ------------------------------------------------------------------------------
# 4. Dependency Checks
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
# 5. Install Component Files
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

chmod +x "${TARGET_DIR}/lyric_listener.py"
chmod +x "${TARGET_DIR}/run.sh"

success "Installed files to ${TARGET_DIR}."

# ------------------------------------------------------------------------------
# 6. Create Convenient Binary Wrapper
# ------------------------------------------------------------------------------
step "Creating Executable Wrapper in ${BIN_DIR}/quickshell-lyricbar..."

cat << 'EOF' > "${BIN_DIR}/quickshell-lyricbar"
#!/usr/bin/env bash
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
# 7. Configure HyprGlass (Liquid Glass Integration)
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
# 8. Finished & Next Steps
# ------------------------------------------------------------------------------
printf "\n${C_GREEN}${C_BOLD}======================================================${C_RESET}\n"
printf "${C_GREEN}${C_BOLD}   Quickshell Floating LyricBar Successfully Installed! ${C_RESET}\n"
printf "${C_GREEN}${C_BOLD}======================================================${C_RESET}\n\n"

info "How to run:"
printf "  • Run directly:       ${C_BOLD}quickshell-lyricbar${C_RESET}  (or ${C_BOLD}qs -c lyricbar${C_RESET})\n"
printf "  • Run in Demo mode:   ${C_BOLD}quickshell-lyricbar --demo${C_RESET}\n"
printf "  • Run in Background:  ${C_BOLD}quickshell-lyricbar --background${C_RESET}\n"
printf "  • Stop instance:      ${C_BOLD}quickshell-lyricbar --kill${C_RESET}\n\n"

info "Autostart in Hyprland:"
printf "  Add the following line to your ${C_CYAN}~/.config/hypr/hyprland/execs.lua${C_RESET} or ${C_CYAN}hyprland.conf${C_RESET}:\n"
printf "  ${C_BOLD}exec-once = quickshell-lyricbar --background${C_RESET}\n\n"

info "Hyprland Keybinding Example:"
printf "  ${C_BOLD}bind = SUPER, L, exec, qs -c lyricbar ipc call lyricbar toggle${C_RESET}\n\n"

if [[ "$START_NOW" -eq 1 ]]; then
    step "Starting Quickshell LyricBar..."
    "${BIN_DIR}/quickshell-lyricbar" --background
    success "LyricBar started in background."
fi
