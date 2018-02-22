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

/// The protocol, which the principal class of a Volta plugin needs to conform to.
@protocol VoltaPlugin <NSObject>

/// A unique string to identify the plugin.
/// Reverse domain name notation is recommended.
@property (readonly) NSString* pluginIdentifier;

/// The display name of the plugin.
@property (readonly) NSString* pluginName;

/// The organization or individual providing the plugin.
@property (readonly) NSString* pluginVendor;

/// The version of the plugin.
@property (readonly) NSString* pluginVersion;

/// What kind of a Volta plugin the plugin is.
@property (readonly) VoltaPluginType pluginType;

/// @return an object which implements the specific plugin type
- (NSObject*) newPluginImplementer;

/// @return a list of NSMenuItem objects to be added to the application main menu.
+ (NSArray*) mainMenuItems;

@end

