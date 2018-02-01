namespace Resizer {
  public class DropArea : Gtk.Overlay {

    private Gtk.Image image;
    private Gtk.Label drag_label;

    construct {
      image = new Gtk.Image ();
      image.get_style_context ().add_class ("card");
      image.hexpand = true;
      image.width_request = 300;
      image.height_request = 200;
      image.margin = 6;
      image.valign = Gtk.Align.CENTER;
      image.halign = Gtk.Align.CENTER;

      drag_label = new Gtk.Label (_("Drop Image Here"));
      drag_label.justify = Gtk.Justification.CENTER;

      var drag_label_style_context = drag_label.get_style_context ();
      drag_label_style_context.add_class ("h2");
      drag_label_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

      this.add (image);
      this.add_overlay (drag_label);
    }
    public void show_preview(File[] files) {
      drag_label.visible = false;
      drag_label.no_show_all = true;

      var file = files[0];
      var pixbuf = new Gdk.Pixbuf.from_file_at_scale (
        file.get_path (),
        300,
        500,
        true
      );
      image.set_from_pixbuf (pixbuf);
      image.height_request = pixbuf.height;
      image.width_request = pixbuf.width;
    }
  }
}
