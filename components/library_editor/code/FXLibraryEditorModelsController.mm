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

#import "FXLibraryEditorModelsController.h"
#import "FXModelGroup.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXLibraryEditorModelsCellView.h"
#import "FXLibraryEditorTableRowView.h"
#import "FXSystemUtils.h"


typedef NS_ENUM(short, FXLibraryEditorModelsUpdateMode)
{
  FXLibraryEditorModelsUpdateMode_Generic,
  FXLibraryEditorModelsUpdateMode_RemovingItems,
  FXLibraryEditorModelsUpdateMode_AddingItems,
};


@interface FXLibraryEditorModelsController ()
  <
  VoltaLibraryObserver,
  FXLibraryEditorModelsCellViewClient,
  NSOutlineViewDelegate,
  NSOutlineViewDataSource
  >
@end



@implementation FXLibraryEditorModelsController
{
@private
  id<VoltaLibrary> mLibrary;
  id<VoltaCloudLibraryController> mCloudLibraryController;
  FXOutlineView* __unsafe_unretained mModelsTable;
  NSMutableArray* mModelGroupWrappers; // contains FXModelGroup objects for mModelsTable
  FXClipView* __unsafe_unretained mClipView;
  NSButton* __unsafe_unretained mModelsFolderButton;
  NSButton* __unsafe_unretained mAddModelButton;
  NSButton* __unsafe_unretained mRemoveModelsButton;
  FXLibraryEditorModelsCellView* mDummyCellView;
  FXLibraryEditorModelsUpdateMode mUpdateMode;
}

@synthesize modelsTable = mModelsTable;
@synthesize clipView = mClipView;
@synthesize modelsFolderButton = mModelsFolderButton;
@synthesize addModelsButton = mAddModelButton;
@synthesize removeModelsButton = mRemoveModelsButton;
@synthesize library = mLibrary;
@synthesize cloudLibraryController = mCloudLibraryController;


- (id) init
{
  self = [super initWithNibName:@"Models" bundle:[NSBundle bundleForClass:[self class]]];
  if (self != nil)
  {
    mModelGroupWrappers = [[NSMutableArray alloc] init];
    mDummyCellView = [[FXLibraryEditorModelsCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 50)];
    [mDummyCellView layoutSubtreeIfNeeded];
    mUpdateMode = FXLibraryEditorModelsUpdateMode_Generic;
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mDummyCellView)
  FXRelease(mModelGroupWrappers)
  FXRelease(mLibrary)
  self.cloudLibraryController = nil;
  FXDeallocSuper
}


#pragma mark NSViewController overrides


- (void) loadView
{
  [super loadView];
  [self initializeUI];
}


#pragma mark NSResponder overrides


- (void) encodeRestorableStateWithCoder:(NSCoder*)coder
{
  [mModelsTable encodeRestorableStateWithCoder:coder];
  NSMutableArray* expandedGroups = [NSMutableArray arrayWithCapacity:[mModelGroupWrappers count]];
  for ( FXModelGroup* group in mModelGroupWrappers )
  {
    if ( [mModelsTable isItemExpanded:group] )
    {
      [expandedGroups addObject:group.name];
    }
  }
  [coder encodeObject:expandedGroups forKey:@"Models_ExpandedGroups"];
  NSPoint const scrollPosition = [[[mModelsTable enclosingScrollView] contentView] documentVisibleRect].origin;
  [coder encodePoint:scrollPosition forKey:@"Models_LastScrollPosition"];
}


- (void) restoreStateWithCoder:(NSCoder*)coder
{
  [mModelsTable restoreStateWithCoder:coder];
  NSArray* expandedGroups = [coder decodeObjectForKey:@"Models_ExpandedGroups"];
  for ( NSString* groupName in expandedGroups )
  {
    for ( FXModelGroup* group in mModelGroupWrappers )
    {
      if ( [group.name isEqualToString:groupName] )
      {
        [mModelsTable expandItem:group];
        break;
      }
    }
  }
  NSPoint const lastScrollPosition = [coder decodePointForKey:@"Models_LastScrollPosition"];
  [mModelsTable scrollPoint:lastScrollPosition];
}


