project(
    'com.github.peteruithoven.resizer',
    ['vala', 'c'],
    meson_version : '>= 0.47',
    license: 'GPL-3.0+'
)

i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

# Create config.vala from config.vala.in,
# replacing variables like PROJECT_NAME
conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
config_file = configure_file(
    input : 'src/config.vala.in',
    output : 'config.vala',
    configuration : conf_data
)

meson.build_root()

executable(
    meson.project_name(),
    'src/Application.vala',
    'src/HeaderBar.vala',
    'src/Window.vala',
    'src/ResizePage.vala',
    'src/ResizingPage.vala',
    'src/Resizer.vala',
    'src/DropArea.vala',
    'src/MessageCenter.vala',
    config_file,
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('granite'),
        dependency('libhandy-1', version: '>=1.0.0')
    ],
    install : true
)

meson.add_install_script('meson/post_install.py')

subdir('data')
subdir('po')
