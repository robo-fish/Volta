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

#import "FXSchematicPaletteView.h"


@implementation FXSchematicPaletteView
{
@private
  CGColorSpaceRef mColorspace;
  CGGradientRef mGradient;
}


- (id) initWithFrame:(NSRect)frame
{
  if ( (self = [super initWithFrame:frame]) != nil )
  {
    mColorspace = NULL;
    mGradient = NULL;
  }
  return self;
}


- (void) dealloc
{
  if ( mColorspace != NULL )
  {
    CGColorSpaceRelease(mColorspace);
  }
  if ( mGradient != NULL )
  {
    CGGradientRelease(mGradient);
  }
  FXDeallocSuper
}


- (void) drawRect:(NSRect)visibleRect
{  
  if ( mGradient == NULL )
  {
    CGFloat gradientStopLocations[2] = { 0.0, 1.0 };
    CGFloat gradientStopColors[8] = {
      0.97, 1.00, 0.97, 1.0,
      0.90, 0.93, 0.90, 1.0 };
    mColorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    mGradient = CGGradientCreateWithColorComponents(mColorspace, gradientStopColors, gradientStopLocations, 2);
  }
  
  CGContextRef context = FXGraphicsContext;
  CGContextDrawLinearGradient(context, mGradient, CGPointMake(0,self.bounds.size.height), CGPointMake(0,0), 0);
}


@end
