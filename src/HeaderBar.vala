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
    public class HeaderBar : Gtk.HeaderBar {

        construct {
            show_close_button = true;
            var header_context = get_style_context ();
            header_context.add_class ("titlebar");
            header_context.add_class ("default-decoration");
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
            info_menu.popover = infoPopover;

            pack_end (info_menu);

            this.show_all ();
        }
    }
}
