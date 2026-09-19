test_image_geometry = executable(
    'test-image-geometry',
    ['test-image-geometry.vala', image_geometry_sources],
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('gio-2.0'),
    ],
    build_by_default: false,
)

test('image-geometry', test_image_geometry)
