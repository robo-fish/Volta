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

#import "VoltaPersistentTypes.h"
@class FXElement, FXModel;


@interface FX(FXVoltaLibraryUtilities) : NSObject


+ (VoltaModelType) modelTypeForString:(FXString const &)modelTypeName;


+ (FXString) codeStringForModelType:(VoltaModelType)modelType;


/// @return A localized name for the given model name, if it exists. Otherwise it just passes the given name.
+ (NSString*) userVisibleNameForModelName:(NSString*)modelName;


/// @return the name of the built-in model group containing models of the given type.
+ (NSString*) userVisibleNameForModelGroupOfType:(VoltaModelType)type;


/// @return the name of the given model type.
+ (NSString*) userVisibleNameForModelType:(VoltaModelType)type;


+ (FXElement*) elementFromModel:(FXModel*)model;


@end
