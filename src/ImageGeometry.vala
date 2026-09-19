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

namespace Resizer {
    // Pure resize math and naming rules, kept free of GTK/threading/I/O so
    // they can be unit tested directly. See tests/test-image-geometry.vala.
    public class ImageGeometry {
        // Mirrors ImageMagick's "-resize WxH>" geometry: fit within max_width x
        // max_height while preserving aspect ratio, but never enlarge.
        public static void bounded_size (
            int width, int height, int max_width, int max_height, out int new_width, out int new_height
        ) {
            double scale = double.min (1.0, double.min ((double) max_width / width, (double) max_height / height));
            new_width = int.max (1, (int) (width * scale + 0.5));
            new_height = int.max (1, (int) (height * scale + 0.5));
        }
        public static string pixbuf_type_for_path (string path) throws Error {
            var extension = path.slice (path.last_index_of_char ('.') + 1, path.length).down ();
            switch (extension) {
                case "jpg":
                case "jpeg":
                    return "jpeg";
                case "png":
                    return "png";
                case "bmp":
                    return "bmp";
                case "tif":
                case "tiff":
                    return "tiff";
                default:
                    throw new IOError.NOT_SUPPORTED ("Unsupported image format: .%s".printf (extension));
            }
        }
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
