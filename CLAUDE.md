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

## Linting

`./scripts/lint.sh` runs the same checks as CI: Vala style (`io.elementary.vala-lint`),
`meson.build` formatting (`meson format`), `.po` syntax (`msgfmt --check`), `.desktop.in`
syntax (`desktop-file-validate`), XML well-formedness of `appdata.xml.in`/`gschema.xml`/icons
(`xmllint --noout`), and AppStream metadata (`appstreamcli validate`).

- `io.elementary.vala-lint` isn't in Ubuntu's default apt repos; install it with
  `sudo apt-get install io.elementary.vala-lint` (available via the elementary-os PPA/AppCenter
  repo) or via Docker: `docker run --rm -v "$PWD":/github/workspace -w /github/workspace
  valalang/lint:latest io.elementary.vala-lint -d src`. The script falls back to Docker
  automatically if the binary isn't found.
- `meson format` needs meson >= 1.5; apt's meson on Ubuntu 24.04 is older, so CI installs a
  recent one via pip.
- vala-lint's `-f`/`--fix` flag is unreliable on lines with nested parens (e.g. it turned
  `add(new Gtk.Label (""))` into `add( new Gtk.Label (""))` instead of `add (new ...)`) —
  always review its diff before trusting it.
- `desktop-file-validate` rejects files by extension, so the script/CI copy
  `com.github.peteruithoven.resizer.desktop.in` to a temp `*.desktop` file before checking it.

## GUI testing

- Desktop session is Wayland-native (pantheon-wayland). `xdotool`/`import` only see
  the window if the app is launched with `GDK_BACKEND=x11` (forces XWayland).
- No Xvfb installed — GUI testing happens on the live desktop session (`DISPLAY=:0`).
