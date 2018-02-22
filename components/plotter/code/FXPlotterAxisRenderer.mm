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

#import "FXPlotterAxisRenderer.h"
#import "FXPlotterUtils.h"
#import <cmath>
#import <limits.h>


static CGFloat const skGridlineLabelColor[] = { 0.0, 0.0, 0.0, 1.0 };
static CGFloat const skAxisTitleColor[] = { 0.0, 0.3, 0.0, 1.0 };
static CGFloat const skAxisTitlePrintColor[] = { 0.3, 0.3, 0.3, 1.0 };
static const CGFloat skTextMargin = 6.0; // both horizontal and vertical


@implementation FX(FXPlotterAxisRenderer)
{
@private
  BOOL mIsVertical;
  FXPlotterAxisData mAxisData;
  CGContextRef mContext;
  CGColorSpaceRef mColorSpace;
  CGColorRef mBackgroundColor;
  CFDictionaryRef mTextAttributes;
  CFMutableAttributedStringRef mText;
}

@synthesize isVertical = mIsVertical;
@synthesize backgroundColor = mBackgroundColor;


- (id) initWithColorSpace:(CGColorSpaceRef)colorSpace;
{
	self = [super init];
	if ( self != nil )
	{
    mIsVertical = NO;
    if ( colorSpace != NULL )
    {
      mColorSpace = colorSpace;
      CGColorSpaceRetain(mColorSpace);
      static const CGFloat skDefaultBackgroundColor[] = { 1.0, 1.0, 1.0, 1.0 };
      mBackgroundColor = CGColorCreate(mColorSpace, skDefaultBackgroundColor);
    }
	}
	return self;
}


- (void) dealloc
{
  [self releaseGraphicsObjects];
  FXDeallocSuper
}


#pragma mark Public


- (CGFloat) calculateRequiredMarginForContext:(CGContextRef)context
{
  mContext = context;

  CGFloat result = 3 * skTextMargin; // fix margin

  // Calculating the margin for the axis title
  if ( !mAxisData.getTitle().empty() )
  {
    NSString* titleString = (__bridge NSString*)mAxisData.getTitle().cfString();
    CTLineRef line = [self createTextLineFromString:titleString];
    CGSize const lineSize = [self sizeOfTextLine:line];
    CFRelease(line);
    if ( (lineSize.width == 0) || (lineSize.height == 0) )
    {
      return -1; // The graphics context is probably not yet initialized to provide text metrics. Aborting.
    }
    result += lineSize.height;
  }

  // Calculating the margin for the gridline labels
  {
    CGFloat maxTextMargin = 0;
    for (FXPlotterGridline gridline : mAxisData.getGridlines())
    {
      NSString* labelString = [FXPlotterAxisRenderer labelStringForPlotterNumber:gridline.value preferredScaleType:mAxisData.getScaleType()];
      NSString* processedLabelString = [FXPlotterUtils processSuperscriptsInLabelString:labelString];
      CTLineRef textLine = [self createTextLineFromString:processedLabelString];
      CGSize const textLineSize = [self sizeOfTextLine:textLine];
      CGFloat const textMargin = ceilf(mIsVertical ? textLineSize.width : textLineSize.height);
      maxTextMargin = (maxTextMargin < textMargin) ? textMargin : maxTextMargin;
      CFRelease(textLine);
    }
    result += maxTextMargin;
  }

  return result;
}


- (void) drawInRect:(CGRect)rect withContext:(CGContextRef)context
{
  mContext = context;
  if ( mColorSpace == NULL )
  {
    mColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  }
  CGContextSetFillColorSpace(mContext, mColorSpace);
  CGContextSetStrokeColorSpace(mContext, mColorSpace);
  
  [self drawBackgroundInRect:rect];
  [self drawGridlineLabelsInRect:rect];
  [self drawAxisTitleInRect:rect];
}


- (void) setBackgroundColor:(CGColorRef)backgroundColor
{
  if ( backgroundColor != mBackgroundColor )
  {
    if ( mBackgroundColor != NULL )
    {
      CGColorRelease(mBackgroundColor);
    }
    mBackgroundColor = backgroundColor;
    CGColorRetain(mBackgroundColor);
  }
}


