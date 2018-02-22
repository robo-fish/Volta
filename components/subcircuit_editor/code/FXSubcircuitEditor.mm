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

#import "FXSubcircuitEditor.h"
#import "FXShape.h"
#import "FXShapeView.h"
#import "FXShapeFactory.h"
#import "FXShapeConnectionPoint.h"


static const NSUInteger skMinPinCount = 4;
static const NSUInteger skMaxPinCount = 18;


#pragma mark - FXSubcircuitData_PinNodePair -


@interface FXSubcircuitData_PinNodePair : NSObject
@property (copy) NSString* pin;
@property (copy) NSString* node;
@end

@implementation FXSubcircuitData_PinNodePair
@synthesize pin;
@synthesize node;
- (NSComparisonResult) compare:(FXSubcircuitData_PinNodePair*)otherPair
{
  return [pin compare:[otherPair pin] options:NSNumericSearch];
}
@end


#pragma mark - FXSubcircuitDataCapture -


/// Stores a state of the subcircuit editor. Used for undo.
@interface FXSubcircuitDataCapture : NSObject
{
  @private
  VoltaPTSubcircuitDataPtr mSubcircuitData;
}
- (id) initWithSubcircuitData:(VoltaPTSubcircuitDataPtr)subcircuitData;
- (VoltaPTSubcircuitDataPtr) subcircuitData;
@end


@implementation FXSubcircuitDataCapture

- (id) initWithSubcircuitData:(VoltaPTSubcircuitDataPtr)subcircuitData
{
  self = [super init];
  mSubcircuitData = VoltaPTSubcircuitDataPtr( new VoltaPTSubcircuitData( *subcircuitData ) );
  return self;
}

- (VoltaPTSubcircuitDataPtr) subcircuitData
{
  return mSubcircuitData;
}

@end


#pragma mark - FXSubcircuitEditor -


static NSString* sNodeAssignmentTable_NodesColumn = @"nodes";
static NSString* sNodeAssignmentTable_PinsColumn = @"pins";


@implementation FXSubcircuitEditor
{
@private
  NSTableView* __unsafe_unretained mNodeAssignmentTable;
  NSTextField* __unsafe_unretained mVendorField;
  NSTextField* __unsafe_unretained mTitleField;
  NSPopUpButton* __unsafe_unretained mDIPSelector;
  NSButton* __unsafe_unretained mEnablerCheckbox;
  NSBox* __unsafe_unretained mShapeContainer;
  FXShapeView* mShapePreviewer;
  
  NSMutableArray* mPinNodePairs;
  VoltaPTSubcircuitDataPtr mSubcircuitData;
  
  __weak NSUndoManager* mUndoManager;

  __weak id<VoltaSubcircuitEditorClient> mClient;
}

@synthesize nodeAssignmentTable = mNodeAssignmentTable;
@synthesize vendorField = mVendorField;
@synthesize titleField = mTitleField;
@synthesize shapeSelector = mDIPSelector;
@synthesize enablerCheckbox = mEnablerCheckbox;
@synthesize shapeContainer = mShapeContainer;


- (id) init
{
  if ( (self = [super initWithNibName:@"SubcircuitEditor" bundle:[NSBundle bundleForClass:[self class]]]) != nil )
  {
    mPinNodePairs = [[NSMutableArray alloc] init];
    mSubcircuitData = [self createDefaultSubcircuitData];
  }
  return self;
}


- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  FXRelease(mPinNodePairs)
  FXDeallocSuper
}


#pragma mark VoltaSubcircuitEditor


- (VoltaPTSubcircuitDataPtr) subcircuitData;
{
  return mSubcircuitData;
}


- (void) setSubcircuitData:(VoltaPTSubcircuitDataPtr)subcircuitData
{
  mSubcircuitData = subcircuitData;
  if ( mSubcircuitData->pins.size() == 0 )
  {
    VoltaPTSubcircuitDataPtr defaultSubcircuit = [self createDefaultSubcircuitData];
    mSubcircuitData->pins = defaultSubcircuit->pins;
    mSubcircuitData->externals = defaultSubcircuit->externals;
  }
  [self updateUIFromModel];
}


- (void) setUndoManager:(NSUndoManager*)undoManager
{
  mUndoManager = undoManager;
}


