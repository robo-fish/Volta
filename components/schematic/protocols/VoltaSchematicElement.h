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

#import "SchematicRelativePosition.h"
#import "VoltaModelTypes.h"

@protocol VoltaSchematic;
@protocol FXShape;


@protocol VoltaSchematicElement <NSObject, NSCopying>

@property (copy) NSString* name;
@property (copy) NSString* modelName;
@property (copy) NSString* modelVendor;
@property FXPoint location;    ///< location of the center of the element's shape
@property CGFloat rotation;    ///< counterclockwise from the x-axis, in degrees radian
@property BOOL flipped;        ///< whether the element's shape is flipped horizontally (after rotating)
@property (nonatomic, readonly) CGSize size; ///< the dimensions of the bounding box
@property (nonatomic, readonly) CGRect boundingBox;
@property VoltaModelType type;
@property (nonatomic, readonly) id<VoltaSchematic> schematic; ///< the schematic that contains the receiver
@property (nonatomic, readonly) id<FXShape> shape;
@property SchematicRelativePosition labelPosition; ///< the label position relative to the shape

- (BOOL) isEqualToSchematicElement:(id<VoltaSchematicElement>)otherElement;

- (NSUInteger) numberOfProperties;

- (void) enumeratePropertiesUsingBlock:(void (^)(NSString* key, id value, BOOL* stop))block;

/// We are deliberately using this accessor instead of fully exposing a dictionary object.
/// @return the stored object for the given key.
- (id) propertyValueForKey:(NSString*)key;

/// @param value can be nil, in which case the entry for the given key will be removed
/// @param key should not be nil
- (void) setPropertyValue:(id)value forKey:(NSString*)key;

- (void) removeAllProperties;

- (void) prepareShapeForDrawing;

@end


/// The notification object is the VoltaSchematic which the updated element belongs to.
extern NSString* VoltaSchematicElementUpdateNotification;
