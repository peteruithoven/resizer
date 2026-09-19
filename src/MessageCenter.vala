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
    public class MessageCenter : Gtk.Grid {

        public MessageCenter () {
            this.orientation = Gtk.Orientation.VERTICAL;
        }
        public void add_message (Gtk.MessageType type, string message) {
            stdout.printf ("adding message: %s\n", message);
            var bar = new Gtk.InfoBar ();
            bar.message_type = type;
            var label = new Gtk.Label (message);
            label.wrap = true;
            label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            label.max_width_chars = 1;
            label.xalign = 0;
            // Pin the label's width instead of the usual wrap/hexpand trick:
            // adding a wrapping label to an already-visible, non-resizable
            // window makes GTK compute the new height using the label's
            // near-zero minimum width instead of its real allocated width,
            // ballooning the window height until the window is refocused.
            // A fixed width sidesteps that renegotiation entirely.
            int width = this.get_allocated_width ();
            if (width <= 0) {
                width = 260;
            }
            label.set_size_request (width - 100, -1);
            bar.get_content_area ().add (label);
            bar.show_close_button = true;
            bar.response.connect (() => {
                bar.hide ();
                // TODO: find a better way
                GLib.Timeout.add (1000, () => {
                    bar.destroy ();
                    return false;
                });
            });
            this.add (bar);
            bar.show_all ();
        }
        public void add_error (string message) {
            this.add_message (Gtk.MessageType.ERROR, message);
        }
        private static GLib.Once<MessageCenter> instance;
        public static unowned MessageCenter get_default () {
            return instance.once (() => { return new MessageCenter (); });
        }
    }
}
