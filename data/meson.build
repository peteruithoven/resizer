# Sized hicolor folders may only hold PNGs (Flathub lint), so the pixel-hinted
# small sizes are installed as PNGs pre-rendered from their SVG sources by
# scripts/render-icons.sh. 128.svg doubles as the scalable icon.
icon_sizes = ['16', '24', '32', '48', '64']

foreach i : icon_sizes
    foreach scale : ['', '@2']
        install_data(
            join_paths('icons', i + scale + '.png'),
            install_dir: join_paths(
                get_option('datadir'),
                'icons',
                'hicolor',
                i + 'x' + i + scale,
                'apps',
            ),
            rename: meson.project_name() + '.png',
        )
    endforeach
endforeach

install_data(
    join_paths('icons', '128.svg'),
    install_dir: join_paths(
        get_option('datadir'),
        'icons',
        'hicolor',
        'scalable',
        'apps',
    ),
    rename: meson.project_name() + '.svg',
)

i18n.merge_file(
    input: meson.project_name() + '.desktop.in',
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.project_source_root(), 'po', 'extra'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications'),
)

i18n.merge_file(
    input: meson.project_name() + '.metainfo.xml.in',
    output: meson.project_name() + '.metainfo.xml',
    po_dir: join_paths(meson.project_source_root(), 'po', 'extra'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo'),
)

install_data(
    meson.project_name() + '.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)
