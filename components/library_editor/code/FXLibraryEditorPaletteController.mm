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
#import "FXVoltaLibrary.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXVoltaCircuitDomainAgent.h"
#import "FXShapeRenderer.h"
#import "FXLibraryEditorPaletteController.h"
#import "FXModel.h"
#import "FXModelGroup.h"
#import "FXElement.h"
#import "FXElementGroup.h"
#import "FXLibraryEditorPaletteCellView.h"
#import "FXLibraryEditorTableRowView.h"
#import "FXSystemUtils.h"
#import "VoltaCloudLibraryController.h"


NSString* skLibraryEditorTableColumnIdentifier_Title = @"title";


typedef NS_ENUM(short, FXLibraryEditorPaletteUpdateMode)
{
  FXLibraryEditorPaletteUpdateMode_Generic,
  FXLibraryEditorPaletteUpdateMode_RemovingItems,
  FXLibraryEditorPaletteUpdateMode_AddingItems,
  FXLibraryEditorPaletteUpdateMode_MovingItems,
};


@interface FXLibraryEditorPaletteController () <
  NSOutlineViewDelegate,
  NSOutlineViewDataSource,
  VoltaLibraryObserver,
  FXLibraryEditorPaletteCellViewClient,
  NSTextFieldDelegate
  >
@end


@implementation FXLibraryEditorPaletteController
{
@private
  id<VoltaLibrary> _library;
  id<VoltaCloudLibraryController> _cloudLibraryController;
  NSMutableArray* mElementGroups;
  FXLibraryEditorPaletteCellView* mDummyCellView;
  __weak id mElementGroupWrapperFromWhichElementsAreDragged; FXIssue(155)
  FXLibraryEditorPaletteUpdateMode mUpdateMode;

  // Variables related to moving elements within a group.
  NSString* mNameOfGroupInWhichElementsWereMoved;
  NSRange mFinalIndexRangeOfElementsThatWereMoved;
  NSMutableIndexSet* mOriginalIndexesOfDraggedElements;
}


- (id) init
{
  self = [super initWithNibName:@"Palette" bundle:[NSBundle bundleForClass:[self class]]];
  if (self != nil)
  {
    mElementGroups = [[NSMutableArray alloc] init];
    mDummyCellView = [[FXLibraryEditorPaletteCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
    mUpdateMode = FXLibraryEditorPaletteUpdateMode_Generic;
    mFinalIndexRangeOfElementsThatWereMoved.location = NSNotFound;
    mOriginalIndexesOfDraggedElements = [[NSMutableIndexSet alloc] init];
  }
  return self;
}


//MARK: NSViewController overrides


- (void) loadView
{
  [super loadView];
  [self initializeUI];
}


//MARK: Public


- (void) setLibrary:(id<VoltaLibrary>)library
{
  if ( _library != library )
  {
    FXRelease(mLibrary)
    _library = library;
    FXRetain(mLibrary)

    if ( _library != nil )
    {
      [_library addObserver:self];
      [self updateTableFromLibraryData];
    }
    else
    {
      [_paletteTable setDataSource:nil];
      @synchronized(mElementGroups)
      {
        [mElementGroups removeAllObjects];
      }
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
    self.paletteFolderButton.image = [[NSBundle bundleForClass:[self class]] imageForResource:@"iCloud_small"];
    self.paletteFolderButton.toolTip = FXLocalizedString(@"ShowCloudFilesButtonTooltip");
  }
}


- (IBAction) createOrCopyGroup:(id)sender
{
  [_library beginEditingPalette];
  NSIndexSet* selectedItems = [_paletteTable selectedRowIndexes];
  if ( [selectedItems count] > 0 )
  {
    FXIssue(148)
    [selectedItems enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL* stop) {
      id item = [_paletteTable itemAtRow:rowIndex];
      if ( [item isKindOfClass:[FXElementGroup class]] )
      {
        FXString const originalGroupName( (__bridge CFStringRef)[(FXElementGroup*)item name] );
        [_library copyElementGroup:originalGroupName];
      }
    }];
  }
  else
  {
    [_library createElementGroup];
  }
  mUpdateMode = FXLibraryEditorPaletteUpdateMode_AddingItems;
  [_library endEditingPalette];
}


- (IBAction) removeSelectedItems:(id)sender
{
  NSIndexSet* selectedRows = [_paletteTable selectedRowIndexes];
  if ( [selectedRows count] > 0 )
  {
    [self removeSelectedElementsAndGroups];
  }
}


- (IBAction) revealPaletteFolder:(id)sender
{
  if ( (_cloudLibraryController != nil) && _cloudLibraryController.nowUsingCloudLibrary )
  {
    [_cloudLibraryController showContentsOfCloudFolder:VoltaCloudFolderType_LibraryPalette];
  }
  else
  {
    [FXSystemUtils revealFileAtLocation:[_library paletteLocation]];
  }
}


#pragma mark NSResponder overrides


- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  [_paletteTable encodeRestorableStateWithCoder:state];
  NSMutableArray* expandedGroups = [NSMutableArray arrayWithCapacity:[mElementGroups count]];
  for ( FXModelGroup* group in mElementGroups )
  {
    if ( [_paletteTable isItemExpanded:group] )
    {
      [expandedGroups addObject:group.name];
    }
  }
  [state encodeObject:expandedGroups forKey:@"Palette_ExpandedGroups"];
  NSPoint const scrollPosition = [[[_paletteTable enclosingScrollView] contentView] documentVisibleRect].origin;
  [state encodePoint:scrollPosition forKey:@"Palette_LastScrollPosition"];
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  [_paletteTable restoreStateWithCoder:state];
  NSArray* expandedGroups = [state decodeObjectForKey:@"Palette_ExpandedGroups"];
  for ( NSString* groupName in expandedGroups )
  {
    for ( FXElementGroup* group in mElementGroups )
    {
      if ( [group.name isEqualToString:groupName] )
      {
        [_paletteTable expandItem:group];
        break;
      }
    }
  }
  NSPoint const lastScrollPosition = [state decodePointForKey:@"Palette_LastScrollPosition"];
  [_paletteTable scrollPoint:lastScrollPosition];
}


#pragma mark NSOutlineViewDataSource


- (id) outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
  id result = nil;
  @synchronized(self)
  {
    if ( item == nil )
    {
      if ( outlineView == _paletteTable )
      {
        @synchronized(mElementGroups)
        {
          result = mElementGroups[index];
        }
      }
    }
    else if ( [item isKindOfClass:[FXElementGroup class]] )
    {
      FXElementGroup* groupWrapper = item;
      NSAssert( (index >= 0) && (index < [[groupWrapper elements] count]), @"NSOutlineView index is out of bounds." );
      result = groupWrapper.elements[index];
    }
  }
  return result;
}


- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  BOOL result = NO;
  @synchronized(self)
  {
    result = [item isKindOfClass:[FXElementGroup class]];
  }
  return result;
}


- (NSInteger) outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
  NSInteger result = 0;
  @synchronized(self)
  {
    if ( item == nil )
    {
      if ( outlineView == _paletteTable )
      {
        @synchronized(mElementGroups)
        {
          result = [mElementGroups count];
        }
      }
    }
    else if ( [item isKindOfClass:[FXElementGroup class]] )
    {
      result = [[(FXElementGroup*)item elements] count];
    }
  }
  return result;
}


- (void) outlineView:(NSOutlineView*)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn*)tableColumn byItem:(id)item
{
  @synchronized(self)
  {
    if ( outlineView == _paletteTable )
    {
      if ( [item isKindOfClass:[FXElementGroup class]] )
      {
        FXElementGroup* groupWrapper = item;
        if ( [object isKindOfClass:[NSString class]] )
        {
          NSString* stringObject = object;
          FXString newName( (__bridge CFStringRef)stringObject );
          FXString groupName( (__bridge CFStringRef)[groupWrapper name] );
          [_library renameElementGroup:groupName proposedName:newName];
        }
      }
    }
  }
}


- (void) outlineView:(NSOutlineView*)outlineView draggingSession:(NSDraggingSession*)session willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray*)draggedItems
{
  [_paletteTable deselectAll:self];
  mElementGroupWrapperFromWhichElementsAreDragged = [self findCommonGroupForItems:draggedItems];
  [mOriginalIndexesOfDraggedElements removeAllIndexes];
  NSInteger const elementGroupRowIndex = [_paletteTable rowForItem:mElementGroupWrapperFromWhichElementsAreDragged];
  if ( elementGroupRowIndex >= 0 )
  {
    for ( id draggedItem in draggedItems )
    {
      NSInteger rowIndex = [_paletteTable rowForItem:draggedItem];
      NSAssert(rowIndex >= 0, @"dragged item has no row index");
      [mOriginalIndexesOfDraggedElements addIndex:(rowIndex - elementGroupRowIndex - 1)];
    }
  }

  session.draggingFormation = NSDraggingFormationList;
  [session enumerateDraggingItemsWithOptions:0 forView:_paletteTable classes:@[[FXElement class]] searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
    FXElement* draggedElement = draggingItem.item;
    FXLibraryEditorPaletteCellView* cellView = mDummyCellView;
    cellView.library = _library;
    draggingItem.imageComponentsProvider = ^() {
      [cellView removeConstraints:[cellView constraints]];
      cellView.element = draggedElement;
      [cellView addConstraint:[NSLayoutConstraint constraintWithItem:cellView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:[cellView height]]];
      cellView.frame = NSMakeRect(0, 0, [_paletteTable frame].size.width, [cellView height]);
      [cellView setNeedsLayout:YES];
      [cellView layoutSubtreeIfNeeded];
      return [cellView draggingImageComponents];
    };
  }];
}


- (id <NSPasteboardWriting>) outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item
{
  if ([item isKindOfClass:[FXElement class]])
  {
    return (FXElement*)item;
  }
  return nil;
}


- (BOOL) outlineView:(NSOutlineView*)outlineView acceptDrop:(id<NSDraggingInfo>)info item:(id)targetItem childIndex:(NSInteger)index
{
  BOOL acceptsDrop = NO;
  @synchronized(self)
  {
    if ( outlineView == _paletteTable )
    {
      acceptsDrop = YES;

      NSPasteboard* pboard = [info draggingPasteboard];
      if ( [self objectsHaveSameClass:[pboard pasteboardItems]] )
      {
        [_library beginEditingPalette];

        NSArray* droppedElements = [pboard readObjectsForClasses:@[[FXElement class]] options:nil];
        [self handleDroppedElements:droppedElements onElementGroup:targetItem atIndex:index];

        NSArray* droppedModelGroups = [pboard readObjectsForClasses:@[[FXModelGroup class]] options:nil];
        [self handleDroppedModelGroups:droppedModelGroups onElementGroup:targetItem atIndex:index];

        NSArray* droppedModels = [pboard readObjectsForClasses:@[[FXModel class]] options:nil];
        [self handleDroppedModels:droppedModels onElementGroup:targetItem atIndex:index];

        [_library endEditingPalette];
      }
    }
    mElementGroupWrapperFromWhichElementsAreDragged = nil;
  }
  return acceptsDrop;
}


