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

#import "FXAnimatedGearWheelButton.h"
#include <math.h>
#include <stdatomic.h>

static const CGFloat skMaxRotationSpeed = M_PI_4/10.0;
static const NSUInteger skMaxTransitionCount = 24;
static const CGFloat skColor_disabled[] = { 0.45, 0.45, 0.45, 1.0 };
static const CGFloat skColor_stopped_fill[] = { 0.28, 0.28, 0.28, 1.0 };
static const CGFloat skColor_stopped_stroke[] = { 0.4, 0.4, 0.4, 1.0 };
static const CGFloat skColor_running_fill[] = { 0.7, 0.0, 0.0, 1.0 };
static const CGFloat skColor_running_stroke[] = { 0.6, 0.45, 0.45, 1.0 };


@implementation FXAnimatedGearWheelButton
{
@private
  BOOL               mUserStartsClick;   // set to true on mouseDown and checked on mouseUp
  NSUInteger         mAnimationCounter;
  NSUInteger         mTransitionCounter; // Used for gradual transition of colors.
  CGFloat            mRotation;
  atomic_bool        mAnimating;         // indicates that the animation is not running when its value is 0, and that the animation is running when the value is not 0.
  BOOL               mEnabled;
  CGColorSpaceRef    mColorSpace;
  CGFloat const *    mFillColor;
  CGFloat const *    mStrokeColor;
  CGFloat            mRotationSpeed;
  CGFloat            mColor_transitional_fill[4];
  CGFloat            mColor_transitional_stroke[4];
}

- (id) initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    mUserStartsClick = NO;
    mAnimating = 0;
    mRotation = 0.0f;
    mRotationSpeed = skMaxRotationSpeed;
    mTransitionCounter = 0;
    mEnabled = NO;
    mColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  }
  return self;
}


- (void) dealloc
{
  CGColorSpaceRelease(mColorSpace);
  FXDeallocSuper
}


#pragma mark Public


- (void) startAnimation
{
  if (!atomic_fetch_or_explicit(&mAnimating, 1, memory_order_relaxed))
  {
    mTransitionCounter = skMaxTransitionCount;
    mRotationSpeed = skMaxRotationSpeed;
    [NSThread detachNewThreadSelector:@selector(animate) toTarget:self withObject:nil];
  }
}


- (void) stopAnimation
{
  mAnimating = 0;
}


- (BOOL) isAnimating
{
  return (mAnimating != 0);
}


- (BOOL) enabled
{
  return mEnabled;
}


- (void) setEnabled:(BOOL)state
{
  mEnabled = state;
  [self setNeedsDisplay:YES];
}


#pragma mark NSView overrides


- (void)drawRect:(NSRect)visibleRect
{
  static const CGFloat skStep = M_PI_4;
  static const CGFloat skRotationalDifference = 0.0576;

  static CGFloat const skMarginForStrokeWidth = 1.0;
  CGRect const rect = NSInsetRect([self frame], skMarginForStrokeWidth, skMarginForStrokeWidth);

  CGFloat const kDimension = MIN(rect.size.width,rect.size.height);
  CGFloat const kOuterRadius = kDimension * 0.28f;
  CGFloat const kInnerRadius = kDimension * 0.19f;
  CGFloat const kHoleRadius = kDimension * 0.105f;
  CGFloat centerX, centerY;
  CGFloat rotation;
  int i,j;
  
  CGContextRef context = FXGraphicsContext;

  [self updateColors];
  CGContextSetFillColorSpace(context, mColorSpace);
  CGContextSetFillColor(context, mFillColor);
  CGContextSetStrokeColorSpace(context, mColorSpace);
  CGContextSetStrokeColor(context, mStrokeColor);

  // Turning each gear wheel
  for (i = -1; i < 2; i+=2)
  {
    const CGAffineTransform transform = CGAffineTransformIdentity;
    CGMutablePathRef path = CGPathCreateMutable();
    centerX = visibleRect.origin.x + (rect.size.width * 0.5f) + (i * 0.24f * kDimension);
    centerY = visibleRect.origin.y + (rect.size.height * 0.5f) + (i * 0.10f * kDimension);
    for (j = 0; j < (int)(2 * M_PI / skStep); j++)
    {
      rotation = i * mRotation + (i + 1) * skRotationalDifference + j * skStep; // wheels rotate in opposite directions
      CGPathAddArc(path, &transform, centerX, centerY, kInnerRadius, rotation, rotation + skStep * 0.4f, 0);
      // move outwards, creating a wheel projection
      CGPathAddLineToPoint(path, &transform, centerX + kOuterRadius * cos(rotation + skStep * 0.5f), centerY + kOuterRadius * sin(rotation + skStep * 0.5f));
      CGPathAddArc(path, &transform, centerX, centerY, kOuterRadius, rotation + skStep * 0.5f, rotation + skStep * 0.9f, 0);
      // move toward center, finishing the projection
      CGPathAddLineToPoint(path, &transform, centerX + kInnerRadius * cos(rotation + skStep), centerY + kInnerRadius * sin(rotation + skStep));
    }
    // move towards center to give the wheel a thickness but leave a hole at the center
    CGPathMoveToPoint(path, &transform, centerX + kInnerRadius * 0.5f, centerY);
    CGPathAddEllipseInRect(path, &transform, CGRectMake(centerX - kHoleRadius, centerY - kHoleRadius, 2.0f * kHoleRadius, 2.0f * kHoleRadius));
    CGPathCloseSubpath(path);
    CGContextAddPath(context, path);
    CGContextEOFillPath(context);
    CGContextFillPath(context);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGPathRelease(path);
  }
}

