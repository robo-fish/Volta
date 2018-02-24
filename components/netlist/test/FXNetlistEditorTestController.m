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
#import "VoltaNetlistEditor.h"

@interface FXNetlistEditorTestController () <NSWindowDelegate>
@end

@implementation FXNetlistEditorTestController
{
  IBOutlet NSWindow*     mWindow;
  IBOutlet NSBox*        mEditorBox;

@private
  id<VoltaNetlistEditor> _netlistEditor;
  NSUndoManager*         _undoManager;
}

- (id) init
{
  self = [super init];
  mEditorBox = nil;
  mWindow = nil;
  _netlistEditor = nil;
  _undoManager = nil;
  return self;
}

- (void) awakeFromNib
{
  NSAssert( mEditorBox != nil, @"Error while awaking NIB" );
  id<VoltaPlugin> netlistEditorPlugin = [[FX(FXNetlistEditorVoltaPlugin) alloc] init];
  _netlistEditor = (id<VoltaNetlistEditor>)[netlistEditorPlugin newPluginImplementer];
  NSView* pluginView = [_netlistEditor editorView];
  [pluginView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [pluginView setFrame:[[mEditorBox contentView] frame]];
  [mEditorBox setContentView:pluginView];
  _undoManager = [[NSUndoManager alloc] init];
  [_netlistEditor setUndoManager:_undoManager];
}

//MARK: NSWindowDelegate

- (BOOL) windowShouldClose:(NSWindow *)sender
{
  [[NSApplication sharedApplication] terminate:self];
  return YES;
}

@end
