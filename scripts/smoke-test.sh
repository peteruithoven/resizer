#!/usr/bin/env bash
# Headless smoke test: launches the installed app with a generated test
# image via the command line (skipping drag-and-drop), and checks that a
# window actually appears and renders that image in its preview thumbnail.
# This is meant to catch "the app doesn't even start" regressions (e.g. a
# broken GTK/Granite/libhandy dependency bump) rather than to drive the full
# UI - synthetic keyboard input doesn't reliably reach the app under a
# nested/XWayland session, and clicking specific buttons by pixel position is
# too fragile to be worth it for a smoke test. See CLAUDE.md for background.
#
# Requires an X display (export DISPLAY, e.g. via `xvfb-run -a`), the app
# installed and on PATH (e.g. `sudo ninja -C build install`), and xdotool +
# ImageMagick (`convert`/`import`).
set -euo pipefail

if [ -z "${DISPLAY:-}" ]; then
    echo "DISPLAY is not set. Run this under a real or virtual X server, e.g. 'xvfb-run -a $0'." >&2
    exit 1
fi

# Force the X11 backend. Without this, on a Wayland desktop session
# (WAYLAND_DISPLAY still set even under xvfb-run, since xvfb-run only sets
# DISPLAY) GTK3 prefers Wayland and the app connects to the *real* desktop
# session instead of the virtual X display xvfb-run just set up - so it
# visibly appears on screen while xdotool, which only ever looks at the
# virtual X server, never finds it.
export GDK_BACKEND=x11

# Skip ATK's attempt to reach the AT-SPI accessibility bus. On CI runners
# that have a D-Bus session but no accessibility bus service registered,
# this lookup logs a "ServiceUnknown" warning and can measurably slow down
# startup; disabling it is the standard fix (same env var GNOME/Electron/etc
# use in CI) and costs nothing since a smoke test doesn't need accessibility.
export NO_AT_BRIDGE=1

if ! command -v com.github.peteruithoven.resizer >/dev/null 2>&1; then
    echo "com.github.peteruithoven.resizer not found on PATH. Install it first (e.g. 'sudo ninja -C build install')." >&2
    exit 1
fi

work_dir=$(mktemp -d)
cleanup () {
    [ -n "${app_pid:-}" ] && kill "$app_pid" 2>/dev/null || true
    rm -rf "$work_dir"
}
trap cleanup EXIT

# A synthetic, solid-color fixture: easy to recognize a pixel of it in the
# rendered preview, and generated fresh each run instead of depending on a
# repo screenshot whose size/content is free to change for unrelated reasons.
test_image="$work_dir/smoke-test.png"
convert -size 2000x1500 xc:"#87ceeb" "$test_image"

# HANDLES_OPEN: passing a file path opens it directly, skipping drag-and-drop.
com.github.peteruithoven.resizer "$test_image" &
app_pid=$!

window_id=""
for _ in $(seq 1 60); do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        echo "App exited before its window appeared" >&2
        exit 1
    fi
    # Anchored to the exact window title: the app also has a small (20x20),
    # unmapped helper window whose name is the app ID, which a loose
    # substring match like "Resizer" also picks up.
    window_id=$(xdotool search --name "^Resizer$" 2>/dev/null | head -1) || true
    if [ -n "$window_id" ]; then
        break
    fi
    sleep 0.5
done
if [ -z "$window_id" ]; then
    echo "App window never appeared after 30s. All windows currently on the display:" >&2
    xdotool search --name "." 2>&1 | while read -r w; do
        echo "  $w: $(xdotool getwindowname "$w" 2>&1)" >&2
    done
    exit 1
fi

sleep 0.5 # let the preview finish rendering
screenshot="$work_dir/window.png"
import -window "$window_id" "$screenshot"

# Sample a point inside the preview thumbnail (roughly a quarter across,
# just under halfway down the dialog) and check it matches the test image's
# fill color, confirming the app actually decoded and rendered it.
eval "$(xdotool getwindowgeometry --shell "$window_id")"
sample_x=$((WIDTH * 28 / 100))
sample_y=$((HEIGHT * 46 / 100))
pixel=$(convert "$screenshot" -format "%[pixel:p{$sample_x,$sample_y}]" info:)
if [ "$pixel" != "srgb(135,206,235)" ]; then
    echo "Preview thumbnail did not show the test image at (${sample_x},${sample_y}): got '$pixel', expected 'srgb(135,206,235)'" >&2
    exit 1
fi

if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "App process is no longer running" >&2
    exit 1
fi

echo "Smoke test passed: window appeared and rendered the test image"
