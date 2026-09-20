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
    public class ResizingPage : Gtk.Grid {

        public ResizingPage () {
            this.width_request = 350;
            var spacing = 12;

            var bar = new Gtk.ProgressBar ();
            bar.hexpand = true;
            bar.halign = Gtk.Align.FILL;

            var remaining_label = new Gtk.Label ("");
            remaining_label.halign = Gtk.Align.START;

            this.orientation = Gtk.Orientation.VERTICAL;
            this.margin_start = this.margin_end = this.margin_bottom = spacing;
            this.margin_top = 0;
            this.attach (bar, 0, 0, 1, 1);
            this.attach (remaining_label, 0, 1, 1, 1);

            Resizer.get_default ().progress_changed.connect ((r, num_files, num_files_resized) => {
                bar.fraction = ((double) num_files_resized) / ((double) num_files);
                var images_remaining = num_files - num_files_resized;
                if (images_remaining == 0) {
                    remaining_label.label = _("All images resized");
                    bar.add_css_class ("success");
                } else if (images_remaining == 1) {
                    remaining_label.label = _("1 image remaining");
                } else {
                    remaining_label.label = _("%i images remaining").printf (images_remaining);
                }
            });
        }
    }
}
