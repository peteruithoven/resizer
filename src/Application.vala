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
            set_accels_for_action ("app.quit", {"<Ctrl>Q", "Escape"});
        }

        public override void open (File[] files, string hint) {
            activate();
            Resizer.get_default ().files = files;
        }

        protected override void activate () {
            set_theme();

            window = new Window ();
            window.set_application (this);
            window.show_all ();
        }

        private void set_theme (){
            var sys_settings = Granite.Settings.get_default ();
            var settings = Gtk.Settings.get_default ();

            settings.gtk_application_prefer_dark_theme = is_dark_theme_prefered(sys_settings, settings);

            /* be notified when system theme is changed and change accordingly */
            sys_settings.notify["prefers-color-scheme"].connect (() => {
                settings.gtk_application_prefer_dark_theme = is_dark_theme_prefered(sys_settings, settings);
            });
        }

        private bool is_dark_theme_prefered (Granite.Settings sys_settings, Gtk.Settings settings){
                return (sys_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK);
        }


        public static int main (string[] args) {
            var app = new Application ();
            return app.run (args);
        }
    }
}
