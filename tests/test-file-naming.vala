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

void test_output_name_uses_a_single_number_for_square_sizes () {
    var name = Resizer.Core.FileNaming.output_name ("/home/user/Pictures/picture.jpg", 1000, 1000);
    assert (name == "/home/user/Pictures/picture-1000.jpg");
}

void test_output_name_uses_wxh_for_non_square_sizes () {
    var name = Resizer.Core.FileNaming.output_name ("/home/user/Pictures/picture.jpg", 2000, 1500);
    assert (name == "/home/user/Pictures/picture-2000x1500.jpg");
}

void test_output_name_preserves_directory_and_extension_with_dots_in_the_filename () {
    var name = Resizer.Core.FileNaming.output_name ("/home/user/Pictures/sub dir/my.photo.png", 500, 500);
    assert (name == "/home/user/Pictures/sub dir/my.photo-500.png");
}
