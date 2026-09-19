# CLAUDE.md

Notes for working on this repo that aren't obvious from the code alone.

## Flatpak builds (test locally without sudo)

```
flatpak install --user flathub org.flatpak.Builder   # once
flatpak install --user appcenter io.elementary.Sdk//8 io.elementary.Platform//8
flatpak run --filesystem=host org.flatpak.Builder --force-clean \
  <project-dir>/_build/build com.github.peteruithoven.resizer.yml
```

- Build dir must be **inside the project directory**, not `/tmp` — cross-filesystem
  builds fail with `Invalid cross-device link`.
- `--stop-at=MODULE` stops *before* that module. To actually build module X, pass
  the module that comes *after* X in the manifest.

## Source quirks

- `src/ErrorPage.vala` is dead code: not listed in `src/meson.build`, references a
  signal that doesn't exist on `Resizer`. Don't try to fix it, just ignore it.
- The app's file picker only accepts **PNG / JPEG / BMP / TIFF**
  (`DropArea.vala`, `supported_mimetypes`). No WebP, SVG, or GIF support.
- `Math.round()` in Vala needs libm, which isn't linked by the current
  `meson.build`. Prefer `(int)(x + 0.5)` for positive values instead of adding
  the dependency.

## GUI testing

- Desktop session is Wayland-native (pantheon-wayland). `xdotool`/`import` only see
  the window if the app is launched with `GDK_BACKEND=x11` (forces XWayland).
- No Xvfb installed — GUI testing happens on the live desktop session (`DISPLAY=:0`).
