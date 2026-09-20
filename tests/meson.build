test_deps = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
]

test_core = executable(
    'test-core',
    [
        'test-image-geometry.vala',
        'test-image-format.vala',
        'test-file-naming.vala',
        'test-strings.vala',
        'test-core-main.vala',
        core_sources,
    ],
    dependencies: test_deps,
    build_by_default: false,
)
test('core', test_core)

# Messages/* only ever produce strings (no GTK), but do pull in Core/* for
# things like Strings.truncated_join.
test_messages = executable(
    'test-messages',
    [
        'test-unsupported-file-types-message.vala',
        'test-resize-failure-message.vala',
        'test-preview-error-message.vala',
        'test-messages-main.vala',
        message_sources,
        core_sources,
    ],
    dependencies: test_deps,
    build_by_default: false,
)
test('messages', test_messages)
