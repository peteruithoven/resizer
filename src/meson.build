# Exposed separately so tests/meson.build can compile them into test
# executables without pulling in the GTK-dependent sources.
core_sources = files(
    'Core/FileNaming.vala',
    'Core/ImageFormat.vala',
    'Core/ImageGeometry.vala',
    'Core/Strings.vala',
)
message_sources = files(
    'Messages/PreviewErrorMessage.vala',
    'Messages/ResizeFailureMessage.vala',
    'Messages/UnsupportedFileTypesMessage.vala',
)

sources = core_sources + message_sources + files(
    'Application.vala',
    'DropArea.vala',
    'HeaderBar.vala',
    'MessageCenter.vala',
    'ResizePage.vala',
    'Resizer.vala',
    'ResizingPage.vala',
    'Window.vala',
)