- (NSDragOperation) outlineView:(NSOutlineView*)outlineView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
  if (outlineView == _paletteTable)
  {
    NSPasteboard* pboard = [info draggingPasteboard];
    if ( [item isKindOfClass:[FXElementGroup class]] )
    {
      if ( [pboard canReadObjectForClasses:@[[FXModel class], [FXModelGroup class], [FXElement class]] options:nil] )
      {
        return NSDragOperationGeneric;
      }
      info.animatesToDestination = YES;
    }
  }
  return NSDragOperationNone;
}


#pragma mark NSOutlineViewDelegate


- (NSView*) outlineView:(NSOutlineView*)outlineView viewForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
  NSView* result = nil;
  NSAssert( outlineView == _paletteTable, @"NSOutlineView delegate method called for wrong table." );
  if ( [item isKindOfClass:[FXElement class]] )
  {
    result = [self prepareCellViewForElement:(FXElement*)item];
  }
  else if ( [item isKindOfClass:[FXElementGroup class]] )
  {
    result = [self prepareCellViewForElementGroup:(FXElementGroup*)item];
  }
  return result;
}


- (NSTableRowView*) outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
  FXLibraryEditorTableRowView *result = [[FXLibraryEditorTableRowView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
  FXAutorelease(result)
  return result;
}


- (BOOL) outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
  return NO;//[item isKindOfClass:[FXElementGroup class]];
}


- (CGFloat) outlineView:(NSOutlineView*)outlineView heightOfRowByItem:(id)item
{
  if ( [item isKindOfClass:[FXElement class]] )
  {
    NSInteger rowIndex = [_paletteTable rowForItem:item];
    if ( rowIndex >= 0 )
    {
      [mDummyCellView setElement:(FXElement*)item];
      return [mDummyCellView height];
    }
  }
  return [outlineView rowHeight];
}


- (BOOL) outlineView:(NSOutlineView*)outlineView shouldSelectItem:(id)item
{
  BOOL result = NO;
  @synchronized(self)
  {
    if ( outlineView == _paletteTable )
    {
      result = YES;
    }
  }
  return result;
}


- (BOOL) outlineView:(NSOutlineView*)outlineView shouldEditTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
  BOOL result = NO;
  @synchronized(self)
  {
    if ( outlineView == _paletteTable )
    {
      result = [item isKindOfClass:[FXElementGroup class]];
    }
  }
  return result;
}


- (void) outlineViewSelectionDidChange:(NSNotification*)notification
{
  [self handleSelectedItems];
}


#pragma mark VoltaLibraryObserver


- (void) handleVoltaLibraryPaletteChanged:(id<VoltaLibrary>)library
{
  [self updateTableFromLibraryData];
}


#pragma mark FXLibraryEditorPaletteCellViewClient


- (void) handleNewName:(NSString*)newName
            forElement:(FXElement*)editedElement
     inPaletteCellView:(FXLibraryEditorPaletteCellView*)cellView
{
  if ( editedElement != nil )
  {
    NSString* groupName = [(FXElementGroup*)[_paletteTable parentForItem:editedElement] name];
    if ( groupName != nil )
    {
      if (![_library renameElement:(CFStringRef)editedElement.name inGroup:(CFStringRef)groupName toName:(CFStringRef)newName])
      {
        NSBeep();
        cellView.primaryField.stringValue = editedElement.name; // reverting the change
      }
    }
  }
}


- (void) handleChangedPropertiesOfElement:(FXElement*)editedElement
                        inPaletteCellView:(FXLibraryEditorPaletteCellView*)cellView
{
  if ( editedElement != nil )
  {
    NSString* groupName = [(FXElementGroup*)[_paletteTable parentForItem:editedElement] name];
    if ( groupName != nil )
    {
      [_library updateProperties:editedElement.properties ofElement:(CFStringRef)editedElement.name inGroup:(CFStringRef)groupName];
    }
  }
}


#pragma mark NSTextFieldDelegate


- (void) controlTextDidEndEditing:(NSNotification*)notification
{
  NSInteger row = [_paletteTable rowForView:[notification object]];
  id item = [_paletteTable itemAtRow:row];
  if ( [item isKindOfClass:[FXElementGroup class]] )
  {
    FXElementGroup* group = item;
    NSString* newGroupName = [(NSTextField*)[notification object] stringValue];
    if ( ![group.name isEqualToString:newGroupName] )
    {
      if (![_library renameElementGroup:(CFStringRef)group.name proposedName:(CFStringRef)newGroupName])
      {
        NSBeep();
        [(NSTextField*)[notification object] setStringValue:group.name]; // reverting the change
      }
    }
  }
}


#pragma mark Private


