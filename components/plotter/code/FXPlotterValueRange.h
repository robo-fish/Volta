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


// The rounded range is larger than, or equal to, its corresponding FXPlotterValueRange.
// Used for creating nice graph grid lines.
class FXPlotterRoundedValueRange
{
public:
  FXPlotterNumber step;
  FXPlotterNumber min;
  FXPlotterNumber max;

  /// Transforms 'min', 'max' and 'step' to use the minimum exponent of those three.
  void equalizeExponents();

  /// Convenience method to simplify 'min', 'max', and 'step'.
  void simplify();
};


class FXPlotterValueRange
{
public:
  float min;
  float max;
  FXPlotterValueRange( float min_ = 0.0f, float max_ = 0.0f );
  FXPlotterRoundedValueRange roundedLinearRange() const;
  FXPlotterRoundedValueRange roundedLogarithmicRange() const;
private:
  FXPlotterNumber calculateStepSize() const;
};
