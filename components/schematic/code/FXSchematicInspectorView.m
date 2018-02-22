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

#import "FXSchematicInspectorView.h"

#define LAYER_BACKED_INSPECTOR (0)

const CGFloat kInspectorViewWidth = 180.0;
const CGFloat kInspectorViewMinHeight = 170.0;
const CGFloat kInspectorViewMaxHeight = 170.0;
const CGFloat kInspectorViewInsetTop = 15.0;
const CGFloat kInspectorViewInsetSide = 5.0;
const CGFloat kInspectorViewInsetBottom = 5.0;


@implementation FX(FXSchematicInspectorView)
{
@private
  NSView* mInspectionView;
  NSPoint mMouseDownLocation;
  NSPoint mFrameOriginOnMouseDown;
  BOOL mViewWasDragged;
  CGImageRef mImage;
  FXSchematicInspectorStickiness mStickiness;
}


- (id) initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    mInspectionView = nil;
    mStickiness = FXStickiness_TopRightCorner;
    [self resetEventHandling];
  #if LAYER_BACKED_INSPECTOR
    [self setWantsLayer:YES];
    [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawOnSetNeedsDisplay];
  #endif
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mInspectionView)
  if ( mImage != NULL )
  {
    CGImageRelease( mImage );
  }
  FXDeallocSuper
}


#pragma mark Public


- (void) setInspectionView:(NSView*)inspectionView
{
  if ( inspectionView != mInspectionView )
  {
    NSAssert( [[self subviews] count] <= 1, @"there can't be more than one subview" );
    [mInspectionView removeFromSuperviewWithoutNeedingDisplay];
    mInspectionView = inspectionView;
    if ( mInspectionView != nil )
    {
      // Resize the subview to make it fit into the receiver
      NSRect const myFrame = [self frame];
      [mInspectionView setFrame:NSMakeRect(kInspectorViewInsetSide, kInspectorViewInsetBottom,
        myFrame.size.width - 2*kInspectorViewInsetSide,
        myFrame.size.height - kInspectorViewInsetTop - kInspectorViewInsetBottom)];
      [mInspectionView setAutoresizingMask:NSViewHeightSizable];
      [self addSubview:mInspectionView];
    }
  }
}

-  (NSView*) inspectionView
{
  return mInspectionView;
}


- (void) hide
{
  NSDictionary* animationDictionary = @{
    NSViewAnimationTargetKey : self,
    NSViewAnimationEffectKey : NSViewAnimationFadeOutEffect
  };
  NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:@[animationDictionary]];
  [animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
  [animation setAnimationCurve:NSAnimationLinear];
  [animation setDuration:0.10];
  [animation setFrameRate:0.0];
  [animation setDelegate:self];
  [animation startAnimation];
}


- (void) show
{
  [self setHidden:NO];
  NSDictionary* animationDictionary = @{
    NSViewAnimationTargetKey : self,
    NSViewAnimationEffectKey : NSViewAnimationFadeInEffect
  };
  NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:@[animationDictionary]];
  [animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
  [animation setAnimationCurve:NSAnimationLinear];
  [animation setDuration:0.10];
  [animation setFrameRate:0.0];
  [animation setDelegate:self];
  [animation startAnimation];
}


- (void) setStickiness:(FXSchematicInspectorStickiness)newStickiness
{
  if ( mStickiness != newStickiness )
  {
    mStickiness = newStickiness;
    [self applyStickiness];
  }
}


#pragma mark NSAnimationDelegate


- (void) animationDidEnd:(NSAnimation*)animation
{
  FXRelease(animation)
  [[self window] invalidateRestorableState];
}


#pragma mark NSResponder overrides


- (void) mouseDown:(NSEvent*)mouseEvent
{
  mMouseDownLocation = [mouseEvent locationInWindow];
  mFrameOriginOnMouseDown = [self frame].origin;
}


- (void) mouseDragged:(NSEvent*)mouseEvent
{
  mViewWasDragged = YES;
  NSPoint draggingLocation = [mouseEvent locationInWindow];
  NSRect frame = [self frame];
  frame.origin.x = mFrameOriginOnMouseDown.x + (draggingLocation.x - mMouseDownLocation.x);
  if ( [[self superview] isFlipped] )
  {
    frame.origin.y = mFrameOriginOnMouseDown.y - (draggingLocation.y - mMouseDownLocation.y);
  }
  else
  {
    frame.origin.y = mFrameOriginOnMouseDown.y + (draggingLocation.y - mMouseDownLocation.y);
  }
  frame.origin = [self constrainedFrameOriginForProposedOrigin:frame.origin];
  [self setFrame:frame];
}


- (void) mouseUp:(NSEvent*)mouseEvent
{
  if ( mViewWasDragged )
  {
    [self updateStickiness];
    [[self window] invalidateRestorableState];
  }
  [self resetEventHandling];
}


NSString* FXResume_InspectorOrigin       = @"FXResume_InspectorOrigin";
NSString* FXResume_InspectorStickiness   = @"FXResume_InspectorStickiness";
NSString* FXResume_InspectorVisibility   = @"FXResume_InspectorVisibility";


- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  [super encodeRestorableStateWithCoder:state];
  [state encodeInteger:mStickiness forKey:FXResume_InspectorStickiness];
  [state encodePoint:self.frame.origin forKey:FXResume_InspectorOrigin]; FXIssue(190)
  [state encodeBool:[self isHidden] forKey:FXResume_InspectorVisibility];
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  [super restoreStateWithCoder:state];

  if ( [state containsValueForKey:FXResume_InspectorOrigin] )
  {
    NSPoint const decodedFrameOrigin = [state decodePointForKey:FXResume_InspectorOrigin];
    NSPoint const appliedFrameOrigin = [self constrainedFrameOriginForProposedOrigin:decodedFrameOrigin];
    [self setFrameOrigin:appliedFrameOrigin]; FXIssue(190)
  }

  if ( [state containsValueForKey:FXResume_InspectorVisibility] )
  {
    self.hidden = [state decodeBoolForKey:FXResume_InspectorVisibility];
  }

  // Stickiness must be set after the frame origin
  mStickiness = [state decodeIntegerForKey:FXResume_InspectorStickiness];
  [self applyStickiness];
}


#pragma mark NSView overrides


- (BOOL) canDrawConcurrently
{
  return YES;
}


- (void) drawRect:(NSRect)visibleRect
{
  CGContextRef context = FXGraphicsContext;
  if ( mImage == NULL )
  {
    [self refreshImageForSize:self.bounds.size];
  }
  CGContextDrawImage( context, CGRectMake(0,0,CGImageGetWidth(mImage),CGImageGetHeight(mImage)), mImage );
}


- (void) viewWillMoveToSuperview:(NSView*)newSuperview
{
  if ( newSuperview != nil )
  {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSuperViewFrameChange:) name:NSViewFrameDidChangeNotification object:newSuperview];
  }
  else
  {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  }
}


#pragma mark Private


#define INSPECTOR_VIEW_HAS_GRADIENT (1)

- (void) drawImageInRect:(NSRect)rect context:(CGContextRef)context colorSpace:(CGColorSpaceRef)colorSpace
{
#if INSPECTOR_VIEW_HAS_GRADIENT
  CGFloat gradientStopPositions[2] = { 0.0, 1.0 };
  CGFloat gradientStopColors[8] = {
    0.90, 0.93, 0.90, 0.9,
    0.78, 0.80, 0.78, 0.9 };
  CGGradientRef gradient = CGGradientCreateWithColorComponents (colorSpace, gradientStopColors, gradientStopPositions, 2 );
#endif

  static const CGFloat skCornerRadius = 6.0;
  CGMutablePathRef outlinePath = CGPathCreateMutable();

  CGPathMoveToPoint( outlinePath, NULL, skCornerRadius, 0.0 );
  CGPathAddLineToPoint( outlinePath, NULL, rect.size.width - skCornerRadius, 0.0 );
  CGPathAddArc( outlinePath, NULL, rect.size.width - skCornerRadius, skCornerRadius, skCornerRadius, -M_PI_2, 0, 0 );
  CGPathAddLineToPoint( outlinePath, NULL, rect.size.width, rect.size.height - skCornerRadius );
  CGPathAddArc( outlinePath, NULL, rect.size.width - skCornerRadius, rect.size.height - skCornerRadius, skCornerRadius, 0, M_PI_2, 0 );
  CGPathAddLineToPoint( outlinePath, NULL, skCornerRadius, rect.size.height );
  CGPathAddArc( outlinePath, NULL, skCornerRadius, rect.size.height - skCornerRadius, skCornerRadius, M_PI_2, M_PI, 0 );
  CGPathAddLineToPoint( outlinePath, NULL, 0.0, skCornerRadius );
  CGPathAddArc( outlinePath, NULL, skCornerRadius, skCornerRadius, skCornerRadius, M_PI, 3*M_PI_2, 0 );
  CGPathCloseSubpath( outlinePath );
  
  CGContextSaveGState( context );
#if INSPECTOR_VIEW_HAS_GRADIENT
  CGContextBeginPath( context );
  CGContextAddPath( context, outlinePath );
  CGContextClip (context);
  CGContextDrawLinearGradient( context, gradient, CGPointMake(0.0, rect.size.height), CGPointMake(0.0, 0.0), 0 );
#else
  CGContextSetRGBFillColor( context, 0.78, 0.80, 0.78, 0.90 );
  CGContextBeginPath( context );
  CGContextAddPath( context, outlinePath );
  CGContextFillPath( context );
#endif
  CGContextRestoreGState( context );
  CGPathRelease(outlinePath);
#if INSPECTOR_VIEW_HAS_GRADIENT
  CGGradientRelease(gradient);
#endif
}


