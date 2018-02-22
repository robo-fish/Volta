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

#ifndef VOLTA_VECTOR_H
#define VOLTA_VECTOR_H

#include <cmath>

//! 2D vector implementation
struct FXVector
{
  CGFloat x, y;
	
  FXVector() : x(0.0f), y(0.0f) {}
	
  FXVector(CGFloat x_, CGFloat y_) : x(x_), y(y_) {}
    
  FXVector(CGPoint p) : x(p.x), y(p.y) {}
		
  //! \return the magnitude of the vector
  CGFloat magnitude() const { return std::sqrt(x*x + y*y); }

  //! \return the square of the magnitude
  CGFloat squaredMagnitude() const { return x*x + y*y; }
	
  //! Turns the vector into a unit vector
  void normalize();
	
  //! \return a normalized copy
  FXVector asUnitVector() const
  {
    FXVector v(x,y);
    v.normalize();
    return v;
  }

  //! \return an inverted copy
  FXVector inverse() const { return FXVector(-x, -y); }

  //! inverts this vector
  void invert() { x = -x; y = -y; }

  CGFloat dot(const FXVector & v) const { return x*v.x + y*v.y; }

  //! \return the angle between two vectors, in radian
  CGFloat angle(FXVector const & v) const
  {
    return std::acos( dot(v) / v.magnitude() / magnitude() );
  }

  //! Rotates the vector by the given angle around the (optional) pivot point
  //! \param angle counterclockwise rotation angle in radians
  //! \param pivot pivot point
  void rotate( CGFloat angle, FXVector const & pivot = FXVector(0.0f, 0.0f) );
	
  void scale( CGFloat scale_x, CGFloat scale_y )
  {
    x *= scale_x;
    y *= scale_y;
  }
};

bool     operator== (FXVector const & v1, FXVector const & v2);
bool     operator!= (FXVector const & v1, FXVector const & v2);
bool     operator<  (FXVector const & v1, FXVector const & v2);
FXVector operator+  (FXVector const & v1, FXVector const & v2);
FXVector operator-  (FXVector const & v1, FXVector const & v2);
FXVector operator*  (FXVector const & v, const CGFloat f);
FXVector operator*  (CGFloat f, FXVector const & v);
FXVector operator/  (FXVector const & v, const CGFloat f);
void     operator+= (FXVector & v1, const FXVector & v2);
void     operator-= (FXVector & v1, const FXVector & v2);
void     operator*= (FXVector & v, const CGFloat f);
void     operator/= (FXVector & v, const CGFloat f);


#endif
