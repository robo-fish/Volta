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

#import "FXNetlistEditorTestController.h"
#import "FXNetlistEditorVoltaPlugin.h"

@implementation FXNetlistEditorTestController

- (id) init
{
  [super init];
  mEditorBox = nil;
  mNetlistEditor = nil;
  mOutputTextView = nil;
  mWindow = nil;
  mUndoManager = nil;
  return self;
}


- (void) dealloc
{
  FXRelease(mUndoManager)
  FXDeallocSuper
}


- (void) awakeFromNib
{
  NSAssert( mEditorBox != nil, @"Error while awaking NIB" );
  id<VoltaPlugin> netlistEditorPlugin = [[FX(FXNetlistEditorVoltaPlugin) alloc] init];
  mNetlistEditor = (id<VoltaNetlistEditor>)[netlistEditorPlugin newPluginImplementer];
  NSView* pluginView = [mNetlistEditor editorView];
  [pluginView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [pluginView setFrame:[[mEditorBox contentView] frame]];
  [mEditorBox setContentView:pluginView];
  mUndoManager = [[NSUndoManager alloc] init];
  [mNetlistEditor setUndoManager:mUndoManager];
}

#pragma mark -

- (void) updateDocumentEditedStatus:(NSNotification*)notification
{
  [mOutputTextView setString:[mNetlistEditor netlistString]];
}


@end
