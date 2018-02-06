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
  public class ResizingPage : Gtk.Grid {

    public ResizingPage () {
      this.width_request = 350;
      var spacing = 12;

      var bar = new Gtk.ProgressBar ();
      bar.hexpand = true;
      bar.halign = Gtk.Align.FILL;

      var remaining_label = new Gtk.Label ("");
      remaining_label.halign = Gtk.Align.START;

      this.orientation = Gtk.Orientation.VERTICAL;
      this.margin = spacing;
      this.margin_top = 0;
      this.add(bar);
      this.add(remaining_label);

      Resizer.get_default ().progress_changed.connect((r, numFiles, numFilesResized) => {
        bar.fraction = ((double) numFilesResized) / ((double) numFiles);
        var imagesRemaining = numFiles-numFilesResized;
        if (imagesRemaining == 1) {
          remaining_label.label = _("1 image remaining");
        } else {
          remaining_label.label = _("%i images remaining").printf (imagesRemaining);
        }
      });
    }
  }
}
