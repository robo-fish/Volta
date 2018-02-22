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

#import "FXVoltaPluginsController.h"
#import "VoltaPlugin.h"
#import "FXVoltaPlugin.h"
#import "FXVoltaPluginGroup.h"
#import "FXVoltaNotifications.h"


NSString* FXVoltaPluginActivatedNotification = @"FXVoltaPluginActivatedNotification";


@implementation FXVoltaPluginsController


#pragma mark Singleton implementation

static FXVoltaPluginsController* sharedPluginsControllerInstance = nil;

+ (FXVoltaPluginsController*) sharedController
{
  @synchronized( self )
  {
    if ( sharedPluginsControllerInstance == nil )
    {
      sharedPluginsControllerInstance = [[FXVoltaPluginsController alloc] init];
    }
  }
  return sharedPluginsControllerInstance;
}

+ (id) allocWithZone:(NSZone*)zone
{
  @synchronized(self)
  {
    if ( sharedPluginsControllerInstance == nil )
    {
      sharedPluginsControllerInstance = [super allocWithZone:zone];
      return sharedPluginsControllerInstance;  // assignment and return on first allocation
    }
  }
  return nil; //on subsequent allocation attempts return nil
}

- (id) copyWithZone:(NSZone *)zone
{
  return self;
}


#pragma mark -


- (id) init
{
  if ( (self = [super init]) != nil )
  {
    // Initialize plugins dictionary
    mPlugins = [[NSMutableDictionary alloc] initWithCapacity:VoltaPluginType_Count];
    for (VoltaPluginType i = VoltaPluginType_First; i < VoltaPluginType_Count; i++ )
    {
      FXVoltaPluginGroup* pluginGroup = [[FXVoltaPluginGroup alloc] init];			
      switch ( i )
      {
        case VoltaPluginType_Simulator:        pluginGroup.name = FXLocalizedString(@"VoltaPluginGroup_Simulators"); break;
        case VoltaPluginType_SchematicEditor:  pluginGroup.name = FXLocalizedString(@"VoltaPluginGroup_Schematic_Editors"); break;
        case VoltaPluginType_NetlistEditor:    pluginGroup.name = FXLocalizedString(@"VoltaPluginGroup_Netlist_Editors"); break;
        case VoltaPluginType_LibraryEditor:    pluginGroup.name = FXLocalizedString(@"VoltaPluginGroup_Library_Editors"); break;
        case VoltaPluginType_SubcircuitEditor: pluginGroup.name = FXLocalizedString(@"VoltaPluginGroup_Subcircuit_Editors"); break;
        case VoltaPluginType_Plotter:          pluginGroup.name = FXLocalizedString(@"VoltaPluginGroup_Plotters"); break;
        default: NSAssert( NO, @"Unknown plugin type!" );
      }
      mPlugins[@(i)] = pluginGroup;
      FXRelease(pluginGroup)
    }
        
    // Build the plugins library. Scan all plugins.
    FXIssue(16)
    NSUInteger numPlugins = 0;
    NSArray* localAndUserPluginFolders = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask | NSLocalDomainMask, YES);
    NSMutableArray* allPluginFolders = [NSMutableArray arrayWithCapacity:([localAndUserPluginFolders count] + 1)];
    [allPluginFolders addObject:[[NSBundle mainBundle] builtInPlugInsPath]]; // The built-in plugins folder must come first
    for ( NSString* localAndUserPluginFolder in localAndUserPluginFolders )
    {
      [allPluginFolders addObject:[localAndUserPluginFolder stringByAppendingPathComponent:@"Volta/Plugins"]];
    }
    NSFileManager* fm = [NSFileManager defaultManager];
    for ( NSString* pluginFolder in allPluginFolders )
    {
      NSArray* pluginFiles = [fm contentsOfDirectoryAtPath:pluginFolder error:NULL];
      if ( pluginFiles != nil )
      {
        numPlugins += [self scanPluginsInFolder:pluginFolder];
      }
    }
        
    mContainer = nil;
  }
  return self;
}

- (void) dealloc
{
  FXRelease(mContainer)
  FXRelease(mPlugins)
  FXDeallocSuper
}


#pragma mark Private


