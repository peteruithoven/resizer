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
                _files = drop_unsupported (value);
                changed ();
            }
        }
        public signal void changed ();

        // Drops files the app can't actually resize (e.g. svg) up front, so the
        // rest of the app only ever has to deal with files it can act on.
        private File[] drop_unsupported (File[] candidates) {
            File[] supported = {};
            string[] unsupported_types = {};
            foreach (var file in candidates) {
                try {
                    Core.ImageFormat.pixbuf_type_for_path (file.get_path ());
                    supported += file;
                } catch (Error e) {
                    unsupported_types += Core.ImageFormat.extension_label (file.get_basename ());
                }
            }
            if (unsupported_types.length > 0) {
                MessageCenter.get_default ().add_error (
                    Messages.UnsupportedFileTypesMessage.format (unsupported_types)
                );
            }
            return supported;
        }

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
            string[] failed_names = {};
            foreach (var file in files) {
                stdout.printf ("resizing: %s\n", file.get_path ());

                var input_name = file.get_path ();
                var output_name = Core.FileNaming.output_name (input_name, max_width, max_height);

                try {
                    yield resize_image (input_name, output_name, max_width, max_height);
                    stdout.printf ("Successfully resized: %s\n", output_name);
                    num_files_resized++;
                    if (num_files_resized == num_files) {
                        stdout.printf ("All successfully resized\n");
                        set_state (State.SUCCESS);
                    }
                } catch (Error e) {
                    failed_names += file.get_basename ();
                }
            }
            if (failed_names.length > 0) {
                MessageCenter.get_default ().add_error (
                    Messages.ResizeFailureMessage.format (failed_names, num_files)
                );
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
                    Core.ImageGeometry.bounded_size (
                        pixbuf.width, pixbuf.height, max_width, max_height, out width, out height
                    );
                    if (width != pixbuf.width || height != pixbuf.height) {
                        pixbuf = pixbuf.scale_simple (width, height, Gdk.InterpType.BILINEAR);
                    }
                    pixbuf.savev (output, Core.ImageFormat.pixbuf_type_for_path (output), {}, {});
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
        private static GLib.Once<Resizer> instance;
        public static unowned Resizer get_default () {
            return instance.once (() => { return new Resizer (); });
        }
    }
}