- (void) setAxisData:(const FXPlotterAxisData &)axisData
{
  mAxisData = axisData;
}


- (void) clear
{
  FXPlotterAxisData emptyAxisData;
  mAxisData = emptyAxisData;
}


#pragma mark Private


- (void) releaseGraphicsObjects
{
  if ( mColorSpace != NULL )
    CGColorSpaceRelease(mColorSpace);
  if ( mBackgroundColor != NULL )
    CGColorRelease(mBackgroundColor);
  if ( mText != NULL )
    CFRelease(mText);
  if ( mTextAttributes != NULL )
    CFRelease(mTextAttributes);
}


- (void) drawBackgroundInRect:(CGRect)rect
{
  CGContextSetFillColorWithColor( mContext, mBackgroundColor );
  CGContextFillRect( mContext, rect );
}


- (void) initializeTextObjects
{
  CTFontRef font = CTFontCreateWithName(CFSTR("Lucida-Grande"), 12.0, &CGAffineTransformIdentity);
  CFStringRef attributeKeys[] = { kCTFontAttributeName, kCTForegroundColorFromContextAttributeName };
  CFTypeRef attributeValues[] = { font, kCFBooleanTrue };
  mTextAttributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)attributeKeys, (const void**)attributeValues, sizeof(attributeKeys)/sizeof(attributeKeys[0]), &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFRelease(font);
  mText = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
}


+ (NSString*) labelStringForPlotterNumber:(FXPlotterNumber const &)number preferredScaleType:(FXPlotterScaleType)scaleType
{
  NSString* result = nil;

  if ( number.significand == 0 )
  {
    result = @"0";
  }
  else if ( number.exponent == 0 )
  {
    result = [NSString stringWithFormat:@"%d", number.significand];
  }
  else if ( (number.significand == 1) || (number.significand == -1) )
  {
    if ( (scaleType == FXPlotterScaleType::Log10) || (number.exponent > 2) || (number.exponent < -2) )
    {
      NSString* formatString = (number.significand == 1) ? @"10^%d" : @"-10^%d";
      result = [NSString stringWithFormat:formatString, number.exponent];
    }
    else
    {
      NSNumber* floatNumber = @(number.significand * powf(10, number.exponent));
      result = [NSNumberFormatter localizedStringFromNumber:floatNumber numberStyle:NSNumberFormatterDecimalStyle];
    }
  }
  else
  {
    float const value = number.significand * powf(10, number.exponent);
    float const absValue = fabs(value);
    if ( (scaleType == FXPlotterScaleType::Linear) && (fabs(number.significand) < 10) && (absValue < 1000) && (absValue > 0.01) )
    {
      result = [NSNumberFormatter localizedStringFromNumber:@(value) numberStyle:NSNumberFormatterDecimalStyle];
    }
    else if ( fabs(number.significand) >= 10 )
    {
      result = [FXPlotterUtils stringForNumber:number byReducingSignificand:YES];
    }
    else
    {
      result = [NSString stringWithFormat:@"%d*10^%d", number.significand, number.exponent];
    }
  }

  return result;
}


- (CTLineRef) createTextLineFromString:(NSString*)textString
{
  if ( mText == NULL )
  {
    [self initializeTextObjects];
  }

  NSAssert( mText != NULL, @"Could not initialize text objects for rendering a plotter axis." );
  CFAttributedStringReplaceString(mText, CFRangeMake(0,CFAttributedStringGetLength(mText)), (CFStringRef)textString);
  CFAttributedStringSetAttributes(mText, CFRangeMake(0,CFAttributedStringGetLength(mText)), mTextAttributes, true);
  return CTLineCreateWithAttributedString(mText);
}


- (CGSize) sizeOfTextLine:(CTLineRef)line
{
  static CGFloat const skBufferMargin = 2.0;
  CGSize result = CTLineGetImageBounds(line, mContext).size;
  if ( (result.width > 0) && (result.height > 0) )
  {
    result.width = ceil(result.width + skBufferMargin);
    result.height = ceil(result.height + skBufferMargin);
  }
  return result;
}


