namespace Resizer {
  public class DropArea : Gtk.Overlay {

    private Gtk.Image image;
    private Gtk.Label drag_label;

    construct {
      image = new Gtk.Image ();
      image.get_style_context ().add_class ("card");
      image.hexpand = true;
      image.height_request = 200;
      image.width_request = 300;
      image.margin = 6;

      drag_label = new Gtk.Label (_("Drop Image Here"));
      drag_label.justify = Gtk.Justification.CENTER;

      var drag_label_style_context = drag_label.get_style_context ();
      drag_label_style_context.add_class ("h2");
      drag_label_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

      this.add (image);
      this.add_overlay (drag_label);
    }
  }
}
