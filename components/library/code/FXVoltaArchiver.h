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

/// Singleton which archives/unarchives circuits and libraries to/from the Volta persistence format
/// defined at http://kulfx.com/volta
@interface FXVoltaArchiver : NSObject

/// @return The archived library in XML string form
+ (NSString*) archiveLibrary:(VoltaPTLibraryPtr)libraryData;

/// @param libraryDescription Archived Volta library as string.
/// @param[out] upgraded this is YES on return if the format of the archive had to be upgraded
/// @param[out] error The error code is one of the values of FXVoltaArchiverError
+ (VoltaPTLibraryPtr) unarchiveLibraryFromString:(NSString*)libraryDescription formatUpgradedWhileUnarchiving:(BOOL*)upgraded error:(NSError**)error;

/// @return The archived circuit document in XML string form
+ (NSString*) archiveCircuit:(VoltaPTCircuitPtr)circuitData;

/// @param circuitDescription Archived Volta document as string.
/// @param[out] upgraded this is YES on return if the format of the archive had to be upgraded
/// @param[out] error The error code is one of the values of FXVoltaArchiverError
+ (VoltaPTCircuitPtr) unarchiveCircuitFromString:(NSString*)circuitDescription formatUpgradedWhileUnarchiving:(BOOL*)upgraded error:(NSError**)error;

@end
