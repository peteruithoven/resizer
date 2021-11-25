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
    public class HeaderBar : Hdy.HeaderBar {

        construct {
            show_close_button = true;
            var header_context = get_style_context ();
            header_context.add_class (Gtk.STYLE_CLASS_TITLEBAR);
            header_context.add_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);
            header_context.add_class (Gtk.STYLE_CLASS_FLAT);

            var info_text = new Gtk.Label (_("Resizer will never upscale and always maintain the aspect ratio of your images."));
            info_text.max_width_chars = 30;
            info_text.wrap = true;
            info_text.margin_top = info_text.margin_bottom = 10;
            info_text.margin_start = info_text.margin_end = 6;
            info_text.show_all ();

            var infoPopover = new Gtk.Popover (null);
            infoPopover.add (info_text);

            var info_menu = new Gtk.MenuButton ();
            info_menu.tooltip_text = _("Info");
            info_menu.image = new Gtk.Image.from_icon_name ("dialog-information", Gtk.IconSize.SMALL_TOOLBAR);
            info_menu.valign = Gtk.Align.CENTER;
            info_menu.popover = infoPopover;

            var insert_button = new Gtk.Button.from_icon_name ("insert-image",
                                                               Gtk.IconSize.SMALL_TOOLBAR);
            insert_button.tooltip_text = _("Insert image(s)");
            insert_button.valign = Gtk.Align.CENTER;
            insert_button.clicked.connect (open_files_using_file_chooser);

            pack_end (info_menu);
            pack_end (insert_button);
        }
    }

    private void open_files_using_file_chooser() {
        var file_chooser = new Gtk.FileChooserNative (_("Open Image(s)"), 
                                                      null,
                                                      Gtk.FileChooserAction.OPEN,
                                                      _("Open"),
                                                      _("Cancel"));

        var files = new GenericArray<File> ();
        file_chooser.select_multiple = true;
        var response = file_chooser.run();
        if (response == Gtk.ResponseType.ACCEPT) {
            var uris = file_chooser.get_uris();
            foreach (var uri in uris) {
                stdout.printf ("opening: %s\n", uri);
                var file = File.new_for_uri (uri);
                files.add(file);
                Resizer.get_default().files = files.data;
            }
        }
    }
}
