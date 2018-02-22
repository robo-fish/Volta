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
#pragma once

#import "FXTableView.h"

/// This class was meant to be used for displaying the default value of a property
/// if the value is not set. The default value stuff is currently not used.
@interface FXSchematicPropertyWrapper : NSObject

@property (nonatomic, copy) NSString* name;
@property (nonatomic, copy) NSString* value;
@property (nonatomic, copy) NSString* defaultValue;
@property (nonatomic) BOOL hasMultipleValues;

@end



@interface FXPropertiesTableNameCell : NSTextFieldCell
@end



@interface FXPropertiesTableValueCell : NSTextFieldCell
@property BOOL representsMultiValueProperty;
@end



@interface FXSchematicPropertiesTableView : FXTableView

@end



extern NSString* FXSchematicPropertiesTableNamesColumnIdentifier;
extern NSString* FXSchematicPropertiesTableValuesColumnIdentifier;