- (void) setClient:(id<VoltaSubcircuitEditorClient>)client
{
  mClient = client;
}


- (CGSize) minimumViewSize
{
  return CGSizeMake(170, 362);
}


#pragma mark NSObject overrides


- (void) awakeFromNib
{
  [self initializeUI];
  [self updateUIFromModel];
}


#pragma mark Private


- (VoltaPTSubcircuitDataPtr) createDefaultSubcircuitData
{
  VoltaPTSubcircuitDataPtr defaultSubcircuit( new VoltaPTSubcircuitData );
  defaultSubcircuit = VoltaPTSubcircuitDataPtr( new VoltaPTSubcircuitData );
  defaultSubcircuit->enabled = false;
  defaultSubcircuit->labelPosition = VoltaPTLabelPosition::Top;
  defaultSubcircuit->pins = {
    VoltaPTPin("1", -28, 14),
    VoltaPTPin("2", -28, 0),
    VoltaPTPin("3", -28, -14),
    VoltaPTPin("4",  28, 14),
    VoltaPTPin("5",  28, 0),
    VoltaPTPin("6",  28, -14) };
  defaultSubcircuit->externals["1"] = "";
  defaultSubcircuit->externals["2"] = "";
  defaultSubcircuit->externals["3"] = "";
  defaultSubcircuit->externals["4"] = "";
  defaultSubcircuit->externals["5"] = "";
  defaultSubcircuit->externals["6"] = "";
  defaultSubcircuit->metaData = {
    { "FXVolta_SubcircuitShapeType", "DIP6" },
    { "FXVolta_SubcircuitShapeLabel", "" } };
  return defaultSubcircuit;
}


- (void) handleDIPSelection:(id)sender
{
  NSAssert( sender == mDIPSelector, @"This handler must be called by the shape selector." );
  NSInteger numPins = [[mDIPSelector titleOfSelectedItem] integerValue];
  NSString* shapeType = @""; 
  if ( numPins > 0 )
  {
    shapeType = [NSString stringWithFormat:@"DIP%@", [mDIPSelector titleOfSelectedItem]];
  }
  
  BOOL foundExistingMetaDataItem = NO;
  for( VoltaPTMetaDataItem & metaDataItem : mSubcircuitData->metaData )
  {
    if ( metaDataItem.first == FXVolta_SubcircuitShapeType )
    {
      metaDataItem.second = (__bridge CFStringRef)shapeType;
      foundExistingMetaDataItem = YES;
      break;
    }
  }
  if ( !foundExistingMetaDataItem )
  {
    mSubcircuitData->metaData.push_back( { FXVolta_SubcircuitShapeType, (__bridge CFStringRef)shapeType } );
  }
  id<FXShape> newShape = [FXShapeFactory shapeFromMetaData:mSubcircuitData->metaData];
  [mShapePreviewer setShape:newShape];
  [self handleUIShapeDidChange:self];
}


- (void) handleUIShapeWillChange:(NSNotification*)notification
{
  [self createUndoPointForActionName:FXLocalizedString(@"Action_change_shape")];
}


- (void) handleUIShapeDidChange:(id)sender
{
  [self updateModelFromUIShape];    
  [self updateUINodeAssignmentsFromModel];
}


- (void) handleEnablerCheckbox:(id)sender
{
  NSAssert( sender == mEnablerCheckbox, @"action called by wrong sender" );
  [self createUndoPointForActionName: (mSubcircuitData->enabled ? FXLocalizedString(@"Action_disable_subcircuit") : FXLocalizedString(@"Action_enable_subcircuit")) ];
  mSubcircuitData->enabled = ([mEnablerCheckbox state] == NSOnState);
  [mClient subcircuitEditor:self changedActivationState:mSubcircuitData->enabled];
  [self updateUIEnableStateFromModel];
}


- (void) initializeUI
{
  [self initializeEnablerCheckbox];
  [self initializeTitleField];
  [self initializeVendorField];
  [self initializeDIPSelector];
  [self initializeShapePreviewer];
  [self initializeNodeAssignmentTable];
}


