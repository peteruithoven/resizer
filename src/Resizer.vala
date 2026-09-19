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
    public class Resizer {
        public int max_width = 1000;
        public int max_height = 1000;

        private File[] _files;
        public File[] files {
            get {
                return _files;
            }
            set {
                _files = value;
                changed ();
            }
        }
        public signal void changed ();

        public enum State {
            IDLE,
            RESIZING,
            SUCCESS
        }
        private State _state = State.IDLE;
        private void set_state (State value) {
            _state = value;
            state_changed (value);
        }
        public signal void state_changed (State state);

        private int num_files;
        private int _num_files_resized;
        private int num_files_resized {
            get {
                return _num_files_resized;
            }
            set {
                _num_files_resized = value;
                progress_changed (num_files, _num_files_resized);
            }
        }
        public signal void progress_changed (int num_files, int num_files_resized);

        public async void resize_images () {
            set_state (State.RESIZING);

            num_files = files.length;
            num_files_resized = 0;
            foreach (var file in files) {
                stdout.printf ("resizing: %s\n", file.get_path ());

                var input_name = file.get_path ();
                var output_name = get_output_name (input_name, max_width, max_height);

                try {
                    yield resize_image (input_name, output_name, max_width, max_height);
                    stdout.printf ("Successfully resized: %s\n", output_name);
                    num_files_resized++;
                    if (num_files_resized == num_files) {
                        stdout.printf ("All successfully resized\n");
                        set_state (State.SUCCESS);
                    }
                } catch (Error e) {
                    var message = _("There was an issue resizing '%s'").printf (input_name);
                    MessageCenter.get_default ().add_error (message);
                }
            }
        }
        // Loads, scales and saves the image on a worker thread so the UI thread
        // stays responsive between files.
        private async void resize_image (string input, string output, int max_width, int max_height) throws Error {
            SourceFunc callback = resize_image.callback;
            Error? thread_error = null;
            new Thread<void*> ("resize-image", () => {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file (input);
                    int width, height;
                    get_bounded_size (pixbuf.width, pixbuf.height, max_width, max_height, out width, out height);
                    if (width != pixbuf.width || height != pixbuf.height) {
                        pixbuf = pixbuf.scale_simple (width, height, Gdk.InterpType.BILINEAR);
                    }
                    pixbuf.savev (output, get_pixbuf_type (output), {}, {});
                } catch (Error e) {
                    thread_error = e;
                }
                Idle.add ((owned) callback);
                return null;
            });
            yield;
            if (thread_error != null) {
                throw thread_error;
            }
        }
        // Mirrors ImageMagick's "-resize WxH>" geometry: fit within max_width x
        // max_height while preserving aspect ratio, but never enlarge.
        private void get_bounded_size (
            int width, int height, int max_width, int max_height, out int new_width, out int new_height
        ) {
            double scale = double.min (1.0, double.min ((double) max_width / width, (double) max_height / height));
            new_width = int.max (1, (int) (width * scale + 0.5));
            new_height = int.max (1, (int) (height * scale + 0.5));
        }
        private string get_pixbuf_type (string path) throws Error {
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
        public string get_output_name (string input, int width, int height) {
            try {
                // turns "/home/user/Pictures/picture.jpg" into somesthing like:
                // "/home/user/Pictures/picture-2000.jpg" or
                // "/home/user/Pictures/picture-2000x1500.jpg" ors
                var file_regex = new GLib.Regex ("""(\/[^/]+)(\.\w+)$""");
                var max_size = "";
                if (width == height) {
                    max_size = width.to_string ();
                } else {
                    max_size = width.to_string () + "x" + height.to_string ();
                }
                string output_name = file_regex.replace (input, input.length, 0, """\1-""" + max_size + """\2""");
                return output_name;
            } catch (RegexError e) {
                stderr.printf ("Error on file: %s", e.message);
                return "";
            }
        }
        private static GLib.Once<Resizer> instance;
        public static unowned Resizer get_default () {
            return instance.once (() => { return new Resizer (); });
        }
    }
}
