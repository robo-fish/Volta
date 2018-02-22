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

#import "FXNetlistEditorVoltaPlugin.h"
#import "FXNetlistEditor.h"


@implementation FX(FXNetlistEditorVoltaPlugin)

#pragma mark VoltaPlugin protocol implementation

- (NSString*) pluginIdentifier
{
	return @"fish.robo.volta.netlisteditor";
}

- (NSObject*) newPluginImplementer
{
  return [FX(FXNetlistEditor) new];
}

- (NSString*) pluginName
{
  return @"Volta Netlist Editor";
}

- (NSString*) pluginVendor
{
  return VENDOR_STRING;
}

- (NSString*) pluginVersion
{
  return [[NSString stringWithFormat:@"%s", FXStringizeValue(NetlistEditorVersion)] stringByReplacingOccurrencesOfString:@"_" withString:@"."];
}

- (VoltaPluginType) pluginType
{
  return VoltaPluginType_NetlistEditor;
}

+ (NSArray*) mainMenuItems
{
  return @[];
}

@end