- (void) initializeDIPSelector
{
  NSAssert( mDIPSelector != nil, @"view must exist" );
  [mDIPSelector removeAllItems];
  NSInteger i = skMinPinCount;
  NSMenu* menu = [[NSMenu alloc] initWithTitle:@"DIP Selection"];
  for ( ; i <= skMaxPinCount; i+=2 )
  {
    NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%ld", i] action:NULL keyEquivalent:@""];
    [menuItem setTag:i];
    [menu addItem:menuItem];
    FXRelease(menuItem)
  }
  [mDIPSelector setMenu:menu];
  FXRelease(menu)
  [mDIPSelector setAction:@selector(handleDIPSelection:)];
  [mDIPSelector setTarget:self];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUIShapeWillChange:) name:NSPopUpButtonWillPopUpNotification object:mDIPSelector];
}


- (void) initializeEnablerCheckbox
{
  NSAssert( mEnablerCheckbox != nil, @"the view must exist" );
  [mEnablerCheckbox setTitle:FXLocalizedString(@"SubcircuitEditorEnablerCheckboxTitle")];
  [mEnablerCheckbox setState:(mSubcircuitData->enabled ? NSOnState : NSOffState)];
  [mEnablerCheckbox setTarget:self];
  [mEnablerCheckbox setAction:@selector(handleEnablerCheckbox:)];
}


- (void) initializeShapePreviewer
{
  NSAssert( mShapeContainer != nil, @"the view must exist" );
  mShapePreviewer = [[FX(FXShapeView) alloc] initWithFrame:[mShapeContainer frame]];
  mShapePreviewer.verticalAlignment = FXShapeViewVerticalAlignment_Top;
  mShapePreviewer.scaleMode = FXShapeViewScaleMode_ScaleDownToFit;
  mShapePreviewer.isCached = NO;
  [mShapeContainer setContentView:mShapePreviewer];
  FXRelease(mShapePreviewer)
}


- (void) initializeTitleField
{
  NSAssert( mTitleField != nil, @"the view must exist" );
  [[mTitleField cell] setPlaceholderString:FXLocalizedString(@"SubcircuitEditorNameFieldPlaceholder")];
  [mTitleField setDelegate:self];
}


- (void) initializeVendorField
{
  NSAssert( mVendorField != nil, @"the view must exist" );
  [[mVendorField cell] setPlaceholderString:FXLocalizedString(@"SubcircuitEditorVendorFieldPlaceholder")];
  [mVendorField setDelegate:self];
}


- (void) initializeNodeAssignmentTable
{
  NSAssert( mNodeAssignmentTable != nil, @"the view must exists" );
  [[[mNodeAssignmentTable enclosingScrollView] verticalScroller] setControlSize:NSControlSizeSmall];
  NSTableColumn* pinsColumn = [mNodeAssignmentTable tableColumnWithIdentifier:sNodeAssignmentTable_PinsColumn];
  NSAssert( pinsColumn != nil, @"the table column must exist" );
  [[pinsColumn headerCell] setStringValue:FXLocalizedString(@"SubcircuitEditorNodeAssignmentTablePinsColumnTitle")];
  NSTableColumn* nodesColumn = [mNodeAssignmentTable tableColumnWithIdentifier:sNodeAssignmentTable_NodesColumn];
  NSAssert( nodesColumn != nil, @"the table column must exist" );
  [[nodesColumn headerCell] setStringValue:FXLocalizedString(@"SubcircuitEditorNodeAssignmentTableNodesColumnTitle")];
  [mNodeAssignmentTable setDataSource:self];
  [mNodeAssignmentTable setDelegate:self];
}


- (void) updateUIFromModel
{
  [mTitleField setStringValue:(__bridge NSString*)mSubcircuitData->name.cfString()];
  [mVendorField setStringValue:(__bridge NSString*)mSubcircuitData->vendor.cfString()];
  [self updateUIDIPSelectorFromModel];
  [self updateUIShapePreviewFromModel];
  [self updateUINodeAssignmentsFromModel];
  [self updateUIEnableStateFromModel];
}


- (void) updateUIEnableStateFromModel
{
  BOOL enabled = mSubcircuitData->enabled;
  NSCellStateValue newState = (enabled ? NSOnState : NSOffState);
  if ( [mEnablerCheckbox state] != newState )
  {
    // This branch is executed when the change was not triggered by the user pressing the checkbox.
    [mEnablerCheckbox setState:newState];
    [mClient subcircuitEditor:self changedActivationState:enabled];
  }
  [mDIPSelector setEnabled:enabled];
  [mNodeAssignmentTable setEnabled:enabled];
  [mVendorField setEnabled:enabled];
  [mTitleField setEnabled:enabled];
  [mShapePreviewer setEnabled:enabled];
}


