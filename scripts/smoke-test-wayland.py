#!/usr/bin/python3
"""EXPERIMENTAL alternative to smoke-test.sh: same goal (launch the built app,
confirm a window appears and renders a test image), but via gala's own
`--headless` Wayland compositor mode and org.gnome.Shell.Screenshot (the same
D-Bus API scripts/screenshots.py uses) instead of Xvfb/XWayland + xdotool +
ImageMagick's `import`.

Why: `import -window <id>` occasionally fails outright with "unable to read
X window image ... Resource temporarily unavailable" (a transient X11
capture race - see smoke-test.sh's retry-loop comment and CLAUDE.md). This
script sidesteps X11 entirely. It's also >10x faster in local testing
(~1.5s end to end vs. smoke-test.sh's multi-second typical run / much larger
worst-case retry budget), because AT-SPI (used here to find the app's
window, the same technique screenshots.py already uses for widgets) doesn't
need to poll/retry the way `xdotool search` does.

The tradeoff: this needs a *real* D-Bus session (org.gnome.Shell.Screenshot
and AT-SPI don't exist without one), unlike smoke-test.sh, which
deliberately blackholes both buses specifically to avoid unpredictable
xdg-desktop-portal backend activation latency (see smoke-test.sh's comment -
one measurement found a real session bus added 25-30s there). This hasn't
been observed here in local testing (which has gnome-keyring and other
desktop helper daemons already installed), but the actual CI container is
much more minimal, so that risk is the main open question this experimental
script exists to answer - hence running it as its own separate CI job
alongside, not instead of, smoke-test.sh for now.

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
unlike smoke-test.sh, since accessibility is how this script finds the
window at all), ImageMagick's `convert` (for pixel sampling of the PNG
Screenshot() writes, not for capture itself), PyGObject with the Atspi gi
binding, and the app installed and on PATH.
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
from gi.repository import Atspi, Gio, GLib  # noqa: E402

sys.stdout.reconfigure(line_buffering=True)

APP_ID = "com.github.peteruithoven.resizer"
BINARY = "com.github.peteruithoven.resizer"
EXPECTED_PIXEL = "srgb(135,206,235)"
VIRTUAL_MONITOR = "1200x800"

t_start = time.monotonic()


def log(msg):
    print(f"[{time.monotonic() - t_start:6.2f}s] {msg}", flush=True)


def fail(msg):
    log(f"FAIL: {msg}")
    sys.exit(1)


def check_requirements():
    for cmd in ("gala", "convert"):
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
    # CI runner with no GPU (gala falls back to software EGL, which took
    # ~4.5s there) a client that connects right after the path appears can
    # still get "Failed to open display" (GTK doesn't retry a failed
    # wl_display_connect). Actually connecting - not just stat()-ing the
    # path - is the only way to confirm the server side is ready.
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

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    while time.monotonic() < deadline:
        has_owner, = bus.call_sync(
            "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
            "NameHasOwner", GLib.Variant("(s)", ("org.gnome.Shell",)), GLib.VariantType("(b)"),
            Gio.DBusCallFlags.NONE, -1, None,
        ).unpack()
        if has_owner:
            log("org.gnome.Shell registered")
            return
        time.sleep(0.05)
    fail("gala never registered org.gnome.Shell on the session bus")


# ---- AT-SPI: find the app's window, mirrors screenshots.py's approach ----


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


def find_frame(node, depth=0):
    if depth > 5:
        return None
    try:
        if node.get_role_name() == "frame":
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
        found = find_frame(child, depth + 1)
        if found is not None:
            return found
    return None


def wait_for_frame(app, deadline):
    frame = None
    while frame is None and time.monotonic() < deadline:
        frame = find_frame(app)
        if frame is None:
            time.sleep(0.05)
    return frame


def wait_for_active(frame, deadline):
    # gala should auto-focus the sole toplevel window (nothing else is
    # running in this headless session to compete for focus), but
    # ScreenshotWindow operates on "whatever's currently focused" with no
    # way to name a target window, so confirm it rather than assume it.
    while time.monotonic() < deadline:
        try:
            if Atspi.StateType.ACTIVE in frame.get_state_set().get_states():
                return True
        except GLib.Error:
            pass
        time.sleep(0.05)
    return False


# ---- screenshot + pixel sample, with the same retry-on-mid-paint logic as
# smoke-test.sh (see its comment - the first frame or two after a window
# appears can still be mid-paint) ----


def capture_and_check(screenshot_path):
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    proxy = Gio.DBusProxy.new_sync(
        bus, Gio.DBusProxyFlags.NONE, None,
        "org.gnome.Shell", "/org/gnome/Shell/Screenshot", "org.gnome.Shell.Screenshot", None,
    )
    pixel = ""
    last_error = ""
    for _ in range(20):
        try:
            result = proxy.call_sync(
                "ScreenshotWindow",
                GLib.Variant("(bbbs)", (False, False, False, str(screenshot_path))),
                Gio.DBusCallFlags.NONE, 2000, None,
            )
            success, _filename_used = result.unpack()
            if not success:
                last_error = "ScreenshotWindow returned success=False"
                time.sleep(0.5)
                continue
        except GLib.Error as e:
            last_error = f"ScreenshotWindow call failed: {e}"
            time.sleep(0.5)
            continue

        identify = subprocess.run(
            ["identify", "-format", "%w %h", str(screenshot_path)], capture_output=True, text=True,
        )
        try:
            width, height = (int(v) for v in identify.stdout.split())
        except ValueError:
            last_error = f"could not read screenshot dimensions: {identify.stdout!r} {identify.stderr!r}"
            time.sleep(0.5)
            continue

        sample_x = width * 28 // 100
        sample_y = height * 46 // 100
        # -alpha off: ScreenshotWindow's PNG carries an alpha channel (the
        # app's preview area is fully opaque, but the pixel format comes
        # back as "srgba(r,g,b,1)" rather than smoke-test.sh's plain
        # "srgb(r,g,b)" from `import`) - strip it so the same EXPECTED_PIXEL
        # constant works for both.
        convert = subprocess.run(
            ["convert", str(screenshot_path), "-alpha", "off", "-format", f"%[pixel:p{{{sample_x},{sample_y}}}]", "info:"],
            capture_output=True, text=True,
        )
        pixel = convert.stdout.strip()
        if pixel == EXPECTED_PIXEL:
            log(f"pixel at ({sample_x},{sample_y}) in {width}x{height} window matches expected test-image color")
            return True
        last_error = f"sampled pixel {pixel!r} at ({sample_x},{sample_y}) in {width}x{height}, expected {EXPECTED_PIXEL!r}"
        time.sleep(0.5)

    log(f"FAIL: preview thumbnail never matched after retries - last attempt: {last_error}")
    return False


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
    subprocess.run(["convert", "-size", "2000x1500", "xc:#87ceeb", str(test_image)], check=True)

    gala_proc, gala_log_file = start_gala(work_dir / "gala.log")
    app_proc = None
    try:
        wait_for_gala_ready(gala_proc, time.monotonic() + 15)

        env = dict(os.environ)
        env["GDK_BACKEND"] = "wayland"
        env["WAYLAND_DISPLAY"] = "wayland-0"
        app_proc = subprocess.Popen([BINARY, str(test_image)], env=env)
        log(f"app launched (pid {app_proc.pid})")

        deadline = time.monotonic() + 15
        app = find_app(APP_ID, deadline)
        if app is None:
            fail(f"app '{APP_ID}' not found via AT-SPI after 15s")
        log("app found via AT-SPI")

        frame = wait_for_frame(app, deadline)
        if frame is None:
            fail("no top-level window (AT-SPI 'frame') found")
        log(f"window found: {frame.get_name()!r}")

        if not wait_for_active(frame, time.monotonic() + 5):
            log("warning: window never reported AT-SPI ACTIVE state, trying to screenshot anyway")

        if app_proc.poll() is not None:
            fail(f"app exited (code {app_proc.returncode}) before it could be screenshotted")

        ok = capture_and_check(work_dir / "shot.png")

        if app_proc.poll() is not None:
            fail(f"app exited (code {app_proc.returncode}) during the test")

        if not ok:
            sys.exit(1)
        log("PASS: window appeared and rendered the test image")
    finally:
        cleanup(app_proc, gala_proc, gala_log_file, runtime_dir)


if __name__ == "__main__":
    main()
