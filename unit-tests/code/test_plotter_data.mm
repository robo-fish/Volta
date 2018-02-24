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

#import <XCTest/XCTest.h>
#import "FXPlotterGraphData.h"

@interface test_plotter_data :XCTestCase
{
@private
  VoltaPTSimulationDataPtr mSimulationData;
}
- (void) createSimulationData;
@end


@implementation test_plotter_data


- (void) setUp
{
  if ( mSimulationData.get() == nullptr )
  {
    [self createSimulationData];
  }
}


- (void) test_FXPlotterNumber
{
  FXPlotterNumber n1( 0, 5 );
  FXUTAssertEqual( n1.exponent, 0 );
  FXUTAssertEqual( n1.significand, 5 );
  FXUTAssert( n1.stringRepresentation() == "5" );

  FXPlotterNumber n2( -5, 200 );
  FXUTAssertEqual( n2.exponent, -3 );
  FXUTAssertEqual( n2.significand, 2 );
  FXUTAssert( n2.stringRepresentation() == "2*10^-3" );

  FXPlotterNumber n3( 6, 130 );
  FXUTAssertEqual( n3.exponent, 7 );
  FXUTAssertEqual( n3.significand, 13 );
  FXUTAssert( n3.stringRepresentation() == "13*10^7" );
}


- (void) test_FXPlotterRoundedValueRange
{
  FXPlotterRoundedValueRange rvr1;
  rvr1.step = FXPlotterNumber( 1, 1 );
  rvr1.max = FXPlotterNumber( 2, 12 );
  rvr1.min = FXPlotterNumber( 0, 8 );
  rvr1.equalizeExponents();
  FXUTAssertEqual( rvr1.min.exponent, 0 );
  FXUTAssertEqual( rvr1.min.significand, 8 );
  FXUTAssertEqual( rvr1.max.exponent, 0 );
  FXUTAssertEqual( rvr1.max.significand, 1200 );
  FXUTAssertEqual( rvr1.step.exponent, 0 );
  FXUTAssertEqual( rvr1.step.significand, 10 );
}


- (void) test_FXPlotterGraphData
{
  FXPlotterGraphData graphData(mSimulationData);
  std::vector<FXPlotterPlot> plots = graphData.plots();
  FXUTAssertEqual(plots.size(), (size_t)2);

  FXPlotterPlot const & plot1 = plots.front();
  FXUTAssert( plot1.getAbscissa().getTitle() == "frequency" );
  FXUTAssert( plot1.getOrdinate().getTitle() == "v(1)" );

  FXPlotterPlot const & plot2 = plots.back();
  FXUTAssert( plot2.getAbscissa().getTitle() == "frequency" );
  FXUTAssert( plot2.getOrdinate().getTitle() == "v(2)" );
}


- (void) test_FXPlotterAxisData_getValueRange_1
{
  FXUTAssert( !mSimulationData->analyses.empty() );
  VoltaPTAnalysisData & analysisData = mSimulationData->analyses.at(0);

  {
    FXPlotterAxisData axisData1(analysisData.entities.at(0), FXPlotterScaleType::Linear, FXPlotterValueType::Real);
    FXUTAssertEqual( axisData1.getValueRange().min, 1.0f );
    FXUTAssertEqual( axisData1.getValueRange().max, 10000000.0f );
  }

  {
    FXPlotterAxisData axisData2(analysisData.entities.at(1), FXPlotterScaleType::Linear, FXPlotterValueType::Real);
    FXUTAssertEqual( axisData2.getValueRange().min, 2.3f );
    FXUTAssertEqual( axisData2.getValueRange().max, 5.0f );
    FXPlotterAxisData axisData22(analysisData.entities.at(1), FXPlotterScaleType::Linear, FXPlotterValueType::Imaginary);
    FXUTAssertEqual( axisData22.getValueRange().min, 0.0f );
    FXUTAssertEqual( axisData22.getValueRange().max, 2.1f );
  }

  {
    FXPlotterAxisData axisData3(analysisData.entities.at(2), FXPlotterScaleType::Linear, FXPlotterValueType::Real);
    FXUTAssertEqual( axisData3.getValueRange().min, 0.0f );
    FXUTAssertEqual( axisData3.getValueRange().max, 5.0f );
    FXPlotterAxisData axisData33(analysisData.entities.at(2), FXPlotterScaleType::Linear, FXPlotterValueType::Imaginary);
    FXUTAssertEqual( axisData33.getValueRange().min, 1.7f );
    FXUTAssertEqual( axisData33.getValueRange().max, 5.0f );
  }
}