- (void) updateUIShapePreviewFromModel
{
  if ( mSubcircuitData.get() != nullptr )
  {
    id<FXShape> shape = [FXShapeFactory shapeFromMetaData:mSubcircuitData->metaData];
    if ( shape == nil )
    {
      shape = [FXShapeFactory shapeWithPersistentShape:mSubcircuitData->shape persistentPins:mSubcircuitData->pins];
    }
    NSString* label = [NSString stringWithString:(__bridge NSString*)mSubcircuitData->name.cfString()];
    mShapePreviewer.shapeAttributes = @{ @"label" : label };
    [mShapePreviewer setShape:shape];
  }
}


- (void) updateUIDIPSelectorFromModel
{
  size_t numDIPLeads = mSubcircuitData->pins.size();
  [mDIPSelector selectItemWithTag:numDIPLeads];
}


- (void) updateUINodeAssignmentsFromModel
{
  [mNodeAssignmentTable setDataSource:nil];
  [mPinNodePairs removeAllObjects];
  if ( mSubcircuitData.get() != nullptr )
  {
    for( VoltaPTSubcircuitExternal const & external : mSubcircuitData->externals )
    {
      FXSubcircuitData_PinNodePair* pinNodePair = [[FXSubcircuitData_PinNodePair alloc] init];
      [pinNodePair setPin:(__bridge NSString*)external.first.cfString()];
      [pinNodePair setNode:(__bridge NSString*)external.second.cfString()];
      [mPinNodePairs addObject:pinNodePair];
      FXRelease(pinNodePair)
    }
    [mPinNodePairs sortUsingSelector:@selector(compare:)];
  }
  [mNodeAssignmentTable setDataSource:self];
}


- (void) updateModelFromUIShape
{
  mSubcircuitData->externals.clear();
  mSubcircuitData->pins.clear();
  id<FXShape> shape = [mShapePreviewer shape];
  for ( FXShapeConnectionPoint* connectionPoint in [shape connectionPoints] )
  {
    FXString key( (__bridge CFStringRef)[connectionPoint name] );
    mSubcircuitData->externals[key] = "";
    mSubcircuitData->pins.push_back( VoltaPTPin(key, [connectionPoint location].x, [connectionPoint location].y) );
  }
  // TODO: Convert id<FXShape> to VoltaPTShape when a shape editor is added.
}


- (void) updateModelName:(NSString*)newName
{
  mSubcircuitData->name = (__bridge CFStringRef)newName;
  BOOL foundExistingMetaDataItem = NO;
  for( VoltaPTMetaDataItem & metaDataItem : mSubcircuitData->metaData )
  {
    if ( metaDataItem.first == FXVolta_SubcircuitShapeLabel )
    {
      metaDataItem.second = (__bridge CFStringRef)newName;
      foundExistingMetaDataItem = YES;
      break;
    }
  }
  if ( !foundExistingMetaDataItem )
  {
    mSubcircuitData->metaData.push_back( { FXVolta_SubcircuitShapeLabel, (__bridge CFStringRef)newName } );
  }
}


- (void) updateModelVendor:(NSString*)newVendor
{
  mSubcircuitData->vendor = (__bridge CFStringRef)newVendor;
}


- (void) performUndo:(FXSubcircuitDataCapture*)stateData
{
  { // Setting the redo state
    FXSubcircuitDataCapture* currentState = [[FXSubcircuitDataCapture alloc] initWithSubcircuitData:[self subcircuitData]];
    [mUndoManager registerUndoWithTarget:self selector:@selector(performUndo:) object:currentState];
    FXRelease(currentState)
  }
  [self setSubcircuitData:[stateData subcircuitData]];
  [self updateUIFromModel];
}


