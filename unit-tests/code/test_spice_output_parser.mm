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
#import "FXSpiceOutputParser.h"
#include <iostream>

@interface test_spice_output_parser : XCTestCase
@end


@implementation test_spice_output_parser


- (NSString*) contentsOfResourceFile:(NSString*)fileName
{
  NSString* result = nil;
  NSError* err = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  NSString* filePath = [bundle pathForResource:fileName ofType:@"txt"];
  if ( filePath != nil )
  {
    NSString* spiceOutput = [NSString stringWithContentsOfFile:filePath encoding:NSASCIIStringEncoding error:&err];
    if( (spiceOutput != nil) && (err == nil) )
    {
      result = spiceOutput;
    }
    else
    {
      DebugLog(@"Error while loading contents of file \"%@\": %@", fileName, [err localizedDescription]);
    }
  }
  return result;
}


- (void) test_basic_parsing
{
  FXString basicOutput =
  "   Circuit:  Basic Output\n"
  "   Basic Output Analysis 1\n"
  "   AC Analysis  Wed Aug 31 00:05:40  2011\n"
  "--------------------------------------------------------------------------------\n"
  "Index   frequency       v(4)                   \n"
  "--------------------------------------------------------------------------------\n"
  "0\t1.00e+01\t4.99e+03,\t-4.99323e+03\t\n"
  "1\t1.25e+01\t3.86e+03,\t-4.86374e+03\t\n"
  "2\t1.50e+01\t3.577e+03,\t-4.73e+03\t\n"
  "3\t1.75e+01\t3.233e+03,\t-4.64e+03\t\n"
  "\n"
  "Index   frequency       v(4)                   \n"
  "--------------------------------------------------------------------------------\n"
  "4\t2.01e+01\t2.92e+03,\t-4.71e+03\t\n"
  "5\t2.262e+01\t2.71e+03,\t-4.58e+03\t\n";

  VoltaPTSimulationDataPtr simData = FXSpiceOutputParser::parse(basicOutput);
  FXUTAssert( simData->title == "Basic Output" );
  FXUTAssertEqual( simData->analyses.size(), (size_t)1 );
  FXUTAssert( simData->analyses.front().entities.front()->title == "frequency" );
  FXUTAssert( simData->analyses.front().entities.back()->title == "v(4)" );
  FXUTAssertEqual( simData->analyses.front().entities.front()->samples.size(), (size_t)6 );
  FXUTAssertEqual( simData->analyses.front().entities.front()->samples.at(0), FXComplexNumber(10) );
  FXUTAssertEqual( simData->analyses.front().entities.back()->samples.at(2), FXComplexNumber(3577,-4730) );
}


- (void) test_parsing_sample_1
{
  NSString* fileContents = [self contentsOfResourceFile:@"ngspice_output_1"];
  FXUTAssert( fileContents != nil );
  VoltaPTSimulationDataPtr simData = FXSpiceOutputParser::parse((__bridge CFStringRef)fileContents);
  FXUTAssertEqual( simData->analyses.size(), (size_t)2 );
  FXUTAssert( simData->title == "2011-08-31 00:05:36 +0300" );

  VoltaPTAnalysisData const & analysisData1 = simData->analyses.front();
  NSLog(@"%@", analysisData1.title.cfString());
  FXUTAssert( analysisData1.title == "Transient Analysis  Wed Aug 31 00:05:40  2011" );
  FXUTAssertEqual( analysisData1.type, VoltaPTAnalysisType::Transient );
  FXUTAssertEqual( analysisData1.entities.size() , (size_t)2 );
  FXUTAssert( analysisData1.entities.front()->title == "time" );
  FXUTAssert( analysisData1.entities.back()->title == "v(4)" );
  FXUTAssertEqual( analysisData1.entities.front()->samples.size(), (size_t)114 );
  FXUTAssertEqual( analysisData1.entities.back()->samples.size(), (size_t)114 );

  VoltaPTAnalysisData const & analysisData2 = simData->analyses.back();
  FXUTAssert( analysisData2.title == "AC Analysis  Wed Aug 31 00:05:40  2011" );
  FXUTAssertEqual( analysisData2.type, VoltaPTAnalysisType::AC );
  FXUTAssert( analysisData2.entities.size() == 2 );
  FXUTAssert( analysisData2.entities.front()->title == "frequency" );
  FXUTAssert( analysisData2.entities.back()->title == "v(4)" );
  FXUTAssertEqual( analysisData2.entities.front()->samples.size(), static_cast<size_t>(31) );
  FXUTAssertEqual( analysisData2.entities.back()->samples.size(), static_cast<size_t>(31) );
}


- (void) test_parsing_sample_2
{
  NSString* fileContents = [self contentsOfResourceFile:@"ngspice_output_2"];
  FXUTAssert( fileContents != nil );
  VoltaPTSimulationDataPtr simData = FXSpiceOutputParser::parse((__bridge CFStringRef)fileContents);
  FXUTAssert(simData->title == "2010-05-05 08:15:04 +0200");
  FXUTAssertEqual(simData->analyses.size(), (size_t)2);
  VoltaPTAnalysisData const & analysis = simData->analyses.at(0);
  FXUTAssert(analysis.title == "Transient Analysis  Tue Oct 19 22:44:55  2010");
  FXUTAssert(analysis.type == VoltaPTAnalysisType::Transient);
  FXUTAssertEqual(analysis.entities.size(), (size_t)3);
  FXUTAssert(analysis.entities.at(0)->title == "time");
  FXUTAssert(analysis.entities.at(1)->title == "v(2)");
  FXUTAssert(analysis.entities.at(2)->title == "v(4)");
  FXUTAssertEqual(analysis.entities.at(0)->samples.size(), (size_t)60 );
  FXUTAssert(analysis.entities.at(1)->samples.at(0) == FXComplexNumber(6.706205e-01,0));
  FXUTAssert(analysis.entities.at(2)->samples.at(1) == FXComplexNumber(5.654866e-04,0));
  FXUTAssert(analysis.entities.at(1)->samples.at(59) == FXComplexNumber(-2.77673e-01,0));
  FXUTAssert(analysis.entities.at(2)->samples.at(59) == FXComplexNumber(-9.51057e-01,0));

  VoltaPTAnalysisData const & analysis2 = simData->analyses.at(1);
  FXUTAssert(analysis2.title == "DC transfer characteristic  Fri Dec 30 11:12:01  2011");
  FXUTAssert(analysis2.type == VoltaPTAnalysisType::DC_TRANS);
  FXUTAssertEqual(analysis2.entities.size(), (size_t)2);
  FXUTAssert(analysis2.entities.at(0)->title == "v-sweep");
  FXUTAssert(analysis2.entities.at(1)->title == "v(out)");
  FXUTAssertEqual(analysis2.entities.at(0)->samples.size(), (size_t)51 );
  FXUTAssert(analysis2.entities.at(0)->samples.at(12) == FXComplexNumber(1.2,0));
  FXUTAssert(analysis2.entities.at(1)->samples.at(26) == FXComplexNumber(2.407143,0));
  FXUTAssert(analysis2.entities.at(0)->samples.at(39) == FXComplexNumber(3.9,0));
  FXUTAssert(analysis2.entities.at(1)->samples.at(48) == FXComplexNumber(1.507361,0));
}


@end
