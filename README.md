# Resizer

<p align="center">
    <a href="https://appcenter.elementary.io/com.github.peteruithoven.resizer">
        <img src="https://appcenter.elementary.io/badge.svg" alt="Get it on AppCenter">
    </a>
</p>

Quickly resize images.
Features:

- Open images with Resizer or open Resizer and Drag and drop images
- Maintains aspect ratio.
- Keyboard control: Change the sizes using the up and down keys, press enter to resize.
- Settings are stored for next time.

![Screenshot resize image](data/screenshots/screenshot-8-dark-image.png)
![Screenshot empty](data/screenshots/screenshot-8-dark-empty.png)
![Screenshot resize multiple images](data/screenshots/screenshot-8-dark-images.png)

## Building, Testing, and Installation

You'll need the following dependencies:

- meson >= 0.47.0
- libgranite-dev
- valac

Run `meson` to configure the build environment and then `ninja` to build

    meson setup build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `com.github.peteruithoven.resizer`

    sudo ninja install
    com.github.peteruithoven.resizer

### Running without installing

To try out changes without `sudo ninja install`, `scripts/run.sh` builds the app into
`_build/meson-native` and runs it straight from there:

    ./scripts/run.sh
    ./scripts/run.sh photo.png   # opens a file directly, skipping drag-and-drop

Handy when working in a git worktree, since each one gets its own isolated build.

### Tests

Unit tests cover the resize/naming logic in `src/ImageGeometry.vala` and run via meson:

    meson test -C build

There's also a headless smoke test that launches the installed app and checks it
renders a real image, useful for catching packaging/dependency regressions. It
needs `xvfb`, `xdotool`, and ImageMagick:

    sudo apt install xvfb xdotool imagemagick
    xvfb-run -a ./scripts/smoke-test.sh

## translations

Generate `.pot` file using `po/LINGUAS` and `po/POTFILES`:

    ninja com.github.peteruithoven.resizer-pot

Generate / update `.po` files:

    ninja com.github.peteruithoven.resizer-update-po

## Credits

A lot of the code is inspired by the [elementary Screenshot tool](https://github.com/elementary/screenshot-tool) and Felipe Escoto's [wallpaperize](https://github.com/Philip-Scott/wallpaperize).
The icon is based on the [elementary Photos icon](https://github.com/elementary/icons/blob/master/apps/128/multimedia-photo-manager.svgs) and was greatly improved by [TraumaD](https://github.com/TraumaD).
