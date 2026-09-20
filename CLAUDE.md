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
- `--stop-at=MODULE` stops _before_ that module. To actually build module X, pass
  the module that comes _after_ X in the manifest.

## Source quirks

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
- CI builds the app twice, deliberately: the `flatpak` job builds it inside
  the Flatpak sandbox and runs `meson test` there (via `run-tests: true`
  above); the `smoke-test` job builds it *natively* on the bare runner,
  because the Flatpak sandbox has no display to run the GUI smoke test
  against. Don't try to consolidate these into one build.

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
- Xvfb (`xvfb-run`) is available on this machine, so `smoke-test.sh` can be
  run locally the same way CI does; use the live desktop session
  (`DISPLAY=:0`) for interactive GUI testing instead.
- `smoke-test.sh` deliberately points `DBUS_SESSION_BUS_ADDRESS` and
  `DBUS_SYSTEM_BUS_ADDRESS` at `unix:path=/dev/null`, so every D-Bus call the
  app makes at startup (GSettings, Granite's dark-mode/portal lookup, AT-SPI)
  fails instantly instead of triggering bus discovery or service activation.
  **Don't remove this or "fix" it with a real bus** (e.g. `dbus-run-session`):
  that was tried first and made things worse, since a fresh session bus makes
  `xdg-desktop-portal` cold-activate its backends on demand, and one backend
  (secrets/keyring) took the full ~25s D-Bus call timeout to fail. It also
  explains the original CI failure this was added for ("app window never
  appeared", only the 20x20 helper window present) — some activation attempt
  was blocking startup entirely. With the addresses blackholed, it's a
  consistent ~1.2s.
- `scripts/run.sh` is the equivalent for interactive manual testing: builds
  (if needed) and runs straight out of `_build/meson-native`, no
  `ninja install`, same D-Bus-blackholed isolation as `smoke-test.sh` (so
  concurrent worktrees/sessions can't collide via the single-instance
  GApplication id). Since that also blocks the appearance portal Granite
  would use for dark-mode detection, it separately reads the real
  `gtk-theme`/`color-scheme` via `gsettings` (run unsandboxed, so it's
  instant) and passes it through `$GTK_THEME`, which GTK reads directly with
  no D-Bus round trip — confirmed via `dbus-run-session` that a real bus
  gets dark mode right too, but cost ~30s to first window on this machine,
  so it's not worth it just for that.
- `smoke-test.sh` retries the pixel sample (up to ~10s) instead of a single
  fixed sleep-then-sample: on GTK4, a CI run once failed with the sampled
  pixel reading pure black even though the window had already appeared —
  the first frame or two can still be mid-paint (e.g. texture upload for the
  preview image) on a slow/contended runner. Reproduced the exact CI
  environment via Docker (versions, window size, sample coordinates all
  matched) but couldn't reproduce the actual failure after several runs,
  meaning it's a rare timing race rather than a deterministic bug - the retry
  loop is a cheap way to absorb it without weakening the assertion itself.
- Reproducing CI-only failures locally with `docker run` needs `--init`
  (without it, your entrypoint is PID 1, which has broken signal-handling
  semantics — this is why `xvfb-run` hung forever once, never receiving the
  `SIGUSR1` "Xvfb is ready" signal it waits for) and `git archive HEAD | tar
  -x` into the container rather than a bind mount (so you test exactly what's
  committed, not local working-tree state, including any stray `build/` dir).
  Also don't assume a tool is covered by the apt packages already listed —
  check with `apt-cache depends <pkg>` (e.g. `glib-compile-schemas` comes via
  `libgtk-3-dev` → `libglib2.0-dev` → `libglib2.0-bin`, but `gettext` and
  `desktop-file-utils` don't come from anywhere in that chain and were missing
  from CI until they caused a build failure).
