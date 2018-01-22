project(
    'com.github.peteruithoven.resizer', 'vala', 'c',
    meson_version : '>= 0.43'
)

i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="io.elementary.screenshot-tool"', language:'c')

executable(
    meson.project_name(),
    'src/Application.vala',
    'src/Window.vala',
    'src/Resizer.vala',
    dependencies: [
        dependency('gtk+-3.0')
    ],
    install : true
)

meson.add_install_script('meson/post_install.py')

subdir('data')
# subdir('po')