- (void) initializeUI
{
  NSAssert( _paletteFolderButton != nil, @"folder button does not exist in NIB" );
  [_paletteFolderButton setImage:[NSImage imageNamed:NSImageNameFolder]];
  [_paletteFolderButton setToolTip:FXLocalizedString(@"PaletteFolderRevealButtonTooltip")];

  [_paletteTable registerForDraggedTypes:@[FXPasteboardDataTypeModelGroup, FXPasteboardDataTypeModel, FXPasteboardDataTypeElement, FXPasteboardDataTypeElementGroup]];
  _paletteTable.verticalMotionCanBeginDrag = NO;
  _paletteTable.dataSource = self;
  _paletteTable.delegate = self;
  _paletteTable.doubleAction = @selector(handleOutlineViewDoubleClick:);
  _paletteTable.target = self;
  _paletteTable.intercellSpacing = NSZeroSize;
  _paletteTable.gridStyleMask = NSTableViewGridNone;
  _paletteTable.focusRingType = NSFocusRingTypeNone;
  _paletteTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;

  NSTableColumn* titleTableColumn = [_paletteTable tableColumnWithIdentifier:skLibraryEditorTableColumnIdentifier_Title];
  titleTableColumn.resizingMask = NSTableColumnAutoresizingMask;
  [_paletteTable setOutlineTableColumn:titleTableColumn];
  [[[_paletteTable enclosingScrollView] verticalScroller] setControlSize:NSControlSizeSmall];

  [self handleSelectedItems];
}


- (void) handleDroppedElements:(NSArray*)droppedElements
                onElementGroup:(FXElementGroup*)elementGroupWrapper
                       atIndex:(NSInteger)index
{
  if ( (droppedElements != nil) && ([droppedElements count] > 0) && (elementGroupWrapper != nil) )
  {
    BOOL const reorderingInsideGroup = (mElementGroupWrapperFromWhichElementsAreDragged == elementGroupWrapper);
    VoltaPTElementVector elements;
    for ( FXElement* elementWrapper in droppedElements )
    {
      elements.push_back([elementWrapper toElement]);
    }
    FXString const groupName((__bridge CFStringRef)[elementGroupWrapper name]);
    if ( [_library insertElements:elements intoGroup:groupName atIndex:index dueToReordering:reorderingInsideGroup] )
    {
      if (reorderingInsideGroup)
      {
        mUpdateMode = FXLibraryEditorPaletteUpdateMode_MovingItems;
        mNameOfGroupInWhichElementsWereMoved = [elementGroupWrapper name];
        FXRetain(mNameOfGroupInWhichElementsWereMoved)
        __block int rangeOffset = 0;
        [mOriginalIndexesOfDraggedElements enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL*){if (idx < index) rangeOffset++;}];
        mFinalIndexRangeOfElementsThatWereMoved = NSMakeRange(index - rangeOffset, elements.size());
      }
      else
      {
        mUpdateMode = FXLibraryEditorPaletteUpdateMode_AddingItems;
      }
    }
  }
}


- (void) handleDroppedModels:(NSArray*)droppedModels
              onElementGroup:(FXElementGroup*)elementGroupWrapper
                     atIndex:(NSInteger)index
{
  if ( (droppedModels != nil) && ([droppedModels count] > 0) && (elementGroupWrapper != nil) )
  {
    __block VoltaPTElementVector elements;

    [droppedModels enumerateObjectsUsingBlock:^(id modelWrapper, NSUInteger, BOOL*) {
      VoltaPTModelPtr model = [(FXModel*)modelWrapper persistentModel];
      VoltaPTElement element(model->elementNamePrefix, model->type, model->name, model->vendor);
      element.properties = FXVoltaCircuitDomainAgent::circuitElementParametersForModel(model);
      element.labelPosition = model->labelPosition;
      elements.push_back(element);
    }];

    FXString const groupName((__bridge CFStringRef)[elementGroupWrapper name]);
    if ( [_library insertElements:elements intoGroup:groupName atIndex:index dueToReordering:NO] )
    {
      mUpdateMode = FXLibraryEditorPaletteUpdateMode_AddingItems;
    }
  }
}


- (void) handleDroppedModelGroups:(NSArray*)droppedModelGroups
                   onElementGroup:(FXElementGroup*)elementGroupWrapper
                          atIndex:(NSInteger)index
{
  if ( (droppedModelGroups != nil) && ([droppedModelGroups count] > 0) && (elementGroupWrapper != nil) )
  {
    NSMutableArray* droppedModels = [[NSMutableArray alloc] initWithCapacity:16];
    for ( FXModelGroup* modelGroup in droppedModelGroups )
    {
      [droppedModels addObjectsFromArray:[modelGroup models]];
    }
    [self handleDroppedModels:droppedModels onElementGroup:elementGroupWrapper atIndex:index];
    FXRelease(droppedModels)
  }
}


- (void) reorderElementGroupsByMovingGroups:(NSArray*)movedGroups toIndex:(NSInteger)index
{
  FXIssue(155)
  @synchronized(mElementGroups)
  {
    NSMutableIndexSet* itemIndexes = [NSMutableIndexSet indexSet];
    for ( FXElementGroup* currentGroupWrapper in movedGroups )
    {
      [itemIndexes addIndex:[mElementGroups indexOfObject:currentGroupWrapper]];
    }
    NSAssert([itemIndexes count] == [movedGroups count], @"Couldn't find indexes for all dropped model group wrappers.");
    if  ( [_library moveElementGroupsAtIndexes:itemIndexes inFrontOfElementGroupAtIndex:index] )
    {
      [self rearrangeObjects:movedGroups ofArray:mElementGroups byInsertingAtIndex:index];
      [self reloadTableByPreservingSelection:NO];
    }
  }
}