- (void) test_FXPlotterAxisData_getValueRange_2
{
  VoltaPTEntityDataPtr entityData( new VoltaPTEntityData );
  entityData->samples = {
    FXComplexNumber(2.1),
    FXComplexNumber(2.7),
    FXComplexNumber(3.1),
    FXComplexNumber(3.5),
    FXComplexNumber(3.6),
    FXComplexNumber(3.3),
    FXComplexNumber(2.9),
    FXComplexNumber(2.7)};
  FXPlotterAxisData axisData( entityData, FXPlotterScaleType::Log10, FXPlotterValueType::Real );
  FXPlotterValueRange range = axisData.getValueRange();
  FXUTAssertSimilar(range.min, 2.1f, 1e-5);
  FXUTAssertSimilar(range.max, 3.6f, 1e-5);
}


- (void) test_FXPlotterValueRange_roundedLinearRange_1
{
  FXPlotterValueRange range( 2.1f, 3.6f );
  FXPlotterRoundedValueRange roundedRange = range.roundedLinearRange();
  FXUTAssertEqual( roundedRange.step.exponent, -1 );
  FXUTAssertEqual( roundedRange.step.significand, 2 );
  FXUTAssertEqual( roundedRange.min.exponent, 0 );
  FXUTAssertEqual( roundedRange.min.significand, 2 );
  FXUTAssertEqual( roundedRange.max.exponent, -1 );
  FXUTAssertEqual( roundedRange.max.significand, 36 );
}


- (void) test_FXPlotterValueRange_roundedLinearRange_2
{
  VoltaPTEntityDataPtr entityData( new VoltaPTEntityData );
  entityData->samples = {
    FXComplexNumber(1.13),
    FXComplexNumber(18.5),
    FXComplexNumber(35.0),
    FXComplexNumber(61.52),
    FXComplexNumber(78.2),
    FXComplexNumber(93.0),
    FXComplexNumber(100.13) };

  {
    FXPlotterAxisData axisData(entityData, FXPlotterScaleType::Linear, FXPlotterValueType::Real);
    FXUTAssertEqual( axisData.getValueRange().min, 1.13f );
    FXUTAssertEqual( axisData.getValueRange().max, 100.13f );
    FXPlotterRoundedValueRange roundedRange = axisData.getValueRange().roundedLinearRange();
    FXUTAssertEqual( roundedRange.min.significand, 0 );
    FXUTAssertEqual( roundedRange.max.significand, 11 );
    FXUTAssertEqual( roundedRange.max.exponent, 1 );
  }

  entityData->samples.push_back(FXComplexNumber(110.0));

  {
    FXPlotterAxisData axisData2(entityData, FXPlotterScaleType::Linear, FXPlotterValueType::Real);
    FXPlotterRoundedValueRange roundedRange = axisData2.getValueRange().roundedLinearRange();
    FXUTAssertEqual( roundedRange.max.significand, 11 );
    FXUTAssertEqual( roundedRange.max.exponent, 1);
  }

  entityData->samples.push_back(FXComplexNumber(113.0));

  {
    FXPlotterAxisData axisData3(entityData, FXPlotterScaleType::Linear, FXPlotterValueType::Real);
    FXPlotterRoundedValueRange roundedRange = axisData3.getValueRange().roundedLinearRange();
    FXUTAssertEqual( roundedRange.max.significand, 12 );
    FXUTAssertEqual( roundedRange.max.exponent, 1 );
  }

  entityData->samples.insert(entityData->samples.begin(), -2.50);

  {
    FXPlotterAxisData axisData4(entityData, FXPlotterScaleType::Linear, FXPlotterValueType::Real);
    FXPlotterRoundedValueRange roundedRange = axisData4.getValueRange().roundedLinearRange();
    FXUTAssertEqual( roundedRange.min.significand, -1 );
    FXUTAssertEqual( roundedRange.min.exponent, 1 );
  }
}


- (void) test_FXPlotterValueRange_roundedLinearRange_3
{
  FXPlotterValueRange range( 4.56e-9, 4.56e-9 );
  FXPlotterRoundedValueRange roundedRange = range.roundedLinearRange();
  FXUTAssertEqual( roundedRange.step.exponent, -9 );
  FXUTAssertEqual( roundedRange.step.significand, 1 );
  FXUTAssertEqual( roundedRange.min.exponent, -9 );
  FXUTAssertEqual( roundedRange.min.significand, 4 );
  FXUTAssertEqual( roundedRange.max.exponent, -9 );
  FXUTAssertEqual( roundedRange.max.significand, 5 );
}


