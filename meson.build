project(
    'com.github.peteruithoven.resizer', 'vala', 'c',
    meson_version : '>= 0.43'
)

# Create config.vala from config.vala.in,
# replacing variables like PROJECT_NAME
conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
config_header = configure_file(
    input : 'src/config.vala.in',
    output : 'config.vala',
    configuration : conf_data
)

subdir('po')

executable(
    meson.project_name(),
    'src/Application.vala',
    'src/Window.vala',
    'src/Resizer.vala',
    'src/Resizer.vala',
    'build/config.vala',
    dependencies: [
        dependency('gtk+-3.0')
    ],
    install : true
)

meson.add_install_script('meson/post_install.py')

subdir('data')
