#!/usr/bin/python3
"""EXPERIMENTAL alternative to smoke-test.sh: same underlying goal (catch
"the app doesn't even start" / "resizing is broken" regressions), but drives
the app under gala's own `--headless` Wayland compositor mode with AT-SPI
(the same button-clicking technique scripts/screenshots.py already uses)
instead of Xvfb/XWayland + xdotool + ImageMagick's `import`.

Why: `import -window <id>` occasionally fails outright with "unable to read
X window image ... Resource temporarily unavailable" (a transient X11
capture race - see smoke-test.sh's retry-loop comment and CLAUDE.md).

This originally worked by screenshotting the window and sampling a pixel
(mirroring smoke-test.sh's own check), via org.gnome.Shell.Screenshot -
gala's own D-Bus screenshot API, the same one screenshots.py uses. That hit
two more CI-only problems (see git log for this file): the CI runner has no
GPU at all, so GTK4's GL/NGL/Vulkan renderers all failed outright and killed
the Wayland connection before a window even appeared (fixed by forcing
GSK_RENDERER=cairo, GTK4's software-only 2D renderer); and, locally (not yet
confirmed in CI), a real D-Bus session also autostarts unrelated desktop
shell clients (wingpanel, dock, appcenter, ...) that can steal the "active"
window gala hands to ScreenshotWindow, since that D-Bus call has no way to
target a specific window - only "whatever's currently focused".

Screenshotting was dropped entirely rather than chasing that further: it
was only ever a proxy for "did the app actually do the thing" anyway. This
version instead clicks the real "Resize" button via an AT-SPI action (the
same technique screenshots.py already uses for its own screenshots, and
notably NOT synthetic key/mouse input - CLAUDE.md notes those don't reliably
reach the app under XWayland, but AT-SPI actions call directly into the
app's own accessibility implementation, sidestepping that whole problem)
and then verifies the actual resized file Resizer.vala writes to disk -
checking real output, not a render of it, so it no longer depends on GPU
availability or window focus at all for the check itself (a working
renderer is still needed to realize a clickable window in the first place,
which is what GSK_RENDERER=cairo is still for).

Usage: XDG_RUNTIME_DIR=<short-path empty dir> dbus-run-session -- \\
           python3 scripts/smoke-test-wayland.py

Must already be wrapped in `dbus-run-session`: a session bus can't be
started from inside this process without this script becoming the thing
responsible for tearing it down on every exit path (including a crash),
which `dbus-run-session` already does correctly by construction (it kills
the bus when its child command exits, for any reason).

XDG_RUNTIME_DIR must be a short, otherwise-empty directory: the Wayland
socket path (`$XDG_RUNTIME_DIR/wayland-0`) is a Unix domain socket, which
has a hard ~108-byte path length limit - a nested-but-reasonable-looking
tmp path (e.g. under a project-scoped scratch dir) can blow past that and
gala fails with "socket path ... exceeds 108 bytes" / "Failed to create
socket" instead of a clear "path too long" error.

Requires: gala, at-spi2-core (for AT-SPI - `NO_AT_BRIDGE` is *not* set here,
unlike smoke-test.sh, since accessibility is how this script finds and
drives the app at all), ImageMagick (to generate the test fixture and
verify the resized output), PyGObject with the Atspi gi binding, and the
app installed and on PATH.
"""
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

try:
    import gi
except ImportError:
    if sys.executable != "/usr/bin/python3":
        os.execv("/usr/bin/python3", ["/usr/bin/python3", __file__, *sys.argv[1:]])
    raise

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi, GLib  # noqa: E402

sys.stdout.reconfigure(line_buffering=True)

APP_ID = "com.github.peteruithoven.resizer"
BINARY = "com.github.peteruithoven.resizer"
VIRTUAL_MONITOR = "1200x800"

