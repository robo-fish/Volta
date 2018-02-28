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
#import <FXKit/FXKit-Swift.h>
#import "FXLibraryEditorModelsCellView.h"
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
  NSMutableArray* mSubcircuitWrappers;              // contains FXModel objects
  NSMutableArray* mDisplayedSubcircuitWrappers;     // contains a subset of mSubcircuitWrappers, depending on filters
  FXLibraryEditorModelsCellView* mDummyCellView;
}

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


#pragma mark NSViewController overrides


- (void) loadView
{
  [super loadView];
  [self initializeUI];
}


#pragma mark NSResponder overrides


- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  [_subcircuitsTable encodeRestorableStateWithCoder:state];
  NSPoint const scrollPosition = [[[_subcircuitsTable enclosingScrollView] contentView] documentVisibleRect].origin;
  [state encodePoint:scrollPosition forKey:@"Subcircuits_LastScrollPosition"];
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  [_subcircuitsTable restoreStateWithCoder:state];
  NSPoint const lastScrollPosition = [state decodePointForKey:@"Subcircuits_LastScrollPosition"];
  [_subcircuitsTable scrollPoint:lastScrollPosition];
}


#pragma mark VoltaLibraryObserver


- (void) handleVoltaLibraryWillShutDown:(id<VoltaLibrary>)library
{
  if ( library == _library )
  {
    @synchronized(self)
    {
      [_subcircuitsTable setDataSource:nil];
      [mSubcircuitWrappers removeAllObjects];
    }
  }
}


- (void) handleVoltaLibraryChangedSubcircuits:(id<VoltaLibrary>)library
{
  if ( library == _library )
  {
    [self loadSubcircuitWrappers:self];
    [self filterSubcircuitTableItems:[_searchField stringValue]];
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
  return [_subcircuitsTable rowHeight];
}


- (BOOL) tableView:(NSTableView*)aTableView shouldEditTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
  return NO;
}


