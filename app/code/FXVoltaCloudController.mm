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

#import "FXVoltaCloudController.h"
#import "FXSystemUtils.h"
#import "FXFileBrowser.h"
#import "FXVoltaPreferencesController.h"

NSString* const FXCloudStorageIdentityKey = @"CloudStorageIdentity";
NSString* const FXUseCloudLibrary = @"UseAppleCloudLibrary";
NSString* const FXVoltaCloudLibraryStateDidChangeNotification = @"FXVoltaCloudLibraryStateDidChangeNotification";
NSString* const FXVoltaCLoudControllerLibraryWindowIdentifier = @"Cloud Library Window";
NSString* const FXVoltaCLoudControllerFileBrowserFolderLocation = @"Cloud File Browser Folder Location";
NSString* const FXVoltaCloudLibrarySubfolderName_Models = @"Models";
NSString* const FXVoltaCloudLibrarySubfolderName_Subcircuits = @"Subcircuits";
NSString* const FXVoltaCloudLibrarySubfolderName_Palette = @"Palette";
static FXFileBrowser* sFileBrowser = nil;
static NSWindow* sFileBrowserWindow = nil;

@interface FXVoltaCloudController () <NSWindowDelegate, NSWindowRestoration>
@property (weak) IBOutlet NSButton* libraryCopyCheckbox;
@end


@implementation FXVoltaCloudController
{
@private
  BOOL mCopyLocalLibrary;
  NSButton* __weak mLibraryCopyCheckbox;
  VoltaCloudLibraryState mLibraryState;
}

@synthesize libraryState = mLibraryState;
@synthesize libraryCopyCheckbox = mLibraryCopyCheckbox;


#pragma mark Public


- (id) init
{
  if ( (self = [super initWithNibName:@"iCloudPrompt" bundle:[NSBundle bundleForClass:[self class]]]) != nil )
  {
    mCopyLocalLibrary = NO;
    mLibraryState = VoltaCloudLibraryState_NotAvailable;
    if ( [self cloudStorageIsAvailable] )
    {
      NSNumber* useCloudLibraryNumber = [[NSUserDefaults standardUserDefaults] objectForKey:FXUseCloudLibrary];
      if (useCloudLibraryNumber == nil)
      {
        [self promptUserAboutWantingToUseTheCloudLibraryAndUpdateState];
      }
      else
      {
        if ([useCloudLibraryNumber boolValue])
        {
          if ([self userIdentityHasChanged])
          {
            [self promptUserAboutWantingToUseTheCloudLibraryAndUpdateState];
          }
          else
          {
            [self switchToLibraryState:VoltaCloudLibraryState_AvailableAndUsing];
          }
        }
        else
        {
          [self switchToLibraryState:VoltaCloudLibraryState_AvailableButNotUsing];
        }
      }
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleCloudConfigurationChanged:) name:NSUbiquityIdentityDidChangeNotification object:nil];
  }
  return self;
}


- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  FXRelease(sFileBrowser)
  sFileBrowser = nil;
  FXRelease(sFileBrowserWindow)
  sFileBrowserWindow = nil;
  FXDeallocSuper
}


- (void) awakeFromNib
{
  self.libraryCopyCheckbox.state = NSOnState;
  self.libraryCopyCheckbox.title = FXLocalizedString(@"Cloud_CopyLibraryOption");
}


- (void) setUseCloudLibrary:(BOOL)userWantsCloudLibrary
{
  [[NSUserDefaults standardUserDefaults] setValue:@(userWantsCloudLibrary) forKey:FXUseCloudLibrary];
  if ( self.libraryState == VoltaCloudLibraryState_AvailableAndUsing )
  {
    [self switchToLibraryState:VoltaCloudLibraryState_AvailableButNotUsing];
  }
  else if ( self.libraryState == VoltaCloudLibraryState_AvailableButNotUsing )
  {
    [self switchToLibraryState:VoltaCloudLibraryState_AvailableAndUsing];
  }
}


- (BOOL) useCloudLibrary
{
  NSNumber* boolValueNumber = [[NSUserDefaults standardUserDefaults] valueForKey:FXUseCloudLibrary];
  return (boolValueNumber != nil) && [boolValueNumber boolValue];
}


- (BOOL) userWantsLocalLibraryToBeCopied
{
  return mCopyLocalLibrary;
}


