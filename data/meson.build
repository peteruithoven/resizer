icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    # Installing icons using configure_file so I
    # could rename the output file
    configure_file(
        input : join_paths('icons', i + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps'),
        output : meson.project_name() + '.svg',
        configuration : configuration_data()
    )
endforeach

install_data(
    meson.project_name() + '.appdata.xml',
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

install_data(
    meson.project_name() + '.desktop',
    install_dir: join_paths(get_option('datadir'), 'applications')
)

install_data(
    meson.project_name() + '.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

install_data(
    meson.project_name() + '.contract',
    install_dir: join_paths(get_option('datadir'), 'contractor')
)