- (void) createUndoPointForActionName:(NSString*)actionName
{
  FXSubcircuitDataCapture* currentState = [[FXSubcircuitDataCapture alloc] initWithSubcircuitData:[self subcircuitData]];
  [mUndoManager registerUndoWithTarget:self selector:@selector(performUndo:) object:currentState];
  [mUndoManager setActionName:actionName];
  FXRelease(currentState)
}


#pragma mark NSTableViewDataSource


- (NSInteger) numberOfRowsInTableView:(NSTableView*)tableView
{
  NSAssert( tableView = mNodeAssignmentTable, @"Wrong table!");
  return [mPinNodePairs count];
}

- (id) tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  NSAssert( tableView = mNodeAssignmentTable, @"Wrong table!");
  NSAssert( rowIndex < [mPinNodePairs count], @"node assignment table row index out of bounds" );
  FXSubcircuitData_PinNodePair* pinNodePair = mPinNodePairs[rowIndex];
  if ( [[tableColumn identifier] isEqualToString:sNodeAssignmentTable_PinsColumn] )
  {
    return pinNodePair.pin;
  }
  else // if ( [[tableColumn identifier] isEqualToString:sNodeAssignmentTable_NodesColumn] )
  {
    return pinNodePair.node;
  }
}

- (void) tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  if ( [[tableColumn identifier] isEqualToString:sNodeAssignmentTable_NodesColumn] )
  {
    NSAssert( [anObject isKindOfClass:[NSString class]], @"The node value must be NSString." );
    FXSubcircuitData_PinNodePair* pinNodePair = mPinNodePairs[rowIndex];
    [self createUndoPointForActionName:FXLocalizedString(@"Action_node_assignment")];
    [pinNodePair setNode:anObject];
    mSubcircuitData->externals[ (__bridge CFStringRef)[pinNodePair pin] ] = (__bridge CFStringRef)[pinNodePair node]; // store in model
  }
}


#pragma mark NSTableViewDelegate


- (BOOL) tableView:(NSTableView*)tableView shouldEditTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  NSAssert( tableView = mNodeAssignmentTable, @"Wrong table!");
  return [[tableColumn identifier] isEqualToString:sNodeAssignmentTable_NodesColumn];
}


#pragma mark NSControlTextEditingDelegate


- (BOOL) control:(NSControl*)control textShouldBeginEditing:(NSText*)fieldEditor
{
  // Note: this delegate method is also called when editing table text cells.
  NSString* actionName = nil;
  if ( control == mTitleField )
  {
    actionName = FXLocalizedString(@"Action_edit_title");
  }
  else if ( control == mVendorField )
  {
    actionName = FXLocalizedString(@"Action_edit_vendor");
  }
  if ( actionName != nil )
  {
    [self createUndoPointForActionName:actionName];
  }
  return YES;
}


- (void) controlTextDidChange:(NSNotification*)notification
{
  NSControl* control = [notification object];
  if ( control == mTitleField )
  {
    [self updateModelName:[mTitleField stringValue]];
    [self updateUIShapePreviewFromModel];
  }
  else if ( control == mVendorField )
  {
    [self updateModelVendor:[mVendorField stringValue]];
  }
}


- (BOOL) control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector
{
  BOOL handled = NO;
  if ( textView == mNodeAssignmentTable.currentEditor )
  {
    if ( (commandSelector == @selector(insertTab:))
        || (commandSelector == @selector(insertBacktab:)) )
    {
      NSInteger const lastRow = mNodeAssignmentTable.numberOfRows - 1;
      if ( lastRow > 0 )
      {
        NSInteger const currentRow = mNodeAssignmentTable.editedRow;
        NSInteger const currentColumn = mNodeAssignmentTable.editedColumn;
        NSInteger nextRow = 0;
        if (commandSelector == @selector(insertTab:))
        {
          nextRow = (currentRow < lastRow) ? currentRow + 1 : 0;
        }
        else
        {
          nextRow = (currentRow > 0) ? currentRow - 1 : lastRow;
        }
        [mNodeAssignmentTable editColumn:currentColumn row:nextRow withEvent:nil select:YES];
        handled = YES;
      }
    }
    else if ( commandSelector == @selector(cancelOperation:) )
    {
      [[[mNodeAssignmentTable tableColumnWithIdentifier:sNodeAssignmentTable_NodesColumn] dataCell] endEditing:textView];
      handled = YES;
    }
  }
  return handled;
}


@end
