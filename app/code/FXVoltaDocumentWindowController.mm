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

#import "FXVoltaDocumentWindowController.h"
#import "FXVoltaDocumentWindow.h"
#import "FXVoltaPersistentMetaKeys.h"
#import <FXKit/FXKit-Swift.h>


static const CGFloat skPlotterWorkAreaMinimumHeight                             = 25.0;
static const CGFloat skCircuitProcessorsWorkAreaMinimumWidth                    = 50.0;
static const CGFloat skSchematicEditorInitialRelativeWidth                      = 0.6;
static const CGFloat skSchematicEditorInitialRelativeHeight                     = 0.6;
NSString* FXVoltaCircuitDocumentWindowIdentifier                                = @"VoltaCircuitDocumentWindow";

typedef NS_ENUM(NSInteger, FXWorkAreaAnimationType)
{
  FXWorkAreaAnimation_None,
  FXWorkAreaAnimation_Open,
  FXWorkAreaAnimation_Close
};


@implementation FXVoltaDocumentWindowController
{
@private
  NSSplitView*     mNetlistAndProcessorsSplitView;
  NSSplitView*     mSchematicAndProcessorsSplitView;
  NSSplitView*     mSchematicAndPlotterSplitView;
  FXClipView*      mSchematicClipView;
  FXClipView*      mPlotterClipView;
  FXClipView*      mSubcircuitClipView;
  FXClipView*      mNetlistClipView;
  FXClipView*      mSimulatorClipView;
  FXTabView*       mCircuitProcessorsTabView;
  NSScrollView*    mSubcircuitEditorScrollView;

  FXWorkAreaAnimationType mPlotterAreaAnimationType;
  FXWorkAreaAnimationType mProcessorsAreaAnimationType;
  NSTimer* mSchematicAndPlotterSplitViewAnimationTimer;
  NSTimer* mSchematicAndProcessorsSplitViewAnimationTimer;

#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
  BOOL mCircuitProcessorsWereVisibleWhenEnteringVersionBrowser;
  BOOL mPlotterWasVisibleWhenEnteringVersionBrowser;
#endif

  CGFloat mSchematicEditorRelativeWidthBeforePanelCloseAnimation;
  CGFloat mSchematicEditorRelativeHeightBeforePanelCloseAnimation;

  BOOL mInsideVersionsBrowser;
}


- (id) init
{
  NSRect const dummyRect = { 0, 0, 200, 200 };
  NSUInteger const kVoltaDocumentWindowStyleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
  FXVoltaDocumentWindow* window = [[FXVoltaDocumentWindow alloc] initWithContentRect:dummyRect styleMask:kVoltaDocumentWindowStyleMask backing:NSBackingStoreBuffered defer:YES];
  if ( (self = [super initWithWindow:window]) != nil )
  {
    mPlotterAreaAnimationType = FXWorkAreaAnimation_None;
    mProcessorsAreaAnimationType = FXWorkAreaAnimation_None;
    mInsideVersionsBrowser = NO;
    mSchematicEditorRelativeWidthBeforePanelCloseAnimation = skSchematicEditorInitialRelativeWidth;
    mSchematicEditorRelativeHeightBeforePanelCloseAnimation = skSchematicEditorInitialRelativeHeight;
    [self setUpWindow];
  }
  return self;
}


#pragma mark Public


/// @return whether the circuit processors area is visible in the document window
- (BOOL) circuitProcessorsAreVisible
{
  CGFloat const splitterWidth = [mSchematicAndProcessorsSplitView frame].size.width;
  CGFloat const schematicEditorWidth = [[[mSchematicAndProcessorsSplitView subviews] objectAtIndex:0] frame].size.width;
  return (splitterWidth - schematicEditorWidth) > skCircuitProcessorsWorkAreaMinimumWidth;
}


- (void) hideCircuitProcessors
{
  if ( [self circuitProcessorsAreVisible] && (mSchematicAndProcessorsSplitViewAnimationTimer == nil) )
  {
    mSchematicEditorRelativeWidthBeforePanelCloseAnimation = 1.0 - (mNetlistAndProcessorsSplitView.frame.size.width / mSchematicAndProcessorsSplitView.frame.size.width);
    mProcessorsAreaAnimationType = FXWorkAreaAnimation_Close;
    [self runProcessorsWorkAreaAnimation:nil]; FXIssue(34)
  }
}


