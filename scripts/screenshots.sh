#!/usr/bin/env bash
# Captures one screenshot per app state, in both light and dark mode, into
# data/screenshots/ as screenshot-<os-version>-<light|dark>-<state>.png -
# candidates for AppStream's <screenshots> in the appdata.xml. This is a
# manual/interactive dev tool (not run in CI): a quick way to eyeball several
# states at once and refresh the screenshots bundled with a release.
#
# Usage: ./scripts/screenshots.sh [os-version]
#   os-version defaults to "8" (the current elementary OS SDK major version
#   this app targets, see CLAUDE.md "Flatpak builds").
#
# Requires a real desktop session (DISPLAY=:0, not xvfb-run - this wants the
# actual elementary OS theme rendered, not a headless render) with xdotool
# and ImageMagick (import/convert/identify) on PATH. See CLAUDE.md
# "GUI testing" for why GDK_BACKEND=x11 and the D-Bus-blackhole isolation
# below are needed on this Wayland desktop.
set -euo pipefail
cd "$(dirname "$0")/.."
repo_root="$PWD"

os_version="${1:-8}"

build_dir="_build/meson-native"
schema_dir="$build_dir/schemas"
binary="$repo_root/$build_dir/com.github.peteruithoven.resizer"
out_dir="$repo_root/data/screenshots"
examples_dir="$repo_root/data/examples"

window_title='^Resizer$'

for cmd in xdotool import convert identify gsettings; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required tool '$cmd' not found on PATH." >&2
        exit 1
    fi
done
if [ -z "${DISPLAY:-}" ]; then
    echo "DISPLAY is not set. Run this from a real desktop session (e.g. DISPLAY=:0), not headless." >&2
    exit 1
fi

echo "==> Building"
if [ ! -d "$build_dir" ]; then
    meson setup "$build_dir"
fi
ninja -C "$build_dir"

mkdir -p "$schema_dir"
cp data/com.github.peteruithoven.resizer.gschema.xml "$schema_dir/"
glib-compile-schemas "$schema_dir"

mkdir -p "$out_dir"

# Base theme name (e.g. "io.elementary.stylesheet.mint"), read once via
# gsettings - this call isn't sandboxed so it's instant, unlike going through
# the (deliberately blackholed, see below) D-Bus appearance portal. The dark
# variant of an elementary stylesheet theme is just this name with ":dark"
# appended.
base_theme="$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")"
if [ -z "$base_theme" ]; then
    echo "Could not read a GTK theme via gsettings; can't force light/dark variants." >&2
    exit 1
fi

app_pid=""

# Launches the app with a forced theme variant and the given file args.
# Sets $app_pid and (after wait_for_window) $wid.
launch_app () {
    local variant="$1"
    shift
    local gtk_theme="$base_theme"
    if [ "$variant" = "dark" ]; then
        gtk_theme="$base_theme:dark"
    fi
    GSETTINGS_SCHEMA_DIR="$repo_root/$schema_dir" \
    GSETTINGS_BACKEND=memory \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/dev/null" \
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=/dev/null" \
    GDK_BACKEND=x11 \
    NO_AT_BRIDGE=1 \
    GTK_THEME="$gtk_theme" \
        "$binary" "$@" >/tmp/resizer-screenshots.log 2>&1 &
    app_pid=$!
}

wid=""
wait_for_window () {
    wid=""
    for _ in $(seq 1 60); do
        if ! kill -0 "$app_pid" 2>/dev/null; then
            echo "App exited before its window appeared. Log:" >&2
            cat /tmp/resizer-screenshots.log >&2
            exit 1
        fi
        wid=$(xdotool search --name "$window_title" 2>/dev/null | head -1) || true
        if [ -n "$wid" ]; then
            return
        fi
        sleep 0.2
    done
    echo "App window never appeared after 12s." >&2
    exit 1
}

close_app () {
    if [ -n "$app_pid" ] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$app_pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$app_pid" 2>/dev/null || true
    fi
    app_pid=""
    wid=""
}
trap close_app EXIT

