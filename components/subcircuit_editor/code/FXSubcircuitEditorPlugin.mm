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

#import "FXSubcircuitEditorPlugin.h"
#import "FXSubcircuitEditor.h"

@implementation FXSubcircuitEditorPlugin


#pragma mark VoltaPlugin


- (NSString*) pluginIdentifier
{
  return @"fish.robo.volta.SubcircuitEditor";
}

- (NSString*) pluginName
{
  return @"Volta Subcircuit Editor";
}

- (NSString*) pluginVendor
{
  return VENDOR_STRING;
}

- (NSString*) pluginVersion
{
  return [[NSString stringWithFormat:@"%s", FXStringizeValue(SubcircuitEditorVersion)] stringByReplacingOccurrencesOfString:@"_" withString:@"."];
}

- (VoltaPluginType)	pluginType
{
  return VoltaPluginType_SubcircuitEditor;
}

- (NSObject*) newPluginImplementer
{
  return [FXSubcircuitEditor new];
}

+ (NSArray*) mainMenuItems
{
  return @[];
}


@end
