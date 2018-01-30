project(
    'com.github.peteruithoven.resizer', 'vala', 'c',
    meson_version : '>= 0.43'
)

i18n = import('i18n')

# Not sure what this does...
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

# Not sure what this does...
c_args = [
  '-include', 'config.h',
  '-DGWEATHER_I_KNOW_THIS_IS_UNSTABLE',
]

executable(
    meson.project_name(),
    'src/Application.vala',
    'src/Window.vala',
    'src/Resizer.vala',
    c_args: c_args, # not sure what this is
    dependencies: [
        dependency('gtk+-3.0')
    ],
    install : true
)

meson.add_install_script('meson/post_install.py')

subdir('data')
# subdir('po')
