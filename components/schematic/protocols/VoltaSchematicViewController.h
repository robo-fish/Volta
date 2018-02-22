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

#import "VoltaSchematicElement.h"

// Defines the interface between an FXSchematicView and its controller
@protocol VoltaSchematicViewController <NSObject, NSUserInterfaceValidations>

/// Called when the schematic view needs to refresh the schematic
- (void) drawSchematicWithContext:(CGContextRef)context inView:(NSView*)schematicView;

#pragma mark -

- (void) mouseDown:(NSEvent*)mouseEvent;
- (void) mouseUp:(NSEvent*)mouseEvent;
- (void) mouseDragged:(NSEvent*)mouseEvent;
- (void) mouseMoved:(NSEvent*)mouseEvent;
- (void) keyDown:(NSEvent*)keyEvent;
- (void) keyUp:(NSEvent*)keyEvent;
- (BOOL) performKeyEquivalent:(NSEvent*)event;
- (void) gestureBegins;
- (void) gestureEnds;
- (void) handleMagnificationGesture:(CGFloat)magnification;
- (void) handleUserInterfaceActionForTag:(NSInteger)tag;

/// Called when pasteboard data is dropped on the FXSchematicView
/// @return whether the dropped data was accepted.
- (BOOL) handleDropForDraggingInfo:(id<NSDraggingInfo>)info;

- (void) updateDraggingItemsForDraggingInfo:(id<NSDraggingInfo>)info;

@end
