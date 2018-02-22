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

#import "FXInternalDrawerView.h"


CGFloat const kCornerRadius                    = 6.0;
CGFloat const kDrawerMinHeight                 = 55.0;
CGFloat const kDrawerMaxHeight                 = 200.0;
CGFloat const kDrawerMinWidth                  = 150.0;   // the drawer can not be smaller than that
CGFloat const kDrawerLeftRightMarginMin        = 0.0;     // the maximum margin between the left or right side of the palette and nearest side of its parent view
CGFloat const kDrawerLeftRightMarginMax        = 0.0;    // the maximum margin between the left or right side of the palette and nearest side of its parent view


@implementation FX(FXInternalDrawerView)
{
@private
  FXInternalDrawerAttachment mAttachment;
  FXInternalDrawerResizing   mResizingPolicy;
  
  CGImageRef    mImage;
  
  NSPoint       mDragStartPoint; ///< valid only during dragging operations
  CGFloat       mDragStartFrameHeight; ///< height of own frame when the dragging action started
  CGFloat       mDragStartFramePosX;   ///< horizontal position of own frame when the dragging action started
  
  /// The vertical offset is the distance between the lower side of the palette table
  /// and the upper side of the schematic view to which it is attached.
  /// Used during mouse drag operations on the view
  CGFloat       mVerticalOffset;
  
  /// Whether the palette view is currently being resized by dragging it vertically
  BOOL          mInLiveResizing;
  
  NSRect        mLastSavedFrame;
  
  BOOL          mDrawerIsHidden;
  
  NSViewAnimation* mHideAnimation;
  NSViewAnimation* mShowAnimation;  
}

@synthesize lockHeight;

- (id) initWithAttachment:(FXInternalDrawerAttachment)attachment
           resizingPolicy:(FXInternalDrawerResizing)resizing
{
  self = [super initWithFrame:NSMakeRect(0, 0, [self initialWidth], [self initialHeight])];
  if (self)
  {
    // The frame is set to stick to the given side of the superview.
    //[self setAutoresizingMask:(NSViewMinYMargin | NSViewMinXMargin | NSViewMaxXMargin)];
    [self setAutoresizingMask:NSViewNotSizable];
    
    mAttachment = attachment;
    mResizingPolicy = resizing;

    mImage = NULL;
    
    mVerticalOffset = 0.0f;
    mInLiveResizing = NO;
    mLastSavedFrame = NSZeroRect;

    mShowAnimation = nil;
    mHideAnimation = nil;
    mDrawerIsHidden = NO;
    self.lockHeight = NO;

    mDragStartFrameHeight = 0;
    mDragStartFramePosX = 0;
  }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if ( mImage != NULL )
  {
    CGImageRelease( mImage );
  }
  FXRelease(mShowAnimation)
  FXRelease(mHideAnimation)
  FXDeallocSuper
}


#pragma mark Private