- (void) test_FXPlotterValueRange_roundedLogarithmicRange
{
  VoltaPTEntityDataPtr entityData( new VoltaPTEntityData );
  entityData->samples = {
    FXComplexNumber(12.0),
    FXComplexNumber(53.0),
    FXComplexNumber(230.0),
    FXComplexNumber(650.0),
    FXComplexNumber(1800.0),
    FXComplexNumber(5300.0),
    FXComplexNumber(13000.0),
    FXComplexNumber(31000.0) };
  FXPlotterAxisData axisData( entityData, FXPlotterScaleType::Log10, FXPlotterValueType::Real );
  FXUTAssertEqual( axisData.getValueRange().min, 12.0f );
  FXUTAssertEqual( axisData.getValueRange().max, 31000.0f );
  FXPlotterRoundedValueRange roundedRange = axisData.getValueRange().roundedLogarithmicRange();
  FXUTAssertEqual( roundedRange.min.exponent, 1 );
  FXUTAssertEqual( roundedRange.min.significand, 1 );
  FXUTAssertEqual( roundedRange.max.exponent, 5 );
  FXUTAssertEqual( roundedRange.max.significand, 1 );
}


- (void) test_FXPlotterAxisData_getGridLines
{
  VoltaPTEntityDataPtr entityData( new VoltaPTEntityData );
  entityData->samples = {
    FXComplexNumber(2.1),
    FXComplexNumber(2.7),
    FXComplexNumber(3.1),
    FXComplexNumber(3.5),
    FXComplexNumber(3.6),
    FXComplexNumber(3.3),
    FXComplexNumber(2.9),
    FXComplexNumber(2.7) };
  FXPlotterAxisData axisData( entityData, FXPlotterScaleType::Linear, FXPlotterValueType::Real );
  FXPlotterGridlines gridlines = axisData.getGridlines();
  FXUTAssertEqual( gridlines.size(), (size_t)9 );
  FXUTAssertEqual( gridlines.front().value.significand, 2 );
  FXUTAssertEqual( gridlines.front().value.exponent, 0 );
  FXUTAssertEqual( gridlines.back().value.significand, 36 );
  FXUTAssertEqual( gridlines.back().value.exponent, -1 );
}


#pragma mark Private methods


- (void) createSimulationData
{
  VoltaPTEntityDataPtr frequencyData( new VoltaPTEntityData );
  frequencyData->title = "frequency";
  frequencyData->unit = "Hz";
  frequencyData->samples = {
    FXComplexNumber(1),
    FXComplexNumber(10),
    FXComplexNumber(100),
    FXComplexNumber(1000),
    FXComplexNumber(10000),
    FXComplexNumber(100000),
    FXComplexNumber(1000000),
    FXComplexNumber(10000000) };

  VoltaPTEntityDataPtr voltageData( new VoltaPTEntityData );
  voltageData->title = "v(1)";
  voltageData->unit = "V";
  voltageData->samples = {
    FXComplexNumber(5.0, 0.0),
    FXComplexNumber(4.5, 0.2),
    FXComplexNumber(4.2, 0.5),
    FXComplexNumber(4.0, 0.8),
    FXComplexNumber(3.7, 1.0),
    FXComplexNumber(3.2, 1.3),
    FXComplexNumber(2.8, 1.7),
    FXComplexNumber(2.3, 2.1) };

  VoltaPTEntityDataPtr voltageData2( new VoltaPTEntityData );
  voltageData2->title = "v(2)";
  voltageData2->unit = "V";
  voltageData2->samples = {
    FXComplexNumber(0.0, 5.0),
    FXComplexNumber(0.8, 4.5),
    FXComplexNumber(1.3, 4.1),
    FXComplexNumber(1.8, 3.6),
    FXComplexNumber(2.4, 3.0),
    FXComplexNumber(3.0, 2.5),
    FXComplexNumber(4.8, 2.1),
    FXComplexNumber(5.0, 1.7) };

  VoltaPTAnalysisData analysisData;
  analysisData.title = "AC Analysis Test Data";
  analysisData.type = VoltaPTAnalysisType::AC;
  analysisData.entities = { frequencyData, voltageData, voltageData2 };

  mSimulationData = VoltaPTSimulationDataPtr( new VoltaPTSimulationData );
  mSimulationData->title = "Test Simulation Data";
  mSimulationData->analyses.push_back(analysisData);
}


@end
