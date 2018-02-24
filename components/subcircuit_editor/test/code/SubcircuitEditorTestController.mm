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

#import "SubcircuitEditorTestController.h"
#import "VoltaSubcircuitEditor.h"
#import "VoltaPlugin.h"
#import "FXTestingUtilities.h"
#import "FXTestingHarness.h"


@implementation SubcircuitEditorTestController
{
@private
  id<VoltaSubcircuitEditor> mEditor;
  FXTestingHarness* mHarness;
}


- (void) awakeFromNib
{
  NSView* editorView = [[self editor] view];
  [editorView setAutoresizingMask:(NSViewHeightSizable|NSViewWidthSizable)];
  mHarness = [[FXTestingHarness alloc] initWithTestableView:editorView testProvider:self];
  [mHarness.harnessWindow makeKeyAndOrderFront:self];
}


- (id<VoltaSubcircuitEditor>) editor
{
  if ( mEditor == nil )
  {
    NSURL* subcircuitEditorBundlePath = [[[NSBundle mainBundle] builtInPlugInsURL] URLByAppendingPathComponent:@"SubcircuitEditor.bundle"];
    NSBundle* subcircuitEditorBundle = [NSBundle bundleWithURL:subcircuitEditorBundlePath];
    if ( [subcircuitEditorBundle load] )
    {
      Class pluginClass = [subcircuitEditorBundle principalClass];
      id<VoltaPlugin> pluginObject = [pluginClass new];
      mEditor = (id<VoltaSubcircuitEditor>)[pluginObject newPluginImplementer];
      FXRelease(pluginObject)
    }
  }
  return mEditor;
}


#pragma mark Tests


- (void) test_enabling_disabling
{

}


- (void) test_PinCountSelection
{
  NSView* pinCountSelector = [FXTestingUtilities findViewWithIdentifier:@"PinCountSelector" startingAtView:[mEditor view]];
  if ( pinCountSelector == nil )
  {
    [mHarness logError:@"Could not find object with description \"PinCountSelector\"."];
  }
  else
  {
    NSMenu* menuObject = (NSMenu*)[FXTestingUtilities findObjectWithRole:(NSString*)kAXMenuRole startingAtObject:pinCountSelector];
    if ( menuObject == nil )
    {
      [mHarness logError:@"Could not find menu object"];
    }
    else
    {
      [pinCountSelector accessibilityPerformAction:NSAccessibilityShowMenuAction];
    }
  }
}


- (void) test_subcircuit_title_entry
{

}


- (void) test_subcircuit_vendor_entry
{

}


@end
