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

#import "FXSystemUtils.h"
#include <sys/xattr.h>


#import <AppKit/NSApplication.h>

static BOOL const sMac_OS_X_10_8_Plus = (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_7_4);

#ifndef NSAppKitVersionNumber10_8
#define NSAppKitVersionNumber10_8 1187
#endif
static BOOL const sMac_OS_X_10_9_Plus = (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8);

#if 0
#include <stdio.h>
#include <sys/sysctl.h>
#endif



@implementation FXSystemUtils


#if 0
+ (void) initialize
{

  // Use sysctl
  int sels[2] = { CTL_KERN , KERN_OSRELEASE };
  size_t bufsize;
  if (sysctl(sels, 2, NULL, &bufsize, NULL, 0) == 0)
  {
    char* buffer = (char*) malloc(bufsize + 1);
    if ( sysctl(sels, 2, buffer, &bufsize, NULL, 0) == 0 )
    {
      buffer[bufsize] = 0;
      mMac_OS_X_10_8_Plus = (strncmp(buffer,"12",2) == 0);
      // "11xxxx" is Mac OS X 10.7
      //    "11.0.0" is Mac OS X 10.7.0
      //    "11.4.0" is Mac OS X 10.7.4
      // "12xxxx" is Mac OS X 10.8
    }
  }
}
#endif


#pragma mark Public methods


+ (NSURL*) appSupportAlternativeFolderWithName:(NSString *)folderName
{
  NSURL* result = nil;
  NSArray* folders = NSSearchPathForDirectoriesInDomains( NSApplicationSupportDirectory, NSUserDomainMask, YES );
  if ( [folders count] > 0 )
  {
    NSAssert( [folders count] == 1, @"There must be one, and only one, application support folder." );
    NSString* basePath = [(NSString*)folders[0] stringByAppendingPathComponent:folderName];
    if ( basePath != nil )
    {
      result = [NSURL fileURLWithPath:basePath];
    }
  }
  return result;
}


+ (NSURL*) appSupportFolder
{
  return [self appSupportAlternativeFolderWithName:@"Volta"];
}


+ (BOOL) systemIsMountainLionOrLater
{
  return sMac_OS_X_10_8_Plus;
}


+ (BOOL) systemIsMavericksOrLater
{
  return sMac_OS_X_10_9_Plus;
}


+ (BOOL) quarantineAttributeSetForFileAtLocation:(NSURL*)fileLocation
{
  BOOL result = NO;
  if ( fileLocation != nil )
  {
    NSString* path = [fileLocation path];
    const char* cStringPath = [path cStringUsingEncoding:NSUTF8StringEncoding];
    char buffer[1024];
    ssize_t const dataLength = getxattr(cStringPath, "com.apple.quarantine", buffer, sizeof(buffer), 0, 0);
    if ( (dataLength == -1) && (errno != ENOATTR) )
    {
      DebugLog(@"%s", strerror(errno));
    }
    else if ( dataLength > 0 )
    {
      result = YES;
    }
  }
  return result;
}


+ (BOOL) removeQuarantineAttributeFromFileAtPath:(NSString*)filePath
{
  int err = removexattr([filePath cStringUsingEncoding:NSUTF8StringEncoding], "com.apple.quarantine", 0);
  return (err == 0) || (errno == ENOATTR);
}


+ (void) revealFileAtLocation:(NSURL*)location
{
  if (location == nil)
    return;

  if (sMac_OS_X_10_8_Plus)
  {
    [[NSWorkspace sharedWorkspace] selectFile:[location path] inFileViewerRootedAtPath:NSHomeDirectory()];
  }
  else
  {
    // OS X 10.7 incorrectly sets the quarantine attribute for folders created inside the own sandbox.
    // The quarantine attribute prevents [NSWorkspace openURL:] from opening folders in Finder.
    // The problem does not occur in OS X 10.8. The solution is to use "/usr/bin/open" with the "R" option.
    // An additional advantage of using 'open -R <file_path>' is that Finder highlights the file.
    // See radar:12143159
    NSTask* task = [[NSTask alloc] init];
    FXAutorelease(task)
    task.launchPath = @"/usr/bin/open";
    task.arguments = @[@"-R", [location path]];
    [task launch];
  }
}


+ (void) removeContentsOfDirectoryAtLocation:(NSURL*)directoryLocation
{
  NSFileManager* fm = [NSFileManager defaultManager];
  BOOL isDir = NO;
  if ( [fm fileExistsAtPath:[directoryLocation path] isDirectory:&isDir] && isDir )
  {
    NSArray* directoryContents = [fm contentsOfDirectoryAtURL:directoryLocation includingPropertiesForKeys:nil options:0 error:NULL];
    if ( directoryContents != nil )
    {
      for ( NSURL* fileLocation in directoryContents )
      {
        [fm removeItemAtURL:fileLocation error:NULL];
      }
    }
  }
}


+ (BOOL) copyContentsOfDirectory:(NSURL*)sourceDirectory
                     toDirectory:(NSURL*)targetDirectory
                      replaceAll:(BOOL)replace
               overwriteExisting:(BOOL)overwrite
                           error:(NSError**)fileError
{
  NSFileManager* fm = [NSFileManager defaultManager];
  BOOL result = NO;
  BOOL isDir = NO;
  if ( [fm fileExistsAtPath:[sourceDirectory path] isDirectory:&isDir] && isDir )
  {
    isDir = NO;
    if ( [fm fileExistsAtPath:[targetDirectory path] isDirectory:&isDir] && isDir )
    {
      result = YES;
      if ( replace )
      {
        [self removeContentsOfDirectoryAtLocation:targetDirectory];
      }
      NSArray* sourceFiles = [fm contentsOfDirectoryAtURL:sourceDirectory includingPropertiesForKeys:nil options:0 error:NULL];
      if ( sourceFiles != nil )
      {
        for ( NSURL* sourceFileLocation in sourceFiles )
        {
          NSURL* targetFileLocation = [targetDirectory URLByAppendingPathComponent:[sourceFileLocation lastPathComponent]];
          if ( [fm fileExistsAtPath:[targetFileLocation path]] )
          {
            if ( overwrite )
            {
              if ( ![fm removeItemAtURL:targetFileLocation error:fileError] )
              {
                result = NO;
                break;
              }
              if (![fm copyItemAtURL:sourceFileLocation toURL:targetFileLocation error:fileError])
              {
                result = NO;
                break;
              }
            }
            else
            {
              continue;
            }
          }
          else
          {
            if (![fm copyItemAtURL:sourceFileLocation toURL:targetFileLocation error:fileError])
            {
              result = NO;
              break;
            }
          }
        }
      }
    }
  }
  return result;
}


+ (BOOL) filePanelHasCloudSupport
{
  return [self systemIsMountainLionOrLater];
}


@end