- (void) drawImageInRect:(NSRect)rect withContext:(CGContextRef)context
{
  CGMutablePathRef outlinePath = CGPathCreateMutable();
  if ( mAttachment == FXDrawerAttachmentTop )
  {
    CGPathMoveToPoint( outlinePath, NULL, 0.0, rect.size.height );
    CGPathAddLineToPoint( outlinePath, NULL, 0.0, kCornerRadius );
    CGPathAddArc( outlinePath, NULL, kCornerRadius, kCornerRadius, kCornerRadius, -M_PI, -M_PI_2, 0 );
    CGPathAddLineToPoint( outlinePath, NULL, rect.size.width - kCornerRadius, 0.0 );
    CGPathAddArc( outlinePath, NULL, rect.size.width - kCornerRadius, kCornerRadius, kCornerRadius, -M_PI_2, 0, 0 );
    CGPathAddLineToPoint( outlinePath, NULL, rect.size.width, rect.size.height );
    CGPathCloseSubpath( outlinePath );
  }
  else if ( mAttachment == FXDrawerAttachmentBottom )
  {
    CGPathMoveToPoint( outlinePath, NULL, 0.0, 0.0 );
    CGPathAddLineToPoint( outlinePath, NULL, 0.0, rect.size.height - kCornerRadius );
    CGPathAddArc( outlinePath, NULL, kCornerRadius, rect.size.height - kCornerRadius, kCornerRadius, M_PI, M_PI_2, 1 );
    CGPathAddLineToPoint( outlinePath, NULL, rect.size.width - kCornerRadius, rect.size.height );
    CGPathAddArc( outlinePath, NULL, rect.size.width - kCornerRadius, rect.size.height - kCornerRadius, kCornerRadius, M_PI_2, 0, 1 );
    CGPathAddLineToPoint( outlinePath, NULL, rect.size.width, 0 );
    CGPathCloseSubpath( outlinePath );
  }
  
  CGContextSaveGState( context );
  CGContextSetRGBFillColor( context, 0.78, 0.80, 0.78, 0.90 );
  CGContextBeginPath( context );
  CGContextAddPath( context, outlinePath );
  CGContextFillPath( context );
  CGContextRestoreGState( context );
  CGPathRelease(outlinePath);
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
    [self drawImageInRect:NSMakeRect(0, 0, size.width, size.height) withContext:bitmapContext];
    
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


- (void) handleSuperViewFrameChange:(NSNotification*)notification
{
  [super setFrame:[self adjustedFrame]];
  [self refreshImageForSize:[self frame].size];
  [self setNeedsDisplay:YES];
}


#pragma mark Public


- (void) show
{
  if ( mDrawerIsHidden )
  {
    NSRect const endFrame = [self adjustedFrame];
    BOOL const superViewIsFlipped = [[self superview] isFlipped];
    mLastSavedFrame = endFrame;
    
    FXIssue(13)
    NSRect startFrame = endFrame;
    if ( ((mAttachment == FXDrawerAttachmentTop) && !superViewIsFlipped)
      || ((mAttachment == FXDrawerAttachmentBottom) && superViewIsFlipped) )
    {
      startFrame.origin.y = [[self superview] frame].size.height;
    }
    else if ( ((mAttachment == FXDrawerAttachmentBottom) && !superViewIsFlipped)
      || ((mAttachment == FXDrawerAttachmentTop) && superViewIsFlipped) )
    {
      startFrame.origin.y = -endFrame.size.height;
    }
    [self setFrame:startFrame];


    NSDictionary* animationDictionary = @{
      NSViewAnimationTargetKey : self,
      NSViewAnimationStartFrameKey : [NSValue valueWithRect:startFrame],
      NSViewAnimationEndFrameKey : [NSValue valueWithRect:endFrame]
    };

    if ( mShowAnimation == nil )
    {
      mShowAnimation = [[NSViewAnimation alloc] initWithViewAnimations:@[animationDictionary]];
    }
    else
    {
      [mShowAnimation setViewAnimations:@[animationDictionary]];
    }

    mDrawerIsHidden = NO;
    [self setHidden:NO];
    [mShowAnimation startAnimation];
  }
}


- (void) hide
{
  mLastSavedFrame = [self frame];
  BOOL const superViewIsFlipped = [[self superview] isFlipped];
  NSRect endFrame = mLastSavedFrame;

  if ( ((mAttachment == FXDrawerAttachmentTop) && !superViewIsFlipped)
    || ((mAttachment == FXDrawerAttachmentBottom) && superViewIsFlipped) )
  {
    endFrame.origin.y = [[self superview] frame].size.height;
  }
  else if ( ((mAttachment == FXDrawerAttachmentBottom) && !superViewIsFlipped)
    || ((mAttachment == FXDrawerAttachmentTop) && superViewIsFlipped) )
  {
    endFrame.origin.y = - mLastSavedFrame.size.height;
  }

  NSDictionary* animationDictionary = @{
    NSViewAnimationTargetKey : self,
    NSViewAnimationEndFrameKey : [NSValue valueWithRect:endFrame]
  };

  if ( mHideAnimation == nil )
  {
    mHideAnimation = [[NSViewAnimation alloc] initWithViewAnimations:@[animationDictionary]];
  }
  else
  {
    [mHideAnimation setViewAnimations:@[animationDictionary]];
  }
  [mHideAnimation setDelegate:self];
  [mHideAnimation startAnimation];
}


/// NSAnimationDelegate method
- (void) animationDidEnd:(NSAnimation*)animation
{
  if ( animation == mHideAnimation )
  {
    mDrawerIsHidden = YES;
    [self setHidden:YES];
  }
}


- (NSRect) adjustedFrame
{
  NSRect const superFrame = [[self superview] frame];
  BOOL const superViewIsFlipped = [[self superview] isFlipped];
  NSRect const ownFrame = [self frame];
  CGFloat newWidth = ownFrame.size.width;
  CGFloat newHeight = ownFrame.size.height;
  CGFloat newPosX = ownFrame.origin.x;
  CGFloat newPosY = ownFrame.origin.y;

  if ( [self isHidden] && !mDrawerIsHidden )
  {
    [self setHidden:NO];
  }

  // Adjusting the width of the drawer.
  if ( mResizingPolicy == FXDrawerResizingAuto )
  {
    // Tracking the width of the container, leaving a margin to the left and right side.
    // The margin depends on the width of the container.

    if ( superFrame.size.width < ([self minWidth] + 2 * kDrawerLeftRightMarginMax) )
    {
      newWidth = [self minWidth];
    }
    else
    {
      newWidth = superFrame.size.width - 2 * kDrawerLeftRightMarginMax;
    }
  }
  else if ( mResizingPolicy == FXDrawerResizingVerticalOnly )
  {
    newWidth = (newWidth < [self minWidth]) ? [self minWidth] : ((newWidth > [self maxWidth]) ? [self maxWidth] : newWidth);
  }

  if ( mResizingPolicy != FXDrawerResizingNone )
  {
    // Adjusting the height.
    if ( superFrame.size.height < [self minHeight] )
    {
      newHeight = [self minHeight];
    }
    else if ( superFrame.size.height < newHeight )
    {
      newHeight = superFrame.size.height;
    }

    // Adjusting the position.
    if ( mResizingPolicy == FXDrawerResizingAuto )
    {
      newPosX = (superFrame.size.width - newWidth)/2.0f;
      newPosX  = (newPosX < kDrawerLeftRightMarginMin) ? kDrawerLeftRightMarginMin : newPosX;
    }
    else if ( mResizingPolicy == FXDrawerResizingVerticalOnly )
    {
      if (superFrame.size.width >= (ownFrame.size.width + 2 * kDrawerLeftRightMarginMax))
      {
        if ( newPosX < kDrawerLeftRightMarginMax )
        {
          newPosX = kDrawerLeftRightMarginMax;
        }
        else if ( newPosX > (superFrame.size.width - ownFrame.size.width - kDrawerLeftRightMarginMax) )
        {
          newPosX = superFrame.size.width - ownFrame.size.width - kDrawerLeftRightMarginMax;
        }
      }
      else
      {
        if ( superFrame.size.width > (ownFrame.size.width + 2 * kDrawerLeftRightMarginMin) )
        {
          newPosX = (superFrame.size.width - ownFrame.size.width)/2;
        }
        else
        {
          newPosX = kDrawerLeftRightMarginMin;
        }
      }
    }
    
    if ( ((mAttachment == FXDrawerAttachmentTop) && !superViewIsFlipped)
      || ((mAttachment == FXDrawerAttachmentBottom) && superViewIsFlipped) )
    {
      newHeight = (newHeight < [self minHeight]) ? [self minHeight] : ((newHeight > [self maxHeight])? [self maxHeight] : newHeight);
      newPosY = superFrame.size.height - newHeight;
    }
    else if ( ((mAttachment == FXDrawerAttachmentBottom) && !superViewIsFlipped)
      || ((mAttachment == FXDrawerAttachmentTop) && superViewIsFlipped) )
    {
      newPosY = 0.0;
    }
  }

  return NSMakeRect( newPosX, newPosY, newWidth, newHeight );
}


- (CGFloat) minHeight
{
  return kDrawerMinHeight;
}


- (CGFloat) maxHeight
{
  return kDrawerMaxHeight;
}


- (CGFloat) initialHeight
{
  return kDrawerMinHeight;
}


- (CGFloat) minWidth
{
  return kDrawerMinWidth;
}


- (CGFloat) maxWidth
{
  return 10000;
}


- (CGFloat) initialWidth
{
  return [self minWidth];
}


#pragma mark NSView overrides


- (void) drawRect:(NSRect)rect
{
  if ( !mDrawerIsHidden )
  {
    CGContextRef context = FXGraphicsContext;

    if ( mInLiveResizing )
    {
      [self drawImageInRect:rect withContext:context];
    }
    else
    {
      if ( mImage == NULL) //|| (CGImageGetWidth(mImage) != rect.size.width) || (CGImageGetHeight(mImage) != rect.size.height) )
      {
        [self refreshImageForSize:rect.size];
      }
      CGContextDrawImage( context, CGRectMake(0,0,CGImageGetWidth(mImage),CGImageGetHeight(mImage)), mImage );
    }

    // Draw subviews
    [super drawRect:rect];
  }
}

- (void) viewDidMoveToSuperview
{
  NSView* superView = [self superview];
  if ( superView != nil )
  {
    [super setFrame:[self adjustedFrame]];
    // Set the receiver up to listen to frame change notifications of super view
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSuperViewFrameChange:) name:NSViewFrameDidChangeNotification object:superView];
  }
}