#pragma mark VoltaLibraryObserver


- (void) handleVoltaLibraryModelsChanged:(id<VoltaLibrary>)library
{
  [self updateModelsFromLibraryData];
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
      [self rebuildModelGroupsDataSource];
    }
    else
    {
      [mModelsTable setDataSource:nil];
      [mModelGroupWrappers removeAllObjects];
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
    mModelsFolderButton.image = [[NSBundle bundleForClass:[self class]] imageForResource:@"iCloud_small"];
    mModelsFolderButton.toolTip = FXLocalizedString(@"ShowCloudFilesButtonTooltip");
  }
}


- (void) createModel:(id)sender
{
  NSInteger selectedRow = [mModelsTable selectedRow];
  if ( selectedRow >= 0 )
  {
    FXModelGroup* groupWrapper = nil; // the group to add the new model to
    VoltaPTModelPtr templateModel; // the existing model to clone the new model from
    id selectedItem = [mModelsTable itemAtRow:selectedRow];

    if ( [selectedItem isKindOfClass:[FXModelGroup class]] )
    {
      groupWrapper = selectedItem;
      NSAssert( [groupWrapper persistentGroup].get() != nullptr, @"VoltaPTModelGroupPtr is empty!" );
      for ( VoltaPTModelPtr candidateModel : [groupWrapper persistentGroup]->models )
      {
        if ( !(candidateModel->isMutable) )
        {
          templateModel = candidateModel; // found a built-in model in the selected group
          break;
        }
      }
    }
    else if ( [selectedItem isKindOfClass:[FXModel class]] )
    {
      // Create a new model, cloned from the selected model.
      FXModel* selectedModelWrapper = selectedItem;
      groupWrapper = [mModelsTable parentForItem:selectedItem];
      templateModel = [selectedModelWrapper persistentModel];
    }

    NSAssert( groupWrapper != nil, @"A group must exist." );
    NSAssert( templateModel.get() != nullptr, @"A prototype model must exist." );
    VoltaPTModelGroupPtr modelGroup = [groupWrapper persistentGroup];

    VoltaPTModelPtr newModel = [mLibrary createModelFromTemplate:templateModel];
    if ( newModel.get() != nullptr )
    {
      mUpdateMode = FXLibraryEditorModelsUpdateMode_AddingItems;
    }
  }
}


- (void) removeModels:(id)sender
{
  [self removeSelectedItems];
}


- (IBAction) revealModelsFolder:(id)sender
{
  if ( (self.cloudLibraryController != nil) && self.cloudLibraryController.nowUsingCloudLibrary )
  {
    [self.cloudLibraryController showContentsOfCloudFolder:VoltaCloudFolderType_LibraryModels];
  }
  else
  {
    [FXSystemUtils revealFileAtLocation:[mLibrary modelsLocation]];
  }
}


#pragma mark FXLibraryEditorPaletteCellViewClient


- (void) handleNewName:(NSString*)newName
              forModel:(FXModel*)editedModel
            inCellView:(FXLibraryEditorModelsCellView*)cellView
{
  if ( editedModel != nil )
  {
    NSString* groupName = [(FXModelGroup*)[mModelsTable parentForItem:editedModel] name];
    if ( groupName != nil )
    {
      if (![mLibrary renameModel:[editedModel persistentModel] toName:(CFStringRef)newName])
      {
        NSBeep();
        cellView.primaryField.stringValue = editedModel.name; // reverting the change
      }
    }
  }
}


- (void) handleNewVendor:(NSString*)newVendorString
                forModel:(FXModel*)editedModel
              inCellView:(FXLibraryEditorModelsCellView*)cellView
{
  if ( editedModel != nil )
  {
    NSString* groupName = [(FXModelGroup*)[mModelsTable parentForItem:editedModel] name];
    if ( groupName != nil )
    {
      VoltaPTModelPtrVector editedModels;
      editedModels.push_back([editedModel persistentModel]);
      if (![mLibrary setVendor:(CFStringRef)newVendorString forModels:editedModels] )
      {
        NSBeep();
        cellView.secondaryField.stringValue = editedModel.vendor; // reverting the change
      }
    }
  }
}


