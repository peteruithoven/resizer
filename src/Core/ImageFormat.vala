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
    // What a file's extension says about its image format: whether
    // GdkPixbuf can handle it, and how to label it for a person.
    public class ImageFormat {
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
        // Uppercase display label for a file's extension (e.g. "photo.svg" ->
        // "SVG"), matching how GNOME/elementary already label formats
        // elsewhere - shared-mime-info's comments (surfaced by GTK file
        // choosers and Nautilus) read "PNG image", "SVG image", etc.
        public static string extension_label (string path) {
            var dot = path.last_index_of_char ('.');
            if (dot < 0) {
                return path.up ();
            }
            return path.slice (dot + 1, path.length).up ();
        }
    }
}
