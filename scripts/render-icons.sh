#!/usr/bin/env bash
# Renders the pixel-hinted app icon sources (data/icons/{16..64}.svg) to the
# PNGs that get installed into hicolor/NxN/apps and hicolor/NxN@2/apps.
# Re-run this and commit the result whenever one of those SVGs changes.
#
# Flathub's linter only allows PNGs in the sized hicolor folders, while the
# small sizes are separately drawn/hinted per size and shouldn't just be a
# downscaled 128.svg. 128.svg itself is installed as-is as the scalable icon,
# so it isn't rendered here. The PNGs are committed rather than rendered at
# build time so building doesn't need rsvg-convert (not installed by default
# on Ubuntu, CI runners included).
set -euo pipefail
cd "$(dirname "$0")/.."

sizes=(16 24 32 48 64)

if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg() { rsvg-convert "$@"; }
elif flatpak info io.elementary.Sdk//8.2 >/dev/null 2>&1; then
    echo "rsvg-convert not installed, falling back to the io.elementary.Sdk flatpak"
    # Reads the SVG via stdin and writes the PNG via stdout: the sandbox has
    # its own /tmp and can't see arbitrary host paths.
    rsvg() {
        flatpak run --command=rsvg-convert io.elementary.Sdk//8.2 "$@" 2>/dev/null
    }
else
    echo "rsvg-convert not found: install with 'sudo apt-get install librsvg2-bin'," \
        "or 'flatpak install --user appcenter io.elementary.Sdk//8.2'" >&2
    exit 1
fi

for size in "${sizes[@]}"; do
    # Always pass -w/-h instead of relying on the SVG's own width/height, so
    # an off-by-a-fraction document size can't produce e.g. a 25x25 PNG.
    rsvg -w "$size" -h "$size" < "data/icons/$size.svg" > "data/icons/$size.png"
    rsvg -w $((size * 2)) -h $((size * 2)) < "data/icons/$size.svg" > "data/icons/$size@2.png"
    echo "data/icons/$size.png, data/icons/$size@2.png"
done
