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

#import "FXShapeView.h"
#import "FXShapeRenderer.h"


static const CGFloat skWhiteColor[] = {1.0, 1.0, 1.0, 1.0};
static const CGFloat skGrayColor[] = {0.4, 0.4, 0.4, 1.0};
static const CGFloat skBlackColor[] = {0.0, 0.0, 0.0, 1.0};
static const CGFloat skLineWidthCompensation = 2.0;


@interface FXShapeView () <NSDraggingSource>
@end


@implementation FXShapeView
{
@private
  id<FXShape>     mShape;
  BOOL            mIsBordered;
  BOOL            mIsDraggable;
  BOOL            mEnabled;
  BOOL            mIsSelected;
  BOOL            mIsCached;
  BOOL            mImageCacheNeedsRefreshing;
  CGFloat         mRotation;
  FXShapeViewScaleMode mScaleMode;
  FXShapeViewVerticalAlignment mVerticalAlignment;
  NSDictionary*   mShapeAttributes;

  // TODO: In order to support on-the-fly switching between Hi-DPI and normal DPI,
  // the image cache should be an NSImage containing two NSBitmapImageRep instances.
  CGImageRef      mImageCache;

  CGColorSpaceRef mColorSpace;
  CGColorRef      mShapeColor;
  CGColorRef      mSelectedShapeColor;
  CGColorRef      mDisabledShapeColor;

  id<FXShapeViewDelegate> __weak mDelegate;

  NSPoint     mLastMouseDownLocation; // for dragging
  BOOL        mDraggingStartedInsideTheView; FXIssue(258)
  NSImage*    mDragIcon; // Cached icon for dragging operations. Eliminates unnecessary rebuilding of the drag image.
}

@synthesize shape = mShape;
@synthesize shapeAttributes = mShapeAttributes;
@synthesize enabled = mEnabled;
@synthesize isCached = mIsCached;
@synthesize isSelected = mIsSelected;
@synthesize isBordered = mIsBordered;
@synthesize isDraggable = mIsDraggable;
@synthesize scaleMode = mScaleMode;
@synthesize rotation = mRotation;
@synthesize shapeColor = mShapeColor;
@synthesize selectedShapeColor = mSelectedShapeColor;
@synthesize verticalAlignment = mVerticalAlignment;
@synthesize delegate = mDelegate;

- (id) initWithFrame:(NSRect)frame
{
  if ((self = [super initWithFrame:frame]))
  {
    mDragIcon = nil;
    mLastMouseDownLocation = NSZeroPoint;
    mIsCached = NO;
    mIsBordered = NO;
    mIsDraggable = YES;
    mScaleMode = FXShapeViewScaleMode_None;
    mEnabled = YES;
    mIsSelected = NO;
    mRotation = 0.0;
    mColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    mShapeColor = CGColorCreate(mColorSpace, skBlackColor);
    mSelectedShapeColor = CGColorCreate(mColorSpace, skWhiteColor);
    mDisabledShapeColor = CGColorCreate(mColorSpace, skGrayColor);
    mImageCacheNeedsRefreshing = NO;
    mVerticalAlignment = FXShapeViewVerticalAlignment_Center;
  }  
  return self;
}


- (void) dealloc
{
  FXRelease(mShape)
  if ( mImageCache != NULL )
    CGImageRelease( mImageCache );
  if ( mShapeColor != NULL )
    CGColorRelease( mShapeColor );
  if ( mSelectedShapeColor != NULL )
    CGColorRelease( mSelectedShapeColor );
  if ( mDisabledShapeColor )
    CGColorRelease( mDisabledShapeColor );
  if ( mColorSpace != NULL )
    CGColorSpaceRelease( mColorSpace );
  FXRelease(mDragIcon)
  FXDeallocSuper
}


#pragma mark Public


- (void) setShape:(id<FXShape>)shape
{
  if ( mShape != shape )
  {
    FXRelease(mShape)
    mShape = shape;
    FXRetain(mShape)
    if ( mIsCached )
    {
      [self refreshImageCache];
    }

    // The drag image needs updating
    FXRelease(mDragIcon)
    mDragIcon = nil;
    [self setNeedsDisplay:YES];
  }
}


- (void) setEnabled:(BOOL)isEnabled
{
  if ( mEnabled != isEnabled )
  {
    mEnabled = isEnabled;
    if ( mIsCached )
    {
      [self refreshImageCache];
    }
    [self setNeedsDisplay:YES];
  }
}


- (void) setIsSelected:(BOOL)isSelected
{
  if ( mIsSelected != isSelected )
  {
    mIsSelected = isSelected;
    mImageCacheNeedsRefreshing = YES;
    [self setNeedsDisplay:YES];
  }
}


- (void) setShapeColor:(CGColorRef)shapeColor
{
  if ( (shapeColor != NULL) && (shapeColor != mShapeColor) )
  {
    CGColorRelease(mShapeColor);
    mShapeColor = CGColorCreateCopy(mShapeColor);
  }
}


