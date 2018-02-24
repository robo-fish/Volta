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
#import <VoltaCore/VoltaLibraryProtocol.h>
#import "VoltaPrintable.h"

/// This protocol must be implemented by the implementer class of a schematic editor plugin.
@protocol VoltaSchematicEditor <NSObject, VoltaPrintable>

/// @return the editor view that displays the schematic and allows editing
- (FXView*) schematicView;

/// @return the minimum size of the view returned by method schematicView
- (CGSize) minimumViewSize;

- (void) setUndoManager:(NSUndoManager*)undoManager;

/// @return schematic data describing the current state of the schematic.
/// The caller is responsible for deallocating the returned data by using "delete".
- (VoltaPTSchematicPtr) capture;

/// Refreshes the palette to display the given library
- (void) setLibrary:(id<VoltaLibrary>)library;

- (void) setSchematicData:(VoltaPTSchematicPtr)schematicData;

/// @return A list of NSToolbarItem objects, with which the user can control the plugin, or nil if the plugin makes no use of toolbar items.
- (NSArray*) toolbarItems;

/// Must be called before the editor is released
- (void) closeEditor;



- (void) encodeRestorableState:(NSCoder*)state;

- (void) restoreState:(NSCoder*)state;



- (void) enterViewingModeWithAnimation:(BOOL)animated;

- (void) exitViewingModeWithAnimation:(BOOL)animated;


@end
