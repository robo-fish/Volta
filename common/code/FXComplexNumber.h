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

#include <math.h>
#include <ostream>

class FXComplexNumber
{
  float real;
  float imaginary;
  float magnitude;

public:
  FXComplexNumber() : real(0), imaginary(0), magnitude(0) {}  
  FXComplexNumber( float r, float i = 0.0f ) : real(r), imaginary(i)
  {
    magnitude = sqrtf((real * real) + (imaginary * imaginary));
  }
  
  float getReal() const { return real; }
  float getImaginary() const { return imaginary; }
  float getMagnitude() const { return magnitude; }

  bool operator== (FXComplexNumber const & c) const;
  bool operator!= (FXComplexNumber const & c) const;
  bool operator< (FXComplexNumber const & c) const;
};

std::ostream& operator<< ( std::ostream & stream, FXComplexNumber const & c );
