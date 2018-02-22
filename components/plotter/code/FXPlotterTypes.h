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

#import "FXPlotterNumber.h"

enum class FXPlotterValueType
{
  Real,
  Imaginary,
  Magnitude
};


struct FXPlotterGridline
{
  float position; // Relative to the canvas size. Between 0.0 and 1.0.
  FXPlotterNumber value; // Within the entity's value range.
  FXPlotterGridline( float pos = 0.0f ) : position(pos) {}
  FXPlotterGridline( float pos, FXPlotterNumber const & number ) : position(pos), value(number) {}
};

typedef std::vector<FXPlotterGridline> FXPlotterGridlines;


enum class FXPlotterScaleType
{
  Linear,
  Log10
};
