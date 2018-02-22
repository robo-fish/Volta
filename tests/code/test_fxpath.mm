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

#import <SenTestingKit/SenTestingKit.h>
#import "FXPath.h"
#import "FXShape.h"
#import "FXSegment.h"
#include <limits>


static BOOL equalFloats(float a, float b )
{
  return std::fabs(a - b) <= std::numeric_limits<float>::epsilon();
}


@interface test_fxpath : SenTestCase
@end


@implementation test_fxpath


- (void) testLineParsing
{
  FXPath* testPath = [FXPath pathWithData:@"l 3 5"];
  FXSegment* segment = testPath.segments[0];
  FXUTAssert( [segment type] == FXSegmentType_Line );
  FXUTAssert( [(FXLineSegment*)segment destination].x == 3 );
  FXUTAssert( [(FXLineSegment*)segment destination].y == 5 );
}


- (void) test_moveto_followed_by_coordinate_pairs
{
  // According to the SVG specification, subsequent coordinates must be treated as line-to commands.
  FXPath* testPath = [FXPath pathWithData:@"M 3 4 6 0 11 2"];
  FXUTAssert([[testPath segments] count] == 3);
  FXUTAssert( [(FXSegment*)testPath.segments[0] type] == FXSegmentType_Jump );
  FXUTAssert( [(FXSegment*)testPath.segments[1] type] == FXSegmentType_Line );
  FXUTAssert( [(FXLineSegment*)testPath.segments[1] destination].x == 6 );
  FXUTAssert( [(FXLineSegment*)testPath.segments[1] destination].y == 0 );
  FXUTAssert( [(FXSegment*)testPath.segments[2] type] == FXSegmentType_Line );
  FXUTAssert( [(FXLineSegment*)testPath.segments[2] destination].x == 11 );
  FXUTAssert( [(FXLineSegment*)testPath.segments[2] destination].y == 2 );
}


- (void) testArcParsing
{
  FXPath* testPath = [FXPath pathWithData:@"M 0 -16 v 6 A 8 9 1.45 0 0 0 15 v 6"];
  FXUTAssert( [testPath.segments count] == 4 );
  FXSegment* segment = testPath.segments[2];
  FXUTAssert( [segment type] == FXSegmentType_Arc );
  FXArcSegment* arcSegment = (FXArcSegment*) segment;
  FXUTAssert( ![arcSegment isRelative] );
  FXUTAssert( equalFloats(arcSegment.endPoint.x, 0) );
  FXUTAssert( equalFloats(arcSegment.endPoint.y, 15) );
  FXUTAssert( equalFloats(arcSegment.radiusX, 8) );
  FXUTAssert( equalFloats(arcSegment.radiusY, 9) );
  FXUTAssert( equalFloats(arcSegment.rotation, 1.45) );
  FXUTAssert( !arcSegment.largeArc );
  FXUTAssert( !arcSegment.sweepPositive );
}


- (void) testCurveParsing
{
  FXPath* testPath = [FXPath pathWithData:@"M 0 -16 c 4 6 7 6 10 0"];
  FXUTAssert( [testPath.segments count] == 2 );
  FXSegment* segment = testPath.segments[1];
  FXUTAssert( [segment type] == FXSegmentType_Curve );
  FXCurveSegment* curveSegment = (FXCurveSegment*) segment;
  FXUTAssert( curveSegment.controlPoint1.x == 4 );
  FXUTAssert( curveSegment.controlPoint1.y == 6 );
  FXUTAssert( curveSegment.controlPoint2.x == 7 );
  FXUTAssert( curveSegment.controlPoint2.y == 6 );
  FXUTAssert( curveSegment.endPoint.x == 10 );
  FXUTAssert( curveSegment.endPoint.y == 0 );
}


- (void) testSegmentTypeRecognition
{
  FXPath* path = [FXPath pathWithData:@"m 10 10 v 10 m 20 10 h 20 a 25,25 -30 0,1 50,-25 L 50,-25 C 100,100 250,100 250,200"];
  FXUTAssert( [path.segments count] == 7 );
  FXUTAssert( [(FXSegment*)path.segments[0] type] == FXSegmentType_Jump );
  FXUTAssert( [(FXSegment*)path.segments[1] type] == FXSegmentType_VerticalLine );
  FXUTAssert( [(FXSegment*)path.segments[2] type] == FXSegmentType_Jump );
  FXUTAssert( [(FXSegment*)path.segments[3] type] == FXSegmentType_HorizontalLine );
  FXUTAssert( [(FXSegment*)path.segments[4] type] == FXSegmentType_Arc );
  FXUTAssert( [(FXSegment*)path.segments[5] type] == FXSegmentType_Line );
  FXUTAssert( [(FXSegment*)path.segments[6] type] == FXSegmentType_Curve );
}


- (void) testRecognizingThatPathStartsWithRelativeMove
{
  FXPath* testPath = [FXPath pathWithData:@"m 10 10 L 20 0"];
  FXUTAssert( ![(FXSegment*)[testPath.segments objectAtIndex:0] isRelative] );
}


- (void) testRecognizingPathClosures
{
  FXPath* testPath1 = [FXPath pathWithData:@"M0,20L5,0zv5"];
  FXPath* testPath2 = [FXPath pathWithData:@"M0,40c 0 1 0 3 5 5 z"];
  FXUTAssert( ![testPath1 closed] );
  FXUTAssert( [testPath2 closed] );
}


- (void) testFills
{

}


@end
