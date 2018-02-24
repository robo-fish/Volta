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


/// This singleton manages the model library and model groupings.
/// Provides the preferences panel for libraries.
/// Manages access to online libraries.
@interface FXVoltaLibrary : NSObject <VoltaLibrary>

@property (nonatomic, readonly, strong) NSURL* rootLocation;

+ (FXVoltaLibrary*) newTestLibrary;

/// @return the standard root location for local storage (i.e., not iCloud).
+ (NSURL*) localStandardRootLocation;

/// @param rootLocation the root folder of the library
- (id) initWithRootLocation:(NSURL*)rootLocation;

/// Reloads subcircuits from all known subcircuit root folders.
- (void) reloadSubcircuits;

/// Reloads the element groups from the palette storage folder.
- (void) reloadPalette;

- (void) shutDown;

@end
