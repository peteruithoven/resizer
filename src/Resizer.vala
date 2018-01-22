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
    public class Resizer : Object {
        public static int maxWidth = 1024;
        public static int maxHeight = 1024;
        public static File file;

        public static void create_resized_image() {
            var input_name = file.get_path ();
            var output_name = get_output_name (input_name);

            try {
                string[] command = get_command(input_name, output_name, maxWidth, maxHeight);
                Subprocess subprocess = new Subprocess.newv (command, SubprocessFlags.STDERR_PIPE);
                if (subprocess.wait_check ()) {
                    stdout.printf ("Success!\n");
                }
            } catch (Error e) {
                stderr.printf ("Error during resize: %s", e.message);
            }
        }
        public static string get_output_name(string input) {
            try {
                var file_regex = new GLib.Regex ("""(\/[^./]+)(\.\w+)""");
                string output_name = file_regex.replace (input, input.length, 0, """\1-resized\2""");
                stdout.printf ("output_name: %s\n", output_name);
                return output_name;
            } catch (RegexError e) {
                stderr.printf ("Error on file: %s", e.message);
                return "";
            }
        }
        public static string[] get_command (string input, string output, int width, int height) {
            var array = new GenericArray<string> ();
            array.add ("convert");
            array.add (input);
            array.add ("-resize");
            array.add (width.to_string () +  "x" + height.to_string ());
            array.add (output);
            stdout.printf ("Command:\n");
            array.foreach ((str) => {
        		stdout.printf ("- %s\n", str);
        	});
            return array.data;
        }
    }
}
