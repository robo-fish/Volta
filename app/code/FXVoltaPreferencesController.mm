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

#import "FXVoltaPreferencesController.h"
#import "FXVoltaPluginsController.h"

NSString* const sPluginToolbarItemIdentifier = @"PluginToolbarItemIdentifier";
NSString* const sServicesToolbarItemIdentifier = @"ServicesToolbarItemIdentifier";
NSString* const FXVoltaInitialRun = @"InitialRun";


@interface FXVoltaPreferencesController ()
- (NSToolbarItem*) createToolbarItemWithIdentifier:(NSString*)itemIdentifier
                                         imageName:(NSString*)itemImageName
                                             label:(NSString*)itemLabel;
@end


@implementation FXVoltaPreferencesController


+ (void) initialize
{
  [[NSUserDefaults standardUserDefaults] registerDefaults:@{
    FXVoltaInitialRun : @YES
  }];
}


- (id) init
{
	if ( (self = [super initWithWindowNibName:@"VoltaPreferences"]) != nil )
	{
		mPluginsToolbarItem = nil;
		mServicesToolbarItem = nil;
	}
	return self;
}

- (void) dealloc
{
  FXRelease(mPluginsToolbarItem)
  FXRelease(mServicesToolbarItem)
  FXDeallocSuper
}


#pragma mark Public methods


+ (BOOL) isInitialRun
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  return ([userDefaults objectForKey:FXVoltaInitialRun] == nil) || [userDefaults boolForKey:FXVoltaInitialRun];
}


+ (void) setIsInitialRun:(BOOL)isInitialRun
{
  [[NSUserDefaults standardUserDefaults] setValue:@(isInitialRun) forKey:FXVoltaInitialRun];
}


- (void) showPreference:(id)sender
{
  NSToolbarItem* senderItem = (NSToolbarItem*) sender;
  NSString* tbarID = [senderItem itemIdentifier];
  if ( [tbarID isEqualToString:sPluginToolbarItemIdentifier] )
  {
    self.window.contentView = [[FXVoltaPluginsController sharedController] view];
  }
}


#pragma mark NSWindowController overrides


- (void) windowDidLoad
{
  mToolbar = [[NSToolbar alloc] initWithIdentifier:@"PreferencesToolbar"];
  mToolbar.allowsUserCustomization = NO;
  mToolbar.delegate = self;
  self.window.toolbar = mToolbar;
  self.window.title = FXLocalizedString(@"Volta Preferences");
}


#pragma mark NSToolbarDelegate


- (NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*) toolbar
{
  NSAssert( toolbar == mToolbar, @"calling delegate method for wrong toolbar" );
  return @[sPluginToolbarItemIdentifier,
  #if VOLTA_DEBUG
    sServicesToolbarItemIdentifier
  #endif
  ];
}


- (NSArray*) toolbarAllowedItemIdentifiers:(NSToolbar*) toolbar
{
  return [self toolbarDefaultItemIdentifiers:toolbar];
}


- (NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar*) toolbar
{
  return [self toolbarDefaultItemIdentifiers:toolbar];
}


- (NSToolbarItem*) toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
  NSToolbarItem* result = nil;
  NSAssert( toolbar == mToolbar, @"calling delegate method for wrong toolbar" );
  if ( [itemIdentifier isEqualToString:sPluginToolbarItemIdentifier] )
  {
    if ( mPluginsToolbarItem == nil )
    {
      mPluginsToolbarItem = [self
        createToolbarItemWithIdentifier:sPluginToolbarItemIdentifier
        imageName:@"preferences_toolbar_plugins_icon"
        label:FXLocalizedString(@"Plugins")];
    }
    result = mPluginsToolbarItem;
  }

#if 0
  else if ( [itemIdentifier isEqualToString:sServicesToolbarItemIdentifier] )
  {
    if ( mServicesToolbarItem == nil )
    {
      mServicesToolbarItem = [self
        createToolbarItemWithIdentifier:sServicesToolbarItemIdentifier
        imageName:@"preferences_toolbar_services_icon"
        label:FXLocalizedString(@"Services")];
    }
    result = mServicesToolbarItem;
  }
#endif

  if ( result != nil )
  {
    [result setAction:@selector(showPreference:)];
    [result setTarget:self];
  }

  return result;
}


#pragma mark Private


- (NSToolbarItem*) createToolbarItemWithIdentifier:(NSString*)itemIdentifier
                                         imageName:(NSString*)itemImageName
                                             label:(NSString*)itemLabel
{
  NSToolbarItem* result = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
  result.image = [NSImage imageNamed:itemImageName];
  result.label = itemLabel;
  return result;
}


@end