- (void) handleNewProperties:(VoltaPTPropertyVector const &)properties
                    forModel:(FXModel*)editedModel
                  inCellView:(FXLibraryEditorModelsCellView*)cellView
{
  if ( editedModel != nil )
  {
    NSString* groupName = [(FXModelGroup*)[mModelsTable parentForItem:editedModel] name];
    if ( groupName != nil )
    {
      [mLibrary beginEditingModels];
      for ( VoltaPTProperty const & property : properties )
      {
        [mLibrary setPropertyValueOfModel:[editedModel persistentModel] propertyName:property.name propertyValue:property.value];
      }
      [mLibrary endEditingModels];
    }
  }
}


#pragma mark NSOutlineViewDataSource


- (id) outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
  id result = nil;
  @synchronized(self)
  {
    if ( item == nil )
    {
      if ( outlineView == mModelsTable )
      {
        result = mModelGroupWrappers[index];
      }
    }
    else if ( [item isKindOfClass:[FXModelGroup class]] )
    {
      FXModelGroup* groupWrapper = item;
      NSAssert( (index >= 0) && (index < [[groupWrapper models] count]), @"NSOutlineView index is out of bounds." );
      result = groupWrapper.models[index];
    }
  }
  return result;
}


- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  BOOL result = NO;
  @synchronized(self)
  {
    if ( [item isKindOfClass:[FXModelGroup class]] )
    {
      result = YES;
    }
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
      if ( outlineView == mModelsTable )
      {
        result = [mModelGroupWrappers count];
      }
    }
    else if ( [item isKindOfClass:[FXModelGroup class]] )
    {
      result = [[(FXModelGroup*)item models] count];
    }
  }
  return result;
}


- (id <NSPasteboardWriting>) outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item
{
  if ([item isKindOfClass:[FXModel class]])
  {
    return (FXModel*)item;
  }
  else if ([item isKindOfClass:[FXModelGroup class]])
  {
    return (FXModelGroup*)item;
  }
  return nil;
}


- (void) outlineView:(NSOutlineView*)outlineView draggingSession:(NSDraggingSession*)session willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray*)draggedItems
{
  [mModelsTable deselectAll:self];
  session.draggingFormation = NSDraggingFormationList;
  [session enumerateDraggingItemsWithOptions:0 forView:mModelsTable classes:@[[FXModel class]] searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
    FXMutableModel* draggedModel = draggingItem.item;
    draggedModel.library = mLibrary;
    FXLibraryEditorModelsCellView* cellView = mDummyCellView;
    draggingItem.imageComponentsProvider = ^() {
      [cellView removeConstraints:[cellView constraints]];
      cellView.model = draggedModel;
      [cellView addConstraint:[NSLayoutConstraint constraintWithItem:cellView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:[cellView height]]];
      cellView.frame = NSMakeRect(0, 0, [mModelsTable frame].size.width, [cellView height]);
      [cellView setNeedsLayout:YES];
      [cellView layoutSubtreeIfNeeded];
      return [cellView draggingImageComponents];
    };
  }];
}


#pragma mark NSOutlineViewDelegate


- (NSView*) outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
  NSView* result = nil;
  if ( [item isKindOfClass:[FXModel class]] )
  {
    result = [self prepareCellViewForModel:(FXModel*)item];
  }
  else if ( [item isKindOfClass:[FXModelGroup class]] )
  {
    result = [self prepareCellViewForModelGroup:(FXModelGroup*)item];
  }
  return result;
}


