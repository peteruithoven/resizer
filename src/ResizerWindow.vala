namespace Resizer {
  public class ResizerWindow : Gtk.Dialog {
  // public class ResizerWindow : Gtk.ApplicationWindow {

    // private Settings settings = new Settings ("com.github.peteruithoven.resizer");

    public ResizerWindow () {
      Object (border_width: 6,
              deletable: false,
              resizable: false);
    }
    construct {
      this.default_width = 200;
      this.title = "Resizer";

      var label = new Gtk.Label ("Resize image within:");

      var width_label = new Gtk.Label ("Width:");

      var width_entry = new Gtk.SpinButton.with_range (0, 10240, 1024);
      width_entry.hexpand = true;
      // settings.bind ("width", width_entry, "value", GLib.SettingsBindFlags.DEFAULT);

      var height_label = new Gtk.Label ("Height:");

      var height_entry = new Gtk.SpinButton.with_range (0, 10240, 1024);
      height_entry.hexpand = true;
      // settings.bind ("height", height_entry, "value", GLib.SettingsBindFlags.DEFAULT);

      var grid = new Gtk.Grid ();
      grid.column_spacing = 6 ;
      grid.margin_bottom = 3;
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

      this.show_all ();
    }
    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
            case Gtk.ResponseType.APPLY:

                break;
            case Gtk.ResponseType.CLOSE:
                destroy ();
                break;
            }
        }
    }
}
