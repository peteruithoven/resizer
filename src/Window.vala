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
    public class Window : Hdy.Window {

        private Gtk.Stack pages;
        const Gtk.TargetEntry[] DRAG_TARGETS = { { "text/uri-list", 0, 0 } };

        public Window () {
            Object (border_width: 0,
                            resizable: false,
                            title: _("Resizer")
                         );
        }
        construct {
            Hdy.init ();

            var header = new HeaderBar ();

            var resize_page = new ResizePage (this);
            var resizing_page = new ResizingPage ();

            // Pages stack
            pages = new Gtk.Stack ();
            pages.homogeneous = false;
            pages.transition_duration = 500;
            pages.transition_type = Gtk.StackTransitionType.SLIDE_UP;
            pages.add_named (resize_page, "resize");
            pages.add_named (resizing_page, "resizing");

            var message_center = MessageCenter.get_default();

            var innerGrid = new Gtk.Grid();
            innerGrid.orientation = Gtk.Orientation.VERTICAL;
            innerGrid.row_spacing = 12;
            innerGrid.add(message_center);
            innerGrid.add(pages);

            var grid = new Gtk.Grid();
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.add(header);
            grid.add(innerGrid);
            this.add(grid);

            Resizer.get_default ().state_changed.connect((r, state) => {
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
            Gtk.drag_dest_set (this, Gtk.DestDefaults.MOTION | Gtk.DestDefaults.DROP, DRAG_TARGETS, Gdk.DragAction.COPY);
            drag_data_received.connect (on_drag_data_received);
        }
        private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time) {
            var files = new GenericArray<File> ();
            foreach (var uri in data.get_uris ()) {
                stdout.printf ("received: %s\n", uri);
                var file = File.new_for_uri (uri);
                files.add (file);
            };
            Resizer.get_default ().files = files.data;
            // inform drag source that drop is finished successfully
            Gtk.drag_finish (drag_context, true, false, time);
        }
    }
}