- (FXElementGroup*) findCommonGroupForItems:(NSArray*)items
{
  FXElementGroup* commonParent = nil;
  for ( id item in items )
  {
    id parent = [_paletteTable parentForItem:item];
    if ( parent == nil )
    {
      commonParent = nil;
      break;
    }
    else if ( [parent isKindOfClass:[FXElementGroup class]] )
    {
      if ( commonParent == nil )
      {
        commonParent = parent;
      }
      else if ( parent != commonParent )
      {
        commonParent = nil;
        break;
      }
    }
  }
  return commonParent;
}


- (void) rearrangeObjects:(NSArray*)objectsToInsert ofArray:(NSMutableArray*)objectsToRearrange byInsertingAtIndex:(NSUInteger)insertionIndex
{
  [objectsToRearrange sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
    BOOL const obj1IsReinserted = [objectsToInsert containsObject:obj1];
    BOOL const obj2IsReinserted = [objectsToInsert containsObject:obj2];
    if ( obj1IsReinserted && obj2IsReinserted )
    {
      return [objectsToInsert indexOfObject:obj1] < [objectsToInsert indexOfObject:obj2] ? NSOrderedDescending : NSOrderedAscending;
    }
    else if ( obj1IsReinserted && !obj2IsReinserted )
    {
      return ([objectsToRearrange indexOfObject:obj2] < insertionIndex) ? NSOrderedDescending : NSOrderedAscending;
    }
    else if ( !obj1IsReinserted && obj2IsReinserted )
    {
      return ([objectsToRearrange indexOfObject:obj1] < insertionIndex) ? NSOrderedAscending : NSOrderedDescending;
    }
    else
    {
      return ([objectsToRearrange indexOfObject:obj1] < [objectsToRearrange indexOfObject:obj2]) ? NSOrderedAscending : NSOrderedDescending;
    }
  }];
}


- (void) updateTableFromLibraryData
{
  __block NSMutableArray* newElementGroups = [[NSMutableArray alloc] initWithCapacity:20];
  [_library iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const & group, BOOL* stop) {
    FXElementGroup* groupWrapper = [[FXElementGroup alloc] initWithElementGroup:group];
    [newElementGroups addObject:groupWrapper];
    FXRelease(groupWrapper)
  }];
  [self transitionDisplaySettingsToElementGroups:newElementGroups];
  if ( mUpdateMode == FXLibraryEditorPaletteUpdateMode_Generic )
  {
    [self replaceTableContentsWithElementGroups:newElementGroups];
  }
  else
  {
    [self transitionTableContentsToElementGroups:newElementGroups];
    mUpdateMode = FXLibraryEditorPaletteUpdateMode_Generic;
  }
  FXRelease(newElementGroups)
  newElementGroups = nil;
}


- (void) replaceTableContentsWithElementGroups:(NSArray*)elementGroups
{
  NSPoint const scrollPoint = [[[_paletteTable enclosingScrollView] contentView] documentVisibleRect].origin;
  [_paletteTable beginUpdates];
  NSMutableArray* expandedItems = [NSMutableArray arrayWithCapacity:[mElementGroups count]];
  for ( FXElementGroup* group in mElementGroups )
  {
    if ([_paletteTable isItemExpanded:group])
    {
      [expandedItems addObject:[group name]];
    }
  }
  [mElementGroups setArray:elementGroups];
  [self reloadTableByPreservingSelection:NO];
  for ( FXElementGroup* group in mElementGroups )
  {
    if ( [expandedItems containsObject:[group name]] )
    {
      [_paletteTable expandItem:group];
    }
  }
  [_paletteTable endUpdates];
  [_paletteTable scrollPoint:scrollPoint];
}


- (void) transitionTableContentsToElementGroups:(NSArray*)elementGroups
{
  [_paletteTable beginUpdates];
  switch ( mUpdateMode )
  {
    case FXLibraryEditorPaletteUpdateMode_AddingItems:   [self transitionTableContentsByAddingItemsFromElementGroups:elementGroups]; break;
    case FXLibraryEditorPaletteUpdateMode_RemovingItems: [self transitionTableContentsByRemovingItemsNotFoundInElementGroups:elementGroups]; break;
    case FXLibraryEditorPaletteUpdateMode_MovingItems:   [self transitionTableContentsByMovingElementsToAchieveElementGroups:elementGroups]; break;
    default:
      break;
  }
  [_paletteTable endUpdates];
}


- (void) transitionTableContentsByAddingItemsFromElementGroups:(NSArray*)newElementGroups
{
  [self transitionTableContentsByAddingGroupItemsFromElementGroups:newElementGroups];
  [self transitionTableContentsByAddingElementItemsFromElementGroups:newElementGroups];
}


