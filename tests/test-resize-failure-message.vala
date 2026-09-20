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

void test_resize_failure_message_drops_the_total_for_a_single_failure () {
    string[] failed_names = {"photo.jpg"};
    assert (
        Resizer.Messages.ResizeFailureMessage.format (failed_names, 5)
        == "1 image couldn't be resized: photo.jpg"
    );
}

void test_resize_failure_message_includes_the_total_for_multiple_failures () {
    string[] failed_names = {"a.jpg", "b.jpg"};
    assert (
        Resizer.Messages.ResizeFailureMessage.format (failed_names, 5)
        == "2 of 5 images couldn't be resized: a.jpg, b.jpg"
    );
}

void test_resize_failure_message_truncates_long_name_lists () {
    string[] failed_names = {"AAAAAAAAAAAAAAAAAAAAAAAAAAAA.jpg", "BBBBBBBBBBBBBBBBBBBBBBBBBBBB.jpg"};
    var message = Resizer.Messages.ResizeFailureMessage.format (failed_names, 5);
    assert (message.has_suffix ("…"));
}
