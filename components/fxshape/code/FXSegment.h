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

#import "FXSegmentType.h"
#import "FXVector.h"

#pragma mark - FXSegment -


//! Base class for all 2D vector graphics path segments.
//! All segments use the current point to start drawing from.
//! Coordinates can be relative to the current point or absolute within the coordinate system. 
@interface FXSegment : NSObject <NSCopying>

@property (readonly) BOOL isRelative;
@property (readonly) FXSegmentType type;

- (id) initWithType:(FXSegmentType)type isRelative:(BOOL)relative;

@end


#pragma mark - FXJumpSegment -


//! Segment which jumps to the given point without drawing anything.
//! Corresponds to SVG's "M" (or "m") path data command.
//! Corresponds to Cairo's move_to and rel_move_to commands.
@interface FXJumpSegment : FXSegment <NSCopying>

@property (readonly) FXVector destination;

- (id) initWithDestination:(FXVector const&)destination relative:(BOOL)relative;

@end


#pragma mark - FXLineSegment -


//! Segment which draws a line from the current point to a given point.
//! Corresponds to Cairo's line_to and rel_line_to commands.
@interface FXLineSegment : FXSegment <NSCopying>

@property (readonly) FXVector destination;

- (id) initWithDestination:(FXVector const&)destination relative:(BOOL)relative;
@end


#pragma mark - FXVerticalSegment -


@interface FXVerticalLineSegment : FXSegment <NSCopying>

@property (readonly) CGFloat distance;

- (id) initWithDistance:(CGFloat)distance relative:(BOOL)relative;

@end


#pragma mark - FXHorizontalLineSegment -


@interface FXHorizontalLineSegment : FXSegment <NSCopying>

@property (readonly) CGFloat distance;

- (id) initWithDistance:(CGFloat)distance relative:(BOOL)relative;

@end


#pragma mark - FXArcSegment -


/// An elliptical arc segment in SVG style.
/// The end point of the arc is one of the parameters. This is unusual for
/// 2D graphics libraries and necessitates conversion before the drawing
/// routines are called.
@interface FXArcSegment : FXSegment <NSCopying>

@property (readonly) FXVector endPoint;
@property (readonly) CGFloat         radiusX;
@property (readonly) CGFloat         radiusY;
@property (readonly) CGFloat         rotation;
@property (readonly) BOOL            largeArc;
@property (readonly) BOOL            sweepPositive;

/// @short Draws elliptical arc from current position to given end position
/// @param radiusX maximum extent of the ellipsis (from the center point) along the x axis
/// @param radiusY maximum extent of the ellipsis (from the center point) along the y axis
/// @param rotation angle (in radian) by which the arc should be rotated around the current point
/// @param largeArc indicates whether to draw the larger one of the two possible arc sizes
/// @param positiveSweep indicates whether the arc sweeps in the counterclockwise direction
/// @param relative whether the end position is relative or absolute to the current position
- (id) initWithRadiusX:(CGFloat)radiusX
               radiusY:(CGFloat)radiusY
              rotation:(CGFloat)rotation
              largeArc:(BOOL)largeArc
         positiveSweep:(BOOL)positiveSweep
              endPoint:(FXVector const &)endPoint
              relative:(BOOL)relative;
@end


#pragma mark - FXCurveSegment -


// Cubic Bezier curve.
// Corresponds to SVG's "C" (or "c") path data commands.
// Corresponds to Cairo's curve_to() command.
@interface FXCurveSegment : FXSegment <NSCopying>

@property (readonly) FXVector controlPoint1;
@property (readonly) FXVector controlPoint2;
@property (readonly) FXVector endPoint;

- (id) initWithControlPoint1:(FXVector const &)point1
               controlPoint2:(FXVector const &)point2
                    endPoint:(FXVector const &)endPoint
                    relative:(BOOL)relative;	
@end


// SVG's elliptical arc segments can either be approximated by cubic bezier curves
// or they can be converted to Cairo arcs. Since the conversion requires knowledge
// about the start point (= current point while drawing) this segmented is intended
// to be created while drawing. The source elliptical arc segment can then be replaced
// by the created Cairo arc segment.
// To obtain the desired elliptical arc, while drawing using the Cairo arc() command,
// an additional scaling transformation and a subsequent rotation transformation must
// be applied.
//struct CairoArcSegment : public FXSegment
//{
//	CairoArcSegment(
//		FXArcSegment const & ellipticalArc,
//		FXVector const& currentPoint);
//
//	FXVector center;		//!< Center point of the arc in local coordinates
//	float radius;		//!< Radius of circular arc (in local coordinates)
//	float sweepAngle;	//!< Differential angle which the arc sweeps from the start point.
//	                    //!< The start angle is always PI 
//	
//	// parameters to convert the arc into a general elliptical arc
//	float scale_y;		//!< y-axis scale factor to convert the circular arc into an elliptical arc
//	float rotation;		//!< final rotation applied to the scaled circular arc (= elliptical arc).
//	                    //!< The center of the rotation is the current point.
//};
//
// An arc segment suitable for use with Qt's QPainterPath objects.
// This type of arc segment can be constructed from SVG arc segments
// where the rotation attribute will be ignored.
//struct QtArcSegment : public FXSegment
//{
//	QtArcSegment(
//		FXArcSegment const & ellipticalArc,
//		FXVector const& currentPoint);
//	
//	FXVector center;
//	float radius_x;		// horizontal radius
//	float radius_y;		// vertical radius
//	float startAngle;	// angle where the arc starts
//	float sweepAngle;	// relative angle by which the arc sweeps from the start position
//};
//