# The test fixture and the expected output name/dimensions the app should
# produce for it. Must track data/com.github.peteruithoven.resizer.gschema.xml's
# width/height defaults (1000x1000, the "max width/height" the app resizes
# within when neither has been changed from default in this fresh, isolated
# dconf) and src/Core/ImageGeometry.bounded_size()'s fit-within-bounds math
# (preserve aspect ratio, never enlarge) and src/Core/FileNaming.vala's
# "<input>-<W>x<H><ext>" naming - not read from the app, since a headless
# smoke test has no reliable way to ask it "what will you name this" up
# front; if any of those three change, this needs updating to match.
TEST_IMAGE_WIDTH = 2000
TEST_IMAGE_HEIGHT = 1500
TEST_IMAGE_FILL = "#87ceeb"
DEFAULT_MAX_SIZE = 1000
EXPECTED_OUTPUT_WIDTH = 1000
EXPECTED_OUTPUT_HEIGHT = 750

t_start = time.monotonic()


def log(msg):
    print(f"[{time.monotonic() - t_start:6.2f}s] {msg}", flush=True)


def fail(msg):
    log(f"FAIL: {msg}")
    sys.exit(1)


def check_requirements():
    for cmd in ("gala", "convert", "identify"):
        if shutil.which(cmd) is None:
            fail(f"required tool '{cmd}' not found on PATH")
    if shutil.which(BINARY) is None:
        fail(f"{BINARY} not found on PATH - install it first (e.g. 'sudo ninja -C build install')")
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        fail("no DBUS_SESSION_BUS_ADDRESS - this script must be run inside `dbus-run-session --`")
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "")
    if not runtime_dir:
        fail("XDG_RUNTIME_DIR is not set")
    # 108 bytes is sizeof(sun_path) on Linux; leave room for "/wayland-0".
    if len(runtime_dir) > 90:
        fail(f"XDG_RUNTIME_DIR is {len(runtime_dir)} chars, too long for a Wayland socket path: {runtime_dir}")


# ---- gala lifecycle ----


def start_gala(log_path):
    log_file = open(log_path, "wb")
    proc = subprocess.Popen(
        ["gala", "--headless", "--virtual-monitor", VIRTUAL_MONITOR],
        stdout=log_file, stderr=subprocess.STDOUT,
    )
    return proc, log_file


def wait_for_gala_ready(proc, deadline):
    runtime_dir = Path(os.environ["XDG_RUNTIME_DIR"])
    wayland_socket = runtime_dir / "wayland-0"
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            fail(f"gala exited early (code {proc.returncode}) before its Wayland socket appeared")
        if wayland_socket.exists():
            break
        time.sleep(0.05)
    else:
        fail("gala's Wayland socket never appeared")
    log("gala Wayland socket file exists")

    # The socket *file* can exist slightly before gala is actually listening
    # on it - on a dev machine with real GPU acceleration this window is too
    # small to matter (gala reaches this point in ~0.15s total), but on a
    # CI runner with no GPU (gala falls back to much slower software EGL
    # setup, which took ~4.5s there in one run) a client that connects right
    # after the path appears can still get "Failed to open display" (GTK
    # doesn't retry a failed wl_display_connect). Actually connecting - not
    # just stat()-ing the path - is the only way to confirm the server side
    # is ready.
    import socket as socket_module
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            fail(f"gala exited early (code {proc.returncode}) while waiting for its Wayland socket to accept connections")
        probe = socket_module.socket(socket_module.AF_UNIX, socket_module.SOCK_STREAM)
        try:
            probe.connect(str(wayland_socket))
            break
        except OSError:
            time.sleep(0.05)
        finally:
            probe.close()
    else:
        fail("gala's Wayland socket never accepted a connection")
    log("gala Wayland socket accepting connections")


# ---- AT-SPI: find and drive the app, mirrors screenshots.py's approach ----


def find_app(app_id, deadline):
    while True:
        desktop = Atspi.get_desktop(0)
        for i in range(desktop.get_child_count()):
            app = desktop.get_child_at_index(i)
            if app is not None and app.get_name() == app_id:
                return app
        if time.monotonic() >= deadline:
            return None
        time.sleep(0.05)


def find_once(node, role_name, name=None, depth=0):
    if depth > 30:
        return None
    try:
        if node.get_role_name() == role_name and (name is None or node.get_name() == name):
            return node
        n = node.get_child_count()
    except GLib.Error:
        return None
    for i in range(n):
        try:
            child = node.get_child_at_index(i)
        except GLib.Error:
            continue
        if child is None:
            continue
        found = find_once(child, role_name, name, depth + 1)
        if found is not None:
            return found
    return None