- (void) revealCircuitProcessors
{
  if ( ![self circuitProcessorsAreVisible] && (mSchematicAndProcessorsSplitViewAnimationTimer == nil) )
  {
    if ( floor([mSchematicAndProcessorsSplitView frame].size.width * (1.0 - mSchematicEditorRelativeWidthBeforePanelCloseAnimation)) < skCircuitProcessorsWorkAreaMinimumWidth )
    {
      mSchematicEditorRelativeWidthBeforePanelCloseAnimation = skSchematicEditorInitialRelativeWidth;
    }
    mProcessorsAreaAnimationType = FXWorkAreaAnimation_Open;
    [self runProcessorsWorkAreaAnimation:nil]; FXIssue(34)
  }
}


- (void) toggleCircuitProcessorsPanel:(id)sender
{
  FXIssue(08)
  FXIssue(21)
  if ( [self circuitProcessorsAreVisible] )
    [self hideCircuitProcessors];
  else
    [self revealCircuitProcessors];
}


- (void) selectCircuitProcessorsTabWithTitle:(NSString*)tabTitle
{
  [mCircuitProcessorsTabView selectTabWithTitle:tabTitle animate:NO];
}


- (void) revealNetlistEditor
{
  if ( ![self circuitProcessorsAreVisible] )
  {
    [self revealCircuitProcessors];
  }
}


- (void) revealSimulatorOutput
{
  if ( [self circuitProcessorsAreVisible] )
  {
    [mCircuitProcessorsTabView selectTabWithTitle:FXLocalizedString(@"Simulator") animate:YES];
  }
  else
  {
    [mCircuitProcessorsTabView selectTabWithTitle:FXLocalizedString(@"Simulator") animate:NO];
    [self revealCircuitProcessors];
  }
}


- (void) revealSubcircuitEditor:(id)sender
{
  if ( [self circuitProcessorsAreVisible] )
  {
    [mCircuitProcessorsTabView selectTabWithTitle:FXLocalizedString(@"Subcircuit") animate:YES];
  }
  else
  {
    [mCircuitProcessorsTabView selectTabWithTitle:FXLocalizedString(@"Subcircuit") animate:NO];
    [self revealCircuitProcessors];
  }
}


- (BOOL) plotterIsVisible
{
  return mPlotterClipView.frame.size.height > skPlotterWorkAreaMinimumHeight;
}


- (void) revealPlotter
{
  if ( ![self plotterIsVisible] && (mSchematicAndPlotterSplitViewAnimationTimer == nil) )
  {
    if ( floor([mSchematicAndPlotterSplitView frame].size.width * (1.0 - mSchematicEditorRelativeHeightBeforePanelCloseAnimation)) < skPlotterWorkAreaMinimumHeight )
    {
      mSchematicEditorRelativeHeightBeforePanelCloseAnimation = skSchematicEditorInitialRelativeHeight;
    }
    mPlotterAreaAnimationType = FXWorkAreaAnimation_Open;
    [self runPlotterWorkAreaAnimation:nil]; FXIssue(34)
  }
}


- (void) hidePlotter
{
  if ( [self plotterIsVisible] && (mSchematicAndPlotterSplitViewAnimationTimer == nil) )
  {
    mSchematicEditorRelativeHeightBeforePanelCloseAnimation = ([(NSView*)[[mSchematicAndPlotterSplitView subviews] objectAtIndex:0] frame].size.height / mSchematicAndPlotterSplitView.frame.size.height);
    mPlotterAreaAnimationType = FXWorkAreaAnimation_Close;
    [self runPlotterWorkAreaAnimation:nil]; FXIssue(34)
  }
}


- (void) togglePlotterPanel:(id)sender
{
  FXIssue(62)
  if ( [self plotterIsVisible] )
    [self hidePlotter];
  else
    [self revealPlotter];
}


- (NSDictionary*) collectDocumentSettings
{
  NSMutableDictionary* result = [NSMutableDictionary dictionary];
  [result addEntriesFromDictionary:[self collectDocumentSettingsForFrameOfWindow]];
  [result addEntriesFromDictionary:[self collectDocumentSettingsForSplitViews]];
  return result;
}


- (void) applyDocumentSettings:(NSDictionary*)settings
{
  [self applyDocumentSettingsToFrameOfWindow:settings];
  [self applyDocumentSettingsToSplitViewPositions:settings];
}


