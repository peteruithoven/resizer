#!/usr/bin/python3
"""Captures one screenshot per app state, in both light and dark mode, into
data/screenshots/ as screenshot-<light|dark>-<state>.png - candidates for
AppStream's <screenshots> in the metainfo.xml. This is a manual/interactive
dev tool (not run in CI): a quick way to eyeball several states at once and
refresh the screenshots bundled with a release.

Usage: ./scripts/screenshots.py

Shows what Flathub users get, following Flathub's screenshot guidelines: the
app is built and run inside the Flatpak's GNOME runtime via
`scripts/run.sh --gnome-defaults`, so it renders with the runtime's own
libadwaita and GNOME's default settings (font, accent color, window buttons)
instead of this desktop's.

Requires a real desktop session (not xvfb-run) with ImageMagick
(convert/identify), accessibility (AT-SPI) enabled, and a compositor that
implements org.gnome.Shell.Screenshot (gala, Pantheon's own, does). The
compositor screenshots the focused window, so leave the desktop alone while
this runs: each capture is skipped rather than taken if the app's window
isn't the active one.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# Re-exec under the system python if "gi" isn't importable here - e.g. a
# pyenv/venv python3 shadowing /usr/bin/python3 on $PATH, which won't have
# the PyGObject + AT-SPI bindings a normal elementary OS 8 desktop ships by
# default (gir1.2-atspi-2.0 is a dependency of orca/onboard, both installed
# by default).
try:
    import gi
except ImportError:
    if sys.executable != "/usr/bin/python3":
        os.execv("/usr/bin/python3", ["/usr/bin/python3", __file__, *sys.argv[1:]])
    raise

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi, Gio, GLib  # noqa: E402

# Otherwise fully buffered (not line-buffered) whenever stdout isn't a tty -
# e.g. when a wrapper script or task runner captures this script's output to
# a file - so progress messages would all show up at once at the end instead
# of as each state finishes.
sys.stdout.reconfigure(line_buffering=True)

REPO_ROOT = Path(__file__).resolve().parent.parent
RUN_SCRIPT = REPO_ROOT / "scripts" / "run.sh"
OUT_DIR = REPO_ROOT / "data" / "screenshots"
EXAMPLES_DIR = REPO_ROOT / "data" / "examples"
# Like the real Flatpak, the app can only open files under $HOME, so
# generated test images go here rather than in /tmp.
SCRATCH_DIR = REPO_ROOT / "_build" / "screenshots-tmp"
LOG_PATH = Path("/tmp/resizer-screenshots.log")

APP_ID = "io.github.peteruithoven.resizer"


# ---- AT-SPI: find/click widgets and read the progress bar's real value,
# instead of pixel coordinates and pixel colors ----

# Window.vala switches pages with a Gtk.StackTransitionType.SLIDE_UP over
# this many seconds (transition_duration = 500 in Window.vala) - the
# resizing page's content slides up into place over that whole span, even
# though the window itself is already resized to its final (shorter) height
# well before the slide finishes. A screenshot taken before the transition
# has actually finished catches the label mid-slide-in from below, i.e.
# visibly clipped at the bottom, even though nothing is actually wrong with
# the window's size. 0.05s of margin on top of the transition itself.
STACK_TRANSITION_SETTLE_DELAY = 0.55


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


def find_once(accessible, role_name, name=None):
    # One-shot depth-first search of the accessible tree, swallowing errors
    # from any node that's gone stale mid-walk (accessibles are proxies to
    # live app state, and the tree can change shape - e.g. mid-click - while
    # walking it).
    def visit(node, depth):
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
            found = visit(child, depth + 1)
            if found is not None:
                return found
        return None

    return visit(accessible, 0)


def find_polling(accessible, role_name, name, deadline):
    while True:
        found = find_once(accessible, role_name, name)
        if found is not None:
            return found
        if time.monotonic() >= deadline:
            return None
        time.sleep(0.01)


def click_and_wait_for_mid_progress(button_name, find_timeout=5.0, mid_timeout=2.0):
    """Clicks button_name and waits for a progress bar value strictly
    between its min and max - i.e. at least one file done, not all of them -
    which for this app's 2-file states is exactly the "1 image remaining"
    midpoint. A resize that fails (resizing-error) never reaches this (the
    bar stays at its minimum forever), so this same call is used there too:
    it simply times out, which the caller treats the same as "didn't catch a
    mid frame" and proceeds to screenshot whatever's on screen regardless.
    Returns whether a mid-progress value was actually observed.
    """
    app = find_app(APP_ID, time.monotonic() + find_timeout)
    if app is None:
        print(f"app '{APP_ID}' not found via AT-SPI after {find_timeout}s", file=sys.stderr)
        return False

    button = find_polling(app, "push button", button_name, time.monotonic() + find_timeout)
    if button is None:
        print(f"'{button_name}' button not found via AT-SPI after {find_timeout}s", file=sys.stderr)
        return False

    click_time = time.monotonic()
    try:
        button.get_action_iface().do_action(0)
    except GLib.Error as e:
        print(f"clicking '{button_name}' failed: {e}", file=sys.stderr)
        return False

    deadline = click_time + mid_timeout
    settled_at = click_time + STACK_TRANSITION_SETTLE_DELAY
    while time.monotonic() < deadline:
        try:
            bar = find_once(app, "progress bar")
            if bar is not None:
                value_iface = bar.get_value_iface()
                current = value_iface.get_current_value()
                minimum = value_iface.get_minimum_value()
                maximum = value_iface.get_maximum_value()
                if minimum < current < maximum and time.monotonic() >= settled_at:
                    print(f"mid-progress: {current} (range {minimum}-{maximum})")
                    return True
        except GLib.Error:
            # Most often means the app/window has already gone - a resize
            # fast enough to finish and close before we ever caught a mid
            # frame. Nothing left to wait for.
            print("app disappeared while waiting for mid-progress", file=sys.stderr)
            return False
        time.sleep(0.005)

    print("timed out waiting for a mid-progress value", file=sys.stderr)
    return False


# ---- build + preflight ----


def check_requirements():
    for cmd in ("flatpak", "convert", "identify", "gsettings"):
        if shutil.which(cmd) is None:
            sys.exit(f"Required tool '{cmd}' not found on PATH.")
    if not os.environ.get("WAYLAND_DISPLAY") and not os.environ.get("DISPLAY"):
        sys.exit("No display found. Run this from a real desktop session, not headless.")
    result = subprocess.run(
        ["gsettings", "get", "org.gnome.desktop.interface", "toolkit-accessibility"],
        capture_output=True,
        text=True,
    )
    if result.stdout.strip() != "true":
        sys.exit(
            "Accessibility (AT-SPI) is switched off, so this script can't find/click the app's buttons.\n"
            "Enable it with: gsettings set org.gnome.desktop.interface toolkit-accessibility true"
        )
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    has_owner, = bus.call_sync(
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "NameHasOwner",
        GLib.Variant("(s)", ("org.gnome.Shell",)),
        GLib.VariantType("(b)"),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    ).unpack()
    if not has_owner:
        sys.exit("org.gnome.Shell isn't available on the session bus - is this compositor Pantheon's gala?")
    # The app is single-instance (GApplication): if a real instance is
    # already running, our launches below would just hand it their file
    # args instead of starting their own process, and every AT-SPI/window
    # call in this script would end up acting on that unrelated instance.
    if find_app(APP_ID, time.monotonic()) is not None:
        sys.exit("Resizer is already running - close it first, this script needs to drive its own instance.")


def build():
    print("==> Building")
    subprocess.run([str(RUN_SCRIPT), "--build-only"], check=True)


# ---- app process + window management ----


def launch_app(variant, args):
    env = dict(os.environ)
    env["COLOR_SCHEME"] = f"prefer-{variant}"
    with open(LOG_PATH, "wb") as log:
        return subprocess.Popen(
            [str(RUN_SCRIPT), "--gnome-defaults", *args], env=env, stdout=log, stderr=subprocess.STDOUT
        )


def find_window(app):
    try:
        for i in range(app.get_child_count()):
            window = app.get_child_at_index(i)
            if window is not None and window.get_role_name() == "frame" and window.get_name() == "Resizer":
                return window
    except GLib.Error:
        pass
    return None


def is_active(window):
    try:
        return window.get_state_set().contains(Atspi.StateType.ACTIVE)
    except GLib.Error:
        return False


def wait_for_window(proc, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            log = LOG_PATH.read_text(errors="replace") if LOG_PATH.exists() else ""
            sys.exit(f"App exited before its window appeared. Log:\n{log}")
        app = find_app(APP_ID, time.monotonic())
        window = find_window(app) if app is not None else None
        if window is not None:
            return window
        time.sleep(0.1)
    sys.exit(f"App window never appeared after {timeout}s.")


def close_app(proc):
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    # Its accessible can linger for a moment after the process is gone,
    # and the next launch's wait_for_window() mustn't pick that one up.
    deadline = time.monotonic() + 3
    while find_app(APP_ID, time.monotonic()) is not None and time.monotonic() < deadline:
        time.sleep(0.05)


def color_count(path):
    try:
        result = subprocess.run(["identify", "-format", "%k", str(path)], capture_output=True, text=True, timeout=5)
        return int(result.stdout.strip())
    except (ValueError, subprocess.TimeoutExpired):
        return None


# Lazily created, reused for every capture in the run.
_screenshot_proxy = None


def capture_window(window, out_path, focus_timeout=3.0):
    """Screenshots window to out_path with a real alpha channel, via the
    compositor's own org.gnome.Shell.Screenshot D-Bus interface (gala
    implements this). That captures whichever window is focused, and on
    Wayland there's no way to focus one from here, so this only captures
    once AT-SPI reports the app's window as the active one (a new window
    normally gets focus by itself), and discards the result if focus moved
    away during the capture - otherwise it could save some other app's
    window.
    """
    global _screenshot_proxy
    deadline = time.monotonic() + focus_timeout
    while not is_active(window):
        if time.monotonic() >= deadline:
            print(f"Resizer's window isn't focused, not capturing {out_path.name}", file=sys.stderr)
            return False
        time.sleep(0.05)
    if _screenshot_proxy is None:
        _screenshot_proxy = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SESSION,
            Gio.DBusProxyFlags.NONE,
            None,
            "org.gnome.Shell",
            "/org/gnome/Shell/Screenshot",
            "org.gnome.Shell.Screenshot",
            None,
        )
    try:
        result = _screenshot_proxy.call_sync(
            "ScreenshotWindow",
            GLib.Variant("(bbbs)", (True, False, False, str(out_path))),
            Gio.DBusCallFlags.NONE,
            2000,
            None,
        )
    except GLib.Error as e:
        print(f"ScreenshotWindow failed: {e}", file=sys.stderr)
        return False
    success, _filename_used = result.unpack()
    if success and not is_active(window):
        print(f"focus moved away during capture, discarding {out_path.name}", file=sys.stderr)
        out_path.unlink(missing_ok=True)
        return False
    return success


def capture_when_painted(window, out_path):
    # Retries for a couple seconds if the frame comes back as a single flat
    # color - the window can report as mapped before GTK has actually
    # painted anything into it yet, and a fixed sleep before the first
    # capture isn't always enough (same issue and fix as smoke-test.sh's
    # pixel retry loop, see CLAUDE.md "GUI testing").
    for _ in range(20):
        if not capture_window(window, out_path):
            return False
        colors = color_count(out_path)
        if colors is not None and colors > 20:
            return True
        time.sleep(0.15)
    print(f"warning: {out_path} may still be a blank/unpainted frame", file=sys.stderr)
    return True


# ---- per-state capture ----


def capture_static(variant, state, args):
    proc = launch_app(variant, args)
    try:
        window = wait_for_window(proc)
        time.sleep(0.3)
        if capture_when_painted(window, OUT_DIR / f"screenshot-{variant}-{state}.png"):
            print(f"  wrote screenshot-{variant}-{state}.png")
    finally:
        close_app(proc)


def capture_resizing_error(variant):
    tmp = Path(tempfile.mkdtemp(dir=SCRATCH_DIR))
    try:
        shutil.copy(EXAMPLES_DIR / "example1.jpg", tmp)
        shutil.copy(EXAMPLES_DIR / "example2.jpg", tmp)
        # Read-only dir: the app can load these files fine but can't write
        # the resized output next to them, which is a reliable, fast way to
        # trigger ResizeFailureMessage without needing a slow/huge image.
        tmp.chmod(0o555)

        proc = launch_app(variant, [str(tmp / "example1.jpg"), str(tmp / "example2.jpg")])
        try:
            window = wait_for_window(proc)
            time.sleep(0.3)
            # This click never reaches a mid-progress value (a failed
            # resize's bar stays at its minimum forever), so mid_timeout is
            # kept short - only the click itself landing matters here.
            click_and_wait_for_mid_progress("Resize", mid_timeout=0.2)
            time.sleep(0.6)
            if capture_when_painted(window, OUT_DIR / f"screenshot-{variant}-resizing-error.png"):
                print(f"  wrote screenshot-{variant}-resizing-error.png")
        finally:
            close_app(proc)
    finally:
        tmp.chmod(0o755)
        shutil.rmtree(tmp)


def capture_resizing(variant):
    with tempfile.TemporaryDirectory(dir=SCRATCH_DIR) as tmp_str:
        tmp = Path(tmp_str)
        big_example1 = tmp / "example1.jpg"
        big_example2 = tmp / "example2.jpg"
        # example1.jpg/example2.jpg are tiny (300x200) - resizing them is too fast
        # to ever catch a "1 image remaining" mid-progress moment, so use
        # heavily upscaled copies just to slow the decode/scale down enough
        # to give the poll loop above a real window to land in. Same
        # images, just bigger, and the resizing page shows no image preview
        # anyway (only a progress bar), so the extra pixels are otherwise
        # invisible. Sized (measured on this machine) so the first file
        # alone takes comfortably longer than STACK_TRANSITION_SETTLE_DELAY -
        # a smaller size can reach "1 image remaining" before the page
        # transition has actually finished animating in, which used to
        # produce a screenshot with the label clipped at the bottom.
        subprocess.run(
            ["convert", str(EXAMPLES_DIR / "example1.jpg"), "-resize", "15000x11000!", str(big_example1)], check=True
        )
        subprocess.run(
            ["convert", str(EXAMPLES_DIR / "example2.jpg"), "-resize", "15000x11000!", str(big_example2)], check=True
        )

        proc = launch_app(variant, [str(big_example1), str(big_example2)])
        try:
            window = wait_for_window(proc)
            time.sleep(0.3)
            if click_and_wait_for_mid_progress("Resize"):
                # Caught a strict mid-progress value (AT-SPI-confirmed, not
                # guessed from a pixel), but AT-SPI's reported value can be a
                # frame or two ahead of what's actually been painted yet
                # (the property updates synchronously, the repaint doesn't) -
                # a short settle avoids screenshotting a stale, not-yet-
                # updated frame that still shows the previous value.
                time.sleep(0.08)
                out_path = OUT_DIR / f"screenshot-{variant}-resizing.png"
                if capture_window(window, out_path):
                    print(f"  wrote screenshot-{variant}-resizing.png")
            else:
                print(f"warning: never caught a mid-progress frame for {variant}, skipping", file=sys.stderr)
        finally:
            close_app(proc)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.parse_args()

    check_requirements()
    build()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    SCRATCH_DIR.mkdir(parents=True, exist_ok=True)

    for variant in ("light", "dark"):
        print(f"==> Capturing {variant} screenshots")
        capture_static(variant, "image", [str(EXAMPLES_DIR / "example1.jpg")])
        capture_static(variant, "empty", [])
        capture_static(variant, "images", [str(EXAMPLES_DIR / "example1.jpg"), str(EXAMPLES_DIR / "example2.jpg")])
        capture_static(variant, "format-issues", [str(EXAMPLES_DIR / "example.pdf"), str(EXAMPLES_DIR / "example.svg")])
        capture_resizing(variant)
        capture_resizing_error(variant)

    print(f"==> Done. Screenshots written to {OUT_DIR}")


if __name__ == "__main__":
    main()
