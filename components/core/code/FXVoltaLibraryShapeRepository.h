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


typedef NS_ENUM(short, FXShapeSearchStrategy)
{
  FXShapeSearch_MatchExactly    = 0,
  FXShapeSearch_AnySubtype      = 1,
};


@interface FXVoltaLibraryShapeRepository : NSObject

- (void) addShape:(id<FXShape>)shape
     forModelType:(VoltaModelType)type
          subtype:(NSString*)subtype
             name:(NSString*)modelName
           vendor:(NSString*)vendorName;

- (id<FXShape>) findShapeForModelType:(VoltaModelType)modelType
                              subtype:(NSString*)subtype
                                 name:(NSString*)modelName
                               vendor:(NSString*)vendor
                             strategy:(FXShapeSearchStrategy)strategy;

- (void) removeShapeForModelType:(VoltaModelType)modelType
                         subtype:(NSString*)subtype
                            name:(NSString*)modelName
                          vendor:(NSString*)vendor;

- (void) createAndStoreShapeForModel:(VoltaPTModelPtr)model
                  makeDefaultForType:(BOOL)isDefaultShape;


- (void) renameShapeWithType:(VoltaModelType)modelType
                     subtype:(FXString const &)subtype
                     oldName:(FXString const &)oldName
                   oldVendor:(FXString const &)vendor
                     newName:(FXString const &)newName
                   newVendor:(FXString const &)newVendor;

- (void) removeShapesOfType:(VoltaModelType)modelType
                    subtype:(NSString*)subtype;

/// @return the default shape or nil if no default shape has been registered for the given type and subtype.
- (id<FXShape>) defaultShapeForModelType:(VoltaModelType)type subtype:(NSString*)subtype;

@end
