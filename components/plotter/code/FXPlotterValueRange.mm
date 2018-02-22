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

#import "FXPlotterValueRange.h"
#import <cmath>

#pragma mark FXPlotterRoundedValueRange


/// @param equalizedNumber the number whose base will be matched to the base of targetNumber, also changing its factor.
/// The equalized number loses precision if its original base is smaller than the target's base.
static void changeBase(FXPlotterNumber& equalizedNumber, int const targetExponent)
{
  if ( equalizedNumber.exponent != targetExponent )
  {
    if ( equalizedNumber.exponent > targetExponent )
    {
      while (equalizedNumber.exponent > targetExponent )
      {
        equalizedNumber.exponent -= 1;
        equalizedNumber.significand *= 10;
      }
    }
    else
    {
      while (equalizedNumber.exponent < targetExponent )
      {
        equalizedNumber.exponent += 1;
        equalizedNumber.significand /= 10;
      }
    }
  }
}


void FXPlotterRoundedValueRange::equalizeExponents()
{
  int minExponent = step.exponent;
  if ( min.exponent < minExponent )
    minExponent = min.exponent;
  if ( max.exponent < minExponent )
    minExponent = max.exponent;
  changeBase(min, minExponent);
  changeBase(max, minExponent);
  changeBase(step, minExponent);
}


void FXPlotterRoundedValueRange::simplify()
{
  step.simplify();
  min.simplify();
  max.simplify();
}


#pragma mark FXPlotterValueRange


FXPlotterValueRange::FXPlotterValueRange( float min_, float max_ ) :
min(min_),
max(max_)
{
}


#define FX_LOGBASE(x) case x : return 1e##x##f
#define FX_LOGBASE_NEG(x) case -x : return 1e-##x##f

FXPlotterNumber FXPlotterValueRange::calculateStepSize() const
{
  static float log10_12 = 0.079181; // log10(1.2)
  static float log10_18 = 0.255276; // log10(1.8)

  FXPlotterNumber result;
  assert ( max >= min );
  if ( max > min )
  {
    float const L = std::log10(max - min);

    int const order = static_cast<int>( std::floor(L) );
    float const m = L - order;
    result.exponent = order - 1;
    if ( m <= log10_12 )
    {
      result.significand = 1;
    }
    else if ( m <= log10_18 )
    {
      result.significand = 2;
    }
    else
    {
      result.significand = 1;
      result.exponent += 1;
    }
  }
  else if ( max == min )
  {
    result.significand = 1;
    result.exponent = ( (min == 0) ? 0 : static_cast<int>(std::floor(std::log10f(std::abs(min)))) );
  }
  return result;
}


FXPlotterRoundedValueRange FXPlotterValueRange::roundedLinearRange() const
{
  // Asserting assumptions about the library functions we use.
  assert( std::floor( 1.13f ) == 1.0f );
  assert( std::floor( -1.13f ) == -2.0f );
  assert( std::ceil( 1.13f ) == 2.0f );
  assert( std::ceil( -1.13f ) == -1.0f );

  FXPlotterRoundedValueRange result;
  if ( max >= min )
  {
    result.step = calculateStepSize();
    float const stepValue = result.step.toFloat();
    result.min = (min == 0.0f) ? FXPlotterNumber(0,0) : FXPlotterNumber(result.step.exponent, result.step.significand * std::floor(min/stepValue)).simplify();
    result.max = (max == 0.0f) ? FXPlotterNumber(0,0) : FXPlotterNumber(result.step.exponent, result.step.significand * std::ceil(max/stepValue)).simplify();
  }
  return result;
}


FXPlotterRoundedValueRange FXPlotterValueRange::roundedLogarithmicRange() const
{
  static const float skTolerance = 1e-5f;
  FXPlotterRoundedValueRange result;
  if ( (max > min) && (max > 0) && (min > 0) )
  {
    float const max_log10 = std::log10(max);
    if ( std::abs(lrintf(max_log10) - max_log10) < skTolerance )
    {
      result.max.exponent = (int)lrintf(max_log10);
    }
    else
    {
      result.max.exponent = std::ceil(max_log10);
    }
    result.max.significand = 1;

    float min_log10 = std::log10(min);
    if ( std::abs(lrintf(min_log10) - min_log10) < skTolerance )
    {
      result.min.exponent = (int)lrintf(min_log10);
    }
    else
    {
      result.min.exponent = std::floor(min_log10);
    }
    result.min.significand = 1;
  }
  return result;
}

