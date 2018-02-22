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
#import "VoltaPersistentTypes.h"

@interface FXShapeFactory : NSObject

+ (FXShapeFactory*) sharedFactory;

+ (id<FXShape>) shapeFromMetaData:(std::vector<VoltaPTMetaDataItem> const &)metaData;

+ (id<FXShape>) shapeFromText:(NSString*)text;

+ (id<FXShape>) shapeWithPersistentShape:(VoltaPTShape const &)shape persistentPins:(std::vector<VoltaPTPin> const &)pins;

@end


extern FXString FXVolta_SubcircuitShapeType;   // Meta data key for shape types specific to KulFX Volta.
extern FXString FXVolta_SubcircuitShapeLabel;  // Meta data key for labels drawn inside the subcircuit shape.
