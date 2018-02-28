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

#import "FXPlotterController.h"
#import "FXPlotterView.h"
#import <FXKit/FXKit-Swift.h>

@interface FX(FXPlotterController) ()
- (void) updatePlotSelectorMenu;
- (void) selectPlotForMenuItem:(id)sender;
- (void) selectPlotAtIndex:(NSInteger)index;
@end


#pragma mark -


@implementation FX(FXPlotterController)
{
@private
  FXPlotterGraphDataPtr _graphData;
  FXOverlayTextLineView* _infoView;
}


- (id) init
{
  self = [super initWithNibName:@"Plotter" bundle:[NSBundle bundleForClass:[self class]]];
  if ( self != nil )
  {
    _graphData = FXPlotterGraphDataPtr( new FXPlotterGraphData );
  }
  return self;
}


- (void) awakeFromNib
{
  NSAssert( _plotterView != nil, @"The plotter view should have been loaded by now." );
  CGColorRef whiteColor = CGColorCreateGenericRGB( 1.0, 1.0, 1.0, 1.0 );
  _plotterView.client = self;
  _plotterView.backgroundColor = whiteColor;
  _plotterView.nextResponder = self;
  CGColorRelease(whiteColor);
  [self addNoDataInfo];
}


#pragma mark NSResponder overrides


- (void) mouseDown:(NSEvent*)mouseEvent
{
  [[self.view window] makeFirstResponder:self];
  [super mouseDown:mouseEvent];
}


#pragma mark VoltaPlotter


- (CGSize) minimumViewSize
{
  return CGSizeMake(180, 180);
}


- (void) clear
{
  if ( _graphData.get() != nullptr )
  {
    _graphData->clear();
  }
  [self updatePlotSelectorMenu];
  [_plotterView refresh];
  [self addNoDataInfo];
}


- (void) setSimulationData:(VoltaPTSimulationDataPtr)simulationData
{
  BOOL showNoDataInfo = YES;
  if ( simulationData.get() != nullptr )
  {
    _graphData = FXPlotterGraphDataPtr( new FXPlotterGraphData(simulationData) );
    showNoDataInfo = _graphData->plots().empty();
    [self updatePlotSelectorMenu];
    [self selectPlotAtIndex:0];
  }
  if ( showNoDataInfo )
  {
    [self addNoDataInfo];
  }
  else
  {
    [self removeNoDataInfo];
  }
}


#pragma mark VoltaPrintable


- (FXView*) newPrintableView
{
  FXPlotterView* printableView = nil;
  if ( !_graphData->plots().empty() )
  {
    printableView = [[FXPlotterView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
    printableView.plotIndex = _plotterView.plotIndex;
    printableView.client = self;
  }
  return printableView;
}


- (NSArray*) optionsForPrintableView:(FXView*)view
{
  NSMutableArray* plotNames = [NSMutableArray new];
  for ( FXPlotterPlot const & plot : _graphData->plots() )
  {
    [plotNames addObject:[NSString stringWithString:(__bridge NSString*)plot.getTitle().cfString()]];
  }
  FXAutorelease(plotNames)
  return plotNames;
}


- (NSInteger) selectedOptionForPrintableView:(FXView*)view
{
  return [view isKindOfClass:[FXPlotterView class]] ? [(FXPlotterView*)view plotIndex] : -1;
}


- (void) selectOption:(NSInteger)index forPrintableView:(FXView*)view
{
  if ( [view isKindOfClass:[FXPlotterView class]] )
  {
    FXPlotterView* plotterView = (FXPlotterView*)view;
    plotterView.plotIndex = index;
    [plotterView refresh];
  }
}


#pragma mark FXPlotterViewClient


- (BOOL) hasPlotForIndex:(NSInteger)plotIndex
{
  return (plotIndex >= 0) && (plotIndex < _graphData->plots().size());
}


- (FXPlotterPlot const &) plotForIndex:(NSInteger)plotIndex
{
  return _graphData->plots().at(plotIndex);
}


#pragma mark Private methods


- (void) updatePlotSelectorMenu
{
  if ( _plotSelector != nil )
  {
    [_plotSelector removeAllItems];
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
    NSInteger tagCounter = 0;
    for ( FXPlotterPlot const & plot : _graphData->plots() )
    {
      NSString* menuItemTitle = [NSString stringWithFormat:@"%@", plot.getTitle().cfString()];
      NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:menuItemTitle action:@selector(selectPlotForMenuItem:) keyEquivalent:@""];
      [menuItem setTarget:self];
      [menuItem setTag:tagCounter++];
      [menu addItem:menuItem];
      FXRelease(menuItem)
    }
    [_plotSelector setMenu:menu];
    FXRelease(menu)

    NSPopUpArrowPosition const allowSelection = ([[menu itemArray] count] < 2) ? NSPopUpNoArrow : NSPopUpArrowAtBottom;
    [(NSPopUpButtonCell*)[_plotSelector cell] setArrowPosition:allowSelection];
    [_plotSelector setEnabled:allowSelection];
  }
}


- (void) selectPlotForMenuItem:(id)sender
{
  NSInteger plotIndex = [(NSMenuItem*)sender tag];
  [self selectPlotAtIndex:plotIndex];
}


- (void) selectPlotAtIndex:(NSInteger)plotIndex
{
  _plotterView.plotIndex = plotIndex;
  [_plotterView refresh];
}


- (void) addNoDataInfo
{
  if ( _infoView == nil )
  {
    NSRect overlayFrame = self.view.frame;
    overlayFrame.origin = NSZeroPoint;
    _infoView = [[FXOverlayTextLineView alloc] initWithFrame:overlayFrame];
    _infoView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    _infoView.text = FXLocalizedString(@"NoData");
    [self.view addSubview:_infoView];
    FXRelease(mInfoView)
  }
}


- (void) removeNoDataInfo
{
  [_infoView removeFromSuperview];
  _infoView = nil;
}


@end
