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

#import "FXShape.h"

@interface FXShapeRenderer : NSObject

+ (FXShapeRenderer*) sharedRenderer;

- (void) renderShape:(id<FXShape>)shape
         withContext:(FXShapeRenderContext)renderContext
            forHiDPI:(BOOL)hiDPI
         scaleFactor:(CGFloat)scale;

- (CGImageRef) newImageFromShape:(id<FXShape>)shape
                 backgroundColor:(CGColorRef)backgroundColor
                     strokeColor:(CGColorRef)strokeColor
                       fillColor:(CGColorRef)fillColor
                        forHiDPI:(BOOL)hiDPI
                     scaleFactor:(CGFloat)scale;

- (NSImage*) imageFromCGImage:(CGImageRef)cgImage
                    pointSize:(CGSize)imagePointSize;

/// Convenience method for creating icons from a shape.
/// Draws shapes by using black color for stroking and filling.
- (NSImage*) iconImageForShape:(id<FXShape>)shape
                      forHiDPI:(BOOL)hiDPI
                   scaleFactor:(CGFloat)scale;

@end
