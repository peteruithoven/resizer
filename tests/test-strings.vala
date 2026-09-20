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

void test_truncated_join_keeps_short_lists_untouched () {
    string[] names = {"a.png", "b.png"};
    assert (Resizer.Core.Strings.truncated_join (names, 60) == "a.png, b.png");
}

void test_truncated_join_cuts_at_the_last_full_item_that_fits () {
    string[] names = {"aaaaaaaaaa.png", "bbbbbbbbbb.png", "cccccccccc.png"};
    // 14 chars each + ", " separators; a budget of 20 leaves room for only
    // the first name, so the second and third get dropped entirely rather
    // than being cut mid-name.
    assert (Resizer.Core.Strings.truncated_join (names, 20) == "aaaaaaaaaa.png…");
}

void test_truncated_join_hard_cuts_a_single_name_that_alone_exceeds_the_budget () {
    string[] names = {"a-very-long-single-filename-with-no-comma-to-break-on.png"};
    var result = Resizer.Core.Strings.truncated_join (names, 20);
    assert (result == "a-very-long-single-f…");
}

void test_unique_keeps_first_occurrence_order () {
    string[] items = {"SVG", "GIF", "SVG", "WEBP", "GIF"};
    string[] result = Resizer.Core.Strings.unique (items);
    assert (result.length == 3);
    assert (result[0] == "SVG");
    assert (result[1] == "GIF");
    assert (result[2] == "WEBP");
}

void test_unique_leaves_already_unique_lists_untouched () {
    string[] items = {"a", "b", "c"};
    string[] result = Resizer.Core.Strings.unique (items);
    assert (result.length == 3);
}
