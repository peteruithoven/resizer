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
    public class HeaderBar {
        public static Adw.HeaderBar create () {
            var header = new Adw.HeaderBar ();
            header.add_css_class (Granite.STYLE_CLASS_DEFAULT_DECORATION);

            var info_text = new Gtk.Label (
                _("Resizer will never upscale and always maintain the aspect ratio of your images.")
            );
            info_text.max_width_chars = 30;
            info_text.wrap = true;
            info_text.margin_top = info_text.margin_bottom = 10;
            info_text.margin_start = info_text.margin_end = 6;

            var info_popover = new Gtk.Popover ();
            info_popover.set_child (info_text);

            var info_menu = new Gtk.MenuButton ();
            info_menu.tooltip_text = _("Info");
            info_menu.icon_name = "dialog-information-symbolic";
            info_menu.valign = Gtk.Align.CENTER;
            info_menu.popover = info_popover;

            header.pack_end (info_menu);
            return header;
        }
    }
}
