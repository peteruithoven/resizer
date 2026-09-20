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

namespace Resizer.Core {
    public class FileNaming {
        public static string output_name (string input, int width, int height) {
            try {
                // turns "/home/user/Pictures/picture.jpg" into something like:
                // "/home/user/Pictures/picture-2000.jpg" or
                // "/home/user/Pictures/picture-2000x1500.jpg"
                var file_regex = new GLib.Regex ("""(\/[^/]+)(\.\w+)$""");
                var max_size = "";
                if (width == height) {
                    max_size = width.to_string ();
                } else {
                    max_size = width.to_string () + "x" + height.to_string ();
                }
                return file_regex.replace (input, input.length, 0, """\1-""" + max_size + """\2""");
            } catch (RegexError e) {
                stderr.printf ("Error on file: %s", e.message);
                return "";
            }
        }
    }
}
