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

#import "FXLibraryEditor.h"
#import <FXKit/FXKit-Swift.h>
#import "FXTabView.h"
#import "FXLibraryEditorSubcircuitsController.h"
#import "FXLibraryEditorModelsController.h"
#import "FXLibraryEditorPaletteController.h"

NSString* FXVoltaLibraryWindowIdentifier = @"FXVoltaLibraryWindow";

NSRect const skWindowDefaultFrame = { 0.0, 0.0, 260.0, 650.0 };
NSSize const skWindowMinSize = { 200.0, 300.0 };


@interface FXLibraryEditor () <VoltaLibraryObserver, NSWindowDelegate, NSWindowRestoration>
@end


@implementation FXLibraryEditor
{
@private
  id<VoltaLibrary> mLibrary;
  id<VoltaCloudLibraryController> mCloudLibraryController;
  FXLibraryEditorSubcircuitsController* mSubcircuitsController;
  FXLibraryEditorModelsController* mModelsController;
  FXLibraryEditorPaletteController* mPaletteController;

  NSView* mSubcircuitSectionView;
  NSView* mModelsSectionView;
  NSView* mCustomGroupsSectionView;

  FXTabView* mModelsAndSubcircuitsTabView;

  FXMultiFoldingView* mFoldingView;
}
@synthesize library = mLibrary;
@synthesize cloudLibraryController = mCloudLibraryController;


- (id) init
{
  NSWindow* editorWindow = [self newEditorWindow];
  self = [super initWithWindow:editorWindow];
  if (self != nil)
  {
    [[self window] setDelegate:self];
  }
  FXRelease(editorWindow)
  return self;
}


- (void) dealloc
{
  [[self window] close];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.library = nil;
  self.cloudLibraryController = nil;
  FXRelease(mPaletteController)
  FXRelease(mSubcircuitsController)
  FXRelease(mModelsController)
  FXDeallocSuper
}


#pragma mark Public


- (void) setLibrary:(id<VoltaLibrary>)library
{
  if ( library != mLibrary )
  {
    if ( mLibrary != nil )
    {
      [mLibrary removeObserver:self];
      FXRelease(mLibrary)
      mLibrary = nil;
    }

    if ( library != nil )
    {
      mLibrary = library;
      FXRetain(mLibrary)
      [mLibrary addObserver:self];
    }

    [mSubcircuitsController setLibrary:mLibrary];
    [mModelsController setLibrary:mLibrary];
    [mPaletteController setLibrary:mLibrary];
  }
}


- (void) setCloudLibraryController:(id<VoltaCloudLibraryController>)cloudLibraryController
{
  if ( mCloudLibraryController != cloudLibraryController )
  {
    FXRelease(mCloudLibraryController)
    mCloudLibraryController = cloudLibraryController;
    FXRetain(mCloudLibraryController)
    mModelsController.cloudLibraryController = cloudLibraryController;
    mSubcircuitsController.cloudLibraryController = cloudLibraryController;
    mPaletteController.cloudLibraryController = cloudLibraryController;
  }
}


- (void) show
{
  [[self window] makeKeyAndOrderFront:self];
}


- (void) hide
{
  [[self window] orderOut:self];
}


- (BOOL) isVisible
{
  return [[self window] isVisible];
}


#pragma mark VoltaLibraryObserver


- (void) handleVoltaLibraryOpenEditor:(id<VoltaLibrary>)library
{
  if ( library == mLibrary )
  {
    [self show];
  }
}


- (void) handleVoltaLibraryWillShutDown:(id<VoltaLibrary>)library
{
  if ( library == mLibrary )
  {
  }
}


#pragma mark Private