- (void) transitionTableContentsByAddingGroupItemsFromElementGroups:(NSArray*)newElementGroups
{
  // Note: If a group was added, the order of the groups may change after the insertion operation
  // we are performing here because the file that will be created for the new group triggers a
  // filesystem event, which again triggers a palette reload (FXLibraryEditorPaletteUpdateMode_Generic).
  // Palettes will then be ordered the same as the files.
  NSInteger newGroupIndex = -1;
  NSMutableIndexSet* newGroupIndexes = [NSMutableIndexSet indexSet];
  for ( FXElementGroup* newGroup in newElementGroups )
  {
    newGroupIndex++;
    BOOL foundMatchingExistingGroup = NO;
    for ( FXElementGroup* existingGroup in mElementGroups )
    {
      if ( [newGroup.name isEqualToString:existingGroup.name] )
      {
        foundMatchingExistingGroup = YES;
        break;
      }
    }
    if ( !foundMatchingExistingGroup )
    {
      if ( newGroupIndex >= [mElementGroups count] )
      {
        [mElementGroups addObject:newGroup];
      }
      else
      {
        [mElementGroups insertObject:newGroup atIndex:newGroupIndex];
      }
      [newGroupIndexes addIndex:newGroupIndex];
    }
  }
  if ( [newGroupIndexes count] > 0 )
  {
    [_paletteTable insertItemsAtIndexes:newGroupIndexes inParent:nil withAnimation:NSTableViewAnimationEffectFade];
  }
}


- (void) transitionTableContentsByAddingElementItemsFromElementGroups:(NSArray*)newElementGroups
{
  for ( FXElementGroup* existingGroup in mElementGroups )
  {
    NSMutableIndexSet* indexesOfElementsToBeInserted = [NSMutableIndexSet indexSet];
    for ( FXElementGroup* newGroup in newElementGroups )
    {
      if ( [existingGroup.name isEqualToString:newGroup.name] )
      {
        NSInteger indexOfNewElement = -1;
        for ( FXElement* newElement in newGroup.elements )
        {
          indexOfNewElement++;
          BOOL foundExistingElementWithSameName = NO;
          for ( FXElement* existingElement in existingGroup.elements )
          {
            if ( [newElement.name isEqualToString:existingElement.name] )
            {
              foundExistingElementWithSameName = YES;
              break;
            }
          }
          if ( !foundExistingElementWithSameName )
          {
            [indexesOfElementsToBeInserted addIndex:indexOfNewElement];
            [existingGroup.elements insertObject:newElement atIndex:indexOfNewElement];
          }
        }
        break;
      }
    }
    if ( [indexesOfElementsToBeInserted count] > 0 )
    {
      [_paletteTable insertItemsAtIndexes:indexesOfElementsToBeInserted inParent:existingGroup withAnimation:NSTableViewAnimationEffectFade];
    }
  }
}


- (void) transitionTableContentsByRemovingItemsNotFoundInElementGroups:(NSArray*)newElementGroups
{
  // Note: Removing only those items that are visible to the user should be sufficient since the user
  // can not select items if they are not displayed (i.e. inside collapsed parent items) by the table view.
  NSMutableIndexSet* indexesOfGroupItemsToRemove = [NSMutableIndexSet indexSet];
  NSInteger existingGroupIndex = -1;
  for ( FXElementGroup* existingGroup in mElementGroups )
  {
    existingGroupIndex++;
    FXElementGroup* matchingNewGroup = nil;
    for ( FXElementGroup* newGroup in newElementGroups )
    {
      if ( [newGroup.name isEqualToString:existingGroup.name] )
      {
        matchingNewGroup = newGroup;
        break;
      }
    }
    if ( matchingNewGroup != nil )
    {
      if ( [_paletteTable isItemExpanded:existingGroup] )
      {
        NSMutableIndexSet* indexesOfElementItemsToRemove = [NSMutableIndexSet indexSet];
        NSInteger const parentRowIndex = [_paletteTable rowForItem:existingGroup];
        for ( FXElement* existingElement in existingGroup.elements )
        {
          BOOL foundMatchingElement = NO;
          for ( FXElement* newElement in matchingNewGroup.elements )
          {
            if ( [existingElement.name isEqualToString:newElement.name] )
            {
              foundMatchingElement = YES;
              break;
            }
          }
          if ( !foundMatchingElement )
          {
            [indexesOfElementItemsToRemove addIndex:([_paletteTable rowForItem:existingElement] - parentRowIndex - 1)];
          }
        }
        if ( [indexesOfElementItemsToRemove count] > 0 )
        {
          [_paletteTable removeItemsAtIndexes:indexesOfElementItemsToRemove inParent:existingGroup withAnimation:NSTableViewAnimationEffectFade];
          [existingGroup.elements removeObjectsAtIndexes:indexesOfElementItemsToRemove];
        }
      }
    }
    else // the group was deleted
    {
      [indexesOfGroupItemsToRemove addIndex:existingGroupIndex];
    }
  }
  if ( [indexesOfGroupItemsToRemove count] > 0 )
  {
    [_paletteTable removeItemsAtIndexes:indexesOfGroupItemsToRemove inParent:nil withAnimation:NSTableViewAnimationEffectFade];
    [mElementGroups removeObjectsAtIndexes:indexesOfGroupItemsToRemove];
  }
}


