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

namespace Resizer.Core {
    public class Strings {
        // Adw.Toast's title label has no wrap/max-width-chars knob of its own,
        // so an unbounded list of items grows the toast - and, since the app
        // window is non-resizable but still auto-grows to fit content
        // requests, the window itself - to fit. Truncate before it gets to
        // the toast instead. Cuts at the last full item that still fits
        // rather than mid-item, except when a single item alone busts the
        // budget.
        public static string truncated_join (string[] items, int max_chars) {
            var joined = string.joinv (", ", items);
            if (joined.length <= max_chars) {
                return joined;
            }
            var truncated = joined.substring (0, max_chars);
            var last_boundary = truncated.last_index_of (", ");
            if (last_boundary > 0) {
                truncated = truncated.substring (0, last_boundary);
            }
            return truncated + "…";
        }
        // Deduplicates while preserving first-seen order (plain "in" checks
        // against a growing array are fine at the tiny sizes this app deals
        // with - a handful of distinct file types or names per batch).
        public static string[] unique (string[] items) {
            string[] result = {};
            foreach (unowned string item in items) {
                var already_seen = false;
                foreach (unowned string seen in result) {
                    if (seen == item) {
                        already_seen = true;
                        break;
                    }
                }
                if (!already_seen) {
                    result += item;
                }
            }
            return result;
        }
    }
}
