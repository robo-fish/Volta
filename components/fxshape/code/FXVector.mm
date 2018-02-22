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

#include "FXVector.h"
#include <limits>

void FXVector::normalize()
{
    CGFloat mag = magnitude();
    if ( mag > std::numeric_limits<CGFloat>::epsilon() )
    {
        x /= mag;
        y /= mag;
    }
    else
    {
        x = 1.0f;
        y = 0.0f;
    }
}

void FXVector::rotate( CGFloat angle, FXVector const & pivot )
{
	CGFloat cos_a = std::cos(angle);
	CGFloat sin_a = std::sin(angle);
	x -= pivot.x;
	y -= pivot.y;
	CGFloat xrot = (x * cos_a) - (y * sin_a);
	CGFloat yrot = (x * sin_a) + (y * cos_a);
	x = xrot + pivot.x;
	y = yrot + pivot.y;
}

bool operator== (FXVector const & v1, FXVector const & v2)
{
	return (fabs(v1.x - v2.x) < std::numeric_limits<CGFloat>::epsilon()) &&
		(fabs(v1.y - v2.y) < std::numeric_limits<CGFloat>::epsilon());
}

bool operator!= (FXVector const & v1, FXVector const & v2)
{
	return (fabs(v1.x - v2.x) >= std::numeric_limits<CGFloat>::epsilon()) ||
		(fabs(v1.y - v2.y) >= std::numeric_limits<CGFloat>::epsilon());
}
  
bool operator< (FXVector const & v1, FXVector const & v2)
{
  return (v1.x == v2.x) ? (v1.y < v2.y) : (v1.x < v2.x);
}

FXVector operator+ (FXVector const & v1, FXVector const & v2)
{
	return FXVector(v1.x + v2.x, v1.y + v2.y);
}

FXVector operator- (FXVector const & v1, FXVector const & v2)
{
	return FXVector(v1.x - v2.x, v1.y - v2.y);
}

FXVector operator* (FXVector const & v, const CGFloat f)
{
	return FXVector(f * v.x, f * v.y);
}

FXVector operator* (CGFloat f, FXVector const & v)
{
	return FXVector(f * v.x, f * v.y);
}

FXVector operator/ (FXVector const & v, const CGFloat f)
{
	return FXVector(v.x/f, v.y/f);
}

void operator+= (FXVector & v1, const FXVector & v2)
{
	v1.x += v2.x;
	v1.y += v2.y;
}

void operator-= (FXVector & v1, const FXVector & v2)
{
	v1.x -= v2.x;
	v1.y -= v2.y;
}

void operator*= (FXVector & v, const CGFloat f)
{
	v.x *= f;
	v.y *= f;
}

void operator/= (FXVector & v, const CGFloat f)
{
	v.x /= f;
	v.y /= f; 
}
