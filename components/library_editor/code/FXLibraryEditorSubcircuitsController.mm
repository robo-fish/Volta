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

#import "FXLibraryEditorSubcircuitsController.h"
#import <VoltaCore/VoltaLibraryProtocol.h>
#import "VoltaCloudLibraryController.h"
#import "FXTableView.h"
#import "FXLibraryEditorModelsCellView.h"
#import "FXClipView.h"
#import "FXShapeRenderer.h"
#import "FXModel.h"
#import "FXLibraryEditorTableRowView.h"
#import "FXSystemUtils.h"


NSString* kModelCellViewIdentifier = @"ModelCell";


@interface FXLibraryEditorSubcircuitsController ()
  <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate, NSSearchFieldDelegate, VoltaLibraryObserver>
@end


@implementation FXLibraryEditorSubcircuitsController
{
@private
  id<VoltaLibrary> mLibrary;
  id<VoltaCloudLibraryController> mCloudLibraryController;
  FXTableView* __unsafe_unretained mSubcircuitsTable;
  FXClipView* __unsafe_unretained mClipView;
  NSSearchField* __unsafe_unretained mSearchField;
  NSButton* __unsafe_unretained mSubcircuitFolderButton;

  NSMutableArray* mSubcircuitWrappers;              // contains FXModel objects
  NSMutableArray* mDisplayedSubcircuitWrappers;     // contains a subset of mSubcircuitWrappers, depending on filters

  FXLibraryEditorModelsCellView* mDummyCellView;
}

@synthesize clipView = mClipView;
@synthesize subcircuitsTable = mSubcircuitsTable;
@synthesize searchField = mSearchField;
@synthesize subcircuitFolderButton = mSubcircuitFolderButton;
@synthesize library = mLibrary;
@synthesize cloudLibraryController = mCloudLibraryController;

- (id) init
{
  self = [super initWithNibName:@"Subcircuits" bundle:[NSBundle bundleForClass:[self class]]];
  if (self != nil)
  {
    mSubcircuitWrappers = [[NSMutableArray alloc] init];
    mDisplayedSubcircuitWrappers = [[NSMutableArray alloc] init];
    mDummyCellView = [[FXLibraryEditorModelsCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mDisplayedSubcircuitWrappers)
  FXRelease(mSubcircuitWrappers)
  FXRelease(mDummyCellView)
  FXRelease(mLibrary)
  FXRelease(mCloudLibraryController)
  FXDeallocSuper
}


#pragma mark NSViewController overrides


- (void) loadView
{
  [super loadView];
  [self initializeUI];
}


#pragma mark NSResponder overrides


- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  [mSubcircuitsTable encodeRestorableStateWithCoder:state];
  NSPoint const scrollPosition = [[[mSubcircuitsTable enclosingScrollView] contentView] documentVisibleRect].origin;
  [state encodePoint:scrollPosition forKey:@"Subcircuits_LastScrollPosition"];
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  [mSubcircuitsTable restoreStateWithCoder:state];
  NSPoint const lastScrollPosition = [state decodePointForKey:@"Subcircuits_LastScrollPosition"];
  [mSubcircuitsTable scrollPoint:lastScrollPosition];
}


#pragma mark VoltaLibraryObserver


- (void) handleVoltaLibraryWillShutDown:(id<VoltaLibrary>)library
{
  if ( library == mLibrary )
  {
    @synchronized(self)
    {
      [mSubcircuitsTable setDataSource:nil];
      [mSubcircuitWrappers removeAllObjects];
    }
  }
}


- (void) handleVoltaLibraryChangedSubcircuits:(id<VoltaLibrary>)library
{
  if ( library == mLibrary )
  {
    [self loadSubcircuitWrappers:self];
    [self filterSubcircuitTableItems:[mSearchField stringValue]];
  }
}


#pragma mark NSTableViewDelegate


- (NSView*) tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  return [self prepareCellViewForSubcircuitAtRow:rowIndex];
}


- (NSTableRowView*) tableView:(NSTableView*)tableView rowViewForRow:(NSInteger)row
{
  FXLibraryEditorTableRowView *result = [[FXLibraryEditorTableRowView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
  FXAutorelease(result)
  return result;
}


- (CGFloat) tableView:(NSTableView*)tableView heightOfRow:(NSInteger)row
{
  if ( (row >= 0) && (row < [mSubcircuitWrappers count]) )
  {
    id item = mSubcircuitWrappers[row];
    if ([item isKindOfClass:[FXModel class]])
    {
      return [mDummyCellView height];
    }
  }
  return [mSubcircuitsTable rowHeight];
}


- (BOOL) tableView:(NSTableView*)aTableView shouldEditTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
  return NO;
}


- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
  if ( [notification object] == mSubcircuitsTable )
  {
    [mSubcircuitsTable enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
    #if 0
      FXLibraryEditorModelsCellView* cellView = [rowView viewAtColumn:0];
      cellView.isSelected = rowView.selected;
    #else
      [rowView setNeedsDisplay:YES];
    #endif
    }];
  }
}