#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
- (void) prepareToRevertToOtherDocument
{
  mCircuitProcessorsWereVisibleWhenEnteringVersionBrowser = NO;
  mPlotterWasVisibleWhenEnteringVersionBrowser = NO;
}
#endif


- (void) setNetlistEditorView:(NSView*)view withMinimumSize:(CGSize)minSize
{
  [mNetlistClipView setMinDocumentViewHeight:minSize.height];
  [mNetlistClipView setMinDocumentViewWidth:minSize.width];
  [mNetlistClipView setDocumentView:view];
}


- (void) setSchematicEditorView:(NSView*)view withMinimumSize:(CGSize)minSize
{
  [mSchematicClipView setMinDocumentViewHeight:minSize.height];
  [mSchematicClipView setMinDocumentViewWidth:minSize.width];
  NSSize const size = [mSchematicClipView frame].size;
  view.frame = NSMakeRect(0, 0, size.width, size.height);
  [mSchematicClipView setDocumentView:view];
}


- (void) setPlotterView:(NSView*)view withMinimumViewSize:(CGSize)minSize
{
  [mPlotterClipView setMinDocumentViewHeight:minSize.height];
  [mPlotterClipView setMinDocumentViewWidth:minSize.width];
  [mPlotterClipView setDocumentView:view];
}


- (void) setSubcircuitEditorView:(NSView*)view withMinimumViewSize:(CGSize)minSize
{
  NSSize const subcircuitEditorSize = [view frame].size;

  view.translatesAutoresizingMaskIntoConstraints = NO;
#if 1
  mSubcircuitClipView.constrainsDocumentSize = NO;
#else
  mSubcircuitClipView.constrainsDocumentSize = YES;
  mSubcircuitClipView.minDocumentViewHeight = minSize.height;
  mSubcircuitClipView.minDocumentViewWidth = minSize.width;
#endif
  mSubcircuitClipView.documentView = view;
  NSDictionary* views = NSDictionaryOfVariableBindings(view);
  NSDictionary* metrics = @{
    @"minW" : @(minSize.width),
    @"minH" : @(minSize.height)
  };
  NSArray* constraints = @[
    @"|[view(>=minW)]-(0@800)-|",
    @"V:|[view(>=minH)]-(0@800)-|"
  ];
  for ( NSString* constraint in constraints )
  {
    [mSubcircuitClipView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:constraint options:0 metrics:metrics views:views]];
  }

  [view scrollPoint:NSMakePoint(0, subcircuitEditorSize.height)];
}


- (void) setSimulatorView:(NSView*)view withMinimumSize:(CGSize)minSize
{
  [mSimulatorClipView setMinDocumentViewHeight:minSize.height];
  [mSimulatorClipView setMinDocumentViewWidth:minSize.width];
  [mSimulatorClipView setDocumentView:view];
}


#pragma mark NSWindowDelegate


- (NSApplicationPresentationOptions) window:(NSWindow*)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
  return NSApplicationPresentationFullScreen | NSApplicationPresentationAutoHideToolbar | NSApplicationPresentationAutoHideMenuBar | NSApplicationPresentationHideDock;
}


#if VOLTA_SUPPORTS_RESUME
static NSString* FXResume_SchematicAndProcessorsSplitViewDividerPosition        = @"FXResume_SchematicAndProcessorsSplitViewDividerPosition";
static NSString* FXResume_SchematicAndPlotterSplitViewDividerPosition           = @"FXResume_SchematicAndPlotterSplitViewDividerPosition";
static NSString* FXResume_NetlistAndSimulatorOutputSplitViewDividerPosition     = @"FXResume_NetlistAndSimulatorOutputSplitViewDividerPosition";

- (void) window:(NSWindow*)window willEncodeRestorableState:(NSCoder*)state
{
  FXIssue(177)
  CGFloat dividerPosition;

  dividerPosition = [(NSView*)mSchematicAndProcessorsSplitView.subviews[0] frame].size.width;
  [state encodeFloat:dividerPosition forKey:FXResume_SchematicAndProcessorsSplitViewDividerPosition];

  dividerPosition = [(NSView*)mSchematicAndPlotterSplitView.subviews[0] frame].size.height;
  [state encodeFloat:dividerPosition forKey:FXResume_SchematicAndPlotterSplitViewDividerPosition];

  dividerPosition = [(NSView*)mNetlistAndProcessorsSplitView.subviews[0] frame].size.height;
  [state encodeFloat:dividerPosition forKey:FXResume_NetlistAndSimulatorOutputSplitViewDividerPosition];

  [mCircuitProcessorsTabView encodeRestorableStateWithCoder:state];
}

