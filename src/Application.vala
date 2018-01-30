/*
* Copyright (c) 2011-2018 Peter Uithoven (https://peteruithoven.nl)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
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
    public class Application : Gtk.Application {
        private Window window = null;

        public Application () {
            Object (
                application_id: Constants.PROJECT_NAME,
                flags: ApplicationFlags.HANDLES_OPEN
            );

            // Support quiting app using Super+Q
            var quit_action = new SimpleAction ("quit", null);
            quit_action.activate.connect (() => {
                if (window != null) {
                    window.destroy ();
                }
            });
            add_action (quit_action);
            set_accels_for_action ("app.quit", {"<Ctrl>Q"});
        }

        public override void open (File[] files, string hint) {
            // TODO: throw error when multiple files or handle multiple files
            foreach (var file in files) {
                Resizer.file = file;
            }
            activate();
        }

        protected override void activate () {
            window = new Window ();
            window.set_application (this);
            window.show_all ();
        }

        public static int main (string[] args) {
            var app = new Application ();
            return app.run (args);
        }
    }
}
