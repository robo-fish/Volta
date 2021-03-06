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

#import "FXPlotterTestController.h"
#import "FXSpiceOutputParser.h"
#import "VoltaPlugin.h"
#import "VoltaPlotter.h"


@interface FXPlotterTestController ()
- (void) createSimulationData;
@end


#pragma mark -


@implementation FXPlotterTestController
{
@private
  id<VoltaPlotter> mPlotter;
  VoltaPTSimulationDataPtr mSimulationData;
}


- (id) init
{
  self = [super init];
  return self;
}


- (void) dealloc
{
  FXRelease(mPlotter)
  FXDeallocSuper
}


- (void) loadPlotterPlugin
{
  NSURL* pluginsFolderURL = [[NSBundle mainBundle] builtInPlugInsURL];
  NSURL* plotterBundleURL = [pluginsFolderURL URLByAppendingPathComponent:@"Plotter.bundle"];
  NSBundle* pluginBundle = [NSBundle bundleWithURL:plotterBundleURL];
  if ( pluginBundle != nil )
  {
    NSError* loadError = nil;
    if ( ![pluginBundle loadAndReturnError:&loadError] )
    {
      [NSApp presentError:loadError];
    }
    else
    {
      Class principalClass = [pluginBundle principalClass];
      if ( principalClass != nil )
      {
        NSObject* instance = [[principalClass alloc] init];
        if ( instance && [instance conformsToProtocol:@protocol(VoltaPlugin)] )
        {
          if ( [(id<VoltaPlugin>)instance pluginType] == VoltaPluginType_Plotter )
          {
            mPlotter = (id<VoltaPlotter>)[(id<VoltaPlugin>)instance newPluginImplementer];
          }
          else
          {
            [self showAlertWithTitle:@"Bundle is not a Volta plotter plugin." message:@"The bundle's plugin type does not match the plotter type."];
          }
        }
        else
        {
          [self showAlertWithTitle:@"Bundle is not a Volta plugin." message:@"The bundle's main class does not conform to the VoltaPlugin protocol."];
        }
        FXRelease(instance)
      }
    }
  }
}


- (void) awakeFromNib
{
  NSAssert( self.plotterWindow != nil, @"UI is not initialized" );
  [self loadPlotterPlugin];

  NSView* plotterView = [mPlotter view];
  NSAssert( plotterView != nil, @"A plotter view must exist." );
  [plotterView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  NSRect contentRect = [self.plotterWindow contentRectForFrameRect:[self.plotterWindow frame]];
  [plotterView setFrame:NSMakeRect(0, 0, contentRect.size.width, contentRect.size.height)];
  [self.plotterWindow setContentView:plotterView];

  [self createSimulationData];
  if ( mSimulationData.get() != nullptr )
  {
    [mPlotter setSimulationData:mSimulationData];
  }
}


#pragma mark Private methods


- (void) createSimulationData
{
  static NSString* skSampleOutputFileName = @"ngspice_output_2.txt";
  NSString* simulatorRawOutputFilePath = [[NSBundle mainBundle] pathForResource:skSampleOutputFileName ofType:nil];
  if ( simulatorRawOutputFilePath == nil )
  {
    [self showAlertWithTitle:@"Could not find test data" message:[NSString stringWithFormat:@"The sample SPICE output file %@ could not be located.", skSampleOutputFileName]];
    return;
  }

  NSString* simulatorRawOutput = [NSString stringWithContentsOfFile:simulatorRawOutputFilePath encoding:NSASCIIStringEncoding error:NULL];
  mSimulationData = FXSpiceOutputParser::parse((__bridge CFStringRef)simulatorRawOutput);
}

- (void) showAlertWithTitle:(NSString*)title message:(NSString*)message
{
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = title;
  alert.informativeText = message;
  [alert addButtonWithTitle:@"OK"];
  [alert beginSheetModalForWindow:self.plotterWindow completionHandler:^(NSModalResponse returnCode) {
    [self.plotterWindow orderOut:self];
  }];
}


@end
