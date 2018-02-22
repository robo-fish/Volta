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

#import "VoltaSchematicTool.h"
#import "FXSchematicUtilities.h"

@protocol FXSchematicTool <VoltaSchematicTool>

/// @return the cursor to be displayed when the tool is selected
- (NSCursor*) cursor;

/// @return whether the view should be updated
/// @param location the location of the event in 2D schematic coordinates
- (BOOL) mouseDown:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location;

/// @return whether the view should be updated
/// @param location the location of the event in 2D schematic coordinates
- (BOOL) mouseUp:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location;

/// @return whether the view should be updated
/// @param location the location of the event in 2D schematic coordinates
- (BOOL) mouseDragged:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location;

/// @return whether the view should be updated
/// @param location the location of the event in 2D schematic coordinates
/// @param locationInfo schematic-relevant information about the mouse location, forwarded for performance reasons
- (BOOL) mouseMoved:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location connectionInfo:(FXConnectionInformation*)locationInfo;

/// @return whether the view should be updated
/// @param location the location of the event in 2D schematic coordinates
- (BOOL) scrollWheel:(NSEvent*)theEvent schematicLocation:(NSPoint)location;

/// Called when the Delete key is pressed.
/// @return whether the view should be updated
- (BOOL) toolExecuteDeleteKey;

/// Called when the Escape key is pressed.
/// Usually aborts the current tool action.
/// @return whether the view should be updated
- (BOOL) toolExecuteEscapeKey;

/// Called when the users presses a key with the given key code.
/// @return whether the view should be updated
- (BOOL) toolHandleKeyPress:(UniChar)keyCode modifierFlags:(NSUInteger)flags;

@end