- (void) setSelectedShapeColor:(CGColorRef)selectedShapeColor
{
  if ( (selectedShapeColor != NULL) && (selectedShapeColor != mSelectedShapeColor) )
  {
    CGColorRelease(mSelectedShapeColor);
    mSelectedShapeColor = CGColorCreateCopy(selectedShapeColor);
  }
}


- (NSImage*) draggingImage
{
  if ( mDragIcon == nil )
  {
    if ( mImageCache == NULL )
    {
      [self refreshImageCache];
    }
    mDragIcon = [[FXShapeRenderer sharedRenderer] imageFromCGImage:mImageCache pointSize:mShape.size];
    FXRetain(mDragIcon)
  }
  return mDragIcon;
}


#pragma mark NSView overrides


- (void) setFrameSize:(NSSize)newSize
{
  [super setFrameSize:newSize];
  if ( mIsCached )
  {
    [self refreshImageCache];
  }
}


- (BOOL) acceptsFirstMouse:(NSEvent*)mouseEvent
{
  return YES;
}


- (void) drawRect:(NSRect)rect
{
  if (mShape == NULL)
  {
    return;
  }

  if ( mIsCached )
  {
    if ( (mImageCache == NULL) || mImageCacheNeedsRefreshing )
    {
      [self refreshImageCache];
    }
    if ( mImageCache == NULL )
    {
      DebugLog(@"Could not create an image cache.");
      return;
    }
  }

  CGFloat const scaleFactor = [self calculateScaleFactor];
  CGSize const frameSize = self.bounds.size;
  CGFloat const halfWidth = frameSize.width / 2.0;
  CGFloat const halfHeight = frameSize.height / 2.0;

  CGContextRef context = FXGraphicsContext;
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  
  CGContextSaveGState(context);
  if ( mVerticalAlignment != FXShapeViewVerticalAlignment_Center )
  {
    FXSize const shapeSize = [self shapeSize];
    CGFloat const verticalOffset = (frameSize.height - (scaleFactor * shapeSize.height))/2.0 - skLineWidthCompensation;
    CGContextTranslateCTM(context, 0, (mVerticalAlignment == FXShapeViewVerticalAlignment_Top) ? verticalOffset : -verticalOffset);
  }
  if ( mRotation != 0.0 )
  {
    CGContextTranslateCTM(context, halfWidth, halfHeight);
    CGContextRotateCTM(context, mRotation);
    CGContextTranslateCTM(context, -halfWidth, -halfHeight);
  }
  if ( mIsCached )
  {
    [self drawImageInContext:context withScaleFactor:scaleFactor];
  }
  else
  {
    if ( mShape.doesOwnDrawing && (mShape.attributes == nil) && (self.shapeAttributes != nil) )
    {
      mShape.attributes = self.shapeAttributes;
    }
    [self drawShapeInContext:context withScaleFactor:scaleFactor];
  }
  CGContextRestoreGState(context);

  if ( mIsBordered )
  {
    CGContextSetStrokeColor(context, skBlackColor);
    CGContextStrokeRect(context, rect);
  }
}


- (void) mouseDown:(NSEvent*)mouseEvent
{
  if ( self.isDraggable )
  {
    mLastMouseDownLocation = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
    mDraggingStartedInsideTheView = YES;
  }
  else
  {
    [super mouseDown:mouseEvent];
  }
}


- (void) mouseDragged:(NSEvent*)mouseEvent
{
  if ( self.isDraggable && mDraggingStartedInsideTheView )
  {
    FXPoint currentLocation = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
    float distance = hypotf( currentLocation.x - mLastMouseDownLocation.x, currentLocation.y - mLastMouseDownLocation.y );
    if ( distance > 3.0f ) // tolerance against jittery clicks vs. dragging
    {
      NSArray* draggedObjects = [self draggingItemsForDraggingLocation:currentLocation];
      if ( draggedObjects != nil )
      {
        NSDraggingSession* draggingSession = [self beginDraggingSessionWithItems:draggedObjects event:mouseEvent source:self];
        draggingSession.animatesToStartingPositionsOnCancelOrFail = YES;
        mDraggingStartedInsideTheView = NO;
      }
    }
  }
  else
  {
    [super mouseDragged:mouseEvent];
  }
}


- (void) mouseUp:(NSEvent*)mouseEvent
{
  mDraggingStartedInsideTheView = NO;
}


- (BOOL) shouldDelayWindowOrderingForEvent:(NSEvent*)event
{
  return YES; // So that a shape can be dragged without activating the window that contains the shape view.
}

- (NSDragOperation) draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
  return NSDragOperationGeneric;
}


#pragma mark Private