#pragma mark NSTableViewDataSource


- (NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [mDisplayedSubcircuitWrappers count];
}


- (id <NSPasteboardWriting>) tableView:(NSTableView*)tableView pasteboardWriterForRow:(NSInteger)row
{
  if ( (row >= 0) && (row < [mDisplayedSubcircuitWrappers count]) )
  {
    return (FXModel*)mDisplayedSubcircuitWrappers[row];
  }
  return nil;
}


- (void) tableView:(NSTableView*)tableView draggingSession:(NSDraggingSession*)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet*)rowIndexes
{
  [tableView deselectAll:self];
  session.draggingFormation = NSDraggingFormationList;
  [session enumerateDraggingItemsWithOptions:0 forView:mSubcircuitsTable classes:@[[FXModel class]] searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
    FXMutableModel* draggedModel = draggingItem.item;
    draggedModel.library = mLibrary;
    FXLibraryEditorModelsCellView* cellView = mDummyCellView;
    draggingItem.imageComponentsProvider = ^() {
      [cellView removeConstraints:[cellView constraints]];
      cellView.model = draggedModel;
      [cellView addConstraint:[NSLayoutConstraint constraintWithItem:cellView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:[cellView height]]];
      cellView.frame = NSMakeRect(0, 0, [mSubcircuitsTable frame].size.width, [cellView height]);
      [cellView setNeedsLayout:YES];
      [cellView layoutSubtreeIfNeeded];
      return [cellView draggingImageComponents];
    };
  }];
}


#pragma mark NSTextFieldDelegate


- (void) controlTextDidChange:(NSNotification *)notification
{
  id notificationObject = [notification object];
  if ( notificationObject == mSearchField )
  {
    [self filterSubcircuitTableItems:[mSearchField stringValue]];
  }
}


#pragma mark Public


- (void) setLibrary:(id<VoltaLibrary>)library
{
  if ( library != mLibrary )
  {
    FXRelease(mLibrary)
    mLibrary = library;
    if ( mLibrary != nil )
    {
      FXRetain(mLibrary)
      [mLibrary addObserver:self];
      [self loadSubcircuitWrappers:self];
      [self filterSubcircuitTableItems:[mSearchField stringValue]];
    }
  }
}


- (void) setCloudLibraryController:(id<VoltaCloudLibraryController>)cloudLibraryController
{
  if ( cloudLibraryController != mCloudLibraryController )
  {
    FXRelease(mCloudLibraryController)
    mCloudLibraryController = cloudLibraryController;
    FXRetain(mCloudLibraryController)
  }
  if ( (mCloudLibraryController != nil) && mCloudLibraryController.nowUsingCloudLibrary )
  {
    self.subcircuitFolderButton.image = [[NSBundle bundleForClass:[self class]] imageForResource:@"iCloud_small"];
    self.subcircuitFolderButton.toolTip = FXLocalizedString(@"ShowCloudFilesButtonTooltip");
  }
}


- (IBAction) revealSubcircuitsRootFolder:(id)sender
{
  if ( (mCloudLibraryController != nil) && mCloudLibraryController.nowUsingCloudLibrary )
  {
    [mCloudLibraryController showContentsOfCloudFolder:VoltaCloudFolderType_LibrarySubcircuits];
  }
  else
  {
    [FXSystemUtils revealFileAtLocation:[mLibrary subcircuitsLocation]];
  }
}


#pragma mark Private


- (void) initializeSubcircuitsTable
{
  NSAssert( mSubcircuitsTable != nil, @"subcircuits table not found in NIB" );
  mSubcircuitsTable.dataSource = self;
  mSubcircuitsTable.delegate = self;
  mSubcircuitsTable.doubleAction = @selector(handleTableViewDoubleClick:);
  mSubcircuitsTable.target = self;
  mSubcircuitsTable.focusRingType = NSFocusRingTypeNone;
  mSubcircuitsTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;

  NSTableColumn* titleTableColumn = [mSubcircuitsTable tableColumnWithIdentifier:kModelCellViewIdentifier];
  NSAssert( titleTableColumn != nil, @"table column not found in NIB" );
  [titleTableColumn setResizingMask:NSTableColumnAutoresizingMask];
  [titleTableColumn setMinWidth:60.0];
}


