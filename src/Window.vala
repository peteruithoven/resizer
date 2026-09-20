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
    public class Window : Adw.ApplicationWindow {

        private Gtk.Stack pages;

        public Window (Application app) {
            Object (application: app, resizable: false, title: _("Resizer"));
        }
        construct {
            var header = HeaderBar.create ();

            var resize_page = new ResizePage (this);
            var resizing_page = new ResizingPage ();

            // Pages stack
            pages = new Gtk.Stack ();
            pages.hhomogeneous = false;
            pages.vhomogeneous = false;
            pages.transition_duration = 500;
            pages.transition_type = Gtk.StackTransitionType.SLIDE_UP;
            pages.add_named (resize_page, "resize");
            pages.add_named (resizing_page, "resizing");

            var message_center = MessageCenter.get_default ();

            var inner_grid = new Gtk.Grid ();
            inner_grid.orientation = Gtk.Orientation.VERTICAL;
            inner_grid.row_spacing = 12;
            inner_grid.attach (message_center, 0, 0, 1, 1);
            inner_grid.attach (pages, 0, 1, 1, 1);

            // Adw.ToolbarView (rather than just packing the header bar as a
            // regular content row) is what makes the header bar visually
            // merge into the content below it, with no separating shadow.
            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header);
            toolbar_view.top_bar_style = Adw.ToolbarStyle.FLAT;
            toolbar_view.content = inner_grid;
            this.set_content (toolbar_view);

            Resizer.get_default ().state_changed.connect ((r, state) => {
                switch (state) {
                    case Resizer.State.IDLE:
                        pages.visible_child_name = "resize";
                        break;
                    case Resizer.State.RESIZING:
                        resize_page.visible = false;
                        pages.visible_child_name = "resizing";
                        break;
                    case Resizer.State.SUCCESS:
                        // small delay to show completed progress
                        GLib.Timeout.add (500, () => {
                            this.destroy ();
                            return false;
                        });
                        break;
                }
            });

            // set whole window as drag target
            var drop_target = new Gtk.DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
            drop_target.drop.connect (on_drop);
            ((Gtk.Widget) this).add_controller (drop_target);
        }
        private bool on_drop (GLib.Value value, double x, double y) {
            var file_list = (Gdk.FileList) value.get_boxed ();
            var files = new GenericArray<File> ();
            foreach (unowned var file in file_list.get_files ()) {
                stdout.printf ("received: %s\n", file.get_uri ());
                files.add (file);
            }
            Resizer.get_default ().files = files.data;
            return true;
        }
    }
}