- (NSTableRowView*) outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
  FXLibraryEditorTableRowView *result = [[FXLibraryEditorTableRowView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
  FXAutorelease(result)
  return result;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
  return NO;//[item isKindOfClass:[FXModelGroup class]];
}


- (BOOL) outlineView:(NSOutlineView*)outlineView shouldSelectItem:(id)item
{
  BOOL result = NO;
  @synchronized(self)
  {
    if ( outlineView == mModelsTable )
    {
      if ( [item isKindOfClass:[FXModelGroup class]] )
      {
        result = [(FXModelGroup*)item isMutable];
      }
      else if ( [item isKindOfClass:[FXModel class]] )
      {
        result = YES;
      }
    }
  }
  return result;
}


- (BOOL) outlineView:(NSOutlineView*)outlineView shouldEditTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
  BOOL result = NO;
  @synchronized(self)
  {
    if ( outlineView == mModelsTable )
    {
      if ( [item isKindOfClass:[FXModelGroup class]] )
      {
        result = NO;
      }
      else if ( [item isKindOfClass:[FXModel class]] )
      {
        result = [(FXModel*)item isMutable];
      }
    }
  }
  return result;
}


- (void) outlineViewSelectionDidChange:(NSNotification*)notification
{
  if ( [notification object] == mModelsTable )
  {
    [self handleSelectedItems];
  }
}


- (CGFloat) outlineView:(NSOutlineView*)outlineView heightOfRowByItem:(id)item
{
  if ( [item isKindOfClass:[FXModel class]] )
  {
    mDummyCellView.model = (FXModel*)item;
    return [mDummyCellView height];
  }
  return [outlineView rowHeight];
}


#pragma mark Private


- (void) initializeModelsTable
{
  static const CGFloat skLockColumnWidth = 16.0;
  static const CGFloat skTitleColumnMinWidth = 100.0;

  NSAssert(mModelsTable != nil, @"The table view for displaying models was not created.");
  mModelsTable.headerView = nil;
  mModelsTable.allowsMultipleSelection = YES;
  mModelsTable.allowsEmptySelection = YES;
  mModelsTable.dataSource = self;
  mModelsTable.delegate = self;
  mModelsTable.focusRingType = NSFocusRingTypeNone;
  mModelsTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;

  mModelsTable.doubleAction = @selector(handleOutlineViewDoubleClick:);
  mModelsTable.target = self;

  NSTableColumn* titleTableColumn = [mModelsTable tableColumnWithIdentifier:@"ModelCell"];
  NSAssert(titleTableColumn != nil, @"table column does not exist");
  [titleTableColumn setWidth:mModelsTable.frame.size.width - skLockColumnWidth];
  [titleTableColumn setMinWidth:skTitleColumnMinWidth];
  [titleTableColumn setResizingMask:NSTableColumnAutoresizingMask];
  [mModelsTable setOutlineTableColumn:titleTableColumn];
}


- (void) initializeUI
{
  [self initializeModelsTable];

  NSScrollView* tableScroller = [mModelsTable enclosingScrollView];
  [[tableScroller verticalScroller] setControlSize:NSControlSizeSmall];
  NSAssert([tableScroller horizontalScroller] != nil, @"The horizontal scroller is needed so that all columns are resized correctly");

  NSAssert(mClipView != nil, @"clip view missing from NIB");
  [mClipView setMinDocumentViewWidth:100.0];
  [mClipView setMinDocumentViewHeight:60.0];

  NSAssert(mModelsFolderButton != nil, @"button is missing in NIB");
  mModelsFolderButton.image = [NSImage imageNamed:NSImageNameFolder];
  mModelsFolderButton.toolTip = FXLocalizedString(@"ModelsFolderRevealButtonTooltip");

  [self handleSelectedItems];
}


- (void) updateModelsFromLibraryData
{
  __block NSMutableArray* newModelGroups = [[NSMutableArray alloc] initWithCapacity:VMT_Count];
  [mLibrary iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
    FXModelGroup* groupWrapper = [[FXModelGroup alloc] initWithPersistentGroup:group library:self->mLibrary];
    groupWrapper.name = [FXVoltaLibraryUtilities userVisibleNameForModelGroupOfType:group->modelType];
    [newModelGroups addObject:groupWrapper];
    FXRelease(groupWrapper)
  }];
  [self transitionDisplaySettingsToModelGroups:newModelGroups];
  if ( mUpdateMode == FXLibraryEditorModelsUpdateMode_Generic )
  {
    [self replaceTableContentsWithModelGroups:newModelGroups];
  }
  else
  {
    [self transitionTableContentsToModelGroups:newModelGroups];
    mUpdateMode = FXLibraryEditorModelsUpdateMode_Generic;
  }
  FXRelease(newModelGroups)
  newModelGroups = nil;
}


