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
    public class DropArea : Gtk.Overlay {

        private Gtk.Image image;
        private Gtk.Image image2;
        private Gtk.Box overlay_box;

        construct {
            image = new Gtk.Image ();
            image.get_style_context ().add_class (Granite.STYLE_CLASS_CARD);
            image.hexpand = true;
            image.width_request = 300;
            image.height_request = 200;
            image.margin = 6;

            image2 = new Gtk.Image ();
            image2.get_style_context ().add_class (Granite.STYLE_CLASS_CARD);
            image2.margin = 6;
            image2.margin_start = 6+6;
            image2.margin_top = 6;
            image2.visible = false;

            overlay_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            overlay_box.valign = Gtk.Align.CENTER;
            overlay_box.halign = Gtk.Align.CENTER;

            var or_label = new Gtk.Label (_("or"));
            var or_label_style_context = or_label.get_style_context ();
            or_label_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
            or_label_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            var select_button = new Gtk.Button.with_label (_("Select image"));
            select_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            select_button.clicked.connect (open_files_using_file_chooser);

            var drag_label = new Gtk.Label (_("Drop Image(s) Here"));
            drag_label.justify = Gtk.Justification.CENTER;

            var drag_label_style_context = drag_label.get_style_context ();
            drag_label_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
            drag_label_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            var images = new Gtk.Fixed();
            images.valign = Gtk.Align.CENTER;
            images.halign = Gtk.Align.CENTER;
            images.put (image2, 0, 0);
            images.put (image, 0, 0);

            overlay_box.pack_start (drag_label);
            overlay_box.pack_start (or_label);
            overlay_box.pack_start (select_button);
            this.add (images);
            this.add_overlay (overlay_box);
        }
        public void show_preview(File[] files) throws Error {

            var file = files[0];
            var pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                file.get_path (),
                300,
                500,
                true
            );

            overlay_box.no_show_all = true;
            overlay_box.visible = false;

            image.set_from_pixbuf (pixbuf);
            image.height_request = pixbuf.height;
            image.width_request = pixbuf.width;

            if (files.length > 1) {
                var file2 = files[1];
                var pixbuf2 = new Gdk.Pixbuf.from_file_at_scale (
                    file2.get_path (),
                    300,
                    500,
                    true
                );
                image2.set_from_pixbuf (pixbuf2);
                image2.visible = true;

                image.margin_top = 6+6;
            } else {
                image2.visible = false;

                image.margin_top = 6;
            }
        }

        private void open_files_using_file_chooser () {
            var file_chooser = new Gtk.FileChooserNative (_("Open Image(s)"), 
                                                          null,
                                                          Gtk.FileChooserAction.OPEN,
                                                          _("Open"),
                                                          _("Cancel"));

            var files = new GenericArray<File> ();
            file_chooser.select_multiple = true;
            var response = file_chooser.run ();
            if (response == Gtk.ResponseType.ACCEPT) {
                var uris = file_chooser.get_uris ();
                foreach (var uri in uris) {
                    stdout.printf ("opening: %s\n", uri);
                    var file = File.new_for_uri (uri);
                    files.add (file);
                    Resizer.get_default ().files = files.data;
                }
            }
        }
    }
}
