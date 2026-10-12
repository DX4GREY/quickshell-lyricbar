#!/usr/bin/env bash
# ==============================================================================
# run.sh - Runner script for Quickshell Floating LyricBar
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

print_help() {
    echo "Usage: ./run.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --demo, -t         Run in demo mode with synchronized test lyrics"
    echo "  --background, -b   Run detached in background"
    echo "  --kill, -k         Kill running lyricbar instance"
    echo "  --help, -h         Show this help message"
    echo ""
}

kill_instance() {
    echo "Stopping Quickshell LyricBar instances..."
    pkill -f "qs -p ${PROJECT_DIR}" 2>/dev/null || true
    pkill -f "${PROJECT_DIR}/lyric_listener.py" 2>/dev/null || true
    echo "Done."
}

DEMO_FLAG=0
DAEMON_FLAG=0

for arg in "$@"; do
    case "$arg" in
        --demo|-t)
            DEMO_FLAG=1
            ;;
        --background|-b)
            DAEMON_FLAG=1
            ;;
        --kill|-k)
            kill_instance
            exit 0
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            print_help
            exit 1
            ;;
    esac
done

if [ "$DEMO_FLAG" -eq 1 ]; then
    export QS_LYRIC_DEMO=1
    echo "Starting Quickshell Floating LyricBar in DEMO mode..."
else
    export QS_LYRIC_DEMO=0
    echo "Starting Quickshell Floating LyricBar (MPRIS mode)..."
fi

if [ "$DAEMON_FLAG" -eq 1 ]; then
    nohup qs -p "${PROJECT_DIR}" > /dev/null 2>&1 &
    echo "LyricBar started in background (PID: $!)."
else
    exec qs -p "${PROJECT_DIR}"
fi
