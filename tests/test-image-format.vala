/*
* Copyright (c) 2011-2019 Peter Uithoven (https://peteruithoven.nl)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Peter Uithoven <peter@peteruithoven.nl>
*/

void test_pixbuf_type_maps_known_extensions_case_insensitively () {
    try {
        assert (Resizer.Core.ImageFormat.pixbuf_type_for_path ("photo.JPG") == "jpeg");
        assert (Resizer.Core.ImageFormat.pixbuf_type_for_path ("photo.jpeg") == "jpeg");
        assert (Resizer.Core.ImageFormat.pixbuf_type_for_path ("photo.png") == "png");
        assert (Resizer.Core.ImageFormat.pixbuf_type_for_path ("photo.bmp") == "bmp");
        assert (Resizer.Core.ImageFormat.pixbuf_type_for_path ("photo.tiff") == "tiff");
        assert (Resizer.Core.ImageFormat.pixbuf_type_for_path ("photo.tif") == "tiff");
    } catch (Error e) {
        error ("unexpected error: %s", e.message);
    }
}

void test_pixbuf_type_rejects_unsupported_extensions () {
    try {
        Resizer.Core.ImageFormat.pixbuf_type_for_path ("icon.svg");
        error ("expected an IOError.NOT_SUPPORTED to be thrown");
    } catch (IOError.NOT_SUPPORTED e) {
        // expected
    } catch (Error e) {
        error ("expected IOError.NOT_SUPPORTED, got: %s", e.message);
    }
}

void test_extension_label_uppercases_the_extension () {
    assert (Resizer.Core.ImageFormat.extension_label ("icon.svg") == "SVG");
    assert (Resizer.Core.ImageFormat.extension_label ("ANIMATION.GIF") == "GIF");
    assert (Resizer.Core.ImageFormat.extension_label ("photo.WebP") == "WEBP");
}

void test_extension_label_handles_dots_in_the_filename () {
    assert (Resizer.Core.ImageFormat.extension_label ("my.photo.heic") == "HEIC");
}

void test_extension_label_falls_back_to_the_whole_name_without_a_dot () {
    assert (Resizer.Core.ImageFormat.extension_label ("README") == "README");
}
