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

#import "FXPlotterView.h"
#import "FXPlotterAxisRenderer.h"


@implementation FX(FXPlotterView)
{
@private
  FX(FXPlotterAxisRenderer)* mOrdinateRenderer;
  FX(FXPlotterAxisRenderer)* mAbscissaRenderer;
  id<FXPlotterViewClient> __weak mClient;
  CGColorSpaceRef mColorSpace;
  CGContextRef mContext;
  CGColorRef mBackgroundColor;
}

@synthesize client = mClient;
@synthesize backgroundColor = mBackgroundColor;


- (id) initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if ( self != nil )
	{
    static const CGFloat skDefaultBackgroundColor[] = { 1.0, 1.0, 1.0, 1.0 };
    mBackgroundColor = CGColorCreate(mColorSpace, skDefaultBackgroundColor);

    mColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);

    mOrdinateRenderer = [[FX(FXPlotterAxisRenderer) alloc] initWithColorSpace:mColorSpace];
    [mOrdinateRenderer setIsVertical:YES];

    mAbscissaRenderer = [[FX(FXPlotterAxisRenderer) alloc] initWithColorSpace:mColorSpace];
    [mAbscissaRenderer setIsVertical:NO];

    self.plotIndex = -1;
	}
	return self;
}


- (void) dealloc
{
  FXRelease(mOrdinateRenderer)
  FXRelease(mAbscissaRenderer)
  if ( mColorSpace != NULL )
    CGColorSpaceRelease(mColorSpace);
  if ( mBackgroundColor != NULL )
    CGColorRelease(mBackgroundColor);
  FXDeallocSuper
}


#pragma mark NSView overrides


- (void) drawRect:(NSRect)visibleRect
{
  CGRect const rect = [self frame];
  mContext = FXGraphicsContext;
  static const CGFloat skClearColor[] = { 1.0, 1.0, 1.0, 1.0 };
  CGContextSetFillColor(mContext, skClearColor);
  CGContextFillRect(mContext, rect);
  CGContextClipToRect(mContext, visibleRect);

  if ( (self.client != nil) && [self.client hasPlotForIndex:self.plotIndex] )
  {
    CGContextSetFillColorSpace(mContext, mColorSpace);
    CGContextSetStrokeColorSpace(mContext, mColorSpace);

    FXPlotterPlot const & plot = [self.client plotForIndex:self.plotIndex];

    [mOrdinateRenderer setAxisData:plot.getOrdinate()];
    [mAbscissaRenderer setAxisData:plot.getAbscissa()];

    CGFloat abscissaHeight = [mAbscissaRenderer calculateRequiredMarginForContext:mContext];
    CGFloat ordinateWidth = [mOrdinateRenderer calculateRequiredMarginForContext:mContext];
    if ( (abscissaHeight < 0) || (ordinateWidth < 0) )
    {
      // The context is apparently not set up to draw text yet.
      // Forcing setup now by drawing the axes in an arbitrary region.
      [mOrdinateRenderer drawInRect:CGRectMake(rect.size.width/2, rect.size.height/2, 6, 6) withContext:mContext];
      [mAbscissaRenderer drawInRect:CGRectMake(rect.size.width/2, rect.size.height/2, 6, 6) withContext:mContext];
      // Calculating margins again.
      abscissaHeight = [mAbscissaRenderer calculateRequiredMarginForContext:mContext];
      ordinateWidth = [mOrdinateRenderer calculateRequiredMarginForContext:mContext];
      NSAssert( (abscissaHeight >= 0) || (ordinateWidth >= 0), @"The text rendering system is still not set up." );
    }

    // Note: The rect of the graph has an inset so that the line width is not clipped.
    CGFloat const kGraphLineWidth = 2.0;
    CGFloat const kHalfGraphLineWidth = 1.0;
    CGFloat const kQuarterGraphLineWidth = 0.5;
    CGRect const graphRect = CGRectMake(ordinateWidth + kHalfGraphLineWidth, abscissaHeight + kHalfGraphLineWidth, rect.size.width - ordinateWidth - kGraphLineWidth, rect.size.height - abscissaHeight - kGraphLineWidth);
    if ( [NSGraphicsContext currentContextDrawingToScreen] )
    {
      [self drawBackgroundInRect:graphRect];
    }
    [self drawBorderInRect:graphRect withLineWidth:kQuarterGraphLineWidth];
    [self drawGridOfPlot:plot inRect:graphRect withLineWidth:kHalfGraphLineWidth];
    [self drawGraphOfPlot:plot inRect:graphRect withLineWidth:kGraphLineWidth];

    CGRect const abscissaRect = CGRectMake(ordinateWidth + kHalfGraphLineWidth, 0, rect.size.width - ordinateWidth - kGraphLineWidth, abscissaHeight);
    CGRect const ordinateRect = CGRectMake(0, abscissaHeight + kHalfGraphLineWidth, ordinateWidth, rect.size.height - abscissaHeight - kGraphLineWidth);
    [mOrdinateRenderer drawInRect:ordinateRect withContext:mContext];
    [mAbscissaRenderer drawInRect:abscissaRect withContext:mContext];
  }
}


