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

#import "VoltaPersistentTypes.h"
#import "FXShape.h"

@interface FXBasicShape : NSObject <FXShape, NSCopying>

/// Designated initializer.
/// @param paths array of FXPath objects
/// @param circles array of FXCircle objects
/// @param connectionPoints array of FXShapeConnectionPoint objects
/// @param shapeSize the dimensions of the bounding box of the shape
- (id) initWithPaths:(NSArray*)paths circles:(NSArray*)circles connectionPoints:(NSArray*)connectionPoints size:(CGSize)shapeSize;

/// Convenience initializer
- (id) initWithPersistentShape:(VoltaPTShape const &)shape persistentPins:(std::vector<VoltaPTPin> const &)pins;

@end