def find_polling(app, role_name, name, deadline):
    node = None
    while node is None and time.monotonic() < deadline:
        node = find_once(app, role_name, name)
        if node is None:
            time.sleep(0.05)
    return node


# ---- launching the app ----


def launch_app_with_retry(binary, args, env, deadline):
    # A raw connect() to gala's Wayland socket succeeding (wait_for_gala_ready)
    # doesn't guarantee gala is actually ready to service a real client's
    # full Wayland protocol handshake yet - observed in CI (not locally,
    # where gala starts far faster with real GPU acceleration): the probe
    # connects fine, but the app still gets GTK's "Failed to open display"
    # and exits within ~1s. Rather than adding yet another readiness
    # heuristic on the gala side, treat the app's own connection attempt as
    # the actual readiness signal and retry launching it - the most direct
    # thing that can fail is the thing being retried here.
    attempt = 0
    while True:
        attempt += 1
        proc = subprocess.Popen([binary, *args], env=env)
        settle_deadline = time.monotonic() + 1.5
        while time.monotonic() < settle_deadline:
            if proc.poll() is not None:
                break
            time.sleep(0.1)
        if proc.poll() is None:
            log(f"app launched (pid {proc.pid}, attempt {attempt})")
            return proc
        log(f"app exited early (code {proc.returncode}) on launch attempt {attempt}, retrying")
        if time.monotonic() >= deadline:
            fail(f"app kept exiting early after {attempt} launch attempts (last code {proc.returncode})")
        time.sleep(0.3)


# ---- cleanup ----


def cleanup(app_proc, gala_proc, gala_log_file, runtime_dir):
    if app_proc is not None and app_proc.poll() is None:
        app_proc.terminate()
    if gala_proc is not None and gala_proc.poll() is None:
        gala_proc.terminate()
        try:
            gala_proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            gala_proc.kill()
    if gala_log_file is not None:
        gala_log_file.close()
    # xdg-document-portal mounts a FUSE filesystem at $XDG_RUNTIME_DIR/doc
    # (triggered the first time anything queries org.freedesktop.portal.*
    # over the real bus) that a plain `rm -rf` can't remove - it has to be
    # unmounted first or the caller's own cleanup of runtime_dir will fail.
    doc_mount = Path(runtime_dir) / "doc"
    if doc_mount.is_dir():
        subprocess.run(["fusermount", "-u", str(doc_mount)], capture_output=True)