- (void) initializeUI
{
  [self initializeSubcircuitsTable];

  [[[mSubcircuitsTable enclosingScrollView] verticalScroller] setControlSize:NSControlSizeSmall];

  NSAssert( mSearchField != nil, @"search field not found in NIB" );
  [mSearchField setRecentsAutosaveName:@"Subcircuit Searches"];
  [mSearchField setDelegate:self];

  NSAssert( mSubcircuitFolderButton != nil, @"folder button does not exist in NIB" );
  [mSubcircuitFolderButton setImage:[NSImage imageNamed:NSImageNameFolder]];
  [mSubcircuitFolderButton setToolTip:FXLocalizedString(@"SubcircuitFolderRevealButtonTooltip")];

  NSAssert( mClipView != nil, @"clip view is missing from NIB" );
  [mClipView setMinDocumentViewWidth:40.0];
  [mClipView setMinDocumentViewHeight:80.0];
}


- (void) loadSubcircuitWrappers:(id)sender
{
  @synchronized(mDisplayedSubcircuitWrappers)
  {
    [mSubcircuitsTable setDataSource:nil];
    [mDisplayedSubcircuitWrappers removeAllObjects];
    [mSubcircuitWrappers removeAllObjects];

    [mLibrary iterateOverSubcircuitsByApplyingBlock:^(VoltaPTModelPtr subcircuitModel, BOOL* stop) {
      FXMutableModel* subcircuit = [[FXMutableModel alloc] initWithPersistentModel:subcircuitModel];
      [subcircuit setLibrary:self->mLibrary];
      id<FXShape> subcircuitShape = [self->mLibrary shapeForModelType:subcircuitModel->type name:(__bridge NSString*)subcircuitModel->name.cfString() vendor:(__bridge NSString*)subcircuitModel->vendor.cfString()];
      [subcircuit setShape:subcircuitShape];
      [mSubcircuitWrappers addObject:subcircuit];
      FXRelease(subcircuit)
    }];
    [mSubcircuitsTable setDataSource:self]; // implies reloading table data
  }
}


- (void) filterSubcircuitTableItems:(NSString*)filterMask
{
  @synchronized(mDisplayedSubcircuitWrappers)
  {
    [mSubcircuitsTable setDataSource:nil];
    [mDisplayedSubcircuitWrappers removeAllObjects];
    for ( FXModel* subcircuit in mSubcircuitWrappers )
    {
      VoltaPTModelPtr subcircuitModel = [subcircuit persistentModel];
      if ( (filterMask == nil)
          || ([filterMask length] == 0)
          || (subcircuitModel->name.find((__bridge CFStringRef)filterMask) >= 0)
          || (subcircuitModel->vendor.find((__bridge CFStringRef)filterMask) >= 0) )
      {
        [mDisplayedSubcircuitWrappers addObject:subcircuit];
      }
    }
    [mDisplayedSubcircuitWrappers sortUsingComparator:^NSComparisonResult(id obj1, id obj2){ return [[obj1 name] compare:[obj2 name]];}];
    [mSubcircuitsTable setDataSource:self];
  }
}


- (NSView*) prepareCellViewForSubcircuitAtRow:(NSInteger)rowIndex
{
  FXLibraryEditorModelsCellView* cellView = [mSubcircuitsTable makeViewWithIdentifier:kModelCellViewIdentifier owner:self];
  NSAssert( cellView != nil, @"The model cell view was added to the NIB and should therefore be found." );
  if ( cellView == nil )
  {
    NSRect const dummyFrame = { 0, 0, 200, 100 };
    cellView = [[FXLibraryEditorModelsCellView alloc] initWithFrame:dummyFrame];
    cellView.identifier = kModelCellViewIdentifier;
    FXAutorelease(cellView)
  }
  cellView.isEditable = NO;
  cellView.showsLockSymbol = NO;
  cellView.showsActionButton = YES;
  cellView.actionButton.action = @selector(handleCellViewActionButton:);
  cellView.actionButton.target = self;
  cellView.actionButton.toolTip = FXLocalizedString(@"OpenSubcircuit");
  cellView.model = (FXModel*)mDisplayedSubcircuitWrappers[rowIndex];
  return cellView;
}


- (void) openDocumentForSubcircuitAtRow:(NSInteger)rowIndex
{
  if ( rowIndex >= 0 )
  {
    FXModel* subcircuit = mDisplayedSubcircuitWrappers[rowIndex];
    if ( subcircuit != nil )
    {
      NSString* modelSourcePath = (__bridge NSString*)[subcircuit persistentModel]->source.cfString();
      [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:modelSourcePath] display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
        {
          if ((document == nil) && (error != nil))
          {
            [NSApp presentError:error];
          }
        }
      }];
    }
  }
}


- (void) handleTableViewDoubleClick:(id)sender
{
  if ( sender == mSubcircuitsTable )
  {
    [self openDocumentForSubcircuitAtRow:[mSubcircuitsTable clickedRow]];
  }
}


- (void) handleCellViewActionButton:(id)sender
{
  [self openDocumentForSubcircuitAtRow:[mSubcircuitsTable rowForView:sender]];
}


@end
