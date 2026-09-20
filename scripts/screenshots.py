#!/usr/bin/python3
"""Captures one screenshot per app state, in both light and dark mode, into
data/screenshots/ as screenshot-<os-version>-<light|dark>-<state>.png -
candidates for AppStream's <screenshots> in the appdata.xml. This is a
manual/interactive dev tool (not run in CI): a quick way to eyeball several
states at once and refresh the screenshots bundled with a release.

Usage: ./scripts/screenshots.py [os-version]
  os-version defaults to "8"

Requires a real desktop session (DISPLAY=:0, not xvfb-run - this wants the
actual elementary OS theme rendered, not a headless render) with xdotool,
ImageMagick (import/convert/identify) and accessibility (AT-SPI) enabled.
See CLAUDE.md "GUI testing" for why GDK_BACKEND=x11 is needed on this
Wayland desktop.
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
from gi.repository import Atspi, GLib  # noqa: E402

# Otherwise fully buffered (not line-buffered) whenever stdout isn't a tty -
# e.g. when a wrapper script or task runner captures this script's output to
# a file - so progress messages would all show up at once at the end instead
# of as each state finishes.
sys.stdout.reconfigure(line_buffering=True)

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = REPO_ROOT / "_build" / "meson-native"
SCHEMA_DIR = BUILD_DIR / "schemas"
BINARY = BUILD_DIR / "com.github.peteruithoven.resizer"
OUT_DIR = REPO_ROOT / "data" / "screenshots"
EXAMPLES_DIR = REPO_ROOT / "data" / "examples"
LOG_PATH = Path("/tmp/resizer-screenshots.log")

APP_ID = "com.github.peteruithoven.resizer"
WINDOW_TITLE_RE = "^Resizer$"

# Set once in main() before any capture runs.
OS_VERSION = None
BASE_THEME = None


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
    for cmd in ("xdotool", "import", "convert", "identify", "gsettings"):
        if shutil.which(cmd) is None:
            sys.exit(f"Required tool '{cmd}' not found on PATH.")
    if not os.environ.get("DISPLAY"):
        sys.exit("DISPLAY is not set. Run this from a real desktop session (e.g. DISPLAY=:0), not headless.")
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
    # The app is single-instance (GApplication): if a real instance is
    # already running, our launches below would just hand it their file
    # args instead of starting their own process, and every AT-SPI/window
    # call in this script would end up acting on that unrelated instance.
    if find_app(APP_ID, time.monotonic()) is not None:
        sys.exit("Resizer is already running - close it first, this script needs to drive its own instance.")


def build():
    print("==> Building")
    if not BUILD_DIR.exists():
        subprocess.run(["meson", "setup", str(BUILD_DIR)], check=True)
    subprocess.run(["ninja", "-C", str(BUILD_DIR)], check=True)
    SCHEMA_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy(REPO_ROOT / "data" / "com.github.peteruithoven.resizer.gschema.xml", SCHEMA_DIR)
    subprocess.run(["glib-compile-schemas", str(SCHEMA_DIR)], check=True)


def read_base_theme():
    # Base theme name (e.g. "io.elementary.stylesheet.mint"). The dark
    # variant of an elementary stylesheet theme is just this name with
    # ":dark" appended.
    result = subprocess.run(
        ["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
        capture_output=True,
        text=True,
        check=True,
    )
    theme = result.stdout.strip().strip("'")
    if not theme:
        sys.exit("Could not read a GTK theme via gsettings; can't force light/dark variants.")
    return theme


# ---- app process + window management ----


def launch_app(variant, args):
    gtk_theme = BASE_THEME if variant == "light" else f"{BASE_THEME}:dark"
    env = dict(os.environ)
    env.update(
        {
            "GSETTINGS_SCHEMA_DIR": str(SCHEMA_DIR),
            # Always starts from the schema's defaults (e.g. 300x300)
            # instead of whatever width/height a previous real run of the
            # app happens to have saved - otherwise a stray "9999" can
            # subtly change the resize page's layout, which would be an odd
            # thing for a published screenshot to show.
            "GSETTINGS_BACKEND": "memory",
            "GDK_BACKEND": "x11",
            "GTK_THEME": gtk_theme,
        }
    )
    with open(LOG_PATH, "wb") as log:
        return subprocess.Popen([str(BINARY), *args], env=env, stdout=log, stderr=subprocess.STDOUT)


def wait_for_window(proc, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            log = LOG_PATH.read_text(errors="replace") if LOG_PATH.exists() else ""
            sys.exit(f"App exited before its window appeared. Log:\n{log}")
        result = subprocess.run(["xdotool", "search", "--name", WINDOW_TITLE_RE], capture_output=True, text=True)
        ids = result.stdout.split()
        if ids:
            return ids[0]
        time.sleep(0.2)
    sys.exit("App window never appeared after 12s.")


def close_app(proc):
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


def color_count(path):
    try:
        result = subprocess.run(["identify", "-format", "%k", str(path)], capture_output=True, text=True, timeout=5)
        return int(result.stdout.strip())
    except (ValueError, subprocess.TimeoutExpired):
        return None


def capture_when_painted(window_id, out_path):
    # Retries for a couple seconds if the frame comes back as a single flat
    # color - the window can report as mapped before GTK has actually
    # painted anything into it yet, and a fixed sleep before the first
    # capture isn't always enough (same issue and fix as smoke-test.sh's
    # pixel retry loop, see CLAUDE.md "GUI testing"). The timeout on
    # `import` guards against it hanging instead of failing fast on an
    # already-closed window.
    for _ in range(20):
        try:
            subprocess.run(["import", "-window", window_id, str(out_path)], timeout=1, stderr=subprocess.DEVNULL)
        except subprocess.TimeoutExpired:
            pass
        colors = color_count(out_path)
        if colors is not None and colors > 20:
            return
        time.sleep(0.15)
    print(f"warning: {out_path} may still be a blank/unpainted frame", file=sys.stderr)


# ---- per-state capture ----


def capture_static(variant, state, args):
    proc = launch_app(variant, args)
    try:
        window_id = wait_for_window(proc)
        time.sleep(0.3)
        capture_when_painted(window_id, OUT_DIR / f"screenshot-{OS_VERSION}-{variant}-{state}.png")
    finally:
        close_app(proc)
    print(f"  wrote screenshot-{OS_VERSION}-{variant}-{state}.png")


def capture_resizing_error(variant):
    tmp = Path(tempfile.mkdtemp())
    try:
        shutil.copy(EXAMPLES_DIR / "blue.jpg", tmp)
        shutil.copy(EXAMPLES_DIR / "purple.jpg", tmp)
        # Read-only dir: the app can load these files fine but can't write
        # the resized output next to them, which is a reliable, fast way to
        # trigger ResizeFailureMessage without needing a slow/huge image.
        tmp.chmod(0o555)

        proc = launch_app(variant, [str(tmp / "blue.jpg"), str(tmp / "purple.jpg")])
        try:
            window_id = wait_for_window(proc)
            time.sleep(0.3)
            # This click never reaches a mid-progress value (a failed
            # resize's bar stays at its minimum forever), so mid_timeout is
            # kept short - only the click itself landing matters here.
            click_and_wait_for_mid_progress("Resize", mid_timeout=0.2)
            time.sleep(0.6)
            capture_when_painted(window_id, OUT_DIR / f"screenshot-{OS_VERSION}-{variant}-resizing-error.png")
        finally:
            close_app(proc)
    finally:
        tmp.chmod(0o755)
        shutil.rmtree(tmp)
    print(f"  wrote screenshot-{OS_VERSION}-{variant}-resizing-error.png")


def capture_resizing(variant):
    with tempfile.TemporaryDirectory() as tmp_str:
        tmp = Path(tmp_str)
        big_blue = tmp / "blue.jpg"
        big_purple = tmp / "purple.jpg"
        # blue.jpg/purple.jpg are tiny (300x200) - resizing them is too fast
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
            ["convert", str(EXAMPLES_DIR / "blue.jpg"), "-resize", "15000x11000!", str(big_blue)], check=True
        )
        subprocess.run(
            ["convert", str(EXAMPLES_DIR / "purple.jpg"), "-resize", "15000x11000!", str(big_purple)], check=True
        )

        proc = launch_app(variant, [str(big_blue), str(big_purple)])
        try:
            window_id = wait_for_window(proc)
            time.sleep(0.3)
            if click_and_wait_for_mid_progress("Resize"):
                # Caught a strict mid-progress value (AT-SPI-confirmed, not
                # guessed from a pixel), but AT-SPI's reported value can be a
                # frame or two ahead of what's actually been painted yet
                # (the property updates synchronously, the repaint doesn't) -
                # a short settle avoids screenshotting a stale, not-yet-
                # updated frame that still shows the previous value.
                time.sleep(0.08)
                out_path = OUT_DIR / f"screenshot-{OS_VERSION}-{variant}-resizing.png"
                try:
                    subprocess.run(["import", "-window", window_id, str(out_path)], timeout=1, stderr=subprocess.DEVNULL)
                except subprocess.TimeoutExpired:
                    pass
                print(f"  wrote screenshot-{OS_VERSION}-{variant}-resizing.png")
            else:
                print(f"warning: never caught a mid-progress frame for {variant}, skipping", file=sys.stderr)
        finally:
            close_app(proc)


def main():
    global OS_VERSION, BASE_THEME
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("os_version", nargs="?", default="8", help='elementary OS SDK version, e.g. "8" (default)')
    OS_VERSION = parser.parse_args().os_version

    check_requirements()
    build()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    BASE_THEME = read_base_theme()

    for variant in ("light", "dark"):
        print(f"==> Capturing {variant} screenshots")
        capture_static(variant, "image", [str(EXAMPLES_DIR / "blue.jpg")])
        capture_static(variant, "empty", [])
        capture_static(variant, "images", [str(EXAMPLES_DIR / "blue.jpg"), str(EXAMPLES_DIR / "purple.jpg")])
        capture_static(variant, "format-issues", [str(EXAMPLES_DIR / "example.pdf"), str(EXAMPLES_DIR / "example.svg")])
        capture_resizing(variant)
        capture_resizing_error(variant)

    print(f"==> Done. Screenshots written to {OUT_DIR}")


if __name__ == "__main__":
    main()
