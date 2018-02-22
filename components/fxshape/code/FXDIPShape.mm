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

#import "FXDIPShape.h"
#import "FXShapeConnectionPoint.h"


typedef NS_ENUM(NSInteger, FXDIPShapeVerticalAlignment)
{
  FXDIPShapeVerticalAlignment_Center,
  FXDIPShapeVerticalAlignment_Top,
  FXDIPShapeVerticalAlignment_Bottom,
};


typedef NS_ENUM(NSInteger, FXDIPShapeHorizontalAlignment)
{
  FXDIPShapeHorizontalAlignment_Center,
  FXDIPShapeHorizontalAlignment_Left,
  FXDIPShapeHorizontalAlignment_Right,
};


struct FXDIPShapeAlignment
{
  FXDIPShapeHorizontalAlignment horizontal;
  FXDIPShapeVerticalAlignment vertical;
  FXDIPShapeAlignment(
    FXDIPShapeHorizontalAlignment h = FXDIPShapeHorizontalAlignment_Center,
    FXDIPShapeVerticalAlignment v = FXDIPShapeVerticalAlignment_Center )
    : horizontal(h), vertical(v) {}
};


static const CGFloat skDIPWidth = 56.0;
static const CGFloat skDIPMargin = 9.0;
static const CGFloat skDIPLabelInset = 4.0;
static const CGFloat skDIPLeadSpacing = 14.0;
static const CGFloat skDIPLeadLength = 6.0;

/// The DIP label font should be monospaced and contain easily discernable characters (e.g. I and 1, O and 0).
static const CFStringRef skDIPTextFontName = CFSTR("Menlo");


@implementation FXDIPShape
{
@private
  CGSize mSize;
  NSInteger mLeadCount;
  NSArray* mLeadPoints;
  FXShapeRenderContext mRenderContext;
}

- (id) initWithLeadCount:(NSUInteger)leadCount
{
  if ( (self = [super init]) != nil )
  {
    mLeadCount = (leadCount % 2) ? (leadCount + 1) : leadCount; // The lead count must be even.
    mSize = CGSizeZero;
    mRenderContext.graphicsContext = NULL;
    [self calculateSize];
    [self createLeadPoints];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mLabel)
  FXRelease(mLeadPoints)
  FXDeallocSuper
}


#pragma mark FXShape


@synthesize size = mSize;
@synthesize attributes;


- (BOOL) doesOwnDrawing
{
  return YES;
}


- (BOOL) isReusable
{
  return YES;
}


- (void) drawWithContext:(FXShapeRenderContext)context
{
  mRenderContext = context;
  if ( context.strokeColor != NULL )
  {
    CGContextSetStrokeColorWithColor(context.graphicsContext, context.strokeColor);
    CGContextSetFillColorWithColor(context.graphicsContext, context.strokeColor);
  }
  [self drawFrame];
  [self drawLeads];
  [self drawPinLabels];
  [self drawLabel];
}


- (NSArray*) paths
{
  return nil;
}


- (NSArray*) circles
{
  return nil;
}


- (NSArray*) connectionPoints
{
  return mLeadPoints;
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:mLeadPoints forKey:@"Lead Points"];
  [encoder encodeInteger:mLeadCount forKey:@"Lead Count"];
  [encoder encodeSize:mSize forKey:@"Size"];
  [encoder encodeObject:self.attributes forKey:@"Attributes"];
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  mLeadCount = [decoder decodeIntegerForKey:@"Lead Count"];
  mLeadPoints = [decoder decodeObjectForKey:@"Lead Points"];
  FXRetain(mLeadPoints)
  self.attributes = [decoder decodeObjectForKey:@"Attributes"];
  mSize = [decoder decodeSizeForKey:@"Size"];
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXDIPShape* newCopy = [[FXDIPShape allocWithZone:zone] initWithLeadCount:mLeadCount];
  NSDictionary* copiedAttributes = [[NSDictionary alloc] initWithDictionary:self.attributes copyItems:YES];
  newCopy.attributes = copiedAttributes;
  FXRelease(copiedAttributes)
  return newCopy;
}


#pragma mark Private


- (void) calculateSize
{
  mSize = CGSizeMake(skDIPWidth, ((mLeadCount/2 - 1)* skDIPLeadSpacing) + (2 * skDIPMargin));
}


