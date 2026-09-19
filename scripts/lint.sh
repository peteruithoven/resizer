#!/usr/bin/env bash
# Runs the same checks as CI: Vala style, meson.build formatting, .po syntax,
# and the .desktop/appdata/gschema/icon files under data/.
set -uo pipefail
cd "$(dirname "$0")/.."

status=0

echo "==> Vala style (vala-lint)"
if command -v io.elementary.vala-lint >/dev/null 2>&1; then
    io.elementary.vala-lint -d src || status=1
elif command -v docker >/dev/null 2>&1; then
    echo "io.elementary.vala-lint not installed, falling back to 'docker run valalang/lint'"
    docker run --rm -v "$PWD":/github/workspace -w /github/workspace \
        valalang/lint:latest io.elementary.vala-lint -d src || status=1
else
    echo "SKIPPED: install with 'sudo apt-get install io.elementary.vala-lint', or install docker" >&2
    status=1
fi

echo
echo "==> meson.build formatting"
meson format --check-only -r . || status=1

echo
echo "==> .po file syntax"
for po in po/*.po; do
    msgfmt --check --check-format --check-domain -o /dev/null "$po" || status=1
done

echo
echo "==> .desktop syntax"
if command -v desktop-file-validate >/dev/null 2>&1; then
    tmp_desktop=$(mktemp --suffix=.desktop)
    cp data/com.github.peteruithoven.resizer.desktop.in "$tmp_desktop"
    desktop-file-validate "$tmp_desktop" || status=1
    rm -f "$tmp_desktop"
else
    echo "SKIPPED: install with 'sudo apt-get install desktop-file-utils'" >&2
    status=1
fi

echo
echo "==> XML well-formedness (appdata, gschema, icons)"
if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout data/*.xml.in data/*.xml data/icons/*.svg || status=1
else
    echo "SKIPPED: install with 'sudo apt-get install libxml2-utils'" >&2
    status=1
fi

echo
echo "==> AppStream metadata (appdata.xml.in)"
if command -v appstreamcli >/dev/null 2>&1; then
    appstreamcli validate data/com.github.peteruithoven.resizer.appdata.xml.in || status=1
else
    echo "SKIPPED: install with 'sudo apt-get install appstream'" >&2
    status=1
fi

exit $status