- (void) replaceTableContentsWithModelGroups:(NSArray*)modelGroups
{
  NSPoint const scrollPoint = [[[mModelsTable enclosingScrollView] contentView] documentVisibleRect].origin;
  NSMutableArray* expandedGroupNames = [NSMutableArray arrayWithCapacity:[mModelGroupWrappers count]];
  for ( FXModelGroup* group in mModelGroupWrappers )
  {
    if ([mModelsTable isItemExpanded:group])
    {
      [expandedGroupNames addObject:[group name]];
    }
  }
  [mModelGroupWrappers setArray:modelGroups];
  [mModelsTable reloadData];
  for ( FXModelGroup* group in mModelGroupWrappers )
  {
    if ( [expandedGroupNames containsObject:[group name]] )
    {
      [mModelsTable expandItem:group];
    }
  }
  [mModelsTable scrollPoint:scrollPoint];
}


- (void) transitionDisplaySettingsToModelGroups:(NSArray*)newModelGroups
{
  for ( FXModelGroup* existingGroup in mModelGroupWrappers )
  {
    for ( FXModelGroup* newGroup in newModelGroups )
    {
      if ( [existingGroup.name isEqualToString:newGroup.name] )
      {
        for ( FXModel* existingModel in existingGroup.models )
        {
          for ( FXModel* newModel in newGroup.models )
          {
            if ( *[existingModel persistentModel] == *[newModel persistentModel] )
            {
              newModel.displaySettings = existingModel.displaySettings;
              break;
            }
          }
        }
        break;
      }
    }
  }
}


- (void) transitionTableContentsToModelGroups:(NSArray*)modelGroups
{
  [mModelsTable beginUpdates];
  if ( mUpdateMode == FXLibraryEditorModelsUpdateMode_AddingItems )
  {
    [self transitionTableContentsByAddingItemsFromModelGroups:modelGroups];
  }
  else if ( mUpdateMode == FXLibraryEditorModelsUpdateMode_RemovingItems )
  {
    [self transitionTableContentsByRemovingItemsNotFoundInModelGroups:modelGroups];
  }
  [mModelsTable endUpdates];
}


- (void) transitionTableContentsByAddingItemsFromModelGroups:(NSArray*)modelGroups
{
  for ( FXModelGroup* existingGroup in mModelGroupWrappers )
  {
    NSMutableIndexSet* indexesOfModelsToBeInserted = [NSMutableIndexSet indexSet];
    for ( FXModelGroup* newGroup in modelGroups )
    {
      if ( [existingGroup.name isEqualToString:newGroup.name] )
      {
        NSInteger indexOfNewModel = -1;
        for ( FXModel* newModel in newGroup.models )
        {
          indexOfNewModel++;
          BOOL foundMatchingExistingModel = NO;
          for ( FXModel* existingModel in existingGroup.models )
          {
            if ( *[newModel persistentModel] == *[existingModel persistentModel] )
            {
              foundMatchingExistingModel = YES;
              break;
            }
          }
          if ( !foundMatchingExistingModel )
          {
            [indexesOfModelsToBeInserted addIndex:indexOfNewModel];
            [existingGroup.models insertObject:newModel atIndex:indexOfNewModel];
          }
        }
        break;
      }
    }
    if ( [indexesOfModelsToBeInserted count] > 0 )
    {
      [mModelsTable insertItemsAtIndexes:indexesOfModelsToBeInserted inParent:existingGroup withAnimation:NSTableViewAnimationEffectFade];
    }
  }
}


