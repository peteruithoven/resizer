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

namespace Resizer.Messages {
    // Tells people which file *type(s)* got dropped, not which files - the
    // type is the actionable info, and listing every dropped filename is
    // what made this message unreadably long in the first place.
    public class UnsupportedFileTypesMessage {
        public static string format (string[] types) {
            var unique_types = Core.Strings.unique (types);
            return ngettext (
                "Removed unsupported file type: %s",
                "Removed unsupported file types: %s",
                unique_types.length
            ).printf (Core.Strings.truncated_join (unique_types, 25));
        }
    }
}
