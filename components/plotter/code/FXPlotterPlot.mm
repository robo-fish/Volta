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

#import "FXPlotterPlot.h"
#import <cmath>


FXPlotterPlot::FXPlotterPlot(FXString const & title, FXPlotterAxisData const & abscissaData, FXPlotterAxisData const & ordinateData) :
  mTitle(title),
  mAbscissa(abscissaData),
  mOrdinate(ordinateData)
{
}


FXString FXPlotterPlot::getTitle() const
{
  return mTitle;
}


FXPlotterAxisData & FXPlotterPlot::getAbscissa()
{
  return mAbscissa;
}


FXPlotterAxisData const & FXPlotterPlot::getAbscissa() const
{
  return mAbscissa;
}


FXPlotterAxisData & FXPlotterPlot::getOrdinate()
{
  return mOrdinate;
}


FXPlotterAxisData const & FXPlotterPlot::getOrdinate() const
{
  return mOrdinate;
}

