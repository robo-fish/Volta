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
#import "VoltaCloudLibraryController.h"

@interface FXVoltaCloudController : NSViewController <VoltaCloudLibraryController>

@property (nonatomic) BOOL useCloudLibrary;

@property (nonatomic, readonly) BOOL userWantsLocalLibraryToBeCopied;

/// Copies the content of the given library into the iCloud library.
/// Existing files with the same name as in the source library are replaced.
- (void) copyContentsFromLibraryAtLocation:(NSURL*)sourceLibraryLocation;

/// Copies the contents of the iCloud library to the library at the given root location.
/// Existing files with the same name as in the iCloud library are replaced.
- (void) copyCloudLibraryToLibraryAtLocation:(NSURL*)targetLibraryLocation;

@end


/// This notification is sent when the cloud library state changes
extern NSString* const FXVoltaCloudLibraryStateDidChangeNotification;
