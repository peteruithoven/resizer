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

// Test functions live one-per-source-file, mirroring src/Messages/ - this
// file just wires them all up into a single GLib.Test run. See
// test-unsupported-file-types-message.vala, test-resize-failure-message.vala
// and test-preview-error-message.vala.
public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func (
        "/unsupported-file-types-message/singular", test_unsupported_file_types_message_uses_the_singular_form_for_one_type
    );
    Test.add_func (
        "/unsupported-file-types-message/plural",
        test_unsupported_file_types_message_uses_the_plural_form_for_multiple_types
    );
    Test.add_func (
        "/unsupported-file-types-message/deduplicates", test_unsupported_file_types_message_deduplicates_repeated_types
    );
    Test.add_func (
        "/unsupported-file-types-message/truncates-long-lists", test_unsupported_file_types_message_truncates_long_lists
    );

    Test.add_func (
        "/resize-failure-message/single-failure-drops-total", test_resize_failure_message_drops_the_total_for_a_single_failure
    );
    Test.add_func (
        "/resize-failure-message/multiple-failures-include-total",
        test_resize_failure_message_includes_the_total_for_multiple_failures
    );
    Test.add_func (
        "/resize-failure-message/truncates-long-name-lists", test_resize_failure_message_truncates_long_name_lists
    );

    Test.add_func (
        "/preview-error-message/includes-underlying-error", test_preview_error_message_includes_the_underlying_error
    );

    return Test.run ();
}
