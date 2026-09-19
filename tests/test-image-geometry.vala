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

void test_bounded_size_shrinks_to_fit_preserving_aspect_ratio () {
    int width, height;
    Resizer.ImageGeometry.bounded_size (3072, 2048, 1000, 1000, out width, out height);
    assert (width == 1000);
    assert (height == 667);
}

void test_bounded_size_does_not_enlarge_smaller_images () {
    int width, height;
    Resizer.ImageGeometry.bounded_size (400, 300, 1000, 1000, out width, out height);
    assert (width == 400);
    assert (height == 300);
}

void test_bounded_size_bounds_on_the_limiting_dimension () {
    int width, height;
    Resizer.ImageGeometry.bounded_size (2000, 500, 1000, 1000, out width, out height);
    assert (width == 1000);
    assert (height == 250);
}

void test_bounded_size_rounds_the_non_limiting_dimension_to_nearest () {
    int width, height;
    // Portrait version of the 3072x2048 case: here it's the width (not the
    // height) that lands on a fraction and must round, not truncate.
    Resizer.ImageGeometry.bounded_size (2048, 3072, 1000, 1000, out width, out height);
    assert (width == 667);
    assert (height == 1000);
}

void test_bounded_size_never_rounds_down_to_zero () {
    int width, height;
    Resizer.ImageGeometry.bounded_size (10000, 1, 100, 100, out width, out height);
    assert (width == 100);
    assert (height == 1);
}

void test_pixbuf_type_maps_known_extensions_case_insensitively () {
    try {
        assert (Resizer.ImageGeometry.pixbuf_type_for_path ("photo.JPG") == "jpeg");
        assert (Resizer.ImageGeometry.pixbuf_type_for_path ("photo.jpeg") == "jpeg");
        assert (Resizer.ImageGeometry.pixbuf_type_for_path ("photo.png") == "png");
        assert (Resizer.ImageGeometry.pixbuf_type_for_path ("photo.bmp") == "bmp");
        assert (Resizer.ImageGeometry.pixbuf_type_for_path ("photo.tiff") == "tiff");
        assert (Resizer.ImageGeometry.pixbuf_type_for_path ("photo.tif") == "tiff");
    } catch (Error e) {
        error ("unexpected error: %s", e.message);
    }
}

void test_pixbuf_type_rejects_unsupported_extensions () {
    try {
        Resizer.ImageGeometry.pixbuf_type_for_path ("icon.svg");
        error ("expected an IOError.NOT_SUPPORTED to be thrown");
    } catch (IOError.NOT_SUPPORTED e) {
        // expected
    } catch (Error e) {
        error ("expected IOError.NOT_SUPPORTED, got: %s", e.message);
    }
}

void test_output_name_uses_a_single_number_for_square_sizes () {
    var name = Resizer.ImageGeometry.output_name ("/home/user/Pictures/picture.jpg", 1000, 1000);
    assert (name == "/home/user/Pictures/picture-1000.jpg");
}

void test_output_name_uses_wxh_for_non_square_sizes () {
    var name = Resizer.ImageGeometry.output_name ("/home/user/Pictures/picture.jpg", 2000, 1500);
    assert (name == "/home/user/Pictures/picture-2000x1500.jpg");
}

void test_output_name_preserves_directory_and_extension_with_dots_in_the_filename () {
    var name = Resizer.ImageGeometry.output_name ("/home/user/Pictures/sub dir/my.photo.png", 500, 500);
    assert (name == "/home/user/Pictures/sub dir/my.photo-500.png");
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/image-geometry/bounded-size/shrinks-to-fit", test_bounded_size_shrinks_to_fit_preserving_aspect_ratio
    );
    Test.add_func (
        "/image-geometry/bounded-size/does-not-enlarge", test_bounded_size_does_not_enlarge_smaller_images
    );
    Test.add_func (
        "/image-geometry/bounded-size/bounds-on-limiting-dimension", test_bounded_size_bounds_on_the_limiting_dimension
    );
    Test.add_func (
        "/image-geometry/bounded-size/rounds-non-limiting-dimension",
        test_bounded_size_rounds_the_non_limiting_dimension_to_nearest
    );
    Test.add_func (
        "/image-geometry/bounded-size/never-rounds-down-to-zero", test_bounded_size_never_rounds_down_to_zero
    );
    Test.add_func (
        "/image-geometry/pixbuf-type/known-extensions", test_pixbuf_type_maps_known_extensions_case_insensitively
    );
    Test.add_func (
        "/image-geometry/pixbuf-type/rejects-unsupported", test_pixbuf_type_rejects_unsupported_extensions
    );
    Test.add_func (
        "/image-geometry/output-name/square", test_output_name_uses_a_single_number_for_square_sizes
    );
    Test.add_func (
        "/image-geometry/output-name/non-square", test_output_name_uses_wxh_for_non_square_sizes
    );
    Test.add_func (
        "/image-geometry/output-name/dots-in-filename",
        test_output_name_preserves_directory_and_extension_with_dots_in_the_filename
    );
    return Test.run ();
}
