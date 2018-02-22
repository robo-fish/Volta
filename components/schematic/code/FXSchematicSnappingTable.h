/**
This file is part of the Volta project.
Copyright (C) 2007-2013 Kai Berk Oezer
https://robo.fish/wiki/index.php?title=Volta
https://github.com/robo-fish/Volta

Volta is free software. You can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
#pragma once

#include <set>
#include <vector>


struct FXSchematicSnapping
{
  CGFloat position;
  std::set<CGFloat> alignmentLinePositions;
  bool operator< (FXSchematicSnapping const & p) const { return position < p.position; }
  bool operator== (FXSchematicSnapping const & p) const { return position == p.position; }
};


/// Used to cache snapping positions.
/// Created when a dragging operation starts and is looked up to determine
/// if the connections points of the dragged element aligns with any of the
/// connection points of elements that are not being dragged.
struct FXSchematicSnappingTable
{
  // sorted list of vertical positions which to snap to.
  std::vector<FXSchematicSnapping> verticalSnappings;

  // sorted list of horizontal positions which to snap to.
  std::vector<FXSchematicSnapping> horizontalSnappings;

  bool ready; // whether the table is ready to be used

  FXSchematicSnappingTable() : ready(false) {}

  void clear()
  {
    ready = false;
    verticalSnappings.clear();
    horizontalSnappings.clear();
  }
};