- (void) transitionTableContentsByMovingElementsToAchieveElementGroups:(NSArray*)elementGroups
{
  if ( (mNameOfGroupInWhichElementsWereMoved != nil) && (mFinalIndexRangeOfElementsThatWereMoved.location != NSNotFound) )
  {
    for ( FXElementGroup* group in elementGroups )
    {
      if ( [[group name] isEqualToString:mNameOfGroupInWhichElementsWereMoved] )
      {
        if ( (mFinalIndexRangeOfElementsThatWereMoved.location + mFinalIndexRangeOfElementsThatWereMoved.length) <= [group.elements count] )
        {
          NSAssert([mOriginalIndexesOfDraggedElements count] == mFinalIndexRangeOfElementsThatWereMoved.length, @"The number of dragged items and inserted elements should be the same.");
          for ( FXElementGroup* existingGroup in mElementGroups )
          {
            if ( [existingGroup.name isEqualToString:mNameOfGroupInWhichElementsWereMoved] )
            {
              // First the moved elements are deleted
              [existingGroup.elements removeObjectsAtIndexes:mOriginalIndexesOfDraggedElements];
              [_paletteTable removeItemsAtIndexes:mOriginalIndexesOfDraggedElements inParent:existingGroup withAnimation:NSTableViewAnimationEffectGap];
              // Then, the new items are inserted in the model
              NSIndexSet* insertionIndexSet = [NSIndexSet indexSetWithIndexesInRange:mFinalIndexRangeOfElementsThatWereMoved];
              [existingGroup.elements insertObjects:[group.elements subarrayWithRange:mFinalIndexRangeOfElementsThatWereMoved] atIndexes:insertionIndexSet];
              [_paletteTable insertItemsAtIndexes:insertionIndexSet inParent:existingGroup withAnimation:NSTableViewAnimationEffectGap];
              break;
            }
          }
          [mOriginalIndexesOfDraggedElements removeAllIndexes];
        }
        break;
      }
    }
    FXRelease(mNameOfGroupInWhichElementsWereMoved)
    mNameOfGroupInWhichElementsWereMoved = nil;
    mFinalIndexRangeOfElementsThatWereMoved.location = NSNotFound;
  }
}


- (void) transitionDisplaySettingsToElementGroups:(NSArray*)newElementGroups
{
  for ( FXElementGroup* existingGroup in mElementGroups )
  {
    for ( FXElementGroup* newGroup in newElementGroups )
    {
      if ( [existingGroup.name isEqualToString:newGroup.name] )
      {
        for ( FXElement* existingElement in existingGroup.elements )
        {
          for ( FXElement* newElement in newGroup.elements )
          {
            if ( [existingElement.name isEqualToString:newElement.name] )
            {
              newElement.displaySettings = existingElement.displaySettings;
              break;
            }
          }
        }
        break;
      }
    }
  }
}


- (NSView*) prepareCellViewForElement:(FXElement*)element
{
  FXLibraryEditorPaletteCellView* cellView = [_paletteTable makeViewWithIdentifier:@"ElementCell" owner:self];
  NSAssert(cellView != nil, @"The cell view prototype should have been added to the NIB file.");
  if ( cellView == nil )
  {
    NSRect const dummyFrame = NSMakeRect(0, 0, 200, 100);
    cellView = [[FXLibraryEditorPaletteCellView alloc] initWithFrame:dummyFrame];
    cellView.identifier = @"ElementCell";
    FXAutorelease(cellView)
  }
  cellView.library = _library;
  cellView.showsLockSymbol = NO;
  cellView.element = element;
  cellView.isEditable = YES;
  cellView.heightChangeTarget = self;
  cellView.heightChangeAction = @selector(toggleShowPropertiesTable:);
  cellView.client = self;
  return cellView;
}


- (NSView*) prepareCellViewForElementGroup:(FXElementGroup*)group
{
  NSTableCellView* cellView = [_paletteTable makeViewWithIdentifier:@"ElementGroupCell" owner:self];
  cellView.textField.stringValue = group.name;
  [(NSTextFieldCell*)cellView.textField.cell setLineBreakMode:NSLineBreakByTruncatingTail];
  cellView.textField.editable = YES;
  cellView.textField.delegate = self;
  return cellView;
}


- (NSArray*) selectedItemsForOutlineView:(NSOutlineView*)outlineView
{
  NSMutableArray* selectedItems = nil;
  NSIndexSet* selectedRows = [outlineView selectedRowIndexes];
  if ( [selectedRows count] > 0 )
  {
    selectedItems = [NSMutableArray arrayWithCapacity:[selectedRows count]];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL *stop) {
      id item = [outlineView itemAtRow:rowIndex];
      if (item != nil)
      {
        [selectedItems addObject:item];
      }
    }];
  }
  return selectedItems;
}


- (void) restoreSelection:(NSArray*)selectedItems forOutlineView:(NSOutlineView*)outlineView
{
  if ( selectedItems != nil )
  {
    NSMutableIndexSet* newSelectedRows = [NSMutableIndexSet indexSet];
    for ( id item in selectedItems )
    {
      NSInteger newRowIndex = [outlineView rowForItem:item];
      if ( newRowIndex >= 0 )
      {
        [newSelectedRows addIndex:newRowIndex];
      }
    }
    [outlineView selectRowIndexes:newSelectedRows byExtendingSelection:NO];
  }
}


- (void) reloadTableByPreservingSelection:(BOOL)preserveSelection
{
  NSArray* selectedItems = nil;
  if ( preserveSelection )
  {
    selectedItems = [self selectedItemsForOutlineView:_paletteTable];
  }

  [_paletteTable reloadData];

  if ( preserveSelection && (selectedItems != nil) )
  {
    [self restoreSelection:selectedItems forOutlineView:_paletteTable];
  }
}