- (void) viewWillMoveToSuperview:(FXView*)newSuperview
{
  if ( [self superview] != nil )
  {
    // stop listening to frame change notifications from current super view
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:[self superview]];
  }
}


#pragma mark NSResponder overrides


- (void) mouseDown:(NSEvent*)event
{
    mDragStartPoint = [event locationInWindow];
    NSRect const frame = [self frame];
    mDragStartFrameHeight = frame.size.height;
    mDragStartFramePosX = frame.origin.x;
}

- (void) mouseDragged:(NSEvent*)event
{
    mInLiveResizing = YES;

    NSRect const frame = [self frame];
    NSRect newFrame = frame;
    NSPoint const dragPoint = [event locationInWindow];
    
    if ( !self.lockHeight && (mResizingPolicy != FXDrawerResizingNone) )
    {
        mVerticalOffset = mDragStartPoint.y - dragPoint.y;
        CGFloat newHeight = mDragStartFrameHeight;
        if ( mAttachment == FXDrawerAttachmentTop )
        {
            newHeight += mVerticalOffset;
        }
        else if ( mAttachment == FXDrawerAttachmentBottom )
        {
            newHeight -= mVerticalOffset;
        }

        if ( newHeight < [self minHeight] )
        {
            newHeight = [self minHeight];
        }
        else if ( newHeight > [self maxHeight] )
        {
            newHeight = [self maxHeight];
        }
        newFrame.origin.y += frame.size.height - newHeight;
        newFrame.size.height = newHeight;
    }

    if ( mResizingPolicy & FXDrawerResizingVerticalOnly )
    {
        NSAssert( [self superview] != nil, @"can't drag an FXInternalDrawerView without a superview" );
        NSRect const superViewFrame = [[self superview] frame];
        CGFloat const minX = (superViewFrame.size.width > (frame.size.width + 2 * kDrawerLeftRightMarginMax)) ? kDrawerLeftRightMarginMax : kDrawerLeftRightMarginMin;
        CGFloat const maxX = superViewFrame.size.width - frame.size.width - minX;
        newFrame.origin.x = mDragStartFramePosX + dragPoint.x - mDragStartPoint.x;
        if ( newFrame.origin.x < minX )
        {
            newFrame.origin.x = minX;
        }
        if ( newFrame.origin.x > maxX )
        {
            newFrame.origin.x = maxX;
        }
    }

    [self setFrame:newFrame];
    [super setFrame:[self adjustedFrame]];
    [self setNeedsDisplay:YES];
}

- (void) mouseUp:(NSEvent*)event
{
    [self refreshImageForSize:[self frame].size];
    if (mInLiveResizing)
    {
        mInLiveResizing = NO;
    }
}


@end