- (CGPoint) calculatePositionForGridlineLabel:(CTLineRef)line atRelativePosition:(float)relPosition inRect:(CGRect const)rect
{
  CGPoint labelPos = CGPointZero;
  CGSize const size = [self sizeOfTextLine:line];
  CGFloat const pos = mIsVertical ? (rect.origin.x + rect.size.width - skTextMargin) : (rect.origin.y + rect.size.height - skTextMargin);

  if ( mIsVertical )
  {
    labelPos.x = pos - size.width;
    labelPos.y = rect.origin.y + rintf(relPosition * rect.size.height);
    if ( (labelPos.y + size.height/2.0) > (rect.origin.y + rect.size.height) )
    {
      labelPos.y = rect.origin.y + rect.size.height - size.height;
    }
    else if ( (labelPos.y - size.height/2.0) < rect.origin.y )
    {
      labelPos.y = rect.origin.y;
    }
    else
    {
      labelPos.y -= size.height/2.0;
    }
  }
  else
  {
    labelPos.x = rect.origin.x + rintf(relPosition * rect.size.width);
    if ( (labelPos.x + size.width/2.0) > (rect.origin.x + rect.size.width) )
    {
      labelPos.x = rect.origin.x + rect.size.width - size.width;
    }
    else if ( (labelPos.x - size.width/2.0) < rect.origin.x )
    {
      labelPos.x = rect.origin.x;
    }
    else
    {
      labelPos.x -= size.width/2.0;
    }
    labelPos.y = pos - size.height;
  }
  return labelPos;
}


- (void) drawGridlineLabelsInRect:(CGRect)rect
{

  if ( (mText == NULL) || (mTextAttributes == NULL) )
  {
    [self initializeTextObjects];
    NSAssert( mTextAttributes != NULL, @"No valid text attributes object for displaying scale mark labels." );
    NSAssert( mText != NULL, @"No valid text object for displaying scale mark labels." );
  }

  CGContextSaveGState(mContext);
  CGContextSetFillColor(mContext, skGridlineLabelColor);

  for (FXPlotterGridline gridline : mAxisData.getGridlines())
  {
    NSString* valueString = [FXPlotterAxisRenderer labelStringForPlotterNumber:gridline.value preferredScaleType:mAxisData.getScaleType()];
    valueString = [FXPlotterUtils processSuperscriptsInLabelString:valueString];
    CTLineRef textLine = [self createTextLineFromString:valueString];
    CGPoint const labelPos = [self calculatePositionForGridlineLabel:textLine atRelativePosition:gridline.position inRect:rect];
    
    CGContextSetTextMatrix(mContext, CGAffineTransformMakeTranslation(labelPos.x, labelPos.y) );
    CTLineDraw(textLine, mContext);
    CFRelease(textLine);
  }

  CGContextRestoreGState(mContext);
}


- (void) drawAxisTitleInRect:(CGRect)rect
{
  FXString title = mAxisData.getTitle();
  if ( !title.empty() )
  {
    CGContextSaveGState(mContext);
    CGContextSetFillColor(mContext, [NSGraphicsContext currentContextDrawingToScreen] ? skAxisTitleColor : skAxisTitlePrintColor);
    CTLineRef titleLine = [self createTextLineFromString:(__bridge NSString*)title.cfString()];
    CGSize const titleLineSize = [self sizeOfTextLine:titleLine];
    CGAffineTransform xform;
    if ( mIsVertical )
    {
      xform = CGAffineTransformMakeRotation(M_PI_2);
      xform = CGAffineTransformConcat(xform, CGAffineTransformMakeTranslation(rect.origin.x + skTextMargin + titleLineSize.height, rect.origin.y + (rect.size.height - titleLineSize.width)/2.0));
    }
    else
    {
      xform = CGAffineTransformMakeTranslation(rect.origin.x + (rect.size.width - titleLineSize.width)/2.0, rect.origin.y + skTextMargin);
    }
    CGContextSetTextMatrix(mContext, xform);
    CTLineDraw(titleLine, mContext);
    CFRelease(titleLine);
    CGContextRestoreGState(mContext);
  }
}


@end
