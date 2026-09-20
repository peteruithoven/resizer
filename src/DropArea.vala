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
    public class DropArea : Gtk.Box {

        private Gtk.Picture image;
        private Gtk.Picture image2;
        private Gtk.Widget placeholder_box;
        public Gtk.Button select_button;

        public DropArea () {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        }
        construct {
            image = new Gtk.Picture ();
            image.content_fit = Gtk.ContentFit.CONTAIN;
#if GRANITE_HAS_CSS_CLASS
            image.add_css_class (Granite.CssClass.CARD);
#else
            image.add_css_class (Granite.STYLE_CLASS_CARD);
#endif
            image.hexpand = true;
            image.vexpand = true;
            image.halign = Gtk.Align.FILL;
            image.valign = Gtk.Align.FILL;
            image.width_request = 300;
            image.height_request = 200;
            image.margin_top = image.margin_bottom = image.margin_start = image.margin_end = 6;

            image2 = new Gtk.Picture ();
            image2.content_fit = Gtk.ContentFit.CONTAIN;
#if GRANITE_HAS_CSS_CLASS
            image2.add_css_class (Granite.CssClass.CARD);
#else
            image2.add_css_class (Granite.STYLE_CLASS_CARD);
#endif
            image2.hexpand = true;
            image2.vexpand = true;
            image2.halign = Gtk.Align.FILL;
            image2.valign = Gtk.Align.FILL;
            // Same total margin on each axis as `image` (6+6=12 either way),
            // just redistributed - this shifts image2's box up and to the
            // right by 6px while keeping it exactly the same size as image's
            // box, so both end up with an identical aspect ratio and CONTAIN
            // doesn't have to crop or letterbox either one.
            image2.margin_top = 0;
            image2.margin_bottom = 12;
            image2.margin_start = 12;
            image2.margin_end = 0;
            image2.visible = false;

            var placeholder = new Granite.Placeholder (_("Drop image(s) here"));
            placeholder.description = _("or select image(s) using the button below");

            select_button = new Gtk.Button.with_label (_("Select image(s)"));
            select_button.add_css_class ("suggested-action");
            select_button.halign = Gtk.Align.CENTER;
            select_button.clicked.connect (() => open_files_using_file_chooser.begin ());

            var placeholder_grid = new Gtk.Grid ();
            placeholder_grid.orientation = Gtk.Orientation.VERTICAL;
            placeholder_grid.row_spacing = 12;
            placeholder_grid.valign = Gtk.Align.CENTER;
            placeholder_grid.halign = Gtk.Align.CENTER;
            placeholder_grid.attach (placeholder, 0, 0, 1, 1);
            placeholder_grid.attach (select_button, 0, 1, 1, 1);

            // Gtk.Widget.width_request only raises the *minimum* size, it can't
            // cap the title/description's natural (unwrapped) width - use
            // Adw.Clamp, which actually enforces a maximum, so the text wraps
            // instead of overflowing past the card before any image is loaded.
            var placeholder_clamp = new Adw.Clamp ();
            placeholder_clamp.maximum_size = 260;
            placeholder_clamp.valign = Gtk.Align.CENTER;
            placeholder_clamp.halign = Gtk.Align.CENTER;
            placeholder_clamp.child = placeholder_grid;
            placeholder_box = placeholder_clamp;

            var overlay = new Gtk.Overlay ();
            // No main child - both images and the placeholder are added as
            // overlay layers instead, so all three can be full-size Gtk.Picture
            // widgets (via halign/valign FILL) that stretch to fill however
            // wide the card ends up, rather than staying at a small fixed
            // intrinsic size. Add order controls stacking: image2 (the "peek"
            // photo behind) first, then image (the front preview) on top.
            overlay.add_overlay (image2);
            overlay.add_overlay (image);
            overlay.add_overlay (placeholder_box);
            overlay.set_measure_overlay (image, true);
            overlay.set_measure_overlay (image2, true);
            overlay.set_measure_overlay (placeholder_box, true);
            this.append (overlay);
        }
        public void show_preview (File[] files) throws Error {

            var file = files[0];
            var pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                file.get_path (),
                300,
                500,
                true
            );

            placeholder_box.visible = false;

            image.paintable = Gdk.Texture.for_pixbuf (pixbuf);
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
                image2.paintable = Gdk.Texture.for_pixbuf (pixbuf2);
                image2.height_request = pixbuf2.height;
                image2.width_request = pixbuf2.width;
                image2.visible = true;
            } else {
                image2.visible = false;
            }
        }

        private async void open_files_using_file_chooser () {
            var dialog = new Gtk.FileDialog ();
            dialog.title = _("Open Image(s)");

            var image_files_filter = new Gtk.FileFilter ();
            image_files_filter.set_filter_name (_("Image files"));
            /* some image types like webp, svg are not supported */
            string[] supported_mimetypes = {"image/png", "image/jpeg", "image/bmp", "image/tiff"};
            foreach (var mimetype in supported_mimetypes) {
                image_files_filter.add_mime_type (mimetype);
            }
            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (image_files_filter);
            dialog.filters = filters;
            dialog.default_filter = image_files_filter;

            try {
                var chosen = yield dialog.open_multiple ((Gtk.Window) get_root (), null);
                if (chosen == null) {
                    return;
                }
                var files = new GenericArray<File> ();
                for (uint i = 0; i < chosen.get_n_items (); i++) {
                    var file = (File) chosen.get_item (i);
                    stdout.printf ("opening: %s\n", file.get_uri ());
                    files.add (file);
                }
                Resizer.get_default ().files = files.data;
            } catch (Error e) {
                // user cancelled the dialog
            }
        }
    }
}
