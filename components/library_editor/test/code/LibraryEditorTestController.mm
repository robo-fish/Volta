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

#import "LibraryEditorTestController.h"
#import "FXLibraryEditor.h"
#import "VoltaPlugin.h"


@implementation LibraryEditorTestController
{
@private
  id<VoltaLibraryEditor> mEditor;
  id<VoltaLibrary> mLibrary;
}


- (void) dealloc
{
  FXRelease(mEditor)
  FXRelease(mLibrary)
  FXDeallocSuper
}


- (void) awakeFromNib
{
  [[self editor] show];
}


#pragma mark Public


- (IBAction) showLibraryEditor:(id)sender
{
  [[self editor] show];
}


#pragma mark Private


- (id<VoltaLibraryEditor>) editor
{
  if ( mEditor == nil )
  {
    NSURL* libraryEditorBundlePath = [[[NSBundle mainBundle] builtInPlugInsURL] URLByAppendingPathComponent:@"LibraryEditor.bundle"];
    NSBundle* libraryEditorBundle = [NSBundle bundleWithURL:libraryEditorBundlePath];
    if ( [libraryEditorBundle load] )
    {
      Class pluginClass = [libraryEditorBundle principalClass];
      id<VoltaPlugin> pluginObject = [pluginClass new];
      mEditor = (id<VoltaLibraryEditor>)[pluginObject newPluginImplementer];
      mLibrary = [[FXVoltaLibrary alloc] initWithConfiguration:FXVoltaLibraryConfiguration_ReadOnlyArchive];
      [mEditor setLibrary:mLibrary];
      FXRelease(pluginObject)
    }
  }
  return mEditor;
}


@end