- (NSWindow*) newEditorWindow
{
  static const NSUInteger windowMask = NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskClosable;
  NSPanel* window = [[NSPanel alloc] initWithContentRect:skWindowDefaultFrame styleMask:windowMask backing:NSBackingStoreBuffered defer:YES];
  window.title = FXLocalizedString(@"Library");
  window.floatingPanel = YES;
  window.releasedWhenClosed = NO;
  window.minSize = skWindowMinSize;
  [window center];
  window.collectionBehavior = window.collectionBehavior | NSWindowCollectionBehaviorFullScreenAuxiliary; // requires floating panel
  window.restorable = YES;
  window.identifier = FXVoltaLibraryWindowIdentifier;
  window.restorationClass = [self class];

  mFoldingView = [[FX(FXMultiFoldingView) alloc] initWithFrame:[[window contentView] frame]];
  [mFoldingView addSubview:[self customGroupsSectionView] withTitle:FXLocalizedString(@"Component Palette")];
  [mFoldingView addSubview:[self createSubcircuitsAndModelGroupsSectionView] withTitle:FXLocalizedString(@"Component Sources")];
  [window.contentView addSubview:mFoldingView];
  FXRelease(mFoldingView)

  [FXViewUtils layoutIn:window.contentView visualFormats:@[@"H:|[folder]|", @"V:|[folder]|"] metricsInfo:nil viewsInfo:@{ @"folder" : mFoldingView }];

  return window;
}


#pragma mark NSWindowDelegate


#if VOLTA_DEBUG
FXIssue(121)
- (void) handleWindowWillClose:(NSNotification*)notification
{
  DebugLog(@"Library editor window will close");
}
#endif


- (void) window:(NSWindow*)window willEncodeRestorableState:(NSCoder*)state
{
  FXIssue(177)
  if ( window == [self window] )
  {
    [mFoldingView encodeRestorableStateWithCoder:state];
    [mPaletteController encodeRestorableStateWithCoder:state];
    [mModelsController encodeRestorableStateWithCoder:state];
    [mSubcircuitsController encodeRestorableStateWithCoder:state];
  }
}


- (void) window:(NSWindow*)window didDecodeRestorableState:(NSCoder*)state
{
  FXIssue(177)
  if ( window == [self window] )
  {
    [mFoldingView restoreStateWithCoder:state];
    [mPaletteController restoreStateWithCoder:state];
    [mModelsController restoreStateWithCoder:state];
    [mSubcircuitsController restoreStateWithCoder:state];
  }
}


#pragma mark NSWindowRestoration


+ (void) restoreWindowWithIdentifier:(NSString*)identifier
                               state:(NSCoder *)state
                   completionHandler:(void (^)(NSWindow *, NSError *))restorationHandler
{
  NSWindow* windowToRestore = nil;
  if ( [identifier isEqualToString:FXVoltaLibraryWindowIdentifier] )
  {
    if ( [[NSApp delegate] respondsToSelector:@selector(libraryEditor)] )
    {
      FXLibraryEditor* libraryEditor = [[NSApp delegate] performSelector:@selector(libraryEditor)];
      windowToRestore = [libraryEditor window];
    }
  }
  restorationHandler(windowToRestore, nil);
}


- (NSView*) modelGroupsSectionView
{
  if (mModelsSectionView == nil)
  {
    mModelsController = [[FXLibraryEditorModelsController alloc] init];
    mModelsSectionView = [mModelsController view];
  }
  return mModelsSectionView;
}


- (NSView*) subcircuitSectionView
{
  if (mSubcircuitSectionView == nil)
  {
    mSubcircuitsController = [[FXLibraryEditorSubcircuitsController alloc] init];
    mSubcircuitSectionView = [mSubcircuitsController view];
  }
  return mSubcircuitSectionView;
}


- (NSView*) customGroupsSectionView
{
  if ( mCustomGroupsSectionView == nil )
  {
    mPaletteController = [[FXLibraryEditorPaletteController alloc] init];
    mCustomGroupsSectionView = [mPaletteController view];
  }
  return mCustomGroupsSectionView;
}


- (NSView*) createSubcircuitsAndModelGroupsSectionView
{
  NSRect const dummyFrame = { 0, 0, 200, 200 };
  mModelsAndSubcircuitsTabView = [[FXTabView alloc] initWithFrame:dummyFrame];
  [mModelsAndSubcircuitsTabView addTabView:[self modelGroupsSectionView] withTitle:FXLocalizedString(@"Models")];
  [mModelsAndSubcircuitsTabView addTabView:[self subcircuitSectionView] withTitle:FXLocalizedString(@"Subcircuits")];
  FXAutorelease(mModelsAndSubcircuitsTabView)
  return mModelsAndSubcircuitsTabView;
}


@end

