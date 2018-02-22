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


FXPlotterNumber::FXPlotterNumber( int exponent_, int significand_ ) :
  significand(significand_),
  exponent(exponent_)
{
  simplify();
}


FXPlotterNumber & FXPlotterNumber::simplify()
{
  if ( significand != 0 )
  {
    while ( (significand % 10) == 0 )
    {
      significand /= 10;
      exponent += 1;
    }
  }
  return *this;
}


float FXPlotterNumber::toFloat() const
{
  return significand * powf(10, exponent);
}


FXString FXPlotterNumber::stringRepresentation() const
{
  if ( exponent == 0 )
  {
    return FXString((__bridge CFStringRef)[NSString stringWithFormat:@"%d", significand]);
  }
  return FXString((__bridge CFStringRef)[NSString stringWithFormat:@"%d*10^%d", significand, exponent]);
}