- (NSUInteger) scanPluginsInFolder:(NSString*)folder
{
  NSFileManager* fm = [NSFileManager defaultManager];
  NSArray* folderContents = [fm contentsOfDirectoryAtPath:folder error:nil];
  NSUInteger numPluginsLoaded = 0;
  NSError* fileError;
  for ( NSString* itemPath in folderContents )
  {
    NSString* fullPath = [folder stringByAppendingPathComponent:itemPath];
    NSDictionary* itemAttribs = [fm attributesOfItemAtPath:fullPath error:&fileError];
    if ( itemAttribs != nil )
    {
      // Test whether it's a directory.
      if ( [[itemAttribs valueForKey:NSFileType] isEqualToString:NSFileTypeDirectory] )
      {
        // Is it a Volta plugin?
        FXVoltaPlugin* pluginInfo = [[FXVoltaPlugin alloc] initWithBundlePath:fullPath];
        NSError* error = nil;
        if ( [pluginInfo loadWithError:&error] )
        {
          NSAssert( ([pluginInfo type] >= VoltaPluginType_First) && ([pluginInfo type] < VoltaPluginType_Count), @"Unsupported plugin type" );
          FXVoltaPluginGroup* pluginGroup = mPlugins[@([pluginInfo type])];
          NSAssert( pluginGroup != nil, @"A group for the given plugin type should exist." );
          [[pluginGroup plugins] addObject:pluginInfo];
          [pluginGroup setActivePlugin:pluginInfo];
          numPluginsLoaded++;
        }
        else
        {
          [[NSAlert alertWithError:error] runModal];
        }
        FXRelease(pluginInfo)
      }
    }
    else
    {
      DebugLog( @"%@", [fileError localizedDescription] );
    }
  }
  return numPluginsLoaded;
}


- (void) loadPluginsView
{
  [[NSBundle mainBundle] loadNibNamed:@"VoltaPluginPreferences" owner:self topLevelObjects:NULL];
  NSAssert( mContainer != nil, @"Error loading plugin preference view" );
	
  NSCell* selectionCell = [[mPluginsTable tableColumnWithIdentifier:@"selected"] dataCell];
  [selectionCell setTarget:self];
  [selectionCell setAction:@selector(activateSelectedPlugin:)];
	
  [mPluginsTable setDataSource:self];
  [mPluginsTable setDelegate:self];
}


#pragma mark Public


- (NSView*) view
{
  if ( mContainer == nil )
  {
    [self loadPluginsView];
  }
  NSAssert( mContainer != nil, @"Something must have gone wrong while loading the plugins view." );
  return mContainer;
}

- (NSArray*) pluginsForType:(VoltaPluginType)pluginType
{
  FXVoltaPluginGroup* pluginGroup = mPlugins[@(pluginType)];
  return [pluginGroup plugins];
}

- (FXVoltaPlugin*) activePluginForType:(VoltaPluginType)pluginType
{
  FXVoltaPluginGroup* pluginGroup = mPlugins[@(pluginType)];
  return [pluginGroup activePlugin];
}

- (void) activate:(FXVoltaPlugin*)plugin
{
  NSNumber* pluginTypeNumber = @([plugin type]);
  FXVoltaPluginGroup* pluginGroup = mPlugins[pluginTypeNumber];
  [pluginGroup setActivePlugin:plugin];
  [[NSNotificationCenter defaultCenter] postNotificationName:FXVoltaPluginActivatedNotification object:pluginTypeNumber];
}

- (IBAction) activateSelectedPlugin:(id)sender
{
  id selectedItem = [mPluginsTable itemAtRow:[mPluginsTable selectedRow]];
  NSAssert( [selectedItem isKindOfClass:[FXVoltaPlugin class]], @"the selected row must represent a VoltaPluginInfo" );
  FXVoltaPlugin* plugin = (FXVoltaPlugin*) selectedItem;
  FXVoltaPluginGroup* pluginGroup = (FXVoltaPluginGroup*) [mPluginsTable parentForItem:selectedItem];

  if ( [pluginGroup activePlugin] != plugin )
  {
    [pluginGroup setActivePlugin:plugin];
    [mPluginsTable reloadData];

    FXIssue(17)
    [[NSNotificationCenter defaultCenter] postNotificationName:FXVoltaAllDocumentsShouldCloseAndReopenNotification object:self];
  }
}


@end
