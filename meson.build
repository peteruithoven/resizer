# Project name, programming language and version
project (
    'com.github.peteruithoven.resizer',
    'c', 'vala',
    version: '1.0.1'
)

# Translation module
i18n = import ('i18n')

# Project arguments
add_project_arguments (
    '-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name ()),
    language: 'c'
)

# Config file
conf_data = configuration_data ()

conf_data.set_quoted ('PROJECT_NAME', meson.project_name ())

config_file = configure_file (
    input : 'src/Config.vala.in',
    output : 'Config.vala',
    configuration : conf_data
)

# Listing dependencies
dependencies = [
    dependency ('gtk+-3.0'),
    dependency ('granite'),
    dependency ('libhandy-1')
]

subdir ('src')

# Defining executable
executable (
    meson.project_name (),
    sources,
    config_file,
    dependencies: dependencies,
    install: true
)

subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')
