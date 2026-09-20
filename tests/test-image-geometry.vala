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

void test_bounded_size_shrinks_to_fit_preserving_aspect_ratio () {
    int width, height;
    Resizer.Core.ImageGeometry.bounded_size (3072, 2048, 1000, 1000, out width, out height);
    assert (width == 1000);
    assert (height == 667);
}

void test_bounded_size_does_not_enlarge_smaller_images () {
    int width, height;
    Resizer.Core.ImageGeometry.bounded_size (400, 300, 1000, 1000, out width, out height);
    assert (width == 400);
    assert (height == 300);
}

void test_bounded_size_bounds_on_the_limiting_dimension () {
    int width, height;
    Resizer.Core.ImageGeometry.bounded_size (2000, 500, 1000, 1000, out width, out height);
    assert (width == 1000);
    assert (height == 250);
}

void test_bounded_size_rounds_the_non_limiting_dimension_to_nearest () {
    int width, height;
    // Portrait version of the 3072x2048 case: here it's the width (not the
    // height) that lands on a fraction and must round, not truncate.
    Resizer.Core.ImageGeometry.bounded_size (2048, 3072, 1000, 1000, out width, out height);
    assert (width == 667);
    assert (height == 1000);
}

void test_bounded_size_never_rounds_down_to_zero () {
    int width, height;
    Resizer.Core.ImageGeometry.bounded_size (10000, 1, 100, 100, out width, out height);
    assert (width == 100);
    assert (height == 1);
}