- (void) window:(NSWindow*)window didDecodeRestorableState:(NSCoder*)state
{
  FXIssue(177)
  CGFloat dividerPosition;

  if ( [state containsValueForKey:FXResume_SchematicAndProcessorsSplitViewDividerPosition] )
  {
    dividerPosition = [state decodeFloatForKey:FXResume_SchematicAndProcessorsSplitViewDividerPosition];
    [mSchematicAndProcessorsSplitView setPosition:dividerPosition ofDividerAtIndex:0];
  }

  if ( [state containsValueForKey:FXResume_SchematicAndPlotterSplitViewDividerPosition] )
  {
    dividerPosition = [state decodeFloatForKey:FXResume_SchematicAndPlotterSplitViewDividerPosition];
    [mSchematicAndPlotterSplitView setPosition:dividerPosition ofDividerAtIndex:0];
  }

  if ( [state containsValueForKey:FXResume_NetlistAndSimulatorOutputSplitViewDividerPosition] )
  {
    dividerPosition = [state decodeFloatForKey:FXResume_NetlistAndSimulatorOutputSplitViewDividerPosition];
    [mNetlistAndProcessorsSplitView setPosition:dividerPosition ofDividerAtIndex:0];
  }

  [mCircuitProcessorsTabView restoreStateWithCoder:state];
}
#endif


#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
- (NSSize) window:(NSWindow*)window willResizeForVersionBrowserWithMaxPreferredSize:(NSSize)maxPreferredSize maxAllowedSize:(NSSize)maxAllowedSize
{
  return [NSWindow frameRectForContentRect:[mSchematicAndProcessorsSplitView frame] styleMask:NSWindowStyleMaskTitled].size;
}
#endif


#pragma mark NSSplitViewDelegate


- (BOOL) splitView:(NSSplitView*)splitView canCollapseSubview:(NSView*)subview
{
  return YES;
}


- (BOOL) splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView*)subview
{
  if ( splitView == mSchematicAndPlotterSplitView )
  {
    return (subview == mSchematicClipView);
  }
  if ( splitView == mSchematicAndProcessorsSplitView )
  {
    return (subview == mSchematicAndPlotterSplitView);
  }
  if ( splitView == mNetlistAndProcessorsSplitView )
  {
    return (subview != mNetlistClipView);
  }
  return YES;
}


#if 0 && VOLTA_SUPPORTS_RESUME
- (void) splitViewDidResizeSubviews:(NSNotification *)aNotification
{
  [self invalidateRestorableState];
}
#endif


#pragma mark Private


- (void) setUpWindow
{
  FXVoltaDocumentWindow* window = (FXVoltaDocumentWindow*)[self window];
  [window setReleasedWhenClosed:NO];

  [self buildUI:window];

#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(handleWindowWillEnterVersionBrowser:) name:NSWindowWillEnterVersionBrowserNotification object:window];
  [notificationCenter addObserver:self selector:@selector(handleWindowDidExitVersionBrowser:) name:NSWindowDidExitVersionBrowserNotification object:window];
#endif

#if VOLTA_SUPPORTS_RESUME
  [window setIdentifier:FXVoltaCircuitDocumentWindowIdentifier];
  [window setRestorable:YES];
#endif

  [window setDelegate:self];
}


#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
- (void) handleWindowWillEnterVersionBrowser:(NSNotification*)notification
{
  [self.window.toolbar setVisible:NO];
  mPlotterWasVisibleWhenEnteringVersionBrowser = [self plotterIsVisible];
  [self hidePlotter];
  mCircuitProcessorsWereVisibleWhenEnteringVersionBrowser = [self circuitProcessorsAreVisible];
  [self hideCircuitProcessors];
  mInsideVersionsBrowser = YES;
}


- (void) handleWindowDidExitVersionBrowser:(NSNotification*)notification
{
  [self.window.toolbar setVisible:YES];
  if ( mCircuitProcessorsWereVisibleWhenEnteringVersionBrowser )
    [self revealCircuitProcessors];
  if ( mPlotterWasVisibleWhenEnteringVersionBrowser )
    [self revealPlotter];
  mInsideVersionsBrowser = NO;
}
#endif


