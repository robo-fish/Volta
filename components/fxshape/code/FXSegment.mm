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

#import "FXSegment.h"

#include <numeric>
#include <cmath>
#include <stdexcept>

#pragma mark - FXSegment -

@interface FXSegment ()
@property (readwrite) BOOL isRelative;
@property (readwrite) FXSegmentType type;
@end

@implementation FXSegment
{
@private
  BOOL           mIsRelative;
  FXSegmentType  mType;
}

@synthesize isRelative = mIsRelative;
@synthesize type = mType;

- (id) init
{
  return [self initWithType:FXSegmentType_Unknown isRelative:NO];
}

- (id) initWithType:(FXSegmentType)type isRelative:(BOOL)relative
{
  self = [super init];
  mType = type;
  mIsRelative = relative;
  return self;
}

- (id) copyWithZone:(NSZone*)zone
{
  FX(FXSegment)* newCopy = [[[self class] allocWithZone:zone] init];
  [newCopy setType:mType];
  [newCopy setIsRelative:mIsRelative];
  return newCopy;
}

@end


////////////////////////////////////////////////////////////////////////////////
#pragma mark - FXJumpSegment -


@interface FXJumpSegment ()
@property (readwrite) FXVector destination;
@end

@implementation FXJumpSegment
{
@private
  FXVector mDestination;
}

@synthesize destination = mDestination;

- (id) initWithDestination:(FXVector const&)destination relative:(BOOL)relative
{
  self = [super initWithType:FXSegmentType_Jump isRelative:relative];
  mDestination = destination;
  return self;
}

- (id) copyWithZone:(NSZone*)zone
{
  FX(FXJumpSegment)* newCopy = [super copyWithZone:zone];
  [newCopy setDestination:mDestination];
  return newCopy;
}

@end


////////////////////////////////////////////////////////////////////////////////
#pragma mark - FXLineSegment -


@interface FXLineSegment ()
@property (readwrite) FXVector destination;
@end

@implementation FXLineSegment
{
@private
  FXVector mDestination;
}

@synthesize destination = mDestination;

- (id) initWithDestination:(FXVector const&)destination relative:(BOOL)relative
{
  self = [super initWithType:FXSegmentType_Line isRelative:relative];
  mDestination = destination;
  return self;
}

- (id) copyWithZone:(NSZone*)zone
{
  FX(FXLineSegment)* newCopy = [super copyWithZone:zone];
  [newCopy setDestination:mDestination];
  return newCopy;
}

@end


////////////////////////////////////////////////////////////////////////////////
#pragma mark - FXVerticalLineSegment -

@interface FXVerticalLineSegment ()
@property (readwrite) CGFloat distance;
@end

@implementation FXVerticalLineSegment
{
@private
  CGFloat mDistance;
}

@synthesize distance = mDistance;

- (id) initWithDistance:(CGFloat)distance relative:(BOOL)relative
{
  self = [super initWithType:FXSegmentType_VerticalLine isRelative:relative];
  mDistance = distance;
  return self;
}

- (id) copyWithZone:(NSZone*)zone
{
  FX(FXVerticalLineSegment)* newCopy = [super copyWithZone:zone];
  [newCopy setDistance:mDistance];
  return newCopy;
}

@end


////////////////////////////////////////////////////////////////////////////////
#pragma mark - FXHorizontalLineSegment -


@interface FXHorizontalLineSegment ()
@property (readwrite) CGFloat distance;
@end

@implementation FXHorizontalLineSegment
{
@private
  CGFloat mDistance;
}

@synthesize distance = mDistance;

- (id) initWithDistance:(CGFloat)distance relative:(BOOL)relative
{
  self = [super initWithType:FXSegmentType_HorizontalLine isRelative:relative];
  mDistance = distance;
  return self;
}

- (id) copyWithZone:(NSZone*)zone
{
  FX(FXHorizontalLineSegment)* newCopy = [super copyWithZone:zone];
  [newCopy setDistance:mDistance];
  return newCopy;
}

@end


////////////////////////////////////////////////////////////////////////////////
#pragma mark - FXArcSegment -


@interface FXArcSegment ()
@property (readwrite) FXVector endPoint;
@property (readwrite) CGFloat         radiusX;
@property (readwrite) CGFloat         radiusY;
@property (readwrite) CGFloat         rotation;
@property (readwrite) BOOL            largeArc;
@property (readwrite) BOOL            sweepPositive;
@end

@implementation FXArcSegment
{
@private
  FXVector  mEndPoint;
  CGFloat          mRadiusX;
  CGFloat          mRadiusY;
  CGFloat          mRotation;
  BOOL             mLargeArc;
  BOOL             mSweepPositive;
}

@synthesize endPoint = mEndPoint;
@synthesize radiusX = mRadiusX;
@synthesize radiusY = mRadiusY;
@synthesize rotation = mRotation;
@synthesize largeArc = mLargeArc;
@synthesize sweepPositive = mSweepPositive;

