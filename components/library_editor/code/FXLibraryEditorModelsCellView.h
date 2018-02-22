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

#import "FXLibraryEditorCellView.h"
#import "FXModel.h"

@class FXLibraryEditorModelsCellView;

@protocol FXLibraryEditorModelsCellViewClient
- (void) handleNewName:(NSString*)newName forModel:(FXModel*)editedModel inCellView:(FXLibraryEditorModelsCellView*)cellView;
- (void) handleNewVendor:(NSString*)newName forModel:(FXModel*)editedModel inCellView:(FXLibraryEditorModelsCellView*)cellView;
- (void) handleNewProperties:(VoltaPTPropertyVector const &)properties forModel:(FXModel*)editedModel inCellView:(FXLibraryEditorModelsCellView*)cellView;
@end


@interface FXLibraryEditorModelsCellView : FXLibraryEditorCellView

@property (nonatomic, weak) id<FXLibraryEditorModelsCellViewClient> client;

/// isEditable should be set before calling this method.
- (void) setModel:(FXModel*)model;

@end
