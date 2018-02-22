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

@interface FXSystemUtils : NSObject

+ (BOOL) systemIsMountainLionOrLater;

+ (BOOL) systemIsMavericksOrLater;

+ (BOOL) quarantineAttributeSetForFileAtLocation:(NSURL*)fileLocation;

+ (BOOL) removeQuarantineAttributeFromFileAtPath:(NSString*)filePath;

+ (void) revealFileAtLocation:(NSURL*)location;

+ (NSURL*) appSupportFolder;

/// @return the location of a sub-folder with the given name that lies in the user's generic Application Support folder.
+ (NSURL*) appSupportAlternativeFolderWithName:(NSString*)name;

/// @return whether the Open File or Save File panel support iCloud
+ (BOOL) filePanelHasCloudSupport;

/// @return YES if the files could be copied successfully
/// @param replace whether to replace (delete) all files in the target directory
/// @param overwrite whether to overwrite files in the target directory with the same name as files in the source directory
+ (BOOL) copyContentsOfDirectory:(NSURL*)sourceDirectory
                     toDirectory:(NSURL*)targetDirectory
                      replaceAll:(BOOL)replace
               overwriteExisting:(BOOL)overwrite
                           error:(NSError**)fileError;

+ (void) removeContentsOfDirectoryAtLocation:(NSURL*)directoryLocation;

@end
