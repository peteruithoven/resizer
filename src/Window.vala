/*
* Copyright (c) 2011-2018 Peter Uithoven (https://peteruithoven.nl)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
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
  public class Window : Gtk.Dialog {
  // public class Window : Gtk.ApplicationWindow {

    private Settings settings = new Settings ("com.github.peteruithoven.resizer");

    public Window () {
      Object (border_width: 6,
              resizable: false);
    }
    construct {
      this.default_width = 200;
      this.title = "Resizer";

      var label = new Gtk.Label ("Resize image within:");
      label.halign = Gtk.Align.START;

      var width_label = new Gtk.Label ("Width:");
      width_label.halign = Gtk.Align.START;

      var width_entry = new Gtk.SpinButton.with_range (0, 10240, 1024);
      width_entry.hexpand = true;
      width_entry.set_activates_default (true);
      settings.bind ("width", width_entry, "value", GLib.SettingsBindFlags.DEFAULT);
      width_entry.value_changed.connect (() => {
        Resizer.maxWidth = width_entry.get_value_as_int ();
      });

      var height_label = new Gtk.Label ("Height:");
      height_label.halign = Gtk.Align.START;

      var height_entry = new Gtk.SpinButton.with_range (0, 10240, 1024);
      height_entry.hexpand = true;
      height_entry.set_activates_default (true);
      settings.bind ("height", height_entry, "value", GLib.SettingsBindFlags.DEFAULT);
      height_entry.value_changed.connect (() => {
        Resizer.maxHeight = height_entry.get_value_as_int ();
      });

      var grid = new Gtk.Grid ();
      grid.column_spacing = 12;
      grid.row_spacing = 12;
      grid.margin = 6;
      grid.attach(label, 0, 0, 2, 1);
      grid.attach(width_label, 0, 1, 1, 1);
      grid.attach(width_entry, 1, 1, 1, 1);
      grid.attach(height_label, 0, 2, 1, 1);
      grid.attach(height_entry, 1, 2, 1, 1);
      grid.row_spacing = 6;

      Gtk.Box content = get_content_area () as Gtk.Box;
      content.add (grid);

      this.add_button("Cancel", Gtk.ResponseType.CLOSE);
      var resize_btn = this.add_button("Resize", Gtk.ResponseType.APPLY);
      resize_btn.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
      resize_btn.can_default = true;
      this.set_default (resize_btn);

      response.connect (on_response);
      set_default_response(Gtk.ResponseType.APPLY);

      this.show_all ();
    }
    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.APPLY:
                Resizer.create_resized_image();
                destroy ();
                break;
            case Gtk.ResponseType.CLOSE:
                destroy ();
                break;
            }
        }
    }
}