# Clicks the "Resize" button. Only valid on the 2-image resize page (used by
# the resizing/resizing-error states below) - these fractions of the current
# window size were measured against that exact page in the real elementary
# theme; they'd need re-measuring if that page's layout changes.
click_resize_button () {
    eval "$(xdotool getwindowgeometry --shell "$wid")"
    local x=$((WIDTH * 875 / 1000))
    local y=$((HEIGHT * 836 / 1000))
    xdotool mousemove --window "$wid" "$x" "$y" click 1
}

# click_resize_button, but verifies the click actually landed by checking
# that the (much shorter) resizing page appeared, retrying a couple of times
# if not. Guards against the button's position drifting a bit - e.g. a
# longer "9999" in the width/height spinbuttons subtly changes the resize
# page's height - and a missed click otherwise silently produces a
# screenshot of the wrong page instead of an error.
click_resize_button_verified () {
    local check probe_h
    for _ in 1 2 3; do
        click_resize_button
        for check in 1 2 3 4 5; do
            sleep 0.1
            # A resize that finishes very fast can close the window (or exit
            # the app) inside this same short poll window - that's just as
            # much evidence the click landed as seeing the shorter resizing
            # page appear, so treat either as success.
            ! kill -0 "$app_pid" 2>/dev/null && return 0
            probe_h=$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null | sed -n 's/^HEIGHT=//p')
            [ -n "$probe_h" ] && [ "$probe_h" -lt 400 ] && return 0
        done
    done
    echo "warning: clicking Resize doesn't seem to have switched to the resizing page" >&2
    return 1
}

# Classifies the pixel at a fixed fraction of the progress bar's width
# (90%, comfortably before its right end/rounded corner) as "filled" or
# "unfilled" by checking for color saturation: the unfilled track is a
# neutral gray/white (or dark gray in dark mode) with R==G==B, while any
# accent-colored fill has a clear spread between channels regardless of the
# user's chosen accent color.
# Returns 0 (filled) or 1 (unfilled/unreadable - callers treat "unreadable"
# the same as "unfilled", i.e. keep looking) - never errors out, since a
# frame grabbed mid-repaint or mid-window-resize can occasionally be
# malformed and that's expected here, not a bug to fail the whole capture on.
bar_sample_is_filled () {
    local img="$1"
    local w h
    # No "|| return 1" on these reads: identify/convert's output has no
    # trailing newline, so `read` itself reports EOF (exit 1) even on a
    # successful read - the emptiness checks below are what actually detect
    # a real failure.
    read -r w h < <(identify -format "%w %h" "$img" 2>/dev/null)
    [ -n "${w:-}" ] && [ -n "${h:-}" ] || return 1
    local x=$((w * 90 / 100))
    local y=$((h * 42 / 100))
    local rgb
    rgb=$(convert "$img" -format "%[pixel:p{$x,$y}]" info: 2>/dev/null) || return 1
    local r g b
    read -r r g b < <(echo "$rgb" | grep -oE '[0-9]+' | head -3 | tr '\n' ' ')
    [ -n "${r:-}" ] && [ -n "${g:-}" ] && [ -n "${b:-}" ] || return 1
    local max=$r min=$r v
    for v in "$g" "$b"; do
        if [ "$v" -gt "$max" ]; then max=$v; fi
        if [ "$v" -lt "$min" ]; then min=$v; fi
    done
    [ $((max - min)) -gt 20 ]
}

# Captures $wid to $1, retrying for a couple seconds if the frame comes back
# as a single flat color - the window can report as mapped before GTK has
# actually painted anything into it yet, and a fixed sleep before the first
# capture isn't always enough (same issue and fix as smoke-test.sh's pixel
# retry loop, see CLAUDE.md "GUI testing").
capture_when_painted () {
    local out="$1"
    local colors
    for _ in $(seq 1 20); do
        timeout 1 import -window "$wid" "$out" 2>/dev/null || true
        colors=$(identify -format "%k" "$out" 2>/dev/null) || colors=0
        [ -n "$colors" ] && [ "$colors" -gt 20 ] && return 0
        sleep 0.15
    done
    echo "warning: $out may still be a blank/unpainted frame" >&2
}

