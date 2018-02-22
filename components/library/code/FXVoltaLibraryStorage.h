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
#import "FXVoltaLibraryData.h"


typedef NS_ENUM(NSInteger, FXVoltaLibraryStorageItemType)
{
  FXVoltaLibraryStorageItem_None = -1,

  FXVoltaLibraryStorageItem_Model,
  FXVoltaLibraryStorageItem_Element,
  FXVoltaLibraryStorageItem_Subcircuit
};


@interface FXVoltaLibraryStorage : NSObject

@property (readonly) NSURL* rootLocation;

/// The standard location for the root folder where library data is stored.
/// This is inside the 'Application Support' folder of the application's container folder.
+ (NSURL*) standardRootLocation;

/// A root location for test purposes.
+ (NSURL*) testRootLocation;

/// Designated initializer.
/// @param rootLocation The root folder, under which subcircuits, models and
/// palette elements are stored in their respective sub-folders.
- (id) initWithRootLocation:(NSURL*)rootLocation;

/// Loads stored items of the given type into the given library data structure.
- (void) loadStoredItemsOfType:(FXVoltaLibraryStorageItemType)type
               intoLibraryData:(FXVoltaLibraryData*)data;

/// Loads all items of all types, including built-in models, into the given library data.
- (void) loadAllItemsIntoLibraryData:(FXVoltaLibraryData*)data;

/// Stores all items of the given type from the given library
- (void) storeItemsOfType:(FXVoltaLibraryStorageItemType)type
          fromLibraryData:(FXVoltaLibraryData*)data;

/// Convenience method that stores items of all types from the given library data
- (void) storeItemsFromLibraryData:(FXVoltaLibraryData*)libraryData;

/// The location where subcircuits are stored.
/// If the location is a file URL and the referenced folder does not exist it will be created.
- (NSURL*) subcircuitsLocation;

/// The location where archived element groups are stored.
/// If the location is a file URL and the referenced folder does not exist it will be created.
- (NSURL*) paletteLocation;

/// The location where user-defined models are stored.
/// If the location is a file URL and the referenced folder does not exist it will be created.
- (NSURL*) modelsLocation;

@end