#pragma mark Private - Animations


/// @param position a number between 0 and 1
- (BOOL) moveDividerAtIndex:(NSUInteger)divider
                ofSplitView:(NSSplitView*)splitView
                 toPosition:(CGFloat const)finalPosition
{
  static const CGFloat skAnimationLinearIncrement = 5.0;
  static const CGFloat skAnimationSpringStrength = 0.25;
  
  NSSize const currentSize = [splitView.subviews[divider] bounds].size;
  CGFloat const currentPosition = splitView.isVertical ? currentSize.width : currentSize.height;
  
  BOOL hasReachedPosition = NO;
  if ( currentPosition < finalPosition )
  {
    if ( currentPosition < (finalPosition - 4 * skAnimationLinearIncrement) )
    {
      [splitView setPosition:(currentPosition + floor((finalPosition - currentPosition)*skAnimationSpringStrength)) ofDividerAtIndex:divider];
    }
    else if ( currentPosition < (finalPosition - skAnimationLinearIncrement) )
    {
      [splitView setPosition:(currentPosition + skAnimationLinearIncrement) ofDividerAtIndex:divider];
    }
    else
    {
      [splitView setPosition:finalPosition ofDividerAtIndex:0];
      hasReachedPosition = YES;
    }
  }
  else
  {
    if ( currentPosition > (finalPosition + 4 * skAnimationLinearIncrement) )
    {
      CGFloat newPos = currentPosition - floor((currentPosition - finalPosition)* skAnimationSpringStrength);
      [splitView setPosition:newPos ofDividerAtIndex:divider];
    }
    else if ( currentPosition > (finalPosition + skAnimationLinearIncrement) )
    {
      [splitView setPosition:(currentPosition - skAnimationLinearIncrement) ofDividerAtIndex:divider];
    }
    else
    {
      [splitView setPosition:finalPosition ofDividerAtIndex:divider];
      hasReachedPosition = YES;
    }
  }
  return hasReachedPosition;
}


static const NSTimeInterval skAnimationStepInterval = 0.01; // seconds


- (void) runPlotterWorkAreaAnimation:(NSTimer*)timer
{
  if ( mSchematicAndPlotterSplitViewAnimationTimer == nil )
  {
    mSchematicAndPlotterSplitViewAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:skAnimationStepInterval target:self selector:@selector(runPlotterWorkAreaAnimation:) userInfo:nil repeats:YES];
    FXRetain(mSchematicAndPlotterSplitViewAnimationTimer)
  }
  else
  {
    // Advancing the animation
    BOOL stopAnimating = YES;
    if ( mPlotterAreaAnimationType == FXWorkAreaAnimation_Close )
    {
      FXIssue(62)
      CGFloat const finalPosition = mSchematicAndPlotterSplitView.frame.size.height;
      stopAnimating = [self moveDividerAtIndex:0 ofSplitView:mSchematicAndPlotterSplitView toPosition:finalPosition];
    }
    else if ( mPlotterAreaAnimationType == FXWorkAreaAnimation_Open )
    {
      FXIssue(62)
      CGFloat const finalPosition = floor(mSchematicAndPlotterSplitView.frame.size.height * mSchematicEditorRelativeHeightBeforePanelCloseAnimation);
      stopAnimating = [self moveDividerAtIndex:0 ofSplitView:mSchematicAndPlotterSplitView toPosition:finalPosition];
    }
    
    if ( stopAnimating )
    {
      [mSchematicAndPlotterSplitViewAnimationTimer invalidate];
      FXRelease(mSchematicAndPlotterSplitViewAnimationTimer)
      mSchematicAndPlotterSplitViewAnimationTimer = nil;
    }
  }
}