capture_static () {
    local variant="$1" state="$2"
    shift 2
    launch_app "$variant" "$@"
    wait_for_window
    sleep 0.3
    capture_when_painted "$out_dir/screenshot-$os_version-$variant-$state.png"
    close_app
    echo "  wrote screenshot-$os_version-$variant-$state.png"
}

capture_resizing_error () {
    local variant="$1"
    local tmp
    tmp=$(mktemp -d)
    cp "$examples_dir/blue.jpg" "$examples_dir/purple.jpg" "$tmp/"
    # Read-only dir: the app can load these files fine but can't write the
    # resized output next to them, which is a reliable, fast way to trigger
    # ResizeFailureMessage without needing a slow/huge image.
    chmod 555 "$tmp"

    launch_app "$variant" "$tmp/blue.jpg" "$tmp/purple.jpg"
    wait_for_window
    sleep 0.3
    click_resize_button_verified
    sleep 0.6
    capture_when_painted "$out_dir/screenshot-$os_version-$variant-resizing-error.png"
    close_app

    chmod 755 "$tmp"
    rm -rf "$tmp"
    echo "  wrote screenshot-$os_version-$variant-resizing-error.png"
}

capture_resizing () {
    local variant="$1"
    local tmp
    tmp=$(mktemp -d)
    # blue.jpg/purple.jpg are tiny (300x200) - resizing them is too fast to
    # ever catch a "1 image remaining" mid-progress frame, so use heavily
    # upscaled copies just to slow the decode/scale down to something a
    # screenshot loop can actually catch. Same images, just bigger, and the
    # resizing page shows no image preview anyway (only a progress bar), so
    # the extra pixels are otherwise invisible.
    convert "$examples_dir/blue.jpg" -resize 8000x6000\! "$tmp/blue.jpg"
    convert "$examples_dir/purple.jpg" -resize 8000x6000\! "$tmp/purple.jpg"

    launch_app "$variant" "$tmp/blue.jpg" "$tmp/purple.jpg"
    wait_for_window
    sleep 0.3
    click_resize_button_verified

    local best="" frame="" frame_h
    for i in $(seq 1 60); do
        frame="$tmp/frame-$i.png"
        # timeout guards against import hanging instead of failing fast when
        # $wid has just been destroyed (observed in practice: a plain
        # `import -window` on an already-gone window can block indefinitely
        # rather than erroring out).
        timeout 1 import -window "$wid" "$frame" 2>/dev/null || { frame=""; break; }
        # The resizing page (just a progress bar) is much shorter than the
        # resize page (image previews + inputs) it replaces - frames grabbed
        # before the page switch has actually happened are still the old,
        # tall resize page, and its colorful preview images would otherwise
        # get misread by bar_sample_is_filled as "the bar is full". Skip
        # those instead of treating them as progress-bar candidates.
        frame_h=$(identify -format "%h" "$frame" 2>/dev/null) || continue
        [ -n "$frame_h" ] && [ "$frame_h" -lt 400 ] || continue
        if bar_sample_is_filled "$frame"; then
            break
        fi
        best="$frame"
    done
    if [ -z "$best" ]; then
        best="$frame"
    fi
    if [ -n "$best" ] && [ -f "$best" ]; then
        cp "$best" "$out_dir/screenshot-$os_version-$variant-resizing.png"
        echo "  wrote screenshot-$os_version-$variant-resizing.png"
    else
        echo "warning: never captured a usable resizing-page frame for $variant, skipping" >&2
    fi
    close_app

    rm -rf "$tmp"
}

for variant in light dark; do
    echo "==> Capturing $variant screenshots"
    capture_static "$variant" image "$examples_dir/blue.jpg"
    capture_static "$variant" empty
    capture_static "$variant" images "$examples_dir/blue.jpg" "$examples_dir/purple.jpg"
    capture_static "$variant" format-issues "$examples_dir/example.pdf" "$examples_dir/example.svg"
    capture_resizing "$variant"
    capture_resizing_error "$variant"
done

echo "==> Done. Screenshots written to $out_dir"