- (id) initWithRadiusX:(CGFloat)radiusX
               radiusY:(CGFloat)radiusY
              rotation:(CGFloat)rotation
              largeArc:(BOOL)largeArc
         positiveSweep:(BOOL)positiveSweep
              endPoint:(FXVector const &)endPoint
              relative:(BOOL)relative
{
  NSAssert( radiusX > 0.0f, @"radius must be positive" );
  NSAssert( radiusY > 0.0f, @"radius must be positive" );
  self = [super initWithType:FXSegmentType_Arc isRelative:relative];
  mRadiusX = fabs(radiusX);
  mRadiusY = fabs(radiusY);
  mRotation = rotation;
  mLargeArc = largeArc;
  mSweepPositive = positiveSweep;
  mEndPoint = endPoint;
  return self;
}

- (id) copyWithZone:(NSZone*)zone
{
  FX(FXArcSegment)* newCopy = [super copyWithZone:zone];
  [newCopy setEndPoint:mEndPoint];
  [newCopy setRadiusX:mRadiusX];
  [newCopy setRadiusY:mRadiusY];
  [newCopy setRotation:mRotation];
  [newCopy setLargeArc:mLargeArc];
  [newCopy setSweepPositive:mSweepPositive];
  return newCopy;
}

- (NSString*) description
{
  return [NSString stringWithFormat:@"Arc to point (%f,%f) with radiusX %f, radiusY %f, rotation %f", mEndPoint.x, mEndPoint.y, mRadiusX, mRadiusY, mRotation];
}

@end


////////////////////////////////////////////////////////////////////////////////
#pragma mark - FXCurveSegment -


@interface FXCurveSegment ()
@property (readwrite) FXVector controlPoint1;
@property (readwrite) FXVector controlPoint2;
@property (readwrite) FXVector endPoint;
@end

@implementation FXCurveSegment
{
@private
  FXVector mControlPoint1;
  FXVector mControlPoint2;
  FXVector mEndPoint;
}

@synthesize controlPoint1 = mControlPoint1;
@synthesize controlPoint2 = mControlPoint2;
@synthesize endPoint = mEndPoint;

- (id) initWithControlPoint1:(FXVector const &)point1
               controlPoint2:(FXVector const &)point2
                    endPoint:(FXVector const &)endPoint
                    relative:(BOOL)relative
{
  self = [super initWithType:FXSegmentType_Curve isRelative:relative];
  mControlPoint1 = point1;
  mControlPoint2 = point2;
  mEndPoint = endPoint;
  return self;
}

- (id) copyWithZone:(NSZone*)zone
{
  FX(FXCurveSegment)* newCopy = [super copyWithZone:zone];
  [newCopy setEndPoint:mEndPoint];
  [newCopy setControlPoint1:mControlPoint1];
  [newCopy setControlPoint2:mControlPoint2];
  return newCopy;
}

@end



////////////////////////////////////////////////////////////////////////////////
//#pragma mark -

//CairoArcSegment::CairoArcSegment(
//	FXArcSegment const & ellipticalArc,
//	FXVector const& currentPoint
//	) : FXSegment(FXSegment::CAIRO_ARC_SEGMENT, false)
//{
//	// First, rotate the arc back to the x-axis
//	FXVector endPointT = ellipticalArc.endPoint;
//	endPointT.rotate( -ellipticalArc.rotation, currentPoint );
//	// Apply scaling to make ry equal to rx
//	endPointT.scale( 1.0f, ellipticalArc.radius_x / ellipticalArc.radius_y );
//	// calculate the angle for the transformed end point
//	float endPointAngle = std::atan( (endPointT.y - currentPoint.y) / ellipticalArc.radius_x );
//	
//	// Now we know all the parameters for a Cairo arc
//	sweepAngle = M_PI - endPointAngle;
//	scale_y = ellipticalArc.radius_y / ellipticalArc.radius_x;
//	radius = ellipticalArc.radius_x;
//	rotation = ellipticalArc.rotation;
//	center = currentPoint + FXVector( ellipticalArc.radius_x, 0.0f );	
//}
	

