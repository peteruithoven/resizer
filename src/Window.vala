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

    private Settings settings = new Settings (Constants.PROJECT_NAME);
    private Gtk.Label intro_label;
    private Gtk.SpinButton width_entry;
    private Gtk.SpinButton height_entry;
    private DropArea drop_area;
    private Gtk.Widget cancel_btn;
    private Gtk.Widget resize_btn;
    const Gtk.TargetEntry[] DRAG_TARGETS = {{ "text/uri-list", 0, 0 }};

    public Window () {
      Object (border_width: 6,
              resizable: false);
    }
    construct {
      this.default_width = 500;
      this.title = _("Resizer");
      var spacing = 12;

      intro_label = new Gtk.Label ("");
      intro_label.margin_bottom = spacing/2;

      // Width input
      var width_label = new Gtk.Label (_("Width:"));
      // width_label.halign = Gtk.Align.START;
      width_label.halign = Gtk.Align.END;

      width_entry = new Gtk.SpinButton.with_range (1, 10000, 1000);
      width_entry.hexpand = true;
      width_entry.set_activates_default (true);
      settings.bind ("width", width_entry, "value", GLib.SettingsBindFlags.DEFAULT);

      var width_input = new Gtk.Grid ();
      width_input.column_spacing = spacing/2;
      width_input.column_homogeneous = true;
      width_input.add(width_label);
      width_input.add(width_entry);
      // Create 3th column, making sure the entry is in the center
      width_input.add(new Gtk.Label (""));

      // height input
      var height_label = new Gtk.Label (_("Height:"));
      height_label.halign = Gtk.Align.START;

      height_entry = new Gtk.SpinButton.with_range (1, 10000, 1000);
      height_entry.hexpand = true;
      height_entry.set_activates_default (true);
      settings.bind ("height", height_entry, "value", GLib.SettingsBindFlags.DEFAULT);

      var height_input = new Gtk.Grid ();
      height_input.row_spacing = spacing/2;
      height_input.valign = Gtk.Align.CENTER;
      height_input.orientation = Gtk.Orientation.VERTICAL;
      height_input.add(height_label);
      height_input.add(height_entry);
      // Create 3th row, making sure the entry is in the center
      height_input.add(new Gtk.Label (""));

      drop_area = new DropArea();

      var grid = new Gtk.Grid ();
      grid.column_spacing = spacing/2;
      grid.row_spacing = spacing;
      grid.margin = spacing/2;
      grid.margin_right = spacing;
      grid.attach(intro_label, 0, 0, 2, 1);
      grid.attach(width_input, 0, 1, 1, 1);
      grid.attach(drop_area, 0, 2, 1, 1);
      grid.attach(height_input, 1, 2, 1, 1);
      grid.row_spacing = 6;

      Gtk.Box content = get_content_area () as Gtk.Box;
      content.add (grid);

      cancel_btn = this.add_button(_("Cancel"), Gtk.ResponseType.CLOSE);
      resize_btn = this.add_button(_("Resize"), Gtk.ResponseType.APPLY);
      resize_btn.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
      resize_btn.can_default = true;
      this.set_default (resize_btn);

      response.connect (on_response);
      set_default_response(Gtk.ResponseType.APPLY);

      this.show_all ();

      // set whole window as drag target
      Gtk.drag_dest_set (this, Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, DRAG_TARGETS, Gdk.DragAction.COPY);
      drag_data_received.connect (on_drag_data_received);

      update ({});
    }
    private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time) {
      var files = new GenericArray<File> ();
      foreach (var uri in data.get_uris ()) {
        stdout.printf ("received: %s\n", uri);
        var file = File.new_for_uri (uri);
        files.add (file);
      };
      Resizer.files = files.data;
      // inform drag source that drop is finished successfully
      Gtk.drag_finish (drag_context, true, false, time);

      update (Resizer.files);
    }
    public void update (File[] files) {
      if (files.length == 0) {
        cancel_btn.sensitive = false;
        resize_btn.sensitive = false;
        intro_label.label = _("Resize image(s) within:");
      } else {
        cancel_btn.sensitive = true;
        resize_btn.sensitive = true;
        if (files.length == 1) {
          intro_label.label = _("Resize image within:");
        } else {
          intro_label.label = _("Resize %i images within:").printf (files.length);
        }
        drop_area.show_preview (files);
      }
    }
    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.APPLY:
                Resizer.maxWidth = width_entry.get_value_as_int ();
                Resizer.maxHeight = height_entry.get_value_as_int ();
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