- (void) copyContentsFromLibraryAtLocation:(NSURL*)sourceLibraryLocation
{
  NSError* replaceError = nil;
  NSURL* targetLocation = [self libraryStorageLocationForFolder:VoltaCloudFolderType_LibraryRoot];
  if ( ![self copyLibraryAtLocation:sourceLibraryLocation toLibraryAtLocation:targetLocation error:&replaceError] && (replaceError != nil) )
  {
    [self presentError:replaceError];
  }
}


- (void) copyCloudLibraryToLibraryAtLocation:(NSURL*)targetLibraryLocation
{
  NSError* replaceError = nil;
  NSURL* sourceLocation = [self libraryStorageLocationForFolder:VoltaCloudFolderType_LibraryRoot];
  if ( ![self copyLibraryAtLocation:sourceLocation toLibraryAtLocation:targetLibraryLocation error:&replaceError] )
  {
    [self presentError:replaceError];
  }
}


#pragma mark VoltaCloudLibraryController


- (BOOL) cloudStorageIsAvailable
{
  return [self accountIsActive] && ([self cloudStorageLocation] != nil);
}


- (BOOL) nowUsingCloudLibrary
{
  return self.cloudStorageIsAvailable && self.useCloudLibrary;
}


- (NSURL*) libraryStorageLocationForFolder:(VoltaCloudFolderType)folderType
{
  NSURL* const libraryStorageRootLocation = [[self cloudStorageLocation] URLByAppendingPathComponent:@"Library"];
  NSString* subfolderName = nil;
  switch (folderType)
  {
    case VoltaCloudFolderType_LibrarySubcircuits: subfolderName = FXVoltaCloudLibrarySubfolderName_Subcircuits; break;
    case VoltaCloudFolderType_LibraryModels:      subfolderName = FXVoltaCloudLibrarySubfolderName_Models;      break;
    case VoltaCloudFolderType_LibraryPalette:     subfolderName = FXVoltaCloudLibrarySubfolderName_Palette;     break;
    case VoltaCloudFolderType_Documents:
    case VoltaCloudFolderType_LibraryRoot:
    default: subfolderName = nil;
  }
  NSURL* result = (subfolderName != nil) ? [libraryStorageRootLocation URLByAppendingPathComponent:subfolderName] : libraryStorageRootLocation;
  return result;
}


- (void) showContentsOfCloudFolder:(VoltaCloudFolderType)folderType
{
  if ( sFileBrowser == nil )
  {
    [[self class] createFileBrowser];
    sFileBrowserWindow.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBrowserWindowClosing:) name:NSWindowWillCloseNotification object:sFileBrowserWindow];
  }
  @synchronized(sFileBrowser)
  {
    NSURL* folderLocation = [self libraryStorageLocationForFolder:folderType];
    sFileBrowser.rootFolderLocation = folderLocation;
    [sFileBrowserWindow setTitleWithRepresentedFilename:[folderLocation path]];
  }
  [sFileBrowserWindow makeKeyAndOrderFront:self];
}


- (void) highlightFiles:(NSArray*)fileNames
{
  [sFileBrowser highlightFiles:fileNames];
}


#pragma mark NSWindowDelegate


- (void) window:(NSWindow*)window willEncodeRestorableState:(NSCoder*)state
{
  if ( window == sFileBrowserWindow )
  {
    if ( sFileBrowser.rootFolderLocation != nil )
    {
      [state encodeObject:sFileBrowser.rootFolderLocation forKey:FXVoltaCLoudControllerFileBrowserFolderLocation];
    }
    [sFileBrowser encodeRestorableStateWithCoder:state];
  }
}


- (void) window:(NSWindow*)window didDecodeRestorableState:(NSCoder*)state
{
  if ( window == sFileBrowserWindow )
  {
    NSURL* location = [state decodeObjectForKey:FXVoltaCLoudControllerFileBrowserFolderLocation];
    if ( location != nil )
    {
      sFileBrowser.rootFolderLocation = location;
    }
    [sFileBrowser restoreStateWithCoder:state];
  }
}


#pragma mark NSWindowRestoration


