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

/// Manages the inspection view for schematic elements.
/// The view contains a table for listing and editing the properties of the
/// inspected elements. The content of the table depends on whether the type
/// and model of the inspected elements are all the same.
@interface FXSchematicElementInspector : NSViewController <NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>

/// The inspection view is reset if the given set is nil.
/// @param inspectables a set of VoltaSchematicElement objects
- (void) inspect:(NSSet*)inspectables;

/// @return whether any elements are currently being inspected.
- (BOOL) isInspecting;

- (void) rotateInspectedElementsPlus90:(id)sender;

- (void) rotateInspectedElementsMinus90:(id)sender;

- (void) flipInspectedElementsVertically:(id)sender;

- (void) flipInspectedElementsHorizontally:(id)sender;

@end