- (void) refreshImageForSize:(NSSize)size
{
  CGContextRef bitmapContext = NULL;
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  size_t const rowLength = ceilf(size.width);
  size_t const numRows = ceilf(size.height);
  size_t const numComponents = 4; // RGBA, 8 bit each
  size_t const bitsPerComponent = 8;
  size_t const bytesPerRow = numComponents * rowLength;
  void* bitmapData = calloc( numRows, bytesPerRow );
  bitmapContext = CGBitmapContextCreate( bitmapData, rowLength, numRows, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast );
  if ( bitmapContext != NULL )
  {
    [self drawImageInRect:NSMakeRect(0, 0, size.width, size.height) context:bitmapContext colorSpace:colorSpace];
    
    if ( mImage != NULL )
    {
      CGImageRelease( mImage );
    }
    mImage = CGBitmapContextCreateImage( bitmapContext );
    
    CGContextRelease( bitmapContext );
  }
  free( bitmapData );
  CGColorSpaceRelease(colorSpace);
}


- (NSPoint) constrainedFrameOriginForProposedOrigin:(NSPoint)origin
{
  NSSize const parentSize = [[self superview] frame].size;
  NSSize const ownSize = [self frame].size;

  if ( ownSize.width >= parentSize.width )
  {
    origin.x = 0; // sticking to the left side is preferred
  }
  else if ( origin.x < 0 )
  {
    origin.x = 0;
  }
  else if ( origin.x > (parentSize.width - ownSize.width) )
  {
    origin.x = (parentSize.width - ownSize.width);
  }

  if ( ownSize.height >= parentSize.height )
  {
    origin.y = 0; // sticking to the top side is preferred
  }
  else if ( origin.y < 0 )
  {
    origin.y = 0;
  }
  else if ( origin.y > (parentSize.height - ownSize.height) )
  {
    origin.y = (parentSize.height - ownSize.height);
  }

  return origin;
}


- (void) resetEventHandling
{
  mViewWasDragged = NO;
  mMouseDownLocation = NSZeroPoint;
  mFrameOriginOnMouseDown = NSZeroPoint;
}


- (void) handleSuperViewFrameChange:(NSNotification*)notification
{
  [self applyStickiness];
}


- (void) applyStickiness
{
  NSRect frame = [self frame];
  BOOL const superViewIsFlipped = [[self superview] isFlipped];
  switch( mStickiness )
  {
    case FXStickiness_None:
      {
        frame.origin = [self constrainedFrameOriginForProposedOrigin:frame.origin];
        break;
      }
    case FXStickiness_TopLeftCorner:
      {
        frame.origin.x = 0.0;
        if ( superViewIsFlipped )
        {
          frame.origin.y = 0.0;
        }
        else
        {
          frame.origin.y = [[self superview] frame].size.height - frame.size.height;
        }
        break;
      }
    case FXStickiness_TopRightCorner:
      {
        NSSize const superviewSize = [[self superview] frame].size;
        frame.origin.x = superviewSize.width - frame.size.width;
        if ( superViewIsFlipped )
        {
          frame.origin.y = 0.0;
        }
        else
        {
          frame.origin.y = superviewSize.height - frame.size.height;
        }
        break;
      }
    case FXStickiness_BottomLeftCorner:
      {
        frame.origin.x = 0.0;
        if ( superViewIsFlipped )
        {
          frame.origin.y = [[self superview] frame].size.height - frame.size.height;
        }
        else
        {
          frame.origin.y = 0.0;
        }
        break;
      }
    case FXStickiness_BottomRightCorner:
      {
        frame.origin.x = [[self superview] frame].size.width - frame.size.width;
        if ( superViewIsFlipped )
        {
          frame.origin.y = [[self superview] frame].size.height - frame.size.height;
        }
        else
        {
          frame.origin.y = 0.0;
        }
        break;
      }
  }
  [self setFrame:frame];
}


- (void) updateStickiness
{
  if ( [self superview] != nil )
  {
    BOOL const superViewIsFlipped = [[self superview] isFlipped];
    FXSchematicInspectorStickiness newStickiness = FXStickiness_None;
    NSRect const frame = [self frame];
    NSSize const superSize = [[self superview] frame].size;
    if ( frame.origin.x <= 0.0 )
    {
      if ( frame.origin.y >= (superSize.height - frame.size.height) )
      {
        newStickiness = superViewIsFlipped ? FXStickiness_BottomLeftCorner : FXStickiness_TopLeftCorner;
      }
      else if ( frame.origin.y <= 0.0 )
      {
        newStickiness = superViewIsFlipped ? FXStickiness_TopLeftCorner : FXStickiness_BottomLeftCorner;
      }
    }
    else if ( frame.origin.x >= (superSize.width - frame.size.width) )
    {
      if ( frame.origin.y >= (superSize.height - frame.size.height) )
      {
        newStickiness = superViewIsFlipped ? FXStickiness_BottomRightCorner : FXStickiness_TopRightCorner;
      }
      else if ( frame.origin.y <= 0.0 )
      {
        newStickiness = superViewIsFlipped ? FXStickiness_TopRightCorner : FXStickiness_BottomRightCorner;
      }
    }
    mStickiness = newStickiness;
  }
}


@end