- (void) tableViewSelectionDidChange:(NSNotification *)notification
{
  if ( [notification object] == _subcircuitsTable )
  {
    [_subcircuitsTable enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
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
  [session enumerateDraggingItemsWithOptions:0 forView:_subcircuitsTable classes:@[[FXModel class]] searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
    FXMutableModel* draggedModel = draggingItem.item;
    draggedModel.library = _library;
    FXLibraryEditorModelsCellView* cellView = mDummyCellView;
    draggingItem.imageComponentsProvider = ^() {
      [cellView removeConstraints:[cellView constraints]];
      cellView.model = draggedModel;
      [cellView addConstraint:[NSLayoutConstraint constraintWithItem:cellView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:[cellView height]]];
      cellView.frame = NSMakeRect(0, 0, [_subcircuitsTable frame].size.width, [cellView height]);
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
  if ( notificationObject == _searchField )
  {
    [self filterSubcircuitTableItems:[_searchField stringValue]];
  }
}


#pragma mark Public


- (void) setLibrary:(id<VoltaLibrary>)library
{
  if ( library != _library )
  {
    _library = library;
    if ( _library != nil )
    {
      [_library addObserver:self];
      [self loadSubcircuitWrappers:self];
      [self filterSubcircuitTableItems:[_searchField stringValue]];
    }
  }
}


- (void) setCloudLibraryController:(id<VoltaCloudLibraryController>)cloudLibraryController
{
  if ( cloudLibraryController != _cloudLibraryController )
  {
    FXRelease(mCloudLibraryController)
    _cloudLibraryController = cloudLibraryController;
    FXRetain(mCloudLibraryController)
  }
  if ( (_cloudLibraryController != nil) && _cloudLibraryController.nowUsingCloudLibrary )
  {
    self.subcircuitFolderButton.image = [[NSBundle bundleForClass:[self class]] imageForResource:@"iCloud_small"];
    self.subcircuitFolderButton.toolTip = FXLocalizedString(@"ShowCloudFilesButtonTooltip");
  }
}


- (IBAction) revealSubcircuitsRootFolder:(id)sender
{
  if ( (_cloudLibraryController != nil) && _cloudLibraryController.nowUsingCloudLibrary )
  {
    [_cloudLibraryController showContentsOfCloudFolder:VoltaCloudFolderType_LibrarySubcircuits];
  }
  else
  {
    [FXSystemUtils revealFileAtLocation:[_library subcircuitsLocation]];
  }
}


#pragma mark Private


- (void) initializeSubcircuitsTable
{
  NSAssert( _subcircuitsTable != nil, @"subcircuits table not found in NIB" );
  _subcircuitsTable.dataSource = self;
  _subcircuitsTable.delegate = self;
  _subcircuitsTable.doubleAction = @selector(handleTableViewDoubleClick:);
  _subcircuitsTable.target = self;
  _subcircuitsTable.focusRingType = NSFocusRingTypeNone;
  _subcircuitsTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;

  NSTableColumn* titleTableColumn = [_subcircuitsTable tableColumnWithIdentifier:kModelCellViewIdentifier];
  NSAssert( titleTableColumn != nil, @"table column not found in NIB" );
  [titleTableColumn setResizingMask:NSTableColumnAutoresizingMask];
  [titleTableColumn setMinWidth:60.0];
}


- (void) initializeUI
{
  [self initializeSubcircuitsTable];

  [[[_subcircuitsTable enclosingScrollView] verticalScroller] setControlSize:NSControlSizeSmall];

  NSAssert( _searchField != nil, @"search field not found in NIB" );
  [_searchField setRecentsAutosaveName:@"Subcircuit Searches"];
  [_searchField setDelegate:self];

  NSAssert( _subcircuitFolderButton != nil, @"folder button does not exist in NIB" );
  [_subcircuitFolderButton setImage:[NSImage imageNamed:NSImageNameFolder]];
  [_subcircuitFolderButton setToolTip:FXLocalizedString(@"SubcircuitFolderRevealButtonTooltip")];

  NSAssert( _clipView != nil, @"clip view is missing from NIB" );
  if( ![_clipView isKindOfClass:[FXClipView class]] )
  {
    FXClipView* newClipView = [[FXClipView alloc] initWithFrame:_clipView.frame flipped:NO];
    newClipView.translatesAutoresizingMaskIntoConstraints = NO;
    [FXViewUtils transferSubviewsFrom:_clipView to:newClipView];
    [_clipView removeFromSuperview];
    _clipView = newClipView;
    [self.view addSubview:_clipView];
  }
  [_clipView setMinDocumentViewWidth:40.0];
  [_clipView setMinDocumentViewHeight:80.0];
}


- (void) loadSubcircuitWrappers:(id)sender
{
  @synchronized(mDisplayedSubcircuitWrappers)
  {
    [_subcircuitsTable setDataSource:nil];
    [mDisplayedSubcircuitWrappers removeAllObjects];
    [mSubcircuitWrappers removeAllObjects];

    [_library iterateOverSubcircuitsByApplyingBlock:^(VoltaPTModelPtr subcircuitModel, BOOL* stop) {
      FXMutableModel* subcircuit = [[FXMutableModel alloc] initWithPersistentModel:subcircuitModel];
      [subcircuit setLibrary:self->_library];
      id<FXShape> subcircuitShape = [self->_library shapeForModelType:subcircuitModel->type name:(__bridge NSString*)subcircuitModel->name.cfString() vendor:(__bridge NSString*)subcircuitModel->vendor.cfString()];
      [subcircuit setShape:subcircuitShape];
      [mSubcircuitWrappers addObject:subcircuit];
    }];
    [_subcircuitsTable setDataSource:self]; // implies reloading table data
  }
}


- (void) filterSubcircuitTableItems:(NSString*)filterMask
{
  @synchronized(mDisplayedSubcircuitWrappers)
  {
    [_subcircuitsTable setDataSource:nil];
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
    [_subcircuitsTable setDataSource:self];
  }
}


- (NSView*) prepareCellViewForSubcircuitAtRow:(NSInteger)rowIndex
{
  FXLibraryEditorModelsCellView* cellView = [_subcircuitsTable makeViewWithIdentifier:kModelCellViewIdentifier owner:self];
  NSAssert( cellView != nil, @"The model cell view was added to the NIB and should therefore be found." );
  if ( cellView == nil )
  {
    NSRect const dummyFrame = { 0, 0, 200, 100 };
    cellView = [[FXLibraryEditorModelsCellView alloc] initWithFrame:dummyFrame];
    cellView.identifier = kModelCellViewIdentifier;
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
  if ( sender == _subcircuitsTable )
  {
    [self openDocumentForSubcircuitAtRow:[_subcircuitsTable clickedRow]];
  }
}


- (void) handleCellViewActionButton:(id)sender
{
  [self openDocumentForSubcircuitAtRow:[_subcircuitsTable rowForView:sender]];
}


@end
