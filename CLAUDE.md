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

## Automated tests

- Business logic (bounded-size math, extension→format mapping, output-filename
  generation) lives in `src/ImageGeometry.vala`, kept free of GTK so it's
  unit-testable in isolation. Tests: `tests/test-image-geometry.vala`
  (GLib.Test/TAP), run via `meson test`.
- Sharing a Vala source across sibling meson subdirs via a relative path string
  (e.g. `'../src/Foo.vala'`) breaks meson's generated C file paths
  (`tests/src/Foo.c: No such file or directory`). Export it as a `files()`
  variable from the owning subdir's `meson.build`
  (`image_geometry_sources = files(...)`) and reference that variable instead.
- flatpak-builder only runs `ninja test` for a module if that module has
  `run-tests: true` in the manifest — the GH Action's own `run-tests: true`
  input alone doesn't do it. `--disable-tests` on the flatpak-builder CLI is
  the opt-*out*, not opt-in.
- `ninja install` builds *all* targets regardless of `build_by_default: false`
  (used on the test binary to keep it out of a plain `ninja`).

## GUI testing

- Desktop session is Wayland-native (pantheon-wayland). `xdotool`/`import` only see
  the window if the app is launched with `GDK_BACKEND=x11` (forces XWayland).
- Synthetic keyboard input (`xdotool key`/`type`) does not reach the app in that
  XWayland session — mouse clicks work, keyboard doesn't. Don't rely on keyboard
  shortcuts (e.g. Enter-to-resize) for local interactive testing; real Xvfb (no
  window manager) may behave differently.
- The app has a hidden 20x20 helper window whose title is the app ID, not
  "Resizer" — `xdotool search --name` must anchor with `^Resizer$`, or a loose
  match can grab the wrong window.
- `scripts/smoke-test.sh` is a headless smoke test: launches the app, opens a
  generated test image via CLI (`HANDLES_OPEN`), and checks the preview
  thumbnail actually rendered it — deliberately no button-clicking, to avoid
  the input fragility above. Run with `xvfb-run -a ./scripts/smoke-test.sh`
  once the app is installed and on PATH.
- `xvfb-run` only sets `DISPLAY`; it does **not** unset `WAYLAND_DISPLAY`. On
  a real Wayland desktop session, GTK3 prefers Wayland when both are set, so
  without forcing `GDK_BACKEND=x11` the app silently connects to the real
  desktop instead of the virtual display — it visibly pops up on screen while
  `xdotool`, which only ever looks at the virtual X server, finds nothing.
  `smoke-test.sh` exports `GDK_BACKEND=x11` itself for exactly this reason.
- No Xvfb installed locally — interactive GUI testing happens on the live
  desktop session (`DISPLAY=:0`).
- D-Bus/portal activation is a real hang risk under Xvfb and was the cause of
  a CI failure ("app window never appeared" after 30s, only the 20x20 helper
  window present). Don't try to fix this by providing a *working* D-Bus
  session (e.g. `dbus-run-session`) — that was tried and made things worse: on
  a machine with real portal backends installed, a fresh session bus
  triggered on-demand activation of `xdg-desktop-portal`, and one backend
  (secrets/keyring) took the full ~25s D-Bus call timeout before giving up.
  The fix `smoke-test.sh` uses instead is to point both
  `DBUS_SESSION_BUS_ADDRESS` and `DBUS_SYSTEM_BUS_ADDRESS` at
  `unix:path=/dev/null`, so every D-Bus call fails immediately with no
  autolaunch/activation attempted at all. Consistently ~1.2s end to end this
  way, vs. up to 26s+ or an outright hang otherwise.
- Reproducing CI-only failures locally: a bare `docker run` isn't equivalent
  to a GitHub Actions runner. Two gotchas hit while investigating the above:
  (1) `docker run` without `--init` makes your entrypoint PID 1, which gets
  special (broken) signal-handling semantics in Linux — `xvfb-run` hung
  forever because it never received the `SIGUSR1` "Xvfb is ready" signal it
  waits for. Always use `docker run --init` for this kind of repro.
  (2) Package availability isn't just about what's in the apt list — verify
  transitively-pulled tools too (e.g. `glib-compile-schemas` comes via
  `libgtk-3-dev` → `libglib2.0-dev` → `libglib2.0-bin`, but `gettext` and
  `desktop-file-utils` don't come from anywhere in that chain and must be
  installed explicitly). Use `apt-cache depends <pkg>` to check before
  assuming, and `git archive HEAD | tar -x` (not a bind mount) to test
  against exactly what's committed, not local working-tree state.
