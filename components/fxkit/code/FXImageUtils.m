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

#import "FXImageUtils.h"


@implementation FXImageUtils


+ (NSImage*) newColorInvertedImageFromImage:(NSImage*)image
{
  CIImage* colorInvertedCIImage = [self colorInvertedCIImageFromNSImage:image];
  NSImage* result = [self newImageFromCIImage:colorInvertedCIImage];
  return result;
}


+ (NSImage*) newImageFromImage:(NSImage*)image withBrightnessChange:(float)deltaBrightness
{
  CIImage* adjustedImage = [self CIImageFromNSImage:image withAdjustedBrightness:deltaBrightness];
  NSImage* result = [self newImageFromCIImage:adjustedImage];
  return result;
}


+ (CIImage*) colorInvertedCIImageFromNSImage:(NSImage*)image
{
  CIImage* inputImage = [[CIImage alloc] initWithData:[image TIFFRepresentation]];
  CIFilter* filter = [CIFilter filterWithName:@"CIColorInvert"];
  [filter setDefaults];
  [filter setValue:inputImage forKey:@"inputImage"];
  CIImage* outputImage = [filter valueForKey:@"outputImage"];
  FXRelease(inputImage)
  return outputImage;
}


+ (CIImage*) CIImageFromNSImage:(NSImage*)image withAdjustedBrightness:(float)brightness
{
  CIFilter* filter= [CIFilter filterWithName:@"CIColorControls"];
  CIImage* inputImage = [[CIImage alloc] initWithData:[image TIFFRepresentation]];
  [filter setValue:inputImage forKey:@"inputImage"];
  brightness = MAX( -1.0, MIN(1.0, brightness) );
  [filter setValue:[NSNumber numberWithFloat:brightness] forKey:@"inputBrightness"];
  CIImage* outputImage = [filter valueForKey:@"outputImage"];
  FXRelease(inputImage)
  return outputImage;
}


+ (NSImage*) newImageFromCIImage:(CIImage*)ciImage
{
  CGSize const imageSize = [ciImage extent].size;
  NSImage *image = [[NSImage alloc] initWithSize:imageSize];
  [image lockFocus];
#if 0
  // Supposedly this leaks memory
  [[[NSGraphicsContext currentContext] CIContext] drawImage:ciImage atPoint:CGPointMake(0, 0) fromRect:[ciImage extent]];
#else
  // The software renderer prevents leaks
  CGContextRef contextRef = [[NSGraphicsContext currentContext] graphicsPort];
  NSDictionary* renderOptions = @{ kCIContextUseSoftwareRenderer : @YES };
  CIContext *ciContext = [CIContext contextWithCGContext:contextRef options:renderOptions];
  [ciContext drawImage:ciImage inRect:CGRectMake(0,0,imageSize.width,imageSize.height) fromRect:ciImage.extent];
#endif
  [image unlockFocus];
  return image;
}


@end