- (BOOL) isOpaque
{
  return NO;
}

- (BOOL) canDrawConcurrently
{
  return YES;
}

- (void) mouseDown:(NSEvent*)mouseEvent
{
  mUserStartsClick = mEnabled;
  [super mouseDown:mouseEvent];
}

- (void) mouseUp:(NSEvent*)mouseEvent
{
  if (mUserStartsClick && mEnabled)
  {
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.target performSelector:self.action withObject:self];
  #pragma clang diagnostic pop
  }
  mUserStartsClick = NO;
}

- (BOOL) acceptsFirstMouse:(NSEvent*)mouseEvent
{
  return YES; // click-through
}


#pragma mark NSResponder overrides


static NSString* FXResume_GearWheelButtonRotation = @"FXResume_GearWheelButtonRotation";


- (void) encodeRestorableStateWithCoder:(NSCoder*)coder
{
  [super encodeRestorableStateWithCoder:coder];
  [coder encodeFloat:mRotation forKey:FXResume_GearWheelButtonRotation];
}


- (void) restoreStateWithCoder:(NSCoder*)coder
{
  [super restoreStateWithCoder:coder];
  mRotation = [coder decodeFloatForKey:FXResume_GearWheelButtonRotation];
  [self setNeedsDisplay:YES];
}


#pragma mark Private


- (void) animate
{
  NSAssert( ![NSThread isMainThread], @"The animation must not run in the main thread" );
  @autoreleasepool
  {
    while ( (mAnimating != 0) || (mTransitionCounter > 0) )
    {
      if ( mAnimating == 0 )
      {
        mRotationSpeed = mRotationSpeed/1.1;
      }
      mRotation += mRotationSpeed;
      if (mRotation > 2*M_PI)
      {
        mRotation -= 2*M_PI;
      }

      if ( mAnimating == 0 )
      {
        mTransitionCounter -= 1;
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsDisplay:YES];
      });
      [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
  }
}


static void interpolateColor( CGFloat factor, CGFloat * outputColor, CGFloat const * inputColor1, CGFloat const * inputColor2 )
{
  if ( factor < 0.0 )
    factor = 0.0;
  if ( factor > 1.0 )
    factor = 1.0;
  outputColor[0] = inputColor1[0] + (factor * (inputColor2[0] - inputColor1[0]));
  outputColor[1] = inputColor1[1] + (factor * (inputColor2[1] - inputColor1[1]));
  outputColor[2] = inputColor1[2] + (factor * (inputColor2[2] - inputColor1[2]));
  outputColor[3] = inputColor1[3] + (factor * (inputColor2[3] - inputColor1[3]));
}


- (void) updateColors
{
  if ( (mTransitionCounter > 0) && (mTransitionCounter < skMaxTransitionCount) )
  {
    CGFloat const factor = ((CGFloat)mTransitionCounter) / skMaxTransitionCount;
    interpolateColor(factor, mColor_transitional_fill, skColor_stopped_fill, skColor_running_fill);
    interpolateColor(factor, mColor_transitional_stroke, skColor_stopped_stroke, skColor_running_stroke);
    mFillColor = mColor_transitional_fill;
    mStrokeColor = mColor_transitional_stroke;
  }
  else
  {
    mFillColor = ( mEnabled ? ( mAnimating ? skColor_running_fill : skColor_stopped_fill ) : skColor_disabled );
    mStrokeColor = ( mEnabled ? ( mAnimating ? skColor_running_stroke : skColor_stopped_stroke ) : skColor_disabled );
  }
}


@end
