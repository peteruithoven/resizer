project(
    'com.github.peteruithoven.resizer',
    ['vala', 'c'],
    meson_version: '>= 0.59.0',
    version: '2.3.0',
    license: 'GPL-3.0+'
)

i18n = import('i18n')
gnome = import('gnome')

add_project_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language: 'c')

# Create Config.vala from Config.vala.in,
# replacing variables like PROJECT_NAME
conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
config_file = configure_file(
    input : 'src/Config.vala.in',
    output : 'Config.vala',
    configuration : conf_data
)

subdir('src')

executable(
    meson.project_name(),
    sources,
    config_file,
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('granite'),
        dependency('libhandy-1', version: '>=1.0.0')
    ],
    install : true
)

subdir('data')
subdir('po')

gnome.post_install(
    glib_compile_schemas: true,
    update_desktop_database: true
)