- (void) createLeadPoints
{
  NSMutableArray* leadPoints = [NSMutableArray arrayWithCapacity:mLeadCount];
  NSUInteger leadIndex = 0;
  for ( ; leadIndex < mLeadCount; leadIndex++ )
  {
    FX(FXShapeConnectionPoint)* connectionPoint = [[FX(FXShapeConnectionPoint) alloc] init];
    [connectionPoint setName:[NSString stringWithFormat:@"%ld", leadIndex+1]];
    [connectionPoint setLocation:[self locationOfPin:leadIndex]];
    [leadPoints addObject:connectionPoint];
    FXRelease(connectionPoint)
  }
  mLeadPoints = [[NSArray alloc] initWithArray:leadPoints];
}


- (CGPoint) locationOfPin:(NSUInteger)pinIndex
{
  CGPoint result;
  BOOL const leftSide = (pinIndex < mLeadCount/2);
  NSUInteger const numLeadsFromTop = leftSide ? pinIndex : (mLeadCount - 1 - pinIndex);
  result.x = ( leftSide ? -mSize.width : mSize.width) / 2.0;
  result.y = (mRenderContext.flipped ? -1 : 1) * (mSize.height/2.0 - skDIPMargin - (numLeadsFromTop * skDIPLeadSpacing));
  return result;
}


- (void) drawText:(NSString*)text
         location:(CGPoint)textLocation
        alignment:(FXDIPShapeAlignment)textAlignment
       attributes:(CFDictionaryRef)textAttributes
{
  static CFMutableAttributedStringRef sTextString = NULL;
  if ( sTextString == NULL )
  {
    sTextString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
  }
  
  CFAttributedStringReplaceString(sTextString, CFRangeMake(0,CFAttributedStringGetLength(sTextString)), (CFStringRef)text);
  CFAttributedStringSetAttributes(sTextString, CFRangeMake(0,CFAttributedStringGetLength(sTextString)), textAttributes, true);
  CTLineRef textLine = CTLineCreateWithAttributedString(sTextString);  
  CGSize const textSize = CTLineGetImageBounds(textLine, mRenderContext.graphicsContext).size;

  switch( textAlignment.horizontal )
  {
    case FXDIPShapeHorizontalAlignment_Center: textLocation.x -= textSize.width/2.0; break;
    case FXDIPShapeHorizontalAlignment_Right: textLocation.x -= textSize.width; break;
    case FXDIPShapeHorizontalAlignment_Left: break;
  }
  switch( textAlignment.vertical )
  {
    case FXDIPShapeVerticalAlignment_Center: textLocation.y += (mRenderContext.flipped ? 1 : -1) * textSize.height/2.0; break;
    case FXDIPShapeVerticalAlignment_Top: textLocation.y += (mRenderContext.flipped ? 1 : -1) * textSize.height; break;
    case FXDIPShapeVerticalAlignment_Bottom: break;
  }
  CGAffineTransform textTranslation = CGAffineTransformMakeTranslation(textLocation.x, textLocation.y);
  CGContextSetTextMatrix(mRenderContext.graphicsContext, textTranslation );

  CTLineDraw(textLine, mRenderContext.graphicsContext);
  CFRelease(textLine);
}


- (void) drawPinLabel:(NSString*)text
             location:(CGPoint)textLocation
            alignment:(FXDIPShapeAlignment)textAlignment
{
  static CFDictionaryRef sPinTextAttributes = NULL;
  if ( sPinTextAttributes == NULL )
  {
    CTFontRef textFont = CTFontCreateWithName(skDIPTextFontName, 10.0, &CGAffineTransformIdentity);
    CGColorRef textColor = CGColorCreateGenericGray(0.8, 1.0);
    CFStringRef textAttributeKeys[] = { kCTFontAttributeName, kCTForegroundColorAttributeName };
    CFTypeRef textAttributeValues[] = { textFont, textColor };
    sPinTextAttributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)textAttributeKeys, (const void**)textAttributeValues,
      sizeof(textAttributeKeys)/sizeof(textAttributeKeys[0]), &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(textFont);
    CFRelease(textColor);
  }
  [self drawText:text location:textLocation alignment:textAlignment attributes:sPinTextAttributes];
}


- (void) drawDIPLabel:(NSString*)text
             location:(CGPoint)textLocation
            alignment:(FXDIPShapeAlignment)textAlignment
{
  static CFMutableDictionaryRef sDIPTextAttributes = NULL;
  if ( sDIPTextAttributes == NULL )
  {
    CTFontRef textFont = CTFontCreateWithName(skDIPTextFontName, 10.0, &CGAffineTransformIdentity);
    CGColorRef textColor = CGColorCreateGenericGray(0.0, 1.0);
    sDIPTextAttributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 2, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(sDIPTextAttributes, kCTFontAttributeName, textFont);
    CFDictionarySetValue(sDIPTextAttributes, kCTForegroundColorAttributeName, textColor);
    CFRelease(textFont);
    CFRelease(textColor);
  }
  if ( mRenderContext.textColor != NULL )
  {
    if ( CFDictionaryGetValue(sDIPTextAttributes, kCTForegroundColorAttributeName) != mRenderContext.textColor )
    {
      CFDictionarySetValue(sDIPTextAttributes, kCTForegroundColorAttributeName, mRenderContext.textColor);
    }
  }
  [self drawText:text location:textLocation alignment:textAlignment attributes:sDIPTextAttributes];
}


