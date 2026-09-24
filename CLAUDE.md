# CLAUDE.md

Notes for working on this repo that aren't obvious from the code alone.

## Flatpak builds (test locally without sudo)

```
flatpak install --user flathub org.flatpak.Builder   # once
flatpak install --user flathub org.gnome.Sdk//51 org.gnome.Platform//51
flatpak run --filesystem=host org.flatpak.Builder --force-clean \
  <project-dir>/_build/build io.github.peteruithoven.resizer.yml
# Flathub's linter (same checks as the Flathub submission):
flatpak run --filesystem=host --command=flatpak-builder-lint org.flatpak.Builder \
  manifest io.github.peteruithoven.resizer.yml
flatpak run --filesystem=host --command=flatpak-builder-lint org.flatpak.Builder \
  builddir <project-dir>/_build/build
```

- Build dir must be **inside the project directory**, not `/tmp` — cross-filesystem
  builds fail with `Invalid cross-device link`.
- `--stop-at=MODULE` stops _before_ that module. To actually build module X, pass
  the module that comes _after_ X in the manifest.
- The Flatpak uses the GNOME runtime from Flathub (Flathub requires a
  Flathub-hosted runtime, at the latest version when submitting), so it
  renders with stock libadwaita (Adwaita) everywhere, including on elementary
  OS - no elementary stylesheet, no Granite. It does still pick up the
  desktop's appearance through the settings portal (dark style, accent
  color, font, window buttons), and host icon themes (Flatpak exposes them),
  so on elementary OS it gets elementary's accent color, Inter, and
  elementary's symbolic icons.
