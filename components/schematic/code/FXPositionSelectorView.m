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

#import "FXPositionSelectorView.h"

@implementation FX(FXPositionSelectorView)
{
@private
  SEL mAction;
  id  mTarget;
  SchematicRelativePosition mPosition;
  CGColorSpaceRef mColorSpace;
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    mTarget = nil;
    mPosition = SchematicRelativePosition_None;
    mColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  }
  return self;
}


- (void) dealloc
{
  if ( mColorSpace != NULL )
  {
    CGColorSpaceRelease(mColorSpace);
  }
  FXDeallocSuper
}


#pragma mark Public


- (void) setTarget:(id)newTarget
{
  mTarget = newTarget;
}


- (void) setAction:(SEL)newAction
{
  mAction = newAction;
}


- (SchematicRelativePosition) position;
{
  return mPosition;
}


- (void) setPosition:(SchematicRelativePosition)newPosition
{
  mPosition = newPosition;
  [self setNeedsDisplay:YES];
}


#pragma mark NSResponder overrides


- (void) mouseDown:(NSEvent*)theEvent
{
  NSPoint clickPosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  NSRect const rect = [self frame];
  CGFloat x = clickPosition.x - rect.size.width/2.0;
  CGFloat y = clickPosition.y - rect.size.height/2.0;

  if ( (fabs(x) < rect.size.width * 0.15) && (fabs(y) < rect.size.height * 0.15) )
  {
    mPosition = SchematicRelativePosition_None;
  }
  else if (fabs(x) >= fabs(y))
  {
    mPosition = (x >= 0.0f) ? SchematicRelativePosition_Right : SchematicRelativePosition_Left;
  }
  else
  {
    mPosition = (y >= 0.0f) ? SchematicRelativePosition_Top : SchematicRelativePosition_Bottom;
  }

  [self setNeedsDisplay:YES];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [mTarget performSelector:mAction withObject:self];
#pragma clang diagnostic pop
}


- (void) mouseDragged:(NSEvent*)event
{
  /* consume */
}


#pragma mark NSView overrides


- (void)drawRect:(NSRect)visibleRect
{
  static const CGFloat skColor[] = { 0.0, 0.0, 0.0, 1.0 };

  NSRect const rect = [self bounds];
  CGContextRef context = FXGraphicsContext;
  CGContextSetFillColorSpace(context, mColorSpace);
  CGContextSetFillColor(context, skColor);
  
  CGContextBeginPath(context);
  NSRect innerCircleFrame = NSInsetRect(rect, rect.size.width * 0.35, rect.size.height * 0.35);
  CGContextAddEllipseInRect(context, innerCircleFrame);
  CGContextClosePath(context);
  CGContextStrokePath(context);

  CGContextBeginPath(context);
  NSRect outerCircleFrame = NSZeroRect;
  switch( mPosition )
  {
    case SchematicRelativePosition_Top:
      outerCircleFrame = NSMakeRect(rect.origin.x + rect.size.width * 0.375f, rect.origin.y + rect.size.height * 0.70f, rect.size.width * 0.25f, rect.size.height * 0.25f);
      break;
    case SchematicRelativePosition_Bottom:
      outerCircleFrame = NSMakeRect(rect.origin.x + rect.size.width * 0.375f, rect.origin.y + rect.size.height * 0.05f, rect.size.width * 0.25f, rect.size.height * 0.25f);
      break;
    case SchematicRelativePosition_Left:
      outerCircleFrame = NSMakeRect(rect.origin.x + rect.size.width * 0.05f, rect.origin.y + rect.size.height * 0.375f, rect.size.width * 0.25f, rect.size.height * 0.25f);
      break;
    case SchematicRelativePosition_Right:
      outerCircleFrame = NSMakeRect(rect.origin.x + rect.size.width * 0.70f, rect.origin.y + rect.size.height * 0.375f, rect.size.width * 0.25f, rect.size.height * 0.25f);
      break;
    default:
      /* draw nothing */;
  }
  CGContextAddEllipseInRect(context, outerCircleFrame);
  CGContextFillPath(context);
}


- (BOOL) acceptsFirstMouse:(NSEvent*)theEvent
{
  return YES; // for click-through behavior
}


@end
