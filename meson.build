project(
    'com.github.peteruithoven.resizer',
    ['vala', 'c'],
    meson_version: '>= 0.59.0',
    version: '2.3.0',
    license: 'GPL-3.0+',
)

i18n = import('i18n')
gnome = import('gnome')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c',
)

# All C sources here are Vala-generated, so these warnings come from glib
# headers / valac codegen rather than from our own code:
# - GLib's g_once_init_enter()/g_atomic_pointer_get() macros trip
#   -Wincompatible-pointer-types with newer GCC.
# - valac emits an unused '_data_' local in the generated *_finish() function
#   for void async methods.
# - valac emits an unused GParamSpec properties array for every class, and an
#   unused collection-size local for every 'foreach' over a plain array.
# - granite.h declares still-deprecated symbols using an already-deprecated
#   enum, so merely including the header (from using any Granite API) trips
#   -Wdeprecated-declarations, independent of what we actually call.
cc = meson.get_compiler('c')
add_project_arguments(
    cc.get_supported_arguments(
        '-Wno-incompatible-pointer-types',
        '-Wno-unused-but-set-variable',
        '-Wno-unused-variable',
        '-Wno-deprecated-declarations',
    ),
    language: 'c',
)

# Create Config.vala from Config.vala.in,
# replacing variables like PROJECT_NAME
conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: 'Config.vala',
    configuration: conf_data,
)

subdir('src')

executable(
    meson.project_name(),
    sources,
    config_file,
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('granite'),
        dependency('libhandy-1', version: '>=1.0.0'),
    ],
    install: true,
)

subdir('data')
subdir('po')
subdir('tests')

gnome.post_install(glib_compile_schemas: true, update_desktop_database: true)