+ (void) restoreWindowWithIdentifier:(NSString*)identifier
                               state:(NSCoder*)state
                   completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
  BOOL success = NO;
  if ( [identifier isEqualToString:FXVoltaCLoudControllerLibraryWindowIdentifier] )
  {
    NSURL* location = [state decodeObjectForKey:FXVoltaCLoudControllerFileBrowserFolderLocation];
    if ( location != nil )
    {
      BOOL isDirectory = NO;
      if ([[NSFileManager defaultManager] fileExistsAtPath:[location path] isDirectory:&isDirectory])
      {
        [self createFileBrowser];
        sFileBrowser.rootFolderLocation = location;
        [sFileBrowser restoreStateWithCoder:state];
        [sFileBrowserWindow restoreStateWithCoder:state];
        [sFileBrowserWindow setTitleWithRepresentedFilename:[location path]];
        success = YES;
      }
    }
  }
  completionHandler(success ? sFileBrowserWindow : nil, nil);
}


#pragma mark Private


- (BOOL) accountIsActive
{
  return [[NSFileManager defaultManager] ubiquityIdentityToken] != nil;
}


- (void) handleCloudConfigurationChanged:(NSNotification*)notif
{
  if ( self.libraryState == VoltaCloudLibraryState_AvailableAndUsing )
  {
    if ( ![self accountIsActive] )
    {
      [self switchToLibraryState:VoltaCloudLibraryState_NotAvailable];
    }
    else if ( [self userIdentityHasChanged] )
    {
      [self promptUserAboutWantingToUseTheCloudLibraryAndUpdateState];
    }
  }
  else if ( self.libraryState == VoltaCloudLibraryState_AvailableButNotUsing )
  {
    if ( ![self accountIsActive] )
    {
      [self switchToLibraryState:VoltaCloudLibraryState_NotAvailable];
    }
  }
  else if ( self.libraryState == VoltaCloudLibraryState_NotAvailable )
  {
    if ( [self accountIsActive] )
    {
      [self promptUserAboutWantingToUseTheCloudLibraryAndUpdateState];
    }
  }
}


- (NSURL*) cloudStorageLocation
{
  return [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil/*@"XXXXXXXXXX.fish.robo.Volta"*/];
}


