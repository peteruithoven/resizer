i18n = import('i18n')
add_global_arguments('-DGETTEXT_PACKAGE="io.elementary.screenshot-tool"', language:'c')
i18n.gettext(meson.project_name(),
    args: '--directory=' + meson.source_root()
)
