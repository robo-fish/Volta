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

#import "VoltaSchematic.h"

/// Singleton class for creating snapshots of the schematic and integrating
/// them with the application's undo system.
@interface FXSchematicUndoManager : NSObject

@property id<VoltaSchematic> schematic;

@property (weak) NSUndoManager* undoManager;

@end


/// Notification info dictionary entries:
/// "ActionName" -> The name of the undo operation.
/// "CapturedSchematic" -> The FXSchematicCapture to use. If nil the undo manager will capture the schematic itself.
extern NSString* FXSchematicCreateUndoPointNotification;

/// Posted after an undo point has been created successfully.
/// Notification object: The FXSchematicUndoManager object which posted the notification.
extern NSString* FXSchematicDidCreateUndoPointNotification;

/// Posted after an undo operation has been completed.
/// Notification object: The FXSchematicUndoManager object which posted the notification.
extern NSString* FXSchematicInsideUndoNotification;

/// Posted after a redo operation has been completed.
/// Notification object: The FXSchematicUndoManager object which posted the notification.
extern NSString* FXSchematicInsideRedoNotification;
