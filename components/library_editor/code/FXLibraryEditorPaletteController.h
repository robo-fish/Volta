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

@protocol VoltaLibrary;
@protocol VoltaCloudLibraryController;
#import <FXKit/FXKit-Swift.h>

@interface FXLibraryEditorPaletteController : NSViewController

@property (assign) IBOutlet NSOutlineView* paletteTable;
@property (assign) IBOutlet FXClipView* clipView;
@property (assign) IBOutlet NSButton* createGroupButton;
@property (assign) IBOutlet NSButton* removeItemsButton;
@property (assign) IBOutlet NSButton* paletteFolderButton;

@property (nonatomic) id<VoltaLibrary> library;
@property (nonatomic) id<VoltaCloudLibraryController> cloudLibraryController;

- (IBAction) createOrCopyGroup:(id)sender;

- (IBAction) removeSelectedItems:(id)sender;

- (IBAction) revealPaletteFolder:(id)sender;

@end