def main():
    check_requirements()
    runtime_dir = os.environ["XDG_RUNTIME_DIR"]
    work_dir = Path(runtime_dir)

    test_image = work_dir / "smoke-test.png"
    subprocess.run(
        ["convert", "-size", f"{TEST_IMAGE_WIDTH}x{TEST_IMAGE_HEIGHT}", f"xc:{TEST_IMAGE_FILL}", str(test_image)],
        check=True,
    )
    # FileNaming.output_name() names the file after the *requested* max
    # width/height (1000x1000 -> equal, so the square form "-1000", not
    # "-1000x1000"), decided before the aspect-ratio-preserving scale - the
    # actual pixel dimensions inside the file (checked separately below via
    # `identify`) are smaller in one axis (EXPECTED_OUTPUT_WIDTH/HEIGHT).
    # Confirmed against actual FileNaming.vala/Resizer.vala behavior by
    # running this script locally, not just by reading the source - it's
    # easy to misread which width/height each stage uses.
    expected_output = work_dir / f"smoke-test-{DEFAULT_MAX_SIZE}.png"

    gala_proc, gala_log_file = start_gala(work_dir / "gala.log")
    app_proc = None
    try:
        wait_for_gala_ready(gala_proc, time.monotonic() + 15)

        env = dict(os.environ)
        env["GDK_BACKEND"] = "wayland"
        env["WAYLAND_DISPLAY"] = "wayland-0"
        # Without this, the app reads/writes the real dconf database at
        # $HOME/.config/dconf/user (dconf's actual storage isn't scoped to
        # XDG_RUNTIME_DIR or the D-Bus session at all, just ca.desrt.dconf's
        # change-notification service is) - on a dev machine with prior real
        # usage this silently picks up a leftover width/height instead of
        # the schema default EXPECTED_OUTPUT_WIDTH/HEIGHT above are computed
        # from, which is exactly what happened in local testing (resized to
        # "-600" instead of "-1000x750"). screenshots.py isolates the same
        # way for the same reason.
        env["GSETTINGS_BACKEND"] = "memory"
        # A CI runner has no GPU device at all (unlike a dev machine, where
        # gala picks up a real /dev/dri node) - GTK4's GL, NGL and Vulkan
        # renderers all fail to initialize there ("Could not initialize EGL
        # display" / VK_ERROR_INCOMPATIBLE_DRIVER), which kills the Wayland
        # connection entirely before a window ever appears. The window just
        # needs to be clickable, not GPU-accelerated, so force GTK4's
        # software-only cairo renderer and skip GPU rendering altogether
        # rather than trying to get software EGL/Mesa working in CI.
        env["GSK_RENDERER"] = "cairo"
        app_proc = launch_app_with_retry(BINARY, [str(test_image)], env, time.monotonic() + 15)

        # A fresh deadline, not shared with launch_app_with_retry's above:
        # that one may have already spent most of its 15s on retries, which
        # would otherwise leave AT-SPI lookup with almost no time left.
        deadline = time.monotonic() + 15
        app = find_app(APP_ID, deadline)
        if app is None:
            fail(f"app '{APP_ID}' not found via AT-SPI after 15s")
        log("app found via AT-SPI")

        resize_button = find_polling(app, "push button", "Resize", deadline)
        if resize_button is None:
            fail("'Resize' button not found via AT-SPI")
        if app_proc.poll() is not None:
            fail(f"app exited (code {app_proc.returncode}) before the Resize button could be clicked")
        log("'Resize' button found, clicking it")
        try:
            resize_button.get_action_iface().do_action(0)
        except GLib.Error as e:
            fail(f"clicking 'Resize' failed: {e}")

        # Poll for the output file on disk rather than parsing the app's
        # stdout ("All successfully resized") - this way the check is
        # identical to what a real user would see (a file that showed up),
        # not an internal implementation detail of how the app logs.
        resize_deadline = time.monotonic() + 15
        while not expected_output.exists() and time.monotonic() < resize_deadline:
            if app_proc.poll() is not None:
                fail(f"app exited (code {app_proc.returncode}) before writing {expected_output.name}")
            time.sleep(0.05)
        if not expected_output.exists():
            fail(f"{expected_output.name} was never created within 15s of clicking Resize")
        log(f"{expected_output.name} appeared on disk")

        identify = subprocess.run(
            ["identify", "-format", "%w %h", str(expected_output)], capture_output=True, text=True,
        )
        try:
            width, height = (int(v) for v in identify.stdout.split())
        except ValueError:
            fail(f"could not read output image dimensions: {identify.stdout!r} {identify.stderr!r}")
        if (width, height) != (EXPECTED_OUTPUT_WIDTH, EXPECTED_OUTPUT_HEIGHT):
            fail(f"resized output is {width}x{height}, expected {EXPECTED_OUTPUT_WIDTH}x{EXPECTED_OUTPUT_HEIGHT}")
        log(f"output dimensions correct: {width}x{height}")

        # The fixture is a solid fill, so a correctly resized/re-encoded
        # copy should be too - checking a pixel confirms the file is a real
        # decoded-and-rescaled copy of the input, not e.g. a zero-byte or
        # truncated file that happens to still parse enough for `identify`.
        convert = subprocess.run(
            ["convert", str(expected_output), "-alpha", "off", "-format", f"%[pixel:p{{{width // 2},{height // 2}}}]", "info:"],
            capture_output=True, text=True,
        )
        pixel = convert.stdout.strip()
        expected_pixel = "srgb(135,206,235)"  # #87ceeb
        if pixel != expected_pixel:
            fail(f"resized output's center pixel is {pixel!r}, expected {expected_pixel!r}")
        log(f"output pixel content correct: {pixel}")

        if app_proc.poll() is not None and app_proc.returncode != 0:
            fail(f"app exited with code {app_proc.returncode} during the test")

        log("PASS: Resize button click produced a correctly-sized, correctly-rendered output file")
    finally:
        cleanup(app_proc, gala_proc, gala_log_file, runtime_dir)


if __name__ == "__main__":
    main()
