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
#import "VoltaSchematic.h"


@interface FX(FXSchematicCapture) : NSObject

- (id) initWithSchematic:(id <VoltaSchematic>)schematic;

- (BOOL) restoreSchematic:(id<VoltaSchematic>)schematic;

/// @return schematic data describing the current state of the schematic.
/// The caller is responsible for deallocating the returned data by using "delete".
+ (VoltaPTSchematicPtr) capture:(id <VoltaSchematic>)schematic;

/// @return wheter the schematic could be successfully restored
+ (BOOL) restoreSchematic:(id <VoltaSchematic>)schematic
              fromCapture:(VoltaPTSchematicPtr)captured;

@end




/// Posted right before a schematic is going to be restored.
/// Notification object: an object conforming to VoltaSchematic
extern NSString* FXSchematicCaptureWillRestoreSchematicNotification;

/// Posted right after a schematic has been restored.
/// Notification object: an object conforming to VoltaSchematic
extern NSString* FXSchematicCaptureDidRestoreSchematicNotification;
