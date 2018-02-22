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

#import "VoltaPluginTypes.h"
@class FXVoltaPlugin;

/// Singleton class which manages all plugins in the system 
@interface FXVoltaPluginsController : NSObject 
{
  // Maps NSNumber objects (containing VoltaPluginType values) to NSArray objects containing FXVoltaPlugin objects.
  NSMutableDictionary* mPlugins;

  // Member variables used for the preferences panel
  IBOutlet NSView*         mContainer;
  IBOutlet NSOutlineView*  mPluginsTable;
  IBOutlet NSTextField*    mStatusField;
}
+ (FXVoltaPluginsController*) sharedController;

- (NSArray*) pluginsForType:(VoltaPluginType)pluginType;

- (FXVoltaPlugin*) activePluginForType:(VoltaPluginType)pluginType;

- (void) activate:(FXVoltaPlugin*)plugin;

/// load or unloads a plugin
- (IBAction) activateSelectedPlugin:(id)sender;

/// The view which presents the plugins
- (NSView*) view;

@end

#pragma mark -

@interface FXVoltaPluginsController (TableDataSource) <NSOutlineViewDataSource, NSOutlineViewDelegate>
@end;


extern NSString* FXVoltaPluginActivatedNotification;
