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

#include "FXShapeRenderDataPool.h"

#import <QuartzCore/QuartzCore.h>
#import "FXPath.h"
#import "FXVector.h"
#import "FXSegment.h"
#import "FXCircle.h"

static FXShapeRenderData createRenderDataForShape( id<FXShape> shape );
static void createRenderDataForCirclesOfShape( id<FXShape> shape, FXShapeRenderData & renderData );
static void createRenderDataForPathsOfShape( id<FXShape> shape, FXShapeRenderData & renderData );
static void destroyRenderData( FXShapeRenderData & renderData );
static void pathCommandForJumpSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition );
static void pathCommandForLineSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition );
static void pathCommandForVerticalLineSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition );
static void pathCommandForHorizontalLineSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition );
static void pathCommandForArcSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition );
static void pathCommandForCurveSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition );


FXShapeRenderDataPool::~FXShapeRenderDataPool()
{
  for ( auto acceleratorMapItem : mAcceleratorMap )
  {
    destroyRenderData( acceleratorMapItem.second );
  }
  mAcceleratorMap.clear();
}


FXShapeRenderData& FXShapeRenderDataPool::getRenderDataForShape( id<FXShape> shape )
{
  static FXShapeRenderData sEmptyData;
  auto it = mAcceleratorMap.find(shape);
  if ( it == mAcceleratorMap.end() )
  {
    mAcceleratorMap[shape] = createRenderDataForShape(shape);
    return mAcceleratorMap[shape];
  }
  else
  {
    FXShapeRenderData & result = it->second;
    if ( result.pathArray.size() != ([[shape paths] count] + [[shape circles] count]) )
    {
      DebugLog(@"Destroying cached render data for shape %qx", (unsigned long long)shape);
      destroyRenderData( result );
      FXShapeRenderData newRenderData = createRenderDataForShape(shape);
      mAcceleratorMap[shape] = newRenderData;
      result = mAcceleratorMap[shape];
    }
    return result;
  }
  return sEmptyData;
}


FXShapeRenderData createRenderDataForShape( id<FXShape> shape )
{
  FXShapeRenderData result;
  createRenderDataForPathsOfShape( shape, result );
  createRenderDataForCirclesOfShape( shape, result );
  return result;
}


void createRenderDataForPathsOfShape( id<FXShape> shape, FXShapeRenderData & renderData )
{
  for ( FXPath* path in [shape paths] )
  {
    CGMutablePathRef newCGPath = CGPathCreateMutable();
    FXVector lastPosition;

    for ( FXSegment* segment in [path segments] )
    {
      switch (segment.type)
      {
        case FXSegmentType_Jump:           pathCommandForJumpSegment(segment, newCGPath, lastPosition);           break;
        case FXSegmentType_Line:           pathCommandForLineSegment(segment, newCGPath, lastPosition);           break;
        case FXSegmentType_VerticalLine:   pathCommandForVerticalLineSegment(segment, newCGPath, lastPosition);   break;
        case FXSegmentType_HorizontalLine: pathCommandForHorizontalLineSegment(segment, newCGPath, lastPosition); break;
        case FXSegmentType_Arc:            pathCommandForArcSegment( segment, newCGPath, lastPosition );          break;
        case FXSegmentType_Curve:          pathCommandForCurveSegment( segment, newCGPath, lastPosition );        break;
        default:
          DebugLog(@"Unknown path segment found in shape data.");
      }
    }
    if ( [path closed] )
    {
      CGPathCloseSubpath( newCGPath );
    }
    FXPathInfo pathInfo;
    pathInfo.path = newCGPath;
    pathInfo.closed = [path closed];
    pathInfo.filled = [path filled];
    renderData.pathArray.push_back( pathInfo );
  }
}


void createRenderDataForCirclesOfShape( id<FXShape> shape, FXShapeRenderData & renderData )
{
  for ( FXCircle* circle in [shape circles] )
  {
    CGMutablePathRef newCircle = CGPathCreateMutable();
    CGPoint const c = [circle center];
    CGFloat const r = [circle radius];
    CGPathAddEllipseInRect( newCircle, NULL, CGRectMake(c.x - r, c.y - r, 2*r, 2*r) );
    FXPathInfo pathInfo;
    pathInfo.path = newCircle;
    pathInfo.filled = [circle filled];
    renderData.pathArray.push_back( pathInfo );
  }
}


void destroyRenderData( FXShapeRenderData & renderData )
{
  for ( FXPathInfo & pathInfo : renderData.pathArray )
  {
    CGPathRelease( pathInfo.path );
    pathInfo.path = NULL;
  }
}


void pathCommandForJumpSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition )
{
  FXVector jumpPoint = [(FX(FXJumpSegment)*)segment destination];
  lastPosition.x = [segment isRelative] ? lastPosition.x + jumpPoint.x : jumpPoint.x;
  lastPosition.y = [segment isRelative] ? lastPosition.y + jumpPoint.y : jumpPoint.y;
  CGPathMoveToPoint( path, NULL, lastPosition.x, lastPosition.y );
}


void pathCommandForLineSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition )
{
  FXVector lineEndPoint = [(FX(FXLineSegment)*)segment destination];
  lastPosition.x = [segment isRelative] ? lastPosition.x + lineEndPoint.x : lineEndPoint.x;
  lastPosition.y = [segment isRelative] ? lastPosition.y + lineEndPoint.y : lineEndPoint.y;
  CGPathAddLineToPoint( path, NULL, lastPosition.x, lastPosition.y );
}


void pathCommandForVerticalLineSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition )
{
  CGFloat verticalDistance = [(FX(FXVerticalLineSegment)*)segment distance];
  lastPosition.y = [segment isRelative] ? lastPosition.y + verticalDistance : verticalDistance;
  CGPathAddLineToPoint( path, NULL, lastPosition.x, lastPosition.y );
}


void pathCommandForHorizontalLineSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition )
{
  float horizontalDistance = [(FX(FXHorizontalLineSegment)*)segment distance];
  lastPosition.x = [segment isRelative] ? lastPosition.x + horizontalDistance : horizontalDistance;
  CGPathAddLineToPoint( path, NULL, lastPosition.x, lastPosition.y );
}


void pathCommandForArcSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition )
{
  // Converting the SVG arc into a Core Graphics arc.
  // Helpful implementation notes at
  // http://www.w3.org/TR/SVG/implnote.html#ArcConversionEndpointToCenter
  // If one of the radii is 0 then this becomes a straight line.

  FXArcSegment* arcSegment = (FXArcSegment*) segment;
  FXVector endPosition = [arcSegment isRelative] ? lastPosition + [arcSegment endPoint] : [arcSegment endPoint];
  // If the distance between the last position and the end position is less than 5 draw a line instead.
  if ( ([arcSegment radiusX] == 0.0f) || ([arcSegment radiusY] == 0.0f) )
  {
    lastPosition = endPosition;
    CGPathAddLineToPoint( path, NULL, lastPosition.x, lastPosition.y );
  }
  else
  {
    // CONVERTING TO CENTER-POINT PARAMETRIZATION
    // STEP 1: Putting the origin in the middle of the final point and the end point,
    // then rotating back into the x-axis so that the current point and the end point
    // are on the x axis in the transformed space.
    FXVector transformedLastPosition = (lastPosition - endPosition) / 2;
    transformedLastPosition.rotate( - [arcSegment rotation] );
    // STEP 2: Computing the transformed center point
    CGFloat x = transformedLastPosition.x;
    CGFloat y = transformedLastPosition.y;
    CGFloat x2 = x * x;
    CGFloat y2 = y * y;
    CGFloat rx = [arcSegment radiusX];
    CGFloat ry = [arcSegment radiusY];
    CGFloat rx2 = rx * rx;
    CGFloat ry2 = ry * ry;
    // Check if the radii are actually large enough to reach the start point as well as the end point
    {
      CGFloat lambda = (x2 / rx2) + (y2 / ry2);
      if ( lambda > 1.0f )
      {
        // Must make the radii larger
        rx2 = lambda * rx2;
        ry2 = lambda * ry2;
        CGFloat lambda_root = sqrtf( lambda );
        rx = lambda_root * rx;
        ry = lambda_root * ry;
      }
    }
    CGFloat factor = sqrtf( (rx2*ry2 - rx2*y2 - ry2*x2) / (rx2*y2 + ry2*x2) );
    if ( arcSegment.largeArc == arcSegment.sweepPositive )
    {
      factor = -factor;
    }
    FXVector transformedCenterPoint( factor * rx * y / ry, (-factor) * ry * x / rx );
    // STEP 3: Transforming the center point back into original space
    FXVector centerPoint = transformedCenterPoint;
    centerPoint.rotate( [arcSegment rotation] );
    centerPoint = centerPoint + ((lastPosition + endPosition) / 2.0f);
    // STEP 4: Calculating the start angle
    CGFloat cx = transformedCenterPoint.x;
    CGFloat cy = transformedCenterPoint.y;
    CGFloat startAngle = FXVector( (x - cx)/rx, (y - cy)/ry ).angle( FXVector(1, 0) );
    if ( y < cy )
    {
      startAngle = -startAngle;
    }
    // STEP 5: Calculating the sweep angle
    CGFloat sweepAngle = FXVector( (x-cx)/rx, (y-cy)/ry ).angle( FXVector( (-x-cx)/rx, (-y-cy)/ry ) );
    if ( [arcSegment sweepPositive] )
    {
      while ( sweepAngle < 0.0f ) sweepAngle += 2*M_PI;
    }
    else
    {
      while ( sweepAngle > 0.0f ) sweepAngle -= 2*M_PI;
    }

    // Note: We can not apply the calculated parameters as is because Core Graphics accepts only one radius
    // in order to draw a circular arc instead of an elliptical arc. Therefore we use the mean value of both
    // radii. So our implementation will only work correctly for circular arcs.
    CGPathAddArc( path, NULL, centerPoint.x, centerPoint.y, (rx + ry) / 2.0f, startAngle, startAngle + sweepAngle, sweepAngle < 0.0f );
    lastPosition = endPosition;
  }
}


void pathCommandForCurveSegment( FXSegment* segment, CGMutablePathRef path, FXVector & lastPosition )
{
  FXCurveSegment* curveSegment = (FXCurveSegment*) segment;
  FXVector cPoint1 = [curveSegment isRelative] ? lastPosition + [curveSegment controlPoint1] : [curveSegment controlPoint1];
  FXVector cPoint2 = [curveSegment isRelative] ? lastPosition + [curveSegment controlPoint2] : [curveSegment controlPoint2];
  lastPosition = [curveSegment isRelative] ? lastPosition + [curveSegment endPoint] : [curveSegment endPoint];
  CGPathAddCurveToPoint( path, NULL, cPoint1.x, cPoint1.y, cPoint2.x, cPoint2.y, lastPosition.x, lastPosition.y );
}
