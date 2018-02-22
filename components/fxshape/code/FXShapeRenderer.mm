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

#import "FXShapeRenderer.h"
#import "FXPath.h"
#import "FXSegment.h"
#import "FXCircle.h"
#import "FXVector.h"
#import "FXShapeRenderDataPool.h"


@implementation FXShapeRenderer
{
@private
  FXShapeRenderDataPool mRenderDataPool;
}

#pragma mark Singleton implementation

static FX(FXShapeRenderer)* sShapeRenderer = nil;

+ (FX(FXShapeRenderer)*) sharedRenderer
{
  @synchronized( self )
  {
    if ( sShapeRenderer == nil )
    {
      sShapeRenderer = [[FX(FXShapeRenderer) alloc] init];
    }
  }
  return sShapeRenderer;
}

+ (id) allocWithZone:(NSZone*)zone
{
  @synchronized(self)
  {
    if ( sShapeRenderer == nil )
    {
      sShapeRenderer = [super allocWithZone:zone];
      return sShapeRenderer;  // assignment and return on first allocation
    }
  }
  return nil; //on subsequent allocation attempts return nil
}

- (id) copyWithZone:(NSZone *)zone
{
  return self;
}


#pragma mark Public


- (void) renderShape:(id<FXShape>)shape
         withContext:(FXShapeRenderContext)context
            forHiDPI:(BOOL)hiDPI
         scaleFactor:(CGFloat)scaleFactor
{
  CGFloat const scale = hiDPI ? 2 * scaleFactor : scaleFactor;
  if ( [shape doesOwnDrawing] )
  {
    CGContextScaleCTM( context.graphicsContext, scale, scale );
    [shape drawWithContext:context];
  }
  else
  {
    FXShapeRenderData & renderData = mRenderDataPool.getRenderDataForShape(shape);

    CGContextSaveGState( context.graphicsContext );
    if ( context.strokeColor != NULL )
    {
      CGContextSetStrokeColorWithColor(context.graphicsContext, context.strokeColor);
      CGContextSetFillColorWithColor(context.graphicsContext, context.strokeColor);
    }
    CGContextScaleCTM( context.graphicsContext, scale, context.flipped ? -scale : scale );

    for( FXPathInfo & pathInfo : renderData.pathArray )
    {
      CGContextBeginPath( context.graphicsContext );
      CGContextAddPath( context.graphicsContext, pathInfo.path );
      if ( pathInfo.filled )
      {
        CGContextFillPath( context.graphicsContext );
      }
      else
      {
        CGContextStrokePath( context.graphicsContext );
      }
    }

    CGContextRestoreGState( context.graphicsContext );
  }
}


- (CGImageRef) newImageFromShape:(id<FXShape>)shape
                 backgroundColor:(CGColorRef)backgroundColor
                     strokeColor:(CGColorRef)strokeColor
                       fillColor:(CGColorRef)fillColor
                        forHiDPI:(BOOL)hiDPI
                     scaleFactor:(CGFloat)scale
{
  if ( shape == nil )
    return NULL;

  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);

  // The effective width and height are a little larger due to stroke width
  int const lineWidthCompensation = 2;
  int const shapeWidth = (int)ceil(scale*(ceil(shape.size.width) + lineWidthCompensation));
  int const shapeHeight = (int)ceil(scale*(ceil(shape.size.height) + lineWidthCompensation));
  CGSize const bitmapSize = CGSizeMake(hiDPI ? 2 * shapeWidth : shapeWidth, hiDPI ? 2 * shapeHeight : shapeHeight);
  size_t const numComponents = 4; // RGBA, 8 bit each
  size_t const bitsPerComponent = 8;
  size_t const bytesPerRow = numComponents * bitmapSize.width;

  void* bitmapData = calloc( bitmapSize.height, bytesPerRow );
  CGContextRef bitmapContext = CGBitmapContextCreate( bitmapData, bitmapSize.width, bitmapSize.height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast );
  NSAssert( bitmapContext != NULL, @"Image cache drawing context could not be created." );
  if ( backgroundColor != NULL )
  {
    CGContextSetFillColorWithColor( bitmapContext, backgroundColor );
    CGContextFillRect( bitmapContext, CGRectMake(0, 0, bitmapSize.width, bitmapSize.height) );
  }
  CGContextSetStrokeColorWithColor( bitmapContext, strokeColor );
  CGContextSetFillColorWithColor( bitmapContext, fillColor );
  CGContextTranslateCTM( bitmapContext, round(bitmapSize.width/2), round(bitmapSize.height/2) );
  FXShapeRenderContext renderContext;
  renderContext.graphicsContext = bitmapContext;
  renderContext.flipped = NO;
  renderContext.strokeColor = strokeColor;
  renderContext.textColor = strokeColor;
  [self renderShape:shape withContext:renderContext forHiDPI:hiDPI scaleFactor:scale];
  CGImageRef image = CGBitmapContextCreateImage( bitmapContext );
  
  CGContextRelease( bitmapContext );
  free( bitmapData );
  CGColorSpaceRelease(colorSpace);

  return image;
}


- (NSImage*) imageFromCGImage:(CGImageRef)cgImage pointSize:(CGSize)imagePointSize
{
  NSAssert( cgImage != NULL, @"Error while creating the image chache." );
  if ( cgImage == NULL )
    return nil;

  NSBitmapImageRep* imageRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
  imageRep.size = imagePointSize;

  NSImage* image = [[NSImage alloc] initWithSize:imagePointSize];
  [image addRepresentation:imageRep];
  FXRelease(imageRep)

  FXAutorelease(image)
  return image;
}


- (NSImage*) iconImageForShape:(id<FXShape>)shape
                      forHiDPI:(BOOL)hiDPI
                   scaleFactor:(CGFloat)scale
{
  NSImage* iconImage = nil;

  CGColorRef blackColor = CGColorCreateGenericRGB(0, 0, 0, 1);
  CGImageRef cgImage = [self newImageFromShape:shape backgroundColor:NULL strokeColor:blackColor fillColor:blackColor forHiDPI:hiDPI scaleFactor:scale];
  CGColorRelease(blackColor);

  if ( cgImage != NULL )
  {
    CGFloat scale = hiDPI ? 2 : 1;
    CGSize const pointSize = CGSizeMake( CGImageGetWidth(cgImage)/scale, CGImageGetHeight(cgImage)/scale );
    iconImage = [self imageFromCGImage:cgImage pointSize:pointSize];
    CGImageRelease(cgImage);
  }

  return iconImage;
}


@end
