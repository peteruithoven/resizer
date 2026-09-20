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

void test_unsupported_file_types_message_uses_the_singular_form_for_one_type () {
    string[] types = {"SVG"};
    assert (
        Resizer.Messages.UnsupportedFileTypesMessage.format (types) == "Removed unsupported file type: SVG"
    );
}

void test_unsupported_file_types_message_uses_the_plural_form_for_multiple_types () {
    string[] types = {"SVG", "GIF"};
    assert (
        Resizer.Messages.UnsupportedFileTypesMessage.format (types) == "Removed unsupported file types: SVG, GIF"
    );
}

void test_unsupported_file_types_message_deduplicates_repeated_types () {
    // Two .svg files dropped at once shouldn't read "SVG, SVG" - nor should
    // a repeat push the count into the plural form on its own.
    string[] types = {"SVG", "SVG"};
    assert (
        Resizer.Messages.UnsupportedFileTypesMessage.format (types) == "Removed unsupported file type: SVG"
    );
}

void test_unsupported_file_types_message_truncates_long_lists () {
    string[] types = {"AAAAAAAAAAAAAAAAAAAAAAAAAAAA", "BBBBBBBBBBBBBBBBBBBBBBBBBBBB"};
    var message = Resizer.Messages.UnsupportedFileTypesMessage.format (types);
    // The second type is long enough that it wouldn't fit even without the
    // first, so a message that included it in full would mean truncation
    // didn't happen.
    assert (!message.contains (types[1]));
    assert (message.has_suffix ("…"));
}
