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
#import "FXVoltaPluginGroup.h"
#import "FXVoltaPlugin.h"

@implementation FXVoltaPluginsController (TableDataSource)

////////////////////////////////////////////////////////////////////////////////
#pragma mark NSOutlineViewDataSource implementation

- (NSInteger) outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
  NSAssert( outlineView == mPluginsTable, @"this data source is not intended for the given table" );
  if ( item == nil )
  {
    return [mPlugins count];
  }
  else
  {
    NSAssert( [item isKindOfClass:[FXVoltaPluginGroup class]], @"Was expecting a VoltaPluginGroup" );
    return [[((FXVoltaPluginGroup*)item) plugins] count];
  }
}


- (BOOL) outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
  NSAssert( outlineView == mPluginsTable, @"this data source is not intended for the given table" );
  if ( [item isKindOfClass:[FXVoltaPluginGroup class]] && [[(FXVoltaPluginGroup*)item plugins] count] )
  {
    return YES;
  }
  return NO;
}


- (id) outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
  NSAssert( outlineView == mPluginsTable, @"this data source is not intended for the given table" );
  if ( item == nil )
  {
    NSAssert( index < [mPlugins count], @"The child index of the outline view's root container must be less than the number of supported plugin types" );
    return mPlugins[@(index)];
  }
  else
  {
    NSAssert( [item isKindOfClass:[FXVoltaPluginGroup class]], @"Since the max depth of the outline view is 1 the item must be a plugin array." );
    return [[((FXVoltaPluginGroup*) item) plugins] objectAtIndex:index];
  }
  return nil;
}


- (id) outlineView:(NSOutlineView*)outlineView objectValueForTableColumn:(NSTableColumn*)tableColumn byItem:(id)item
{
  NSAssert( outlineView == mPluginsTable, @"this data source is not intended for the given table" );
  if ( [item isKindOfClass:[FXVoltaPluginGroup class]] )
  {
    if ( [[tableColumn identifier] isEqualToString:@"name"] )
    {
      return [((FXVoltaPluginGroup*)item) name];
    }
    return nil;
  }
  else if ( [item isKindOfClass:[FXVoltaPlugin class]] )
  {
    if ( ![[tableColumn identifier] isEqualToString:@"selected"] )
    {
      NSString* pluginData = [((FXVoltaPlugin*)item) valueForKey:[tableColumn identifier]];
      if ( [[tableColumn identifier] isEqualToString:@"bundlePath"] )
      {
        pluginData = [pluginData hasPrefix:[[NSBundle mainBundle] bundlePath]] ? FXLocalizedString(@"Built-in") : pluginData;
      }
      return pluginData;
    }
    return nil;
  }
  return nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark NSOutlineViewDelegate implementation

- (void) outlineView:(NSOutlineView *)outlineView
     willDisplayCell:(id)cell
      forTableColumn:(NSTableColumn *)tableColumn
                item:(id)item
{
  NSAssert( outlineView == mPluginsTable, @"this data source is not intended for the given table" );
  if ( [item isKindOfClass:[FXVoltaPlugin class]] )
  {
    FXVoltaPluginGroup* group = (FXVoltaPluginGroup*)[outlineView parentForItem:item];
    NSAssert( group != nil, @"must have a parent" );
    if ( [[tableColumn identifier] isEqualToString:@"selected"] )
    {
      NSButtonCell* buttonCell = (NSButtonCell*) cell;
      [buttonCell setEnabled:YES];
      [buttonCell setTransparent:NO]; // Need to make the cell explicitly opaque because the previous cell may have been set transparent
      [buttonCell setState:( ([group activePlugin] == item) ? NSOnState : NSOffState )];
    }
  }
  else if ( [item isKindOfClass:[FXVoltaPluginGroup class]] )
  {
    if ( [[tableColumn identifier] isEqualToString:@"name"] )
    {
      // Disabling the group if it has no plugins
      NSTextFieldCell* nameCell = (NSTextFieldCell*) cell;
      [nameCell setEnabled:( [[(FXVoltaPluginGroup*)item plugins] count] > 0 )];
    }
    else if ( [[tableColumn identifier] isEqualToString:@"selected"] )
    {
      NSButtonCell* buttonCell = (NSButtonCell*) cell;
      [buttonCell setTransparent:YES]; // this should make the cell disappear
    }
  }
}


- (BOOL) outlineView:(NSOutlineView*)outlineView shouldSelectItem:(id)item
{
  NSAssert( outlineView == mPluginsTable, @"this data source is not intended for the given table" );
  return [item isKindOfClass:[FXVoltaPluginGroup class]] ? NO : YES;
}


- (void) outlineViewSelectionDidChange:(NSNotification *)notification
{
}


@end
