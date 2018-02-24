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

#import <VoltaCore/VoltaLibraryProtocol.h>
#import "FXOutlineView.h"
#import "FXClipView.h"
#import "VoltaCloudLibraryController.h"

@interface FXLibraryEditorModelsController : NSViewController

@property (assign) IBOutlet FXOutlineView* modelsTable;
@property (assign) IBOutlet FXClipView* clipView;
@property (assign) IBOutlet NSButton* modelsFolderButton;
@property (assign) IBOutlet NSButton* removeModelsButton;
@property (assign) IBOutlet NSButton* addModelsButton;

@property (nonatomic) id<VoltaLibrary> library;
@property (nonatomic) id<VoltaCloudLibraryController> cloudLibraryController;

/// Creates a new model.
/// The type is inferred from the current selected model group or the current selected model.
- (IBAction) createModel:(id)sender;

- (IBAction) removeModels:(id)sender;

- (IBAction) revealModelsFolder:(id)sender;

@end