- (void) runProcessorsWorkAreaAnimation:(NSTimer*)timer
{
  if ( mSchematicAndProcessorsSplitViewAnimationTimer == nil )
  {
    mSchematicAndProcessorsSplitViewAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:skAnimationStepInterval target:self selector:@selector(runProcessorsWorkAreaAnimation:) userInfo:nil repeats:YES];
    FXRetain(mSchematicAndProcessorsSplitViewAnimationTimer)
  }
  else
  {
    // Advancing the animation
    BOOL stopAnimating = YES;
    if ( mProcessorsAreaAnimationType == FXWorkAreaAnimation_Close )
    {
      FXIssue(21)
      CGFloat const finalPosition = mSchematicAndProcessorsSplitView.frame.size.width;
      stopAnimating = [self moveDividerAtIndex:0 ofSplitView:mSchematicAndProcessorsSplitView toPosition:finalPosition];
    }
    else if ( mProcessorsAreaAnimationType == FXWorkAreaAnimation_Open )
    {
      FXIssue(21)
      CGFloat const finalPosition = floor(mSchematicAndProcessorsSplitView.frame.size.width * mSchematicEditorRelativeWidthBeforePanelCloseAnimation);
      stopAnimating = [self moveDividerAtIndex:0 ofSplitView:mSchematicAndProcessorsSplitView toPosition:finalPosition];
    }
    
    if ( stopAnimating )
    {
      [mSchematicAndProcessorsSplitViewAnimationTimer invalidate];
      FXRelease(mSchematicAndProcessorsSplitViewAnimationTimer)
      mSchematicAndProcessorsSplitViewAnimationTimer = nil;
    }
  }
}


#pragma mark Private - UI Building


- (void) buildUI:(FXVoltaDocumentWindow*)window
{
  NSSize const kContentSize = { 700, 500 };
  NSSize const kMinSize = { 450, 350 };
  window.collectionBehavior = window.collectionBehavior | NSWindowCollectionBehaviorFullScreenPrimary;
  window.contentSize = kContentSize;
  window.minSize = kMinSize;
  [window center];
  NSView* contentView = [self buildUI_DocumentRegions:kContentSize];

  window.contentView = contentView;

  [mSchematicAndProcessorsSplitView setPosition:(kContentSize.width - [mSchematicAndProcessorsSplitView dividerThickness]) ofDividerAtIndex:0];
  [mSchematicAndPlotterSplitView setPosition:(kContentSize.height - [mSchematicAndPlotterSplitView dividerThickness]) ofDividerAtIndex:0];
}


- (NSView*) buildUI_NetlistEditor:(NSRect)frame
{
  mNetlistClipView = [[FXClipView alloc] initWithFrame:frame];
  mNetlistClipView.copiesOnScroll = YES;
  FXAutorelease(mNetlistClipView)
  return mNetlistClipView;
}


- (NSView*) buildUI_CircuitProcessors:(NSRect)frame
{
  mCircuitProcessorsTabView = [[FXTabView alloc] initWithFrame:frame];
  [self buildUI_SimulatorOutput];
  [self buildUI_SubcircuitEditor];
  FXClipView* processorsTabViewClipper = [[FXClipView alloc] initWithFrame:frame flipped:NO];
  processorsTabViewClipper.minDocumentViewHeight = [mCircuitProcessorsTabView headerHeight];
  processorsTabViewClipper.minDocumentViewWidth = 100;
  processorsTabViewClipper.documentView = mCircuitProcessorsTabView;
  FXRelease(mCircuitProcessorsTabView)
  FXAutorelease(processorsTabViewClipper)
  return processorsTabViewClipper;
}


