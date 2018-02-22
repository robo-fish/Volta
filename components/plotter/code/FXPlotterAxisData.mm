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

#import "FXPlotterAxisData.h"
#import <cmath>


FXPlotterAxisData::FXPlotterAxisData()
{

}


FXPlotterAxisData::FXPlotterAxisData(VoltaPTEntityDataPtr entityData, FXPlotterScaleType scaleType, FXPlotterValueType valueType) :
mEntityData(entityData),
mScaleType(scaleType),
mValueType(valueType)
{
  if ( mEntityData.get() != nullptr )
  {
    calculateValueRange();
    createGridlines();
    calculateGridlinePositions();
    processEntityData();
  }
}


std::vector<CGFloat> const & FXPlotterAxisData::getData() const
{
  return mProcessedEntityData;
}


FXString const & FXPlotterAxisData::getTitle() const
{
  return mEntityData->title;
}


FXPlotterValueRange FXPlotterAxisData::getValueRange() const
{
  return mValueRange;
}


FXPlotterRoundedValueRange FXPlotterAxisData::getRoundedValueRange() const
{
  if ( mScaleType == FXPlotterScaleType::Linear )
  {
    return mValueRange.roundedLinearRange();
  }
  else
  {
    return mValueRange.roundedLogarithmicRange();
  }
}


FXPlotterRoundedValueRange FXPlotterAxisData::getGridRange() const
{
  FXPlotterRoundedValueRange result;
  if ( !mGridlines.empty() )
  {
    result.min = mGridlines.front().value;
    result.max = mGridlines.back().value;
  }
  return result;
}


FXPlotterGridlines const & FXPlotterAxisData::getGridlines() const
{
  return mGridlines;
}


FXPlotterScaleType FXPlotterAxisData::getScaleType() const
{
  return mScaleType;
}


void FXPlotterAxisData::setScaleType(FXPlotterScaleType scaleType)
{
  if ( mScaleType != scaleType )
  {
    mScaleType = scaleType;
    processEntityData();
  }
}


FXPlotterValueType FXPlotterAxisData::getValueType() const
{
  return mValueType;
}


void FXPlotterAxisData::setValueType(FXPlotterValueType valueType)
{
  if ( mValueType != valueType )
  {
    mValueType = valueType;
    processEntityData();
  }
}


void FXPlotterAxisData::createGridlines()
{
  mGridlines.clear();
  if ( mScaleType == FXPlotterScaleType::Linear )
  {
    FXPlotterRoundedValueRange roundedValueRange = mValueRange.roundedLinearRange();
    roundedValueRange.equalizeExponents();
    int significand = roundedValueRange.min.significand;
    for ( ; significand < roundedValueRange.max.significand; significand += roundedValueRange.step.significand )
    {
      mGridlines.push_back(FXPlotterGridline(0.0, FXPlotterNumber(roundedValueRange.min.exponent, significand)));
    }
    mGridlines.push_back(FXPlotterGridline(0.0, FXPlotterNumber(roundedValueRange.min.exponent, significand)));
  }
  else if ( mScaleType == FXPlotterScaleType::Log10 )
  {
    FXPlotterRoundedValueRange roundedRange = mValueRange.roundedLogarithmicRange();
    for ( int i = roundedRange.min.exponent; i <= roundedRange.max.exponent; i++ )
    {
      mGridlines.push_back(FXPlotterGridline(0.0, FXPlotterNumber(i, 1)));
    }
  }
}


void FXPlotterAxisData::calculateValueRange()
{
  mValueRange.min = mValueRange.max = 0.0;
  bool initialized = false;

  for( FXComplexNumber const & c : mEntityData->samples )
  {
    float numberValue = 0.0;
    switch (mValueType)
    {
      case FXPlotterValueType::Real: numberValue = c.getReal(); break;
      case FXPlotterValueType::Imaginary: numberValue = c.getImaginary(); break;
      case FXPlotterValueType::Magnitude: numberValue = c.getMagnitude(); break;
    }
    if ( !initialized )
    {
      mValueRange.min = mValueRange.max = numberValue;
      initialized = true;
    }
    else
    {
      mValueRange.min = std::min( mValueRange.min, numberValue );
      mValueRange.max = std::max( mValueRange.max, numberValue );
    }
  }
}


void FXPlotterAxisData::calculateGridlinePositions()
{
  size_t const numGridLines = mGridlines.size();
  if ( numGridLines > 1 )
  {
    if ( mScaleType == FXPlotterScaleType::Linear )
    {
      for ( size_t i = 0; i < numGridLines; i++ )
      {
        FXPlotterGridline & gridLine = mGridlines.at(i);
        gridLine.position = float(i) / (numGridLines - 1);
      }
    }
    else // if ( mScaleType == FXPlotterScaleType::Log10 )
    {
      FXPlotterGridline & maxLine = mGridlines.at(numGridLines-1);
      maxLine.position = 1.0;
      FXPlotterGridline & minLine = mGridlines.at(0);
      minLine.position = 0.0;
      float const maxValue = log10f(maxLine.value.significand) + maxLine.value.exponent;
      float const minValue = log10f(minLine.value.significand) + minLine.value.exponent;
      float const valueRange = maxValue - minValue;
      if (valueRange > 0)
      {
        for ( size_t i = 1; i < (numGridLines - 1); i++ )
        {
          FXPlotterGridline & gridLine = mGridlines.at(i);
          float value = log10f(gridLine.value.significand) + gridLine.value.exponent;
          gridLine.position = (value - minValue) / valueRange;
        }
      }
    }
  }
}


void FXPlotterAxisData::processEntityData()
{
  switch (mValueType)
  {
    case FXPlotterValueType::Real:
      for ( FXComplexNumber const & number : mEntityData->samples )
        mProcessedEntityData.push_back(number.getReal());
      break;
    case FXPlotterValueType::Imaginary:
      for ( FXComplexNumber const & number : mEntityData->samples )
        mProcessedEntityData.push_back(number.getImaginary());
      break;
    default:
      for ( FXComplexNumber const & number : mEntityData->samples )
        mProcessedEntityData.push_back(number.getMagnitude());
      break;
  }

  if ( mScaleType == FXPlotterScaleType::Log10 )
  {
    for ( CGFloat & value : mProcessedEntityData )
    {
      value = std::log10(value);
    }
  }
}