- (void) handleOutlineViewDoubleClick:(id)sender
{
  NSOutlineView* outlineView = sender;
  NSInteger clickedRow = [outlineView clickedRow];
  if (clickedRow >= 0 )
  {
    id clickedItem = [outlineView itemAtRow:clickedRow];
    if ( [outlineView isExpandable:clickedItem] )
    {
      if ( [outlineView isItemExpanded:clickedItem] )
      {
        [outlineView collapseItem:clickedItem];
      }
      else
      {
        [outlineView expandItem:clickedItem];
      }
    }
  }
}


- (void) handleSelectedItems
{
  @synchronized(self)
  {
    FXIssue(167)
    NSIndexSet* selectedIndexes = [_paletteTable selectedRowIndexes];
    __block BOOL emptySelectionOrGroupsOnly = YES;
    [selectedIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL* stop) {
      id selectedItem = [_paletteTable itemAtRow:index];
      if ( ![selectedItem isKindOfClass:[FXElementGroup class]] )
      {
        emptySelectionOrGroupsOnly = NO;
        *stop = YES;
      }
    }];
    [_createGroupButton setEnabled:emptySelectionOrGroupsOnly];
    [_removeItemsButton setEnabled:([selectedIndexes count] > 0)];

    [_paletteTable enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
      [rowView setNeedsDisplay:YES];
    }];
  }
}


- (void) selectTableItemOfClass:(Class)itemClass atRow:(NSUInteger)rowIndex
{
  NSUInteger const newNumberOfRows = [_paletteTable numberOfRows];
  if ( newNumberOfRows > 0 )
  {
    NSUInteger const newSelectedRowIndex = (newNumberOfRows > rowIndex) ? rowIndex : (newNumberOfRows - 1);
    if ( [[_paletteTable itemAtRow:newSelectedRowIndex] isKindOfClass:itemClass] )
    {
      [_paletteTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newSelectedRowIndex] byExtendingSelection:NO];
      [_paletteTable scrollRowToVisible:newSelectedRowIndex];
    }
    else
    {
      [_paletteTable deselectAll:self];
    }
  }
}


- (void) removeSelectedElementsAndGroups
{
  [_library beginEditingPalette];

  NSIndexSet* selectedRows = [_paletteTable selectedRowIndexes];

  __block NSMutableArray* groupWrappersToBeRemoved = [[NSMutableArray alloc] initWithCapacity:[selectedRows count]];
  __block NSMutableArray* elementWrappersToBeRemoved = [[NSMutableArray alloc] initWithCapacity:[selectedRows count]];

  [selectedRows enumerateIndexesUsingBlock:^(NSUInteger currentIndex, BOOL *stop) {
    id tableItem = [_paletteTable itemAtRow:currentIndex];
    if ( [tableItem isKindOfClass:[FXElementGroup class]] )
    {
      FXElementGroup* groupWrapper = tableItem;
      [groupWrappersToBeRemoved addObject:groupWrapper];
    }
    else if ( [tableItem isKindOfClass:[FXElement class]] )
    {
      NSInteger const rowIndexOfParentItem = [_paletteTable rowForItem:[_paletteTable parentForItem:tableItem]];
      if ( rowIndexOfParentItem >= 0 )
      {
        if ( ![_paletteTable isRowSelected:rowIndexOfParentItem] )
        {
          [elementWrappersToBeRemoved addObject:tableItem];
        }
      }
    }
  }];

  [self removeElements:elementWrappersToBeRemoved];
  FXRelease(elementWrappersToBeRemoved)
  elementWrappersToBeRemoved = nil;

  [self removeElementGroups:groupWrappersToBeRemoved];
  FXRelease(groupWrappersToBeRemoved)
  groupWrappersToBeRemoved = nil;

  mUpdateMode = FXLibraryEditorPaletteUpdateMode_RemovingItems;
  [_library endEditingPalette];
}


- (void) removeElements:(NSArray*)elementWrappersToBeRemoved
{
  std::vector< std::pair<FXString, FXString> > elementsAndGroups;
  @synchronized(mElementGroups)
  {
    for ( FXElement* elementWrapper in elementWrappersToBeRemoved )
    {
      FXElementGroup* groupWrapper = [_paletteTable parentForItem:elementWrapper];
      if ( groupWrapper != nil )
      {
        elementsAndGroups.push_back( { (__bridge CFStringRef)elementWrapper.name, (__bridge CFStringRef)groupWrapper.name } );
      }
    }
  }
  BOOL const removedAllElements = [_library removeElements:elementsAndGroups];
  NSAssert( removedAllElements, @"All selected elements should have been removed." );
}


- (void) removeElementGroups:(NSArray*)groupWrappersToBeRemoved
{
  FXStringVector groupNames;
  @synchronized(mElementGroups)
  {
    for ( FXElementGroup* groupWrapper in groupWrappersToBeRemoved )
    {
      groupNames.push_back( (__bridge CFStringRef)[groupWrapper name] );
    }
  }
  [_library removeElementGroups:groupNames];
}


- (BOOL) objectsHaveSameClass:(NSArray*)objects
{
  Class commonClass = NULL;
  for ( id anObject in objects )
  {
    if ( commonClass == NULL )
    {
      commonClass = [anObject class];
    }
    else if ( commonClass != [anObject class] )
    {
      commonClass = NULL;
      break;
    }
  }
  return (commonClass != NULL);
}


- (void) toggleShowPropertiesTable:(id)sender
{
  NSInteger rowIndex = [_paletteTable rowForView:sender];
  if ( rowIndex >= 0 )
  {
    [_paletteTable noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:(NSUInteger)rowIndex]];
  }
}


@end
