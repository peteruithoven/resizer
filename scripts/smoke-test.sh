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

# Point D-Bus at an address nothing is listening on, for both buses. This
# makes every D-Bus call the app makes during startup (GSettings,
# Granite.Settings' dark-mode/portal lookup, AT-SPI) fail immediately instead
# of trying to discover or activate a real bus/portal. That discovery path is
# the actual danger here: on one CI run the app hung before its window was
# ever created (no crash, no error, it just never got there), and separately,
# routing it through a *real* freshly-started session bus was observed to
# take 25+ seconds - a slow xdg-desktop-portal backend (secrets/keyring)
# timing out during on-demand activation. A smoke test needs none of this, so
# the fastest and most deterministic option is to not have a bus at all.
export DBUS_SESSION_BUS_ADDRESS="unix:path=/dev/null"
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=/dev/null"

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

# Sample a point inside the preview thumbnail (roughly a quarter across,
# just under halfway down the dialog) and check it matches the test image's
# fill color, confirming the app actually decoded and rendered it. Retried
# rather than a single fixed sleep-then-sample: the first frame or two can
# still be mid-paint (e.g. texture upload for the preview image) on a slow
# or contended CI runner even after the window itself exists, and a single
# snapshot taken right then would sample stale/blank content.
screenshot="$work_dir/window.png"
eval "$(xdotool getwindowgeometry --shell "$window_id")"
sample_x=$((WIDTH * 28 / 100))
sample_y=$((HEIGHT * 46 / 100))
pixel=""
last_error=""
# Both `import` and `convert` are run inside an `if` here, not as bare
# commands - under `set -e`, a bare command failing anywhere aborts the
# whole script immediately, which would defeat this retry loop for the
# exact case it exists to absorb: `import -window` occasionally fails
# outright with "unable to read X window image ... Resource temporarily
# unavailable" (a transient X11 race, seen in CI) rather than just
# returning a stale/blank frame. Only a wrong-pixel result was being
# retried before; a hard `import` failure wasn't.
for _ in $(seq 1 20); do
    if last_error=$(import -window "$window_id" "$screenshot" 2>&1); then
        if convert_output=$(convert "$screenshot" -format "%[pixel:p{$sample_x,$sample_y}]" info: 2>&1); then
            pixel="$convert_output"
            if [ "$pixel" = "srgb(135,206,235)" ]; then
                break
            fi
        else
            last_error="$convert_output"
            pixel=""
        fi
    fi
    sleep 0.5
done
if [ "$pixel" != "srgb(135,206,235)" ]; then
    echo "Preview thumbnail did not show the test image at (${sample_x},${sample_y}): got '$pixel', expected 'srgb(135,206,235)'" >&2
    [ -n "$last_error" ] && echo "Last capture error: $last_error" >&2
    exit 1
fi

if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "App process is no longer running" >&2
    exit 1
fi

echo "Smoke test passed: window appeared and rendered the test image"
