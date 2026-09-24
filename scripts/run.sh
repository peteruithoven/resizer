#!/usr/bin/env bash
# Builds (if needed) and runs the app the way Flathub users get it: compiled
# against and run inside the same GNOME runtime as the Flatpak manifest, not
# the host's own (older) GTK/libadwaita, with the same permissions. Nothing
# is installed - the build lives in _build/, and rebuilds are incremental
# `ninja` runs inside the SDK (via `flatpak build`), so they're quick.
#
# Usage: ./scripts/run.sh [--build-only] [--gnome-defaults] [FILE...]
#   FILE...           opened directly (skips drag-and-drop). Like in the real
#                     Flatpak, they need to be somewhere under $HOME.
#   --gnome-defaults  ignore this desktop's settings (font, accent color,
#                     window buttons, ...) and use GNOME's defaults instead,
#                     i.e. what Flathub's screenshot guidelines ask for.
#                     Light/dark then comes from COLOR_SCHEME
#                     (prefer-light|prefer-dark), defaulting to light.
#   --build-only      just build, don't run.
#
# By default the app talks to the real session bus through Flatpak's
# filtered proxy, exactly like `flatpak run` - it has to: the runtime's
# image loaders (glycin) decode every image in a separate sandbox spawned
# via the Flatpak portal, so without it no image can be opened at all. That
# also means the settings portal applies this desktop's appearance, and the
# file chooser is the desktop's own portal dialog. See CLAUDE.md "GUI
# testing" for why the old "blackhole D-Bus" isolation can't be used anymore.
set -euo pipefail
cd "$(dirname "$0")/.."

gnome_defaults=false
build_only=false
while [ $# -gt 0 ]; do
    case "$1" in
    --gnome-defaults) gnome_defaults=true ;;
    --build-only) build_only=true ;;
    *) break ;;
    esac
    shift
done

app_id="io.github.peteruithoven.resizer"
manifest="$app_id.yml"
build_dir="_build/flatpak-dev"
meson_dir="_build/meson-flatpak"

runtime=$(sed -n 's/^runtime: *//p' "$manifest")
sdk=$(sed -n 's/^sdk: *//p' "$manifest")
runtime_version=$(sed -n "s/^runtime-version: *'\{0,1\}\([^']*\)'\{0,1\}$/\1/p" "$manifest")
mapfile -t finish_args < <(sed -n "s/^ *- *'\{0,1\}\(--[^']*\)'\{0,1\}$/\1/p" "$manifest")

# Start over if the manifest has moved to another runtime version since.
if [ -f "$build_dir/metadata" ] &&
    ! grep -qx "runtime=$runtime/$(flatpak --default-arch)/$runtime_version" "$build_dir/metadata"; then
    echo "==> Runtime changed, removing $build_dir and $meson_dir"
    rm -rf "$build_dir" "$meson_dir"
fi

if [ ! -f "$build_dir/metadata" ]; then
    echo "==> Setting up $build_dir ($runtime $runtime_version)"
    flatpak build-init "$build_dir" "$app_id" "$sdk" "$runtime" "$runtime_version"
fi

sdk_run=(flatpak build --filesystem="$PWD" "$build_dir")
if [ ! -d "$meson_dir" ]; then
    echo "==> Setting up $meson_dir"
    "${sdk_run[@]}" meson setup --prefix=/app "$meson_dir"
fi

echo "==> Building"
"${sdk_run[@]}" ninja -C "$meson_dir" install >/dev/null
if $build_only; then
    exit 0
fi

# The app is a single-instance GApplication on the real session bus, so a
# second copy (the installed Flatpak, or this script in another worktree)
# would just hand its files over to the one already running.
already_running=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.NameHasOwner "$app_id" 2>/dev/null || true)
if [ "$already_running" = "(true,)" ]; then
    echo "Resizer is already running (installed, or from another worktree) - close it first." >&2
    exit 1
fi

run_args=(
    --with-appdir
    --die-with-parent
    "${finish_args[@]}"
    # Any --talk-name makes `flatpak build` set up the same filtered session
    # bus proxy as `flatpak run`, which always allows the portals.
    --talk-name=org.freedesktop.portal.Flatpak
)

# `flatpak build` doesn't proxy the accessibility bus like `flatpak run`
# does, so hand the host's one in directly - screen readers and
# scripts/screenshots.py (AT-SPI) need it.
a11y_address=$(gdbus call --session --dest org.a11y.Bus --object-path /org/a11y/bus \
    --method org.a11y.Bus.GetAddress 2>/dev/null | sed -n "s/^('\(unix:path=\([^,']*\)[^']*\)',)$/\1 \2/p" || true)
if [ -n "$a11y_address" ]; then
    read -r a11y_bus a11y_socket <<<"$a11y_address"
    run_args+=(--filesystem="$(dirname "$a11y_socket")" --env=AT_SPI_BUS_ADDRESS="$a11y_bus")
fi

if $gnome_defaults; then
    # With the settings portal off, GTK and libadwaita fall back to
    # GSettings, which the memory backend pins to the runtime's schema
    # defaults (this also starts the app's own max width/height from their
    # defaults, without saving them). GTK doesn't read the window button
    # layout from there, so that one's set explicitly to GNOME's default.
    gtk_config="$PWD/_build/gnome-defaults"
    mkdir -p "$gtk_config/gtk-4.0"
    printf '[Settings]\ngtk-decoration-layout=appmenu:close\n' >"$gtk_config/gtk-4.0/settings.ini"
    run_args+=(
        --env=GDK_DEBUG=no-portals
        --env=ADW_DISABLE_PORTAL=1
        --env=ADW_DEBUG_COLOR_SCHEME="${COLOR_SCHEME:-prefer-light}"
        --env=GSETTINGS_BACKEND=memory
        --env=XDG_CONFIG_DIRS="$gtk_config"
    )
fi

echo "==> Running"
exec flatpak build "${run_args[@]}" "$build_dir" "$app_id" "$@"
