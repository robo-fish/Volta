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

typedef struct
{
  CGContextRef graphicsContext;
  CGColorRef strokeColor;
  CGColorRef textColor;
  BOOL flipped; // whether Y axis values are increasing from top to bottom
}
FXShapeRenderContext;


@protocol FXShape <NSObject, NSCoding>

@property (readonly, copy)   NSArray*      paths; ///< VoltaPath instances
@property (readonly, copy)   NSArray*      circles;
@property (readonly, copy)   NSArray*      connectionPoints; ///< VoltaShapeConnectionPoint instances
@property (readonly)         CGSize        size;
@property (readonly)         BOOL          doesOwnDrawing; ///< whether the shape draws itself or needs to be rendered by an external entity
@property (readonly)         BOOL          isReusable; ///< whether the shape can be reused to represent multiple elements
@property                    NSDictionary* attributes;

/// Called only if doesOwnRendering == YES
- (void) drawWithContext:(FXShapeRenderContext)context;

@end