#pragma mark Public


- (void) refresh
{
  [self setNeedsDisplay:YES];
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


#pragma mark Private


- (void) drawBackgroundInRect:(CGRect)rect
{
#if 1 // draw with gradient
  static const CGFloat skColorComponents[] = { 1.0, 1.0, 1.0, 1.0,   0.92, 1.0, 0.92, 1.0 };
  static const CGFloat skColorStops[] = { 0.0, 1.0 };
  CGContextSaveGState(mContext);
  CGContextBeginPath(mContext);
  CGContextAddRect(mContext, rect);
  CGContextClosePath(mContext);
  CGContextClip(mContext);
  CGGradientRef gradient = CGGradientCreateWithColorComponents(mColorSpace, skColorComponents, skColorStops, 2);
  CGContextDrawLinearGradient(mContext, gradient, CGPointMake(0.0, rect.size.height), CGPointMake(0.0, 0.0), (kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation));
  CGGradientRelease(gradient);
  CGContextRestoreGState(mContext);
#else
  CGContextSetFillColorWithColor( mContext, mBackgroundColor );
  CGContextFillRect( mContext, rect );
#endif
}


- (void) drawBorderInRect:(CGRect)rect withLineWidth:(CGFloat)lineWidth
{
  static const CGFloat skBorderColor[] = { 0.2, 0.25, 0.2, 1.0 };
  CGContextSaveGState(mContext);
  CGContextSetStrokeColor(mContext, skBorderColor);
  CGContextSetLineWidth(mContext, lineWidth);
  CGContextStrokeRect(mContext, (CGRect)rect);
  CGContextRestoreGState(mContext);
}



- (void) drawGridlines:(FXPlotterGridlines const &)gridlines inRect:(CGRect)rect withLineWidth:(CGFloat)lineWidth isVertical:(BOOL)vertical
{
  static const CGFloat skGridColor[] = { 0.7, 0.7, 0.7, 1.0 };
  CGContextSaveGState(mContext);
  CGContextSetStrokeColor(mContext, skGridColor);
  CGContextBeginPath(mContext);
  for ( FXPlotterGridline const & gridline : gridlines )
  {
    if ( vertical )
    {
      CGFloat posX = rect.origin.x + rintf(gridline.position * rect.size.width);
      CGContextMoveToPoint(mContext, posX, rect.origin.y);
      CGContextAddLineToPoint(mContext, posX, rect.origin.y + rect.size.height);
    }
    else
    {
      CGFloat posY = rect.origin.y + rintf(gridline.position * rect.size.height);
      CGContextMoveToPoint(mContext, rect.origin.x, posY);
      CGContextAddLineToPoint(mContext, rect.origin.x + rect.size.width, posY);
    }
  }
  CGContextSetLineWidth(mContext, lineWidth);
  CGContextStrokePath(mContext);
  CGContextRestoreGState(mContext);
}


- (void) drawGridOfPlot:(FXPlotterPlot const &)plot inRect:(CGRect)rect withLineWidth:(CGFloat)lineWidth
{
  [self drawGridlines:plot.getAbscissa().getGridlines() inRect:rect withLineWidth:lineWidth isVertical:YES];
  [self drawGridlines:plot.getOrdinate().getGridlines() inRect:rect withLineWidth:lineWidth isVertical:NO];
}


- (CGPoint) dataPointOfPlot:(FXPlotterPlot const &)plot atIndex:(int)index
{
  NSAssert( index >= 0, @"Invalid negative index." );
  NSAssert( index < plot.getOrdinate().getData().size(), @"Index of ordinate sample point out of bounds." );
  NSAssert( index < plot.getAbscissa().getData().size(), @"Index of abscissa sample point out of bounds." );
  CGPoint const dataPoint = CGPointMake( plot.getAbscissa().getData().at(index), plot.getOrdinate().getData().at(index) );
  return dataPoint;
}


- (void) drawGraphOfPlot:(FXPlotterPlot const &)plot inRect:(CGRect)rect withLineWidth:(CGFloat)lineWidth
{
  FXPlotterAxisData const & abscissa = plot.getAbscissa();
  FXPlotterAxisData const & ordinate = plot.getOrdinate();
  FXPlotterRoundedValueRange const abscissaRoundedValueRange = abscissa.getRoundedValueRange();
  FXPlotterRoundedValueRange const ordinateRoundedValueRange = ordinate.getRoundedValueRange();

  CGFloat factorX, factorY, offsetX, offsetY;

  if (abscissa.getScaleType() == FXPlotterScaleType::Linear)
  {
    factorX = rect.size.width / (abscissaRoundedValueRange.max.toFloat() - abscissaRoundedValueRange.min.toFloat());
    offsetX = rect.origin.x - (factorX * abscissaRoundedValueRange.min.toFloat());
  }
  else
  {
    factorX = rect.size.width / (abscissaRoundedValueRange.max.exponent - abscissaRoundedValueRange.min.exponent);
    offsetX = rect.origin.x - (factorX * abscissaRoundedValueRange.min.exponent);
  }

  if (ordinate.getScaleType() == FXPlotterScaleType::Linear)
  {
    factorY = rect.size.height / (ordinateRoundedValueRange.max.toFloat() - ordinateRoundedValueRange.min.toFloat());
    offsetY = rect.origin.y - factorY * ordinateRoundedValueRange.min.toFloat();
  }
  else
  {
    factorY = rect.size.height / (ordinateRoundedValueRange.max.exponent - ordinateRoundedValueRange.min.exponent);
    offsetY = rect.origin.y - (factorY * ordinateRoundedValueRange.min.exponent);
  }

  size_t const numSamples = abscissa.getData().size();
  NSAssert( numSamples == ordinate.getData().size(), @"PlotterView: The number of samples of abscissa and ordinate do not match." );
  if ( numSamples > 1 )
  {
    static const CGFloat skGraphColor[] = { 0.0, 0.0, 0.0, 1.0 };

    CGContextSaveGState(mContext);
    CGContextBeginPath(mContext);
    CGPoint startPoint = [self dataPointOfPlot:plot atIndex:0];
    startPoint = CGPointMake( factorX * startPoint.x + offsetX, factorY * startPoint.y + offsetY );
    CGContextMoveToPoint(mContext, startPoint.x, startPoint.y);
    for (int currentSampleIndex = 1; currentSampleIndex < numSamples; currentSampleIndex++ )
    {
      CGPoint currentPoint = [self dataPointOfPlot:plot atIndex:currentSampleIndex];
      currentPoint = CGPointMake( factorX * currentPoint.x + offsetX, factorY * currentPoint.y + offsetY );
      CGContextAddLineToPoint(mContext, currentPoint.x, currentPoint.y );
    }
    CGContextSetLineWidth(mContext, lineWidth);
    CGContextSetStrokeColor(mContext, skGraphColor);
    CGContextStrokePath(mContext);
    CGContextRestoreGState(mContext);
  }
}


@end
