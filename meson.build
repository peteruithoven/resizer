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
configure_file(
    input : 'src/config.vala.in',
    output : 'config.vala',
    configuration : conf_data
)

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
    'build/config.vala',
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('granite')
    ],
    install : true
)

meson.add_install_script('meson/post_install.py')

subdir('data')
subdir('po')