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

@protocol VoltaLibraryEditor;

@interface FXVoltaMainController : NSObject
  <NSApplicationDelegate,
#if VOLTA_SUPPORTS_RESUME
  NSWindowRestoration,
#endif
  NSWindowDelegate>

@property (strong, nonatomic) IBOutlet NSPanel* aboutPanel;
@property (assign) IBOutlet NSTextView* aboutPanel_versionView;
@property (assign) IBOutlet NSTextView* aboutPanel_copyrightTextView;

@property (weak) IBOutlet NSMenuItem* menuItem_preferences;
@property (weak) IBOutlet NSMenuItem* menuItem_circuit;
@property (weak) IBOutlet NSMenuItem* menuItem_cloudLibrarySeparator;
@property (weak) IBOutlet NSMenuItem* menuItem_cloudLibrary;
@property (weak) IBOutlet NSMenuItem* menuItem_useCloudLibrary;
@property (weak) IBOutlet NSMenuItem* menuItem_copyCloudLibrary;
@property (weak) IBOutlet NSMenuItem* menuItem_copyLocalLibrary;

@property (readonly) id<VoltaLibraryEditor> libraryEditor;

#if VOLTA_HAS_PREFERENCES_PANEL
- (IBAction) action_showPreferences:(id)sender;
#endif

- (IBAction) action_showAboutPanel:(id)sender;
- (IBAction) action_toggleLibraryEditor:(id)sender;
- (IBAction) action_browseToVoltaHomepage:(id)sender;

#if VOLTA_SUPPORTS_ICLOUD
- (IBAction) action_useCloudLibrary:(id)sender;
- (IBAction) action_copyCloudLibrary:(id)sender;
- (IBAction) action_copyLocalLibrary:(id)sender;
#endif


@end
