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

#import "FXPlotterGraphData.h"

static FXPlotterAxisData createCommonAbscissa( VoltaPTAnalysisData const & analysisData );
static void createPlots( std::vector<FXPlotterPlot> & plots, VoltaPTAnalysisData const & analysisData, FXPlotterAxisData const & commonAbscissa );
static FXString localizedTitleForAnalysisType( VoltaPTAnalysisType const type );


FXPlotterGraphData::FXPlotterGraphData()
{
}


FXPlotterGraphData::FXPlotterGraphData(VoltaPTSimulationDataPtr simulationData ) : FXPlotterGraphData()
{
  if ( simulationData.get() != nullptr )
  {
    for( VoltaPTAnalysisData const & analysisData : simulationData->analyses )
    {
      if ( analysisData.entities.size() > 1 )
      {
        FXPlotterAxisData const commonAbscissa = createCommonAbscissa(analysisData);
        createPlots( mPlots, analysisData, commonAbscissa );
      }
    }
  }
}


void FXPlotterGraphData::clear()
{
  mPlots.clear();
}


std::vector<FXPlotterPlot> const & FXPlotterGraphData::plots() const
{
  return mPlots;
}


FXPlotterAxisData createCommonAbscissa( VoltaPTAnalysisData const & analysisData )
{
  if ( analysisData.entities.empty() )
  {
    return FXPlotterAxisData( VoltaPTEntityDataPtr() );
  }

  // The first entity is always put on the abscissa of the plot.
  FXPlotterScaleType const scaleType = (analysisData.type == VoltaPTAnalysisType::AC) ? FXPlotterScaleType::Log10 : FXPlotterScaleType::Linear;
  FXPlotterValueType const valueType = (analysisData.type == VoltaPTAnalysisType::AC) ? FXPlotterValueType::Magnitude : FXPlotterValueType::Real;
  FXPlotterAxisData commonAbscissa( analysisData.entities.at(0), scaleType, valueType );
  return commonAbscissa;
}


FXString localizedTitleForAnalysisType( VoltaPTAnalysisType const type )
{
  FXString result;
  switch (type)
  {
    case VoltaPTAnalysisType::AC:        result = "AnalysisTypeDescription_AC";        break;
    case VoltaPTAnalysisType::DC:        result = "AnalysisTypeDescription_DC";        break;
    case VoltaPTAnalysisType::DC_TRANS:  result = "AnalysisTypeDescription_DC_TRANS";  break;
    case VoltaPTAnalysisType::Transient: result = "AnalysisTypeDescription_Transient"; break;
    default:                             result = "AnalysisTypeDescription_Unknown";   break;
  }
  CFBundleRef plotterBundle = CFBundleGetBundleWithIdentifier(CFSTR("fish.robo.volta.Plotter"));
  if ( plotterBundle != NULL )
  {
    CFStringRef localizedTitle = CFBundleCopyLocalizedString(plotterBundle, result.cfString(), result.cfString(), CFSTR("Plotter"));
    result = localizedTitle;
    CFRelease(localizedTitle);
  }
  return result;
}


void createPlots( std::vector<FXPlotterPlot> & plots, VoltaPTAnalysisData const & analysisData, FXPlotterAxisData const & commonAbscissa )
{
  if ( analysisData.entities.size() > 1 )
  {
    for ( int entityIndex = 1; entityIndex < analysisData.entities.size(); entityIndex++ )
    {
      VoltaPTEntityDataPtr currentEntity = analysisData.entities.at(entityIndex);
      if ( currentEntity->samples.size() == commonAbscissa.getData().size() )
      {
        FXString const analysisTitle = (analysisData.type == VoltaPTAnalysisType::Unknown) ? analysisData.title : localizedTitleForAnalysisType(analysisData.type);
        FXString plotTitle = analysisTitle + ": " + currentEntity->title;
        FXPlotterAxisData ordinate(currentEntity);
        plots.push_back( FXPlotterPlot(plotTitle, commonAbscissa, ordinate) );
      }
      else
      {
        DebugLog(@"Plotter: The number of samples for the two simulation entities do not match.");
      }
    }
  }
}

