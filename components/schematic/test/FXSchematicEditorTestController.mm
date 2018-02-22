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

#import "FXSchematicEditorTestController.h"
#import "FXSchematicController.h"
#import "VoltaPlugin.h"
#import "FXVoltaLibrary.h"

@implementation FXSchematicEditorTestController
{
@private
  id<VoltaSchematicEditor> mSchematicEditor;
  id<VoltaLibrary> mLibrary;
  NSWindow* mWindow;
}

@synthesize window = mWindow;

- (id) init
{
  if ( (self = [super init]) != nil )
  {
    mSchematicEditor = nil;
    mWindow = nil;
    mLibrary = [[FXVoltaLibrary alloc] initWithConfiguration:FXVoltaLibraryConfiguration_ReadWriteArchive];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mSchematicEditor)
  FXRelease(mLibrary)
  FXDeallocSuper
}


- (void) loadSchematicEditorPlugin
{
  NSURL* builtInPluginsFolderURL = [[NSBundle mainBundle] builtInPlugInsURL];
  NSURL* schematicEditorBundleURL = [builtInPluginsFolderURL URLByAppendingPathComponent:@"SchematicEditor.bundle"];
  NSBundle* pluginBundle = [[NSBundle alloc] initWithURL:schematicEditorBundleURL];
  if ( (pluginBundle != nil) && [pluginBundle loadAndReturnError:nil] )
  {
    Class principalClass = [pluginBundle principalClass];
    if ( principalClass != nil )
    {
      NSObject* instance = [[principalClass alloc] init];
      if ( instance && [instance conformsToProtocol:@protocol(VoltaPlugin)] )
      {
        id<VoltaPlugin> pluginMainObject = (id<VoltaPlugin>) instance;
        if ( [pluginMainObject pluginType] == VoltaPluginType_SchematicEditor )
        {
          mSchematicEditor = (id<VoltaSchematicEditor>) [pluginMainObject newPluginImplementer];
        }
      }
      else
      {
        FXRelease(instance)
      }
    }
  }
}


- (void) awakeFromNib
{
  NSAssert( mWindow != nil, @"A window should already exist." );

  [self loadSchematicEditorPlugin];
  NSAssert( mSchematicEditor != nil, @"There was a problem loading the schematic editor plugin." );
  [mSchematicEditor setLibrary:mLibrary];

  NSRect contentRect = [[mWindow contentView] frame];
  contentRect.origin.x = 0;
  contentRect.origin.y = 0;
  NSView* schematicView = [mSchematicEditor schematicView];
  [schematicView setFrame:contentRect];
  [schematicView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [[mWindow contentView] addSubview:schematicView];

  [mWindow center];
  [mWindow makeKeyAndOrderFront:self];
}


@end