- (void) transitionTableContentsByRemovingItemsNotFoundInModelGroups:(NSArray*)modelGroups
{
  // Note: Removing only those items that are visible to the user should be sufficient since the user
  // can not select items if they are not displayed (i.e. inside collapsed parent items) by the table view.
  NSMutableIndexSet* indexesOfGroupItemsToRemove = [NSMutableIndexSet indexSet];
  NSInteger existingGroupIndex = -1;
  for ( FXModelGroup* existingGroup in mModelGroupWrappers )
  {
    existingGroupIndex++;
    FXModelGroup* matchingNewGroup = nil;
    for ( FXModelGroup* newGroup in modelGroups )
    {
      if ( [newGroup.name isEqualToString:existingGroup.name] )
      {
        matchingNewGroup = newGroup;
        break;
      }
    }
    if ( matchingNewGroup != nil )
    {
      if ( [mModelsTable isItemExpanded:existingGroup] )
      {
        NSMutableIndexSet* indexesOfModelItemsToRemove = [NSMutableIndexSet indexSet];
        NSInteger const parentRowIndex = [mModelsTable rowForItem:existingGroup];
        for ( FXModel* existingModel in existingGroup.models )
        {
          BOOL foundMatchingModel = NO;
          for ( FXModel* newModel in matchingNewGroup.models )
          {
            if ( *[existingModel persistentModel] == *[newModel persistentModel] )
            {
              foundMatchingModel = YES;
              break;
            }
          }
          if ( !foundMatchingModel )
          {
            [indexesOfModelItemsToRemove addIndex:([mModelsTable rowForItem:existingModel] - parentRowIndex - 1)];
          }
        }
        if ( [indexesOfModelItemsToRemove count] > 0 )
        {
          [mModelsTable removeItemsAtIndexes:indexesOfModelItemsToRemove inParent:existingGroup withAnimation:NSTableViewAnimationEffectFade];
          [existingGroup.models removeObjectsAtIndexes:indexesOfModelItemsToRemove];
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
    [mModelsTable removeItemsAtIndexes:indexesOfGroupItemsToRemove inParent:nil withAnimation:NSTableViewAnimationEffectFade];
    [mModelGroupWrappers removeObjectsAtIndexes:indexesOfGroupItemsToRemove];
  }
}


- (void) rebuildModelGroupsDataSource
{
  @synchronized(self)
  {
    [mModelsTable setDataSource:nil];
    NSAssert( [mModelGroupWrappers count] == 0, @"This is supposed to be called only once." );
    [mLibrary iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
      FXModelGroup* groupWrapper = [[FXModelGroup alloc] initWithPersistentGroup:group library:self->mLibrary];
      groupWrapper.name = [FXVoltaLibraryUtilities userVisibleNameForModelGroupOfType:group->modelType];
      [mModelGroupWrappers addObject:groupWrapper];
      FXRelease(groupWrapper)
    }];
    [mModelsTable setDataSource:self];
    [mModelsTable reloadData];
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
  [mModelsTable enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
#if 0
    NSView* cellView = [rowView viewAtColumn:0];
    if ( [cellView isKindOfClass:[FXLibraryEditorModelsCellView class]] )
    {
      [(FXLibraryEditorModelsCellView*)cellView setIsSelected:[rowView isSelected]];
    }
#else
    [rowView setNeedsDisplay:YES];
#endif
  }];

  BOOL selectedAModel = NO;
  BOOL selectedAModelGroup = NO;
  BOOL selectedAMutableModel = NO;

  @synchronized(self)
  {
    NSInteger const selectedRow = [mModelsTable selectedRow];
    if ( selectedRow >= 0 )
    {
      id selectedItem = [mModelsTable itemAtRow:selectedRow];
      selectedAModelGroup = [selectedItem isKindOfClass:[FXModelGroup class]];
      selectedAModel = !selectedAModelGroup && [selectedItem isKindOfClass:[FXModel class]];
      selectedAMutableModel = selectedAModel && [(FXModel*)selectedItem isMutable];
    }
  }

  mAddModelButton.enabled = selectedAModelGroup || selectedAModel;
  mRemoveModelsButton.enabled = selectedAMutableModel;
}


- (void) removeSelectedItems
{
  VoltaPTModelPtrSet modelsToBeRemoved = [self persistentModelsForSelectedItemsFromModelsTable];
  VoltaPTModelPtrSet removedModels = [mLibrary removeModels:modelsToBeRemoved];
  if ( !removedModels.empty() )
  {
    mUpdateMode = FXLibraryEditorModelsUpdateMode_RemovingItems;
  }
}


- (VoltaPTModelPtrSet) persistentModelsForSelectedItemsFromModelsTable
{
  VoltaPTModelPtrSet result;
  NSIndexSet* selectedRows = [mModelsTable selectedRowIndexes];
  if ( [selectedRows count] > 0 )
  {
    NSUInteger currentIndex = [selectedRows firstIndex];
    while ( currentIndex != NSNotFound )
    {
      id selectedItem = [mModelsTable itemAtRow:currentIndex];
      if ( [selectedItem isKindOfClass:[FXModel class]] )
      {
        FXModel* selectedModelWrapper = selectedItem;
        if ( [selectedModelWrapper isMutable] )
        {
          result.insert([selectedModelWrapper persistentModel]);
        }
      }
      currentIndex = [selectedRows indexGreaterThanIndex:currentIndex];
    }
  }
  return result;
}


- (NSView*) prepareCellViewForModel:(FXModel*)model
{
  FXLibraryEditorModelsCellView* cellView = [mModelsTable makeViewWithIdentifier:@"ModelCell" owner:self];
  if ( cellView == nil )
  {
    NSRect const dummyFrame = { 0, 0, 100, 100 };
    cellView = [[FXLibraryEditorModelsCellView alloc] initWithFrame:dummyFrame];
    cellView.identifier = @"ModelCell";
    cellView.translatesAutoresizingMaskIntoConstraints = NO;
    FXAutorelease(cellView)
  }
  cellView.isEditable = model.isMutable;
  cellView.showsLockSymbol = !model.isMutable;
  cellView.model = model;
  if ( model.source != nil )
  {
    cellView.showsActionButton = YES;
    cellView.actionButton.target = self;
    cellView.actionButton.action = @selector(handleCellViewActionButton:);
    BOOL const usingCloud = (self.cloudLibraryController != nil) && self.cloudLibraryController.nowUsingCloudLibrary;
    cellView.actionButton.toolTip = usingCloud ? FXLocalizedString(@"Tooltip_ShowSourceFileInCloud") : FXLocalizedString(@"Tooltip_ShowSourceFileInFinder");
  }
  else
  {
    cellView.showsActionButton = NO;
  }
  cellView.heightChangeTarget = self;
  cellView.heightChangeAction = @selector(toggleShowModelProperties:);
  cellView.client = self;
  return cellView;
}


- (NSView*) prepareCellViewForModelGroup:(FXModelGroup*)modelGroup
{
  NSTableCellView* cellView = [mModelsTable makeViewWithIdentifier:@"ModelGroupCell" owner:self];
  if ( cellView == nil )
  {
    NSRect const dummyFrame = { 0, 0, 100, 100 };
    cellView = [[NSTableCellView alloc] initWithFrame:dummyFrame];
    cellView.identifier = @"ModelGroupCell";
    FXAutorelease(cellView)
  }
  cellView.textField.stringValue = [modelGroup name];
  return cellView;
}


- (void) toggleShowModelProperties:(id)sender
{
  NSInteger rowIndex = [mModelsTable rowForView:sender];
  if ( rowIndex >= 0 )
  {
    [mModelsTable noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:(NSUInteger)rowIndex]];
  }
}


- (void) handleCellViewActionButton:(id)sender
{
  NSInteger rowIndex = [mModelsTable rowForView:sender];
  FXModel* model = [mModelsTable itemAtRow:rowIndex];

  if ( (self.cloudLibraryController != nil) && self.cloudLibraryController.nowUsingCloudLibrary )
  {
    [self.cloudLibraryController showContentsOfCloudFolder:VoltaCloudFolderType_LibraryModels];
    [self.cloudLibraryController highlightFiles:@[model.source.lastPathComponent]];
  }
  else
  {
    [FXSystemUtils revealFileAtLocation:model.source];
  }
}


@end