- (NSView*) buildUI_NetlistAndProcessors:(NSRect)frame
{
  NSRect const halfFrame = NSMakeRect(0,0,frame.size.width,frame.size.height/2.0);
  
  NSView* netlistEditorView = [self buildUI_NetlistEditor:halfFrame];
  NSView* processorsView = [self buildUI_CircuitProcessors:halfFrame];
  
  mNetlistAndProcessorsSplitView = [[NSSplitView alloc] initWithFrame:frame];
  [mNetlistAndProcessorsSplitView setDividerStyle:NSSplitViewDividerStyleThin];
  [mNetlistAndProcessorsSplitView setVertical:NO];
  [mNetlistAndProcessorsSplitView setDelegate:self];
  [mNetlistAndProcessorsSplitView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [mNetlistAndProcessorsSplitView addSubview:netlistEditorView];
  [mNetlistAndProcessorsSplitView addSubview:processorsView];
  
  FXAutorelease(mNetlistAndProcessorsSplitView)
  return mNetlistAndProcessorsSplitView;
}


- (NSView*) buildUI_SchematicEditor:(NSRect)frame
{
  mSchematicClipView = [[FXClipView alloc] initWithFrame:frame flipped:NO];
  mSchematicClipView.copiesOnScroll = YES;
  FXAutorelease(mSchematicClipView)
  return mSchematicClipView;
}


- (NSView*) buildUI_Plotter
{  
  mPlotterClipView = [[FXClipView alloc] initWithFrame:NSMakeRect(0,0,100,100) flipped:NO];
  mPlotterClipView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  mPlotterClipView.copiesOnScroll = YES;
  FXAutorelease(mPlotterClipView)
  return mPlotterClipView;
}


- (void) buildUI_SubcircuitEditor
{
  NSRect const frame = NSMakeRect(0, 0, 100, 200);
  NSSize const tabViewSize = [mCircuitProcessorsTabView frame].size;
  NSRect const subviewFrame = NSMakeRect(0, 0, tabViewSize.width, tabViewSize.height);

  mSubcircuitClipView = [[FXClipView alloc] initWithFrame:frame flipped:YES];
  //mSubcircuitClipView.verticalClipOffset = 10.0;
  mSubcircuitClipView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  mSubcircuitClipView.copiesOnScroll = YES;

  mSubcircuitEditorScrollView = [[NSScrollView alloc] initWithFrame:subviewFrame];
  mSubcircuitEditorScrollView.autoresizesSubviews = YES;
  mSubcircuitEditorScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  mSubcircuitEditorScrollView.hasVerticalScroller = YES;
  mSubcircuitEditorScrollView.hasHorizontalScroller = NO;
  mSubcircuitEditorScrollView.autohidesScrollers = YES;
  mSubcircuitEditorScrollView.borderType = NSNoBorder;
  mSubcircuitEditorScrollView.verticalScroller.controlSize = NSControlSizeSmall;
  mSubcircuitEditorScrollView.contentView = mSubcircuitClipView;
  FXRelease(mSubcircuitClipView)

  [mCircuitProcessorsTabView addTabView:mSubcircuitEditorScrollView withTitle:FXLocalizedString(@"Subcircuit")];
  FXRelease(mSubcircuitEditorScrollView)
}


- (void) buildUI_SimulatorOutput
{
  mSimulatorClipView = [[FXClipView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100) flipped:NO];
  [mCircuitProcessorsTabView addTabView:mSimulatorClipView withTitle:FXLocalizedString(@"Simulator")];
  FXRelease(mSimulatorClipView)
}


- (NSView*) buildUI_DocumentRegions:(NSSize)size
{
  mSchematicAndProcessorsSplitView = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
  [mSchematicAndProcessorsSplitView setDividerStyle:NSSplitViewDividerStyleThin];
  [mSchematicAndProcessorsSplitView setVertical:YES];
  [mSchematicAndProcessorsSplitView setDelegate:self];
  [mSchematicAndProcessorsSplitView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  
  NSView* schematicView = [self buildUI_SchematicEditor:NSMakeRect(0, 0, size.width/2, size.height)];
  NSView* circuitProcessorsView = [self buildUI_NetlistAndProcessors:NSMakeRect(size.width/2, 0, size.width/2, size.height)];
  NSView* plotterView = [self buildUI_Plotter];
  
  mSchematicAndPlotterSplitView = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, size.width/2, size.height)];
  [mSchematicAndPlotterSplitView setDividerStyle:NSSplitViewDividerStyleThin];
  [mSchematicAndPlotterSplitView setVertical:NO];
  [mSchematicAndPlotterSplitView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [mSchematicAndPlotterSplitView addSubview:schematicView];
  [mSchematicAndPlotterSplitView addSubview:plotterView];
  [mSchematicAndProcessorsSplitView addSubview:mSchematicAndPlotterSplitView];
  FXRelease(mSchematicAndPlotterSplitView)
  [mSchematicAndProcessorsSplitView addSubview:circuitProcessorsView];
  
  FXAutorelease(mSchematicAndProcessorsSplitView)
  return mSchematicAndProcessorsSplitView;
}


#pragma mark Private - Document Settings


- (NSDictionary*) collectDocumentSettingsForSplitViews
{
  CGFloat schematicEditorRelativeWidth = [(NSView*)mSchematicAndProcessorsSplitView.subviews[0] frame].size.width / mSchematicAndProcessorsSplitView.frame.size.width;
  schematicEditorRelativeWidth = round(schematicEditorRelativeWidth * 100) / 100.0;
  NSNumber* number1 = @(schematicEditorRelativeWidth);

  CGFloat schematicEditorRelativeHeight = [(NSView*)mSchematicAndPlotterSplitView.subviews[0] frame].size.height / mSchematicAndPlotterSplitView.frame.size.height;
  schematicEditorRelativeHeight = round(schematicEditorRelativeHeight * 100) / 100.0;
  NSNumber* number2 = @(schematicEditorRelativeHeight);

  return @{
    FXVoltaMac_SchematicEditorRelativeWidth  : [number1 stringValue],
    FXVoltaMac_SchematicEditorRelativeHeight : [number2 stringValue]
  };
}


- (NSDictionary*) collectDocumentSettingsForFrameOfWindow
{
  NSRect const kWindowFrame = [[self window] frame];
  return @{
    FXVoltaMac_WindowWidth     : [@(kWindowFrame.size.width) stringValue],
    FXVoltaMac_WindowHeight    : [@(kWindowFrame.size.height) stringValue],
  };
}


- (void) applyDocumentSettingsToFrameOfWindow:(NSDictionary*)settings
{
  if ( mInsideVersionsBrowser )
  {
    self.window.toolbar.visible = YES; // Making sure the toolbar is visible because the applied frame sizes are only correct when the toolbar is included
  }
  if ( settings[FXVoltaMac_WindowWidth] != nil )
  {
    NSSize const minSize = [[self window] minSize];
    NSRect windowFrame = NSZeroRect;
    windowFrame.size.width = MAX(minSize.width, [settings[FXVoltaMac_WindowWidth] doubleValue]);
    windowFrame.size.height = MAX(minSize.height, [settings[FXVoltaMac_WindowHeight] doubleValue]);
    [[self window] setFrame:windowFrame display:NO];
    [[self window] center];
    windowFrame = [[self window] frame];
    [[self window] setFrame:windowFrame display:YES animate:mInsideVersionsBrowser];
  }
}


- (void) applyDocumentSettingsToSplitViewPositions:(NSDictionary*)settings
{
#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
  if ( [[self document] isInViewingMode] )
  {
    [mSchematicAndProcessorsSplitView setPosition:[mSchematicAndProcessorsSplitView frame].size.width ofDividerAtIndex:0];
    [mSchematicAndPlotterSplitView setPosition:[mSchematicAndPlotterSplitView frame].size.height ofDividerAtIndex:0];
  }
  else
#endif
  {
    NSAssert( mSchematicAndProcessorsSplitView != nil, @"At this point the document window and the split view must already exist." );
    NSSize const schematicAndProcessorsSplitViewSize = mSchematicAndProcessorsSplitView.frame.size;
    NSString* schematicEditorWidthNumber = [settings valueForKey:FXVoltaMac_SchematicEditorRelativeWidth];
    if ( schematicEditorWidthNumber != nil )
    {
      CGFloat const editorWidth = floor(schematicAndProcessorsSplitViewSize.width * [schematicEditorWidthNumber doubleValue]);
      [mSchematicAndProcessorsSplitView setPosition:editorWidth ofDividerAtIndex:0];
    }
    else
    {
      [mSchematicAndProcessorsSplitView setPosition:schematicAndProcessorsSplitViewSize.width ofDividerAtIndex:0];
    }

    NSAssert( mSchematicAndPlotterSplitView != nil, @"At this point the document window and the split view must already exist." );
    NSSize const schematicAndPlotterSplitViewSize = mSchematicAndPlotterSplitView.frame.size;
    NSString* schematicEditorHeightNumber = [settings valueForKey:FXVoltaMac_SchematicEditorRelativeHeight];
    if ( schematicEditorHeightNumber != nil )
    {
      CGFloat const editorHeight = floor(schematicAndPlotterSplitViewSize.height * [schematicEditorHeightNumber doubleValue]);
      [mSchematicAndPlotterSplitView setPosition:editorHeight ofDividerAtIndex:0];
    }
    else
    {
      [mSchematicAndPlotterSplitView setPosition:schematicAndPlotterSplitViewSize.height ofDividerAtIndex:0];
    }
  }
}


#if 0 && VOLTA_DEBUG
- (void) debugConstraintsOfView:(NSView*)view
{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleResizedView:) name:NSViewFrameDidChangeNotification object:view];
}

- (void) handleResizedView:(NSNotification*)notif
{
  NSArray* constraints = [(NSView*)[notif object] constraintsAffectingLayoutForOrientation:NSLayoutConstraintOrientationVertical];
  NSLog(@"%@", [constraints description]);
}
#endif


@end
