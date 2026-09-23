#!/usr/bin/env bash
# Builds (if needed) and runs the app straight out of this worktree's own
# build directory - no `ninja install`, nothing written outside _build/.
# Any file paths given as arguments are opened directly (skips drag-and-drop).
#
# Isolated from the system-installed app and from any other worktree/session
# running this same script concurrently:
# - GSettings schema is compiled locally instead of relying on an installed
#   one (see CLAUDE.md "Flatpak builds").
# - D-Bus is pointed at nothing, so this instance can't be picked up by (or
#   pick up) another already-running instance of the same single-instance
#   GApplication id, and startup isn't slowed by a real bus's
#   xdg-desktop-portal backend activation (see CLAUDE.md "GUI testing" -
#   this was previously tried with `dbus-run-session`, and on this machine a
#   real private bus's secrets/keyring portal backend measurably took ~30s to
#   cold-activate before the window appeared).
#
# Blackholing D-Bus also means the app can't reach the appearance portal it'd
# normally use to detect dark mode, so it would otherwise always open light
# regardless of the desktop's actual setting. To fix that without paying for
# a real bus, the current GTK theme + light/dark preference is read once via
# `gsettings` (this script itself isn't sandboxed, so that call is instant)
# and handed in via $GTK_THEME, which GTK reads directly at startup with no
# D-Bus involved at all.
set -euo pipefail
cd "$(dirname "$0")/.."

build_dir="_build/meson-native"
schema_dir="$build_dir/schemas"

if [ ! -d "$build_dir" ]; then
    echo "==> Setting up $build_dir"
    meson setup "$build_dir"
fi

echo "==> Building"
ninja -C "$build_dir"

mkdir -p "$schema_dir"
cp data/io.github.peteruithoven.resizer.gschema.xml "$schema_dir/"
glib-compile-schemas "$schema_dir"

gtk_theme="$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || true)"
color_scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'" || true)"
if [ "$color_scheme" = "prefer-dark" ] && [ -n "$gtk_theme" ]; then
    gtk_theme="$gtk_theme:dark"
fi

env_vars=(
    GSETTINGS_SCHEMA_DIR="$PWD/$schema_dir"
    DBUS_SESSION_BUS_ADDRESS="unix:path=/dev/null"
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=/dev/null"
)
if [ -n "$gtk_theme" ]; then
    env_vars+=(GTK_THEME="$gtk_theme")
fi

echo "==> Running"
exec env "${env_vars[@]}" "$build_dir/io.github.peteruithoven.resizer" "$@"
