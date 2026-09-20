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

// Test functions live one-per-source-file, mirroring src/Core/ - this file
// just wires them all up into a single GLib.Test run. See
// test-image-geometry.vala, test-image-format.vala, test-file-naming.vala
// and test-strings.vala.
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
        "/image-format/pixbuf-type/known-extensions", test_pixbuf_type_maps_known_extensions_case_insensitively
    );
    Test.add_func (
        "/image-format/pixbuf-type/rejects-unsupported", test_pixbuf_type_rejects_unsupported_extensions
    );
    Test.add_func (
        "/image-format/extension-label/uppercases", test_extension_label_uppercases_the_extension
    );
    Test.add_func (
        "/image-format/extension-label/dots-in-filename", test_extension_label_handles_dots_in_the_filename
    );
    Test.add_func (
        "/image-format/extension-label/no-dot-fallback",
        test_extension_label_falls_back_to_the_whole_name_without_a_dot
    );

    Test.add_func (
        "/file-naming/output-name/square", test_output_name_uses_a_single_number_for_square_sizes
    );
    Test.add_func (
        "/file-naming/output-name/non-square", test_output_name_uses_wxh_for_non_square_sizes
    );
    Test.add_func (
        "/file-naming/output-name/dots-in-filename",
        test_output_name_preserves_directory_and_extension_with_dots_in_the_filename
    );

    Test.add_func (
        "/strings/truncated-join/keeps-short-lists-untouched", test_truncated_join_keeps_short_lists_untouched
    );
    Test.add_func (
        "/strings/truncated-join/cuts-at-last-full-item", test_truncated_join_cuts_at_the_last_full_item_that_fits
    );
    Test.add_func (
        "/strings/truncated-join/hard-cuts-single-long-name",
        test_truncated_join_hard_cuts_a_single_name_that_alone_exceeds_the_budget
    );
    Test.add_func (
        "/strings/unique/keeps-first-occurrence-order", test_unique_keeps_first_occurrence_order
    );
    Test.add_func (
        "/strings/unique/leaves-already-unique-untouched", test_unique_leaves_already_unique_lists_untouched
    );

    return Test.run ();
}