- (BOOL) cloudLibraryIsEmpty
{
  BOOL empty = NO;
  NSFileManager* fm = [NSFileManager defaultManager];
  NSArray* contents = [fm contentsOfDirectoryAtURL:[self libraryStorageLocationForFolder:VoltaCloudFolderType_LibrarySubcircuits] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
  if ((contents == nil) || ([contents count] == 0))
  {
    contents = [fm contentsOfDirectoryAtURL:[self libraryStorageLocationForFolder:VoltaCloudFolderType_LibraryModels] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    if ((contents == nil) || ([contents count] == 0))
    {
      contents = [fm contentsOfDirectoryAtURL:[self libraryStorageLocationForFolder:VoltaCloudFolderType_LibraryPalette] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
      if ((contents == nil) || ([contents count] == 0))
      {
        empty = YES;
      }
    }
  }
  return empty;
}


- (BOOL) copyContentsOfSubdirectory:(NSString*)subdirectoryName
          fromSourceParentDirectory:(NSURL*)sourceLocation
            toTargetParentDirectory:(NSURL*)targetLocation
                              error:(NSError**)error
{
  NSURL* sourceDir = [sourceLocation URLByAppendingPathComponent:subdirectoryName];
  NSURL* targetDir = [targetLocation URLByAppendingPathComponent:subdirectoryName];
  return [FXSystemUtils copyContentsOfDirectory:sourceDir toDirectory:targetDir replaceAll:NO overwriteExisting:YES error:error];
}


- (BOOL) copyLibraryAtLocation:(NSURL*)sourceLibraryLocation
           toLibraryAtLocation:(NSURL*)targetLibraryLocation
                         error:(NSError**)error
{
  if (![self copyContentsOfSubdirectory:@"Palette" fromSourceParentDirectory:sourceLibraryLocation toTargetParentDirectory:targetLibraryLocation error:error])
    return NO;
  if (![self copyContentsOfSubdirectory:@"Models" fromSourceParentDirectory:sourceLibraryLocation toTargetParentDirectory:targetLibraryLocation error:error])
    return NO;
  if (![self copyContentsOfSubdirectory:@"Subcircuits" fromSourceParentDirectory:sourceLibraryLocation toTargetParentDirectory:targetLibraryLocation error:error])
    return NO;
  return YES;
}


- (void) promptUserAboutWantingToUseTheCloudLibraryAndUpdateState
{
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = FXLocalizedString(@"Cloud_UseLibraryPrompt");
  alert.informativeText = FXLocalizedString(@"Cloud_UseLibraryPromptInformative");
  [alert addButtonWithTitle:FXLocalizedString(@"Yes")];
  [alert addButtonWithTitle:FXLocalizedString(@"No")];
  if ( !FXVoltaPreferencesController.isInitialRun )
  {
    alert.accessoryView = self.view;
    self.libraryCopyCheckbox.state = [self cloudLibraryIsEmpty] ? NSOnState : NSOffState;
  }
  [[alert window] center];
  NSInteger const userDecision = [alert runModal];
  if ( userDecision == NSAlertFirstButtonReturn )
  {
    mCopyLocalLibrary = (self.libraryCopyCheckbox.state == NSOnState);
    [self switchToLibraryState:VoltaCloudLibraryState_AvailableAndUsing];
  }
  else
  {
    [self switchToLibraryState:VoltaCloudLibraryState_AvailableButNotUsing];
  }
}


- (BOOL) userIdentityHasChanged
{
  id archivedToken = nil;
  NSData* archivedTokenData = [[NSUserDefaults standardUserDefaults] objectForKey:FXCloudStorageIdentityKey];
  if ( archivedTokenData != nil )
  {
    archivedToken = [NSKeyedUnarchiver unarchiveObjectWithData:archivedTokenData];
  }
  id currentToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
  if ( (currentToken == nil) && (archivedToken == nil) )
  {
    return NO;
  }
  else if ( (currentToken == nil) || (archivedToken == nil) )
  {
    return YES;
  }
  return ![currentToken isEqual:archivedToken];
}


- (void) switchToLibraryState:(VoltaCloudLibraryState)newState
{
  if ( mLibraryState != newState )
  {
    if (newState == VoltaCloudLibraryState_AvailableAndUsing)
    {
      [self checkAndCreateLibraryRootFolder];
      [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:FXUseCloudLibrary];
      id<NSCoding> currentToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
      if ( currentToken != nil )
      {
        NSData* archivedToken = [NSKeyedArchiver archivedDataWithRootObject:currentToken];
        [[NSUserDefaults standardUserDefaults] setObject:archivedToken forKey:FXCloudStorageIdentityKey];
      }
    }
    else
    {
      [[NSUserDefaults standardUserDefaults] setValue:@NO forKey:FXUseCloudLibrary];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:FXCloudStorageIdentityKey];
    }
    mLibraryState = newState;
    [[NSNotificationCenter defaultCenter] postNotificationName:FXVoltaCloudLibraryStateDidChangeNotification object:nil];
  }
}


+ (void) createFileBrowser
{
  if ( sFileBrowser == nil )
  {
    sFileBrowser = [[FXFileBrowser alloc] initWithIdentifier:@"Cloud Library Folder"];
  }
  if ( sFileBrowserWindow == nil )
  {
    NSUInteger const windowStyle = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable;
    NSView* contentView = sFileBrowser.view;
    NSSize const contentSize = [contentView frame].size;
    sFileBrowserWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,contentSize.width,contentSize.height) styleMask:windowStyle backing:NSBackingStoreBuffered defer:NO];
    [sFileBrowserWindow center];
    sFileBrowserWindow.contentView = contentView;
    sFileBrowserWindow.releasedWhenClosed = NO;
    sFileBrowserWindow.restorable = YES;
    sFileBrowserWindow.identifier = FXVoltaCLoudControllerLibraryWindowIdentifier;
    sFileBrowserWindow.restorationClass = self;
    //sFileBrowserWindow.collectionBehavior = sFileBrowserWindow.collectionBehavior | NSWindowCollectionBehaviorFullScreenAuxiliary; // requires the window to be a floating panel
  }
}


- (void) handleBrowserWindowClosing:(NSNotification*)notification
{
  sFileBrowser.rootFolderLocation = nil;
}


- (void) checkAndCreateLibraryRootFolder
{
  NSURL* libraryRootLocation = [self libraryStorageLocationForFolder:VoltaCloudFolderType_LibraryRoot];
  if ( libraryRootLocation != nil )
  {
    NSFileManager* fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL libraryFolderExists = [fm fileExistsAtPath:[libraryRootLocation path] isDirectory:&isDir];
    if ( libraryFolderExists && !isDir )
    {
      [fm removeItemAtURL:libraryRootLocation error:NULL];
      libraryFolderExists = NO;
    }
    if ( !libraryFolderExists )
    {
      [fm createDirectoryAtURL:libraryRootLocation withIntermediateDirectories:NO attributes:nil error:NULL];
    }
  }
}


@end
