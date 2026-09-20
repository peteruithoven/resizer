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
    public class ResizePage : Gtk.Grid {

        private Settings settings = new Settings (Constants.PROJECT_NAME);
        private Gtk.Label intro_label;
        private Gtk.SpinButton width_entry;
        private Gtk.SpinButton height_entry;
        private DropArea drop_area;
        private Gtk.Button cancel_btn;
        private Gtk.Button resize_btn;
        private Window app;

        public ResizePage (Window app) {
            this.app = app;

            var spacing = 12;

            intro_label = new Gtk.Label ("");
            intro_label.margin_bottom = spacing / 2;

            var width_label = new Gtk.Label (_("Max width:"));
            width_label.halign = Gtk.Align.END;

            width_entry = new Gtk.SpinButton.with_range (1, 10000, 1000);
            width_entry.hexpand = true;
            width_entry.set_activates_default (true);
            settings.bind ("width", width_entry, "value", GLib.SettingsBindFlags.DEFAULT);

            var width_input = new Gtk.Grid ();
            width_input.column_spacing = spacing / 2;
            width_input.column_homogeneous = true;
            width_input.attach (width_label, 0, 0, 1, 1);
            width_input.attach (width_entry, 1, 0, 1, 1);
            width_input.attach (new Gtk.Label (""), 2, 0, 1, 1);

            var height_label = new Gtk.Label (_("Max height:"));
            height_label.halign = Gtk.Align.START;

            height_entry = new Gtk.SpinButton.with_range (1, 10000, 1000);
            height_entry.hexpand = true;
            height_entry.set_activates_default (true);
            settings.bind ("height", height_entry, "value", GLib.SettingsBindFlags.DEFAULT);

            var height_input = new Gtk.Grid ();
            height_input.row_spacing = spacing / 2;
            height_input.margin_end = spacing;
            height_input.valign = Gtk.Align.CENTER;
            height_input.orientation = Gtk.Orientation.VERTICAL;
            height_input.attach (height_label, 0, 0, 1, 1);
            height_input.attach (height_entry, 0, 1, 1, 1);
            // Create 3th row, making sure the entry is in the center
            height_input.attach (new Gtk.Label (""), 0, 2, 1, 1);

            drop_area = new DropArea ();
            drop_area.margin_start = spacing / 2;

            cancel_btn = new Gtk.Button.with_label (_("Cancel"));
            cancel_btn.clicked.connect (() => {
                app.destroy ();
            });
            resize_btn = new Gtk.Button.with_label (_("Resize"));
            resize_btn.add_css_class ("suggested-action");
            resize_btn.clicked.connect (() => {
                var resizer = Resizer.get_default ();
                resizer.max_width = width_entry.get_value_as_int ();
                resizer.max_height = height_entry.get_value_as_int ();
                resizer.resize_images.begin ();
            });

            var buttons = new Gtk.Grid ();
            buttons.column_spacing = spacing / 2;
            buttons.halign = Gtk.Align.END;
            buttons.valign = Gtk.Align.END;
            buttons.margin_start = buttons.margin_end = buttons.margin_bottom = spacing;
            buttons.margin_top = 0;
            buttons.attach (cancel_btn, 0, 0, 1, 1);
            buttons.attach (resize_btn, 1, 0, 1, 1);

            this.column_spacing = spacing / 2;
            this.row_spacing = spacing / 2;
            this.attach (intro_label, 0, 0, 2, 1);
            this.attach (width_input, 0, 1, 1, 1);
            this.attach (drop_area, 0, 2, 1, 1);
            this.attach (height_input, 1, 2, 1, 1);
            this.attach (buttons, 0, 3, 2, 1);

            update ({});
            Resizer.get_default ().changed.connect (() => {
                update (Resizer.get_default ().files);
            });
        }
        public void update (File[] files) {
            if (files.length == 0) {
                cancel_btn.sensitive = false;
                resize_btn.sensitive = false;
                intro_label.label = _("Resize image(s) within:");
                // when pressing enter, activate the select images button
                app.set_default_widget (drop_area.select_button);
                app.set_focus (drop_area.select_button);
            } else {
                cancel_btn.sensitive = true;
                resize_btn.sensitive = true;
                if (files.length == 1) {
                    intro_label.label = _("Resize image within:");
                } else {
                    intro_label.label = _("Resize %i images within:").printf (files.length);
                }
                try {
                    drop_area.show_preview (files);
                } catch (Error e) {
                    var message = _("Error creating preview: %s").printf (e.message);
                    MessageCenter.get_default ().add_error (message);
                }
                // when pressing enter, activate the resize button
                app.set_default_widget (resize_btn);
                app.set_focus (resize_btn);
            }
        }
    }
}