- (void) refreshImageCache
{
  // Clear old cache
  if ( mImageCache != NULL )
  {
    CGImageRelease( mImageCache );
    mImageCache = NULL;
  }

  CGColorRef shapeColor = (mEnabled ? (mIsSelected ? mSelectedShapeColor : mShapeColor) : mDisabledShapeColor);
  BOOL const hiDPI = ([[self window] backingScaleFactor] > 1.5);
  mImageCache = [[FXShapeRenderer sharedRenderer] newImageFromShape:mShape backgroundColor:NULL strokeColor:shapeColor fillColor:shapeColor forHiDPI:hiDPI scaleFactor:1.0];
  mImageCacheNeedsRefreshing = NO;
}


- (FXSize) shapeSize
{
  return [mShape size];
}


- (CGFloat) calculateScaleFactor
{
  CGSize const frameSize = self.bounds.size;
  CGSize const availableSize = CGSizeMake(frameSize.width - skLineWidthCompensation, frameSize.height - skLineWidthCompensation);
  FXSize const shapeSize = [self shapeSize];
  BOOL const resizeWidth = ((mScaleMode == FXShapeViewScaleMode_FitToView) && (shapeSize.width != availableSize.width))
  || ((mScaleMode == FXShapeViewScaleMode_ScaleUpToFit) && (shapeSize.width < availableSize.width))
  || ((mScaleMode == FXShapeViewScaleMode_ScaleDownToFit) && (shapeSize.width > availableSize.width));
  BOOL const resizeHeight = ((mScaleMode == FXShapeViewScaleMode_FitToView) && (shapeSize.height != availableSize.height))
  || ((mScaleMode == FXShapeViewScaleMode_ScaleUpToFit) && (shapeSize.height < availableSize.height))
  || ((mScaleMode == FXShapeViewScaleMode_ScaleDownToFit) && (shapeSize.height > availableSize.height));
  CGFloat const scaleFactorX = resizeWidth ? (availableSize.width/shapeSize.width) : 1.0;
  CGFloat const scaleFactorY = resizeHeight ? (availableSize.height/shapeSize.height) : 1.0;
  return MIN(scaleFactorX, scaleFactorY);
}


- (void) drawImageInContext:(CGContextRef)context withScaleFactor:(CGFloat)scaleFactor
{
  CGSize const frameSize = self.bounds.size;
  CGSize const shapeSize = mShape.size;
  CGRect imageRect;
  imageRect.origin.x = floor((frameSize.width - floor(scaleFactor * shapeSize.width))/2);
  imageRect.origin.y = floor((frameSize.height - floor(scaleFactor * shapeSize.height))/2);
  imageRect.size.width = floor(scaleFactor * shapeSize.width);
  imageRect.size.height = floor(scaleFactor * shapeSize.height);
  CGContextDrawImage( context, imageRect, mImageCache );
}


- (void) drawShapeInContext:(CGContextRef)context withScaleFactor:(CGFloat)scaleFactor
{
  CGSize frameSize = self.bounds.size;
  CGColorRef shapeColor = (mEnabled ? (mIsSelected ? mSelectedShapeColor : mShapeColor) : mDisabledShapeColor);
  CGContextTranslateCTM(context, frameSize.width/2, frameSize.height/2);
  FXShapeRenderContext renderContext;
  renderContext.graphicsContext = context;
  renderContext.flipped = NO;
  renderContext.strokeColor = shapeColor;
  renderContext.textColor = shapeColor;
  [[FXShapeRenderer sharedRenderer] renderShape:mShape withContext:renderContext forHiDPI:NO scaleFactor:scaleFactor];
}


- (NSArray*) draggingItemsForDraggingLocation:(NSPoint)draggingLocation
{
  if ( self.delegate != nil )
  {
    NSArray* draggingWriters = [self.delegate provideObjectsForDragging];
    if ( [draggingWriters count] > 0 )
    {
      id<NSPasteboardWriting> writer = draggingWriters[0];
      NSImage* draggingImage = [self draggingImage];
      NSSize viewFrameSize = self.frame.size;
      NSRect const draggingImageFrame = NSMakeRect(0, 0, viewFrameSize.width, viewFrameSize.height);
      NSDraggingItem* draggingItem = [[NSDraggingItem alloc] initWithPasteboardWriter:writer];
      draggingItem.draggingFrame = draggingImageFrame;
      draggingItem.imageComponentsProvider = ^ {
        NSDraggingImageComponent* imageComponents = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
        NSSize const iconSize = draggingImage.size;
        CGFloat const offsetX = round((viewFrameSize.width - iconSize.width)/2);
        CGFloat const offsetY = round((viewFrameSize.height - iconSize.height)/2);
        imageComponents.frame = NSMakeRect(offsetX, offsetY, round(iconSize.width), round(iconSize.height));
        imageComponents.contents = draggingImage;
        return @[imageComponents];
      };
      FXAutorelease(draggingItem)
      return @[draggingItem];
    }
  }
  return nil;
}


@end
