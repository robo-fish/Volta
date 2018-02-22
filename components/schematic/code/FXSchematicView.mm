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

#import "FXSchematicView.h"
#import "FXSchematicElement.h"
#import "FXModel.h"
#import "FXElement.h"

#define SCHEMATIC_VIEW_SUPPORTS_LIVE_RESIZING (0)


@implementation FXSchematicView
{
@private
  id<VoltaSchematicViewController> __weak mController;
  BOOL mCurrentlyResizingLive; // Whether the view is currently being resized interactively by the user. Important for rendering performance considerations.
  NSTrackingArea* mTrackingArea; // for mouse move events
  BOOL mEnabled;
}

@synthesize controller = mController;
@synthesize enabled = mEnabled;

- (id) initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    mEnabled = YES;
    mController = nil;
    mCurrentlyResizingLive = NO;
    mTrackingArea = nil;
    [self registerForDraggedTypes:@[FXPasteboardDataTypeSchematicElement, FXPasteboardDataTypeModel, FXPasteboardDataTypeElement]];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mTrackingArea)
  mController = nil;
  FXDeallocSuper
}


#pragma mark NSView overrides


- (void) drawRect:(NSRect)visibleRect
{
  if ( !mEnabled )
  {
    DebugLog(@"Attempt to render in disabled FXSchematicView.");
    return;
  }

  CGContextRef context = FXGraphicsContext;
  CGContextSaveGState(context);
  CGContextClipToRect(context, visibleRect);
  CGContextSetGrayFillColor( context, 1.0f, 1.0f );
  CGContextFillRect( context, visibleRect );

#if SCHEMATIC_VIEW_SUPPORTS_LIVE_RESIZING
  if ( mCurrentlyResizingLive )
  {
    // draw from cache
  }
  else
#endif
  {
    [mController drawSchematicWithContext:context inView:self];
  }

  CGContextRestoreGState(context);
}

#if SCHEMATIC_VIEW_SUPPORTS_LIVE_RESIZING

- (void) viewWillStartLiveResize
{
  mCurrentlyResizingLive = YES;
}

- (void) viewDidEndLiveResize
{
  mCurrentlyResizingLive = NO;
  if ( mEnabled )
  {
    [self refresh];
  }
}

#endif


#pragma mark NSDraggingDestination


- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
  if ( mEnabled )
  {
    NSPasteboard* pboard = [sender draggingPasteboard];
    if ( [[pboard types] containsObject:FXPasteboardDataTypeSchematicElement]
      || [[pboard types] containsObject:FXPasteboardDataTypeModel]
      || [[pboard types] containsObject:FXPasteboardDataTypeElement] )
    {
      [mController updateDraggingItemsForDraggingInfo:sender];
      return NSDragOperationCopy;
    }
  }
  return NSDragOperationNone;
}


#if 0
// This is the recommended way but is not suited for fast drag & drop operations
// because of the delay with which this method is called.
// Instead, we update the icons immediately upon draggingEntered: (see above).
- (void) updateDraggingItemsForDrag:(id<NSDraggingInfo>)sender
{
  [mController updateDraggingItemsForDraggingInfo:sender];
}
#endif


- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return mEnabled;
}


- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
  if ( !mEnabled )
  {
    DebugLog(@"Attempt to drop data on a disabled FXSchematicView.");
    return NO;
  }
  return [mController handleDropForDraggingInfo:sender];
}


#pragma mark NSResponder overrides


- (BOOL) acceptsFirstResponder
{
  FXIssue(37)
  return YES;
}

- (void) mouseDown:(NSEvent*)mouseEvent
{
  if ( mEnabled )
  {
    // Making sure that subsequent key presses are processed here.
    [[self window] makeFirstResponder:self];

    [mController mouseDown:mouseEvent];
  }
}

- (void) mouseUp:(NSEvent*)mouseEvent
{
  if ( mEnabled )
  {
    [mController mouseUp:mouseEvent];
  }
}

- (void) mouseDragged:(NSEvent*)mouseEvent
{
  if ( mEnabled )
  {
    [mController mouseDragged:mouseEvent];
  }
}

- (void) mouseMoved:(NSEvent*)mouseEvent
{
  if ( mEnabled )
  {
    [mController mouseMoved:mouseEvent];
  }
}

- (void) keyDown:(NSEvent*)keyEvent
{
  if ( mEnabled )
  {
    [mController keyDown:keyEvent];
  }
}

- (void) keyUp:(NSEvent*)keyEvent
{
  if ( mEnabled )
  {
    [mController keyUp:keyEvent];
  }
}

- (BOOL) performKeyEquivalent:(NSEvent*)event
{
  BOOL handled = mEnabled;
  handled = handled && (self == [[self window] firstResponder]); FXIssue(224)
  handled = handled && [mController performKeyEquivalent:event];
  return handled;
}

- (void) magnifyWithEvent:(NSEvent*)gestureEvent
{
  if ( mEnabled )
  {
    [mController handleMagnificationGesture:gestureEvent.magnification];
  }
}

- (void) touchesBeganWithEvent:(NSEvent*)touchEvent
{
  if ( mEnabled )
  {
    [mController gestureBegins];
    [super touchesBeganWithEvent:touchEvent];
  }
}

- (void) touchesEndedWithEvent:(NSEvent*)touchEvent
{
  if ( mEnabled )
  {
    [mController gestureEnds];
    [super touchesEndedWithEvent:touchEvent];
  }
}

- (void) touchesCancelledWithEvent:(NSEvent*)touchEvent
{
  [self touchesEndedWithEvent:touchEvent];
}

#pragma mark NSView overrides


- (void) updateTrackingAreas
{
  FXIssue(25)
  FXIssue(118)
  static const NSUInteger skTrackingOptions = NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect;
  if ( mTrackingArea != nil )
  {
    [self removeTrackingArea:mTrackingArea];
    FXRelease(mTrackingArea)
  }
  mTrackingArea = [[NSTrackingArea alloc] initWithRect:[self frame] options:skTrackingOptions owner:self userInfo:nil];
  [self addTrackingArea:mTrackingArea];
  [super updateTrackingAreas];
}


- (BOOL) acceptsFirstMouse:(NSEvent*)mouseEvent
{
  return YES;
}


- (BOOL) isFlipped
{
#if SCHEMATIC_VIEW_IS_FLIPPED
  return YES;
#else
  return NO;
#endif
}


#pragma mark VoltaSchematicView


- (void) refresh
{
  [self setNeedsDisplay:YES];
}


#pragma mark NSUserInterfaceValidations


- (BOOL) validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
  if ( mEnabled )
  {
    return [mController validateUserInterfaceItem:anItem];
  }
  return NO;
}


#pragma mark Public methods


- (void) performSchematicUserInterfaceAction:(id)sender
{
  if ( mEnabled )
  {
    if ( [sender respondsToSelector:@selector(tag)] )
    {
      [mController handleUserInterfaceActionForTag:[sender tag]];
    }
  }
}


@end