//namespace // anonymous
//{
//
//// Return the directional angle of the first point relative to the second point
//float relativeAngle(FXVector const& first, FXVector const& second)
//{
//	float angle = 0.0f;
//	if ( second.y > first.y )
//	{
//		if ( second.x > first.x )
//		{
//			// first point in third quadrant relative to second point
//			angle = M_PI + std::atan( (second.y - first.y)/(second.x - first.x) );
//		}
//		else if ( second.x < first.x )
//		{
//			// first point in fourth quadrant relative to second point
//			angle = 2.0f * M_PI - std::atan( (second.y - first.y)/(first.x - second.x) );
//		}
//		else // second.x == first.x
//		{
//			angle = 1.5f * M_PI;
//		}
//	}
//	else if ( second.y < first.y )
//	{
//		if ( second.x > first.x )
//		{
//			// first point is in second quadrant relative to second point
//			angle = M_PI - std::atan( (first.y - second.y)/(second.x - first.x) );
//		}
//		else if ( second.x < first.x )
//		{
//			// first point is in first quadrant relative to second point
//			angle = std::atan( (first.y - second.y)/(first.x - second.x) );
//		}
//		else // second.x == first.x
//		{
//			angle = M_PI_2;
//		}
//	}
//	else // second.y == first.y
//	{
//		if ( second.x > first.x )
//		{
//			angle = M_PI;
//		}
//		else
//		{
//			angle = 0.0f;
//		}
//	}
//	return angle;
//}
//
//}
//
//
//QtArcSegment::QtArcSegment(
//	FXArcSegment const & ellipticalArc,
//	FXVector const& currentPoint
//	) : FXSegment( FXSegment::QT_ARC_SEGMENT, false )
//{
//	// For Qt arcs the rotation of the elliptical arc is assumed to be zero
//	// and the current point is assumed to be at the start position.
//	radius_x = ellipticalArc.radius_x;
//	radius_y = ellipticalArc.radius_y;
//	
//	// There are two possible center points for the ellipse, which can
//	// be calculated from the start point, the end point and the two radii.
//	// The calculation involves solving a quadratic equation.
//	float rx2 = radius_x * radius_x;
//	float ry2 = radius_y * radius_y;
//	float dx = currentPoint.x - ellipticalArc.endPoint.x;
//	float dy = currentPoint.y - ellipticalArc.endPoint.y;
//	float d2x = (currentPoint.x * currentPoint.x) -
//		(ellipticalArc.endPoint.x * ellipticalArc.endPoint.x); 
//	float d2y = (currentPoint.y * currentPoint.y) -
//		(ellipticalArc.endPoint.y * ellipticalArc.endPoint.y);
//	// center.x = B - A * center.y
//	float A = rx2 * dy / ry2 / dx;
//	float B = (rx2 * d2y + ry2 * d2x) / 2.0f / ry2 / dx;
//	// E * center.y^2 + F * center.y + G = 0
//	float E = ry2 * A * A + rx2;
//	float F = 2.0f * ( A * ry2 * ( currentPoint.x - B) - (rx2 * currentPoint.y) );
//	float G = (B * B * ry2) + (rx2 * currentPoint.y * currentPoint.y) +
//		(ry2 * currentPoint.x * currentPoint.x) - (rx2 * ry2) - (2.0f * B * ry2 * currentPoint.x);
//	// The discriminant for this equation is
//	float discriminant = F*F - 4.0f * E * G;
//	if ( discriminant <= 0.0f )
//	{
//		throw std::runtime_error( "Not a valid arc" );
//	}
//	float discriminantRoot = std::sqrt( discriminant );
//	// For each of the two solutions we will have different center points,
//	// different start angles and different sweep angles
//	float root1 = (discriminantRoot - F) / 2.0f / E;
//	float root2 = (discriminantRoot + F) / -2.0f / E;
//	FXVector center1( B - A * root1, root1 );
//	FXVector center2( B - A * root2, root2 );
//	
//	float startAngle1 = relativeAngle(currentPoint, center1);
//	float startAngle2 = relativeAngle(currentPoint, center2);
//	float endAngle1 = relativeAngle(ellipticalArc.endPoint, center1);
//	float endAngle2 = relativeAngle(ellipticalArc.endPoint, center2);
//	
//	float positiveSweepAngle1 = startAngle1 - endAngle1;
//	while( positiveSweepAngle1 < 0.0f ) { positiveSweepAngle1 += 2 * M_PI; }
//	float negativeSweepAngle1 = endAngle1 - startAngle1;
//	while( negativeSweepAngle1 < 0.0f ) { negativeSweepAngle1 += 2 * M_PI; }
//	
//	float positiveSweepAngle2 = startAngle2 - endAngle2;
//	while( positiveSweepAngle2 < 0.0f ) { positiveSweepAngle2 += 2 * M_PI; }
//	float negativeSweepAngle2 = endAngle2 - startAngle2;
//	while( negativeSweepAngle2 < 0.0f ) { negativeSweepAngle2 += 2 * M_PI; }
//
//	bool selectFirstCenterPoint = true;
//	if ( ellipticalArc.sweepPositive )
//	{
//		if ( ellipticalArc.largeArc )
//		{
//			selectFirstCenterPoint = (positiveSweepAngle1 > positiveSweepAngle2);
//		}
//		else
//		{
//			selectFirstCenterPoint = (positiveSweepAngle1 < positiveSweepAngle2);
//		}
//	}
//	else
//	{
//		if ( ellipticalArc.largeArc )
//		{
//			selectFirstCenterPoint = (negativeSweepAngle1 > negativeSweepAngle2);
//		}
//		else
//		{
//			selectFirstCenterPoint = (negativeSweepAngle1 < negativeSweepAngle2);			
//		}		
//	}
//	
//	if ( selectFirstCenterPoint )
//	{
//		center = center1;
//		startAngle = startAngle1;
//		sweepAngle = ellipticalArc.sweepPositive ? -positiveSweepAngle1 : negativeSweepAngle1; 
//	}
//	else
//	{
//		center = center2;
//		startAngle = startAngle2;
//		sweepAngle = ellipticalArc.sweepPositive ? -positiveSweepAngle2 : negativeSweepAngle2; 		
//	}
//}


