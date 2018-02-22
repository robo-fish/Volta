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

#import "VoltaSchematicElementGroup.h"

@protocol VoltaSchematicPaletteGroupEditor <NSObject>
- (void) openGroupEditor;
@end


@protocol VoltaSchematicPalette <NSObject>

/// The name of the selected element group.
/// The setter also activates the group with the given name.
@property (copy) NSString* selectedGroup;

@property (readonly, retain) FXView* view;

@property (weak) id<VoltaSchematicPaletteGroupEditor> groupEditor;

- (void) beginEditingElementGroups;

- (void) endEditingElementGroups;

/// Adds the given element group to the palette.
/// @param group collection of FXSchematicElement objects to be added to the palette
- (void) addElementGroup:(id<VoltaSchematicElementGroup>)group;

/// Removes all groups, emptying the palette.
- (void) removeAllElementGroups;

- (CGFloat) minWidth;

@end