- `flatpak-builder-lint` errors that are expected for now:
  `finish-args-home-filesystem-access` (to be justified in the submission:
  the resized image is written next to the original) and
  `appstream-external-screenshot-url` (Flathub's own build mirrors them);
  `lint repo` additionally reports `appstream-screenshots-not-mirrored-in-ostree`
  for the same reason. A screenshot URL that doesn't exist on `main` yet
  (e.g. in a PR adding it) shows up as `appstream-missing-screenshots`
  instead.
- The runtime's image loading goes through glycin, which decodes each image
  in a separate sandbox spawned via the Flatpak portal
  (`flatpak-spawn --sandbox`) on the session bus. So the app can't open any
  image in a sandbox without a session bus (you get a "Loader process exited
  early" error toast) - relevant for `scripts/run.sh`, see "GUI testing".

## Source quirks

- App icon: `data/icons/{16..64}.svg` are pixel-hinted sources only; what gets
  installed is the committed `{N}.png`/`{N}@2.png` rendered from them (Flathub's
  linter rejects SVGs in sized `hicolor/NxN/` folders). After editing one of
  those SVGs, re-run `scripts/render-icons.sh` and commit the PNGs.
  `128.svg` is installed directly as the scalable icon.

- The app's file picker only accepts **PNG / JPEG / BMP / TIFF**
  (`DropArea.vala`, `supported_mimetypes`). No WebP, SVG, or GIF support.
- `Math.round()` in Vala needs libm, which isn't linked by the current
  `meson.build`. Prefer `(int)(x + 0.5)` for positive values instead of adding
  the dependency.
- GTK4 CSS has no `max-width`/`max-height` property (only `min-width`/
  `min-height` exist and affect measurement) — setting one via
  `Gtk.CssProvider` fails silently with a `Theme parser error: ... No
property named "max-width"` warning and, worse, seems to break that node's
  rendering entirely rather than just ignoring the bad declaration. There's
  no way to cap `Adw.Toast`'s width via CSS, and its API only takes a plain
  string (no custom widget to wrap in `Adw.Clamp`, which is what
  `DropArea.vala` uses to cap the placeholder text's width instead). Window
  is `resizable: false` but still auto-grows to fit a child's natural-size
  request (same root cause as the old `Gtk.InfoBar` bug, see
  `MessageCenter.vala`), so an unbounded toast message balloons the window.
  `ImageGeometry.truncated_join()` pre-truncates the message text itself as
  the practical workaround.

## Linting

`./scripts/lint.sh` runs the same checks as CI: Vala style (`io.elementary.vala-lint`),
`meson.build` formatting (`meson format`), `.po` syntax (`msgfmt --check`), `.desktop.in`
syntax (`desktop-file-validate`), XML well-formedness of `metainfo.xml.in`/`gschema.xml`/icons
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
  `io.github.peteruithoven.resizer.desktop.in` to a temp `*.desktop` file before checking it.
- Released metainfo files point their screenshots at `main` (raw GitHub
  URLs), so don't delete or rename screenshots a released version still
  references: AppCenter still serves 2.3.0, which uses the `screenshot*.png`
  files in the repo root.
- The metainfo leaves out the `empty` screenshots on purpose: Flathub's
  guidelines say screenshots shouldn't show empty states.
  `scripts/screenshots.py` still captures them for testing.
- `appstreamcli validate` runs with `--no-net`: the metainfo's screenshot
  URLs point at `main`, so without it a PR that adds or renames a
  screenshot fails until it's merged. Flathub's build fetches (and mirrors)
  them anyway, which catches a broken URL.

## Automated tests

- Business logic is kept free of GTK so it's unit-testable in isolation, in
  two namespaces mirroring `elementary/calculator`'s and
  `elementary/appcenter`'s own `src/Core/` convention for framework-independent
  logic:
    - `src/Core/` — generic reusable logic, one class per file (`ImageGeometry`:
      bounded-size math; `ImageFormat`: extension→pixbuf-type mapping and
      extension display labels; `FileNaming`: output-filename generation;
      `Strings`: truncate-with-ellipsis and dedup-preserving-order helpers).
    - `src/Messages/` — one class per toast message, composing `Core/` helpers
      plus `ngettext`/`_()` into the final localized string
      (`UnsupportedFileTypesMessage`, `ResizeFailureMessage`,
      `PreviewErrorMessage`). `MessageCenter` only ever receives an
      already-formatted string from these.
    - Tests mirror this 1:1 (`tests/test-image-geometry.vala`,
      `tests/test-image-format.vala`, etc.), but are wired into just two
      GLib.Test/TAP binaries — `tests/test-core-main.vala` and
      `tests/test-messages-main.vala` hold the `Test.add_func` calls for every
      test file in their group, since only one file per executable can define
      `main()`. Run via `meson test`.
- `_()`/`ngettext()` work in the test binaries with no extra setup: they're
  Vala/GLib built-ins that just pass strings through untranslated without a
  bound catalog, and `add_project_arguments('-DGETTEXT_PACKAGE=...')` in the
  root `meson.build` already applies to every target, tests included.
- Sharing a Vala source across sibling meson subdirs via a relative path string
  (e.g. `'../src/Foo.vala'`) breaks meson's generated C file paths
  (`tests/src/Foo.c: No such file or directory`). Export it as a `files()`
  variable from the owning subdir's `meson.build`
  (`core_sources = files(...)`) and reference that variable instead.
- `ninja -C build -t targets` (no args) only lists targets reachable from the
  default build, so a `build_by_default: false` test executable like
  `tests/test-core` won't show up there even though it exists — use
  `ninja -C build -t targets all` to see it, and build/run it by its full
  path (`ninja -C build tests/test-core`), not just the bare name passed to
  `executable()`.
- flatpak-builder only runs `ninja test` for a module if that module has
  `run-tests: true` in the manifest — the GH Action's own `run-tests: true`
  input alone doesn't do it. `--disable-tests` on the flatpak-builder CLI is
  the opt-_out_, not opt-in.
- `ninja install` builds _all_ targets regardless of `build_by_default: false`
  (used on the test binary to keep it out of a plain `ninja`).
- CI builds the app twice, deliberately: the `flatpak` job builds it inside
  the Flatpak sandbox and runs `meson test` there (via `run-tests: true`
  above); the `smoke-test` job builds it _natively_ on the bare runner,
  because the Flatpak sandbox has no display to run the GUI smoke test
  against. Don't try to consolidate these into one build.

## GUI testing

- Desktop session is Wayland-native (pantheon-wayland). `xdotool`/`import` only see
  the window if the app is launched with `GDK_BACKEND=x11` (forces XWayland).
  Don't do that for the Flatpak/`scripts/run.sh`, though: under X11, GTK also
  reads `gsd-xsettings`' XSETTINGS (host font etc.), so it no longer shows
  what users see. Drive it via AT-SPI instead (button actions, progress
  value), and capture it with gala's `org.gnome.Shell.Screenshot.ScreenshotWindow`.
- `ScreenshotWindow` captures whichever window is **focused**, not a given
  one, and there's no way to focus a Wayland window from a script. A newly
  opened window normally gets focus, but if someone's using the desktop (or
  a portal dialog is up) it silently captures some other app's window
  instead. Check the app's AT-SPI frame has the `ACTIVE` state before and
  after capturing (`scripts/screenshots.py` does).
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
- For visual/screenshot testing, launch via `scripts/run.sh`, not a native
  build (`meson setup`/`ninja` on the host). A native build links the
  host's own GTK/libadwaita (on elementary OS 8: libadwaita 1.5), while the
  Flatpak gets the GNOME runtime's (GNOME 51: GTK 4.24, libadwaita 1.10) -
  different widget metrics, colors and icons. `run.sh` compiles and runs the
  app inside that runtime (see below).
- `smoke-test.sh` deliberately points `DBUS_SESSION_BUS_ADDRESS` and
  `DBUS_SYSTEM_BUS_ADDRESS` at `unix:path=/dev/null`, so every D-Bus call the
  app makes at startup (GSettings, libadwaita's dark-mode/appearance-portal
  lookup, AT-SPI) fails instantly instead of triggering bus discovery or
  service activation.
  **Don't remove this or "fix" it with a real bus** (e.g. `dbus-run-session`):
  that was tried first and made things worse, since a fresh session bus makes
  `xdg-desktop-portal` cold-activate its backends on demand, and one backend
  (secrets/keyring) took the full ~25s D-Bus call timeout to fail. It also
  explains the original CI failure this was added for ("app window never
  appeared", only the 20x20 helper window present) — some activation attempt
  was blocking startup entirely. With the addresses blackholed, it's a
  consistent ~1.2s.
- `scripts/run.sh` is for interactive manual testing: builds the app
  incrementally inside the Flatpak's SDK (`flatpak build-init` +
  `flatpak build ... ninja`, into `_build/flatpak-dev` and
  `_build/meson-flatpak`) and runs it from there with the manifest's
  permissions, no install. Unlike `smoke-test.sh` it can't blackhole D-Bus:
  glycin needs the Flatpak portal (see "Flatpak builds"), so it uses the
  real session bus through Flatpak's filtered proxy, same as `flatpak run`.
  That brings back the single-instance GApplication collision (with the
  installed Flatpak or another worktree's `run.sh`), so the script refuses
  to start while the app id already has an owner on the bus.
  - Default: looks like the Flatpak on _this_ desktop (desktop's
    dark/accent/font/window buttons via the settings portal, desktop's
    portal file chooser).
  - `--gnome-defaults`: GNOME's defaults, as Flathub's screenshot
    guidelines require - `GDK_DEBUG=no-portals` + `ADW_DISABLE_PORTAL=1`
    make GTK/libadwaita skip the settings portal and fall back to
    GSettings, which `GSETTINGS_BACKEND=memory` pins to the runtime's schema
    defaults (Adwaita Sans 11, blue accent). GTK's fallback doesn't read the
    window button layout from GSettings (it shows minimize+close), so a
    `settings.ini` sets GNOME's `appmenu:close`. Light/dark comes from
    `COLOR_SCHEME` via `ADW_DEBUG_COLOR_SCHEME`. glycin still works, since it
    uses the Flatpak portal directly, not GTK's portal code.
  - `flatpak build` doesn't proxy the a11y bus the way `flatpak run` does,
    so the script hands in the host's AT-SPI bus socket itself.
  - Files passed on the command line must be under `$HOME` (only
    `--filesystem=home` is exposed), same as the real Flatpak -
    `screenshots.py` writes its generated images to `_build/` for this.
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