- (void) drawFrame
{
  CGFloat const outerNutWidth = mSize.width * 0.32;
  CGFloat const innerNutWidth = mSize.width * 0.16;
  CGFloat const nutInset = (mRenderContext.flipped ? -1 : 1) * innerNutWidth * 0.3;
  CGFloat const topY = (mRenderContext.flipped ? -1 : 1) * mSize.height/2.0;
  CGFloat const bottomY = (mRenderContext.flipped ? 1 : -1) * mSize.height/2.0;
  CGContextBeginPath(mRenderContext.graphicsContext);
  CGContextMoveToPoint(mRenderContext.graphicsContext, -mSize.width/2.0 + skDIPLeadLength, bottomY);
  CGContextAddLineToPoint(mRenderContext.graphicsContext, -mSize.width/2.0 + skDIPLeadLength, topY);
#if 0 // curved vs. angled notch
  CGFloat const radius = mSize.width * 0.075;
  CGContextAddLineToPoint(mContext, -radius, topY);
  CGContextAddArc(mContext, 0, bottomY, radius, M_PI, 0, 0);
#else
  CGContextAddLineToPoint(mRenderContext.graphicsContext, -outerNutWidth/2.0, topY);
  CGContextAddLineToPoint(mRenderContext.graphicsContext, -innerNutWidth/2.0, topY - nutInset);
  CGContextAddLineToPoint(mRenderContext.graphicsContext, innerNutWidth/2.0, topY - nutInset);
  CGContextAddLineToPoint(mRenderContext.graphicsContext, outerNutWidth/2.0, topY);
#endif
  CGContextAddLineToPoint(mRenderContext.graphicsContext, mSize.width/2.0 - skDIPLeadLength, topY);
  CGContextAddLineToPoint(mRenderContext.graphicsContext, mSize.width/2.0 - skDIPLeadLength, bottomY);
  CGContextClosePath(mRenderContext.graphicsContext);
}


- (void) drawLeads
{
  NSUInteger i = 0;
  for ( ; i < mLeadCount; i++ )
  {
    CGPoint const leadEndLocation = [self locationOfPin:i];
    BOOL const onLeftSide = i < mLeadCount/2;
    CGContextMoveToPoint(mRenderContext.graphicsContext, leadEndLocation.x, leadEndLocation.y);
    CGContextAddLineToPoint(mRenderContext.graphicsContext, onLeftSide ? (leadEndLocation.x + skDIPLeadLength) : (leadEndLocation.x - skDIPLeadLength), leadEndLocation.y);
  }
  CGContextStrokePath(mRenderContext.graphicsContext);
}


- (void) drawPinLabels
{
  FXDIPShapeAlignment textAlignment;
  NSUInteger i = 0;
  for ( ; i < mLeadCount; i++ )
  {
    CGPoint const pinLocation = [self locationOfPin:i];
    BOOL const leftSide =  i < mLeadCount/2;
    CGPoint const leadStartLocation = CGPointMake( leftSide ? (pinLocation.x + skDIPLeadLength + skDIPLabelInset) : (pinLocation.x - skDIPLeadLength - skDIPLabelInset), pinLocation.y );
    textAlignment.horizontal = leftSide ? FXDIPShapeHorizontalAlignment_Left : FXDIPShapeHorizontalAlignment_Right;
    CGContextSaveGState(mRenderContext.graphicsContext);
    [self drawPinLabel:[NSString stringWithFormat:@"%ld", i+1] location:leadStartLocation alignment:textAlignment];
    CGContextRestoreGState(mRenderContext.graphicsContext);
  }
}


- (void) drawLabel
{
  NSString* label = self.attributes[@"label"];
  if ( label != nil )
  {
    FXDIPShapeAlignment centerAlignment;
    CGContextSaveGState(mRenderContext.graphicsContext);
    CGContextRotateCTM(mRenderContext.graphicsContext, M_PI_2);
    [self drawDIPLabel:label location:CGPointMake(0,0) alignment:centerAlignment];
    CGContextRestoreGState(mRenderContext.graphicsContext);
  }
}


@end
