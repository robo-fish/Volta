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
  FXShapeView* _shapePreviewer;
  NSMutableArray* _pinNodePairs;
  VoltaPTSubcircuitDataPtr _subcircuitData;
  __weak NSUndoManager* _undoManager;
  __weak id<VoltaSubcircuitEditorClient> _client;
}

- (id) init
{
  if ( (self = [super initWithNibName:@"SubcircuitEditor" bundle:[NSBundle bundleForClass:[self class]]]) != nil )
  {
    _pinNodePairs = [[NSMutableArray alloc] init];
    _subcircuitData = [self createDefaultSubcircuitData];
  }
  return self;
}


- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark VoltaSubcircuitEditor


- (VoltaPTSubcircuitDataPtr) subcircuitData;
{
  return _subcircuitData;
}


- (void) setSubcircuitData:(VoltaPTSubcircuitDataPtr)subcircuitData
{
  _subcircuitData = subcircuitData;
  if ( _subcircuitData->pins.size() == 0 )
  {
    VoltaPTSubcircuitDataPtr defaultSubcircuit = [self createDefaultSubcircuitData];
    _subcircuitData->pins = defaultSubcircuit->pins;
    _subcircuitData->externals = defaultSubcircuit->externals;
  }
  [self updateUIFromModel];
}


- (void) setUndoManager:(NSUndoManager*)undoManager
{
  _undoManager = undoManager;
}


- (void) setClient:(id<VoltaSubcircuitEditorClient>)client
{
  _client = client;
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
  NSAssert( sender == _shapeSelector, @"This handler must be called by the shape selector." );
  NSInteger numPins = [[_shapeSelector titleOfSelectedItem] integerValue];
  NSString* shapeType = @""; 
  if ( numPins > 0 )
  {
    shapeType = [NSString stringWithFormat:@"DIP%@", [_shapeSelector titleOfSelectedItem]];
  }
  
  BOOL foundExistingMetaDataItem = NO;
  for( VoltaPTMetaDataItem & metaDataItem : _subcircuitData->metaData )
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
    _subcircuitData->metaData.push_back( { FXVolta_SubcircuitShapeType, (__bridge CFStringRef)shapeType } );
  }
  id<FXShape> newShape = [FXShapeFactory shapeFromMetaData:_subcircuitData->metaData];
  [_shapePreviewer setShape:newShape];
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
  NSAssert( sender == _enablerCheckbox, @"action called by wrong sender" );
  [self createUndoPointForActionName: (_subcircuitData->enabled ? FXLocalizedString(@"Action_disable_subcircuit") : FXLocalizedString(@"Action_enable_subcircuit")) ];
  _subcircuitData->enabled = ([_enablerCheckbox state] == NSOnState);
  [_client subcircuitEditor:self changedActivationState:_subcircuitData->enabled];
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
  NSAssert( _shapeSelector != nil, @"view must exist" );
  [_shapeSelector removeAllItems];
  NSInteger i = skMinPinCount;
  NSMenu* menu = [[NSMenu alloc] initWithTitle:@"DIP Selection"];
  for ( ; i <= skMaxPinCount; i+=2 )
  {
    NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%ld", i] action:NULL keyEquivalent:@""];
    [menuItem setTag:i];
    [menu addItem:menuItem];
    FXRelease(menuItem)
  }
  [_shapeSelector setMenu:menu];
  FXRelease(menu)
  [_shapeSelector setAction:@selector(handleDIPSelection:)];
  [_shapeSelector setTarget:self];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUIShapeWillChange:) name:NSPopUpButtonWillPopUpNotification object:_shapeSelector];
}


- (void) initializeEnablerCheckbox
{
  NSAssert( _enablerCheckbox != nil, @"the view must exist" );
  [_enablerCheckbox setTitle:FXLocalizedString(@"SubcircuitEditorEnablerCheckboxTitle")];
  [_enablerCheckbox setState:(_subcircuitData->enabled ? NSOnState : NSOffState)];
  [_enablerCheckbox setTarget:self];
  [_enablerCheckbox setAction:@selector(handleEnablerCheckbox:)];
}


- (void) initializeShapePreviewer
{
  NSAssert( _shapeContainer != nil, @"the view must exist" );
  _shapePreviewer = [[FX(FXShapeView) alloc] initWithFrame:[_shapeContainer frame]];
  _shapePreviewer.verticalAlignment = FXShapeViewVerticalAlignment_Top;
  _shapePreviewer.scaleMode = FXShapeViewScaleMode_ScaleDownToFit;
  _shapePreviewer.isCached = NO;
  [_shapeContainer setContentView:_shapePreviewer];
  FXRelease(mShapePreviewer)
}


- (void) initializeTitleField
{
  NSAssert( _titleField != nil, @"the view must exist" );
  [[_titleField cell] setPlaceholderString:FXLocalizedString(@"SubcircuitEditorNameFieldPlaceholder")];
  [_titleField setDelegate:self];
}


- (void) initializeVendorField
{
  NSAssert( _vendorField != nil, @"the view must exist" );
  [[_vendorField cell] setPlaceholderString:FXLocalizedString(@"SubcircuitEditorVendorFieldPlaceholder")];
  [_vendorField setDelegate:self];
}


- (void) initializeNodeAssignmentTable
{
  NSAssert( _nodeAssignmentTable != nil, @"the view must exists" );
  [[[_nodeAssignmentTable enclosingScrollView] verticalScroller] setControlSize:NSControlSizeSmall];
  NSTableColumn* pinsColumn = [_nodeAssignmentTable tableColumnWithIdentifier:sNodeAssignmentTable_PinsColumn];
  NSAssert( pinsColumn != nil, @"the table column must exist" );
  [[pinsColumn headerCell] setStringValue:FXLocalizedString(@"SubcircuitEditorNodeAssignmentTablePinsColumnTitle")];
  NSTableColumn* nodesColumn = [_nodeAssignmentTable tableColumnWithIdentifier:sNodeAssignmentTable_NodesColumn];
  NSAssert( nodesColumn != nil, @"the table column must exist" );
  [[nodesColumn headerCell] setStringValue:FXLocalizedString(@"SubcircuitEditorNodeAssignmentTableNodesColumnTitle")];
  [_nodeAssignmentTable setDataSource:self];
  [_nodeAssignmentTable setDelegate:self];
}


- (void) updateUIFromModel
{
  [_titleField setStringValue:(__bridge NSString*)_subcircuitData->name.cfString()];
  [_vendorField setStringValue:(__bridge NSString*)_subcircuitData->vendor.cfString()];
  [self updateUIDIPSelectorFromModel];
  [self updateUIShapePreviewFromModel];
  [self updateUINodeAssignmentsFromModel];
  [self updateUIEnableStateFromModel];
}


- (void) updateUIEnableStateFromModel
{
  BOOL enabled = _subcircuitData->enabled;
  NSCellStateValue newState = (enabled ? NSOnState : NSOffState);
  if ( [_enablerCheckbox state] != newState )
  {
    // This branch is executed when the change was not triggered by the user pressing the checkbox.
    [_enablerCheckbox setState:newState];
    [_client subcircuitEditor:self changedActivationState:enabled];
  }
  [_shapeSelector setEnabled:enabled];
  [_nodeAssignmentTable setEnabled:enabled];
  [_vendorField setEnabled:enabled];
  [_titleField setEnabled:enabled];
  [_shapePreviewer setEnabled:enabled];
}


- (void) updateUIShapePreviewFromModel
{
  if ( _subcircuitData.get() != nullptr )
  {
    id<FXShape> shape = [FXShapeFactory shapeFromMetaData:_subcircuitData->metaData];
    if ( shape == nil )
    {
      shape = [FXShapeFactory shapeWithPersistentShape:_subcircuitData->shape persistentPins:_subcircuitData->pins];
    }
    NSString* label = [NSString stringWithString:(__bridge NSString*)_subcircuitData->name.cfString()];
    _shapePreviewer.shapeAttributes = @{ @"label" : label };
    [_shapePreviewer setShape:shape];
  }
}


- (void) updateUIDIPSelectorFromModel
{
  size_t numDIPLeads = _subcircuitData->pins.size();
  [_shapeSelector selectItemWithTag:numDIPLeads];
}


- (void) updateUINodeAssignmentsFromModel
{
  [_nodeAssignmentTable setDataSource:nil];
  [_pinNodePairs removeAllObjects];
  if ( _subcircuitData.get() != nullptr )
  {
    for( VoltaPTSubcircuitExternal const & external : _subcircuitData->externals )
    {
      FXSubcircuitData_PinNodePair* pinNodePair = [[FXSubcircuitData_PinNodePair alloc] init];
      [pinNodePair setPin:(__bridge NSString*)external.first.cfString()];
      [pinNodePair setNode:(__bridge NSString*)external.second.cfString()];
      [_pinNodePairs addObject:pinNodePair];
      FXRelease(pinNodePair)
    }
    [_pinNodePairs sortUsingSelector:@selector(compare:)];
  }
  [_nodeAssignmentTable setDataSource:self];
}


- (void) updateModelFromUIShape
{
  _subcircuitData->externals.clear();
  _subcircuitData->pins.clear();
  id<FXShape> shape = [_shapePreviewer shape];
  for ( FXShapeConnectionPoint* connectionPoint in [shape connectionPoints] )
  {
    FXString key( (__bridge CFStringRef)[connectionPoint name] );
    _subcircuitData->externals[key] = "";
    _subcircuitData->pins.push_back( VoltaPTPin(key, [connectionPoint location].x, [connectionPoint location].y) );
  }
  // TODO: Convert id<FXShape> to VoltaPTShape when a shape editor is added.
}


- (void) updateModelName:(NSString*)newName
{
  _subcircuitData->name = (__bridge CFStringRef)newName;
  BOOL foundExistingMetaDataItem = NO;
  for( VoltaPTMetaDataItem & metaDataItem : _subcircuitData->metaData )
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
    _subcircuitData->metaData.push_back( { FXVolta_SubcircuitShapeLabel, (__bridge CFStringRef)newName } );
  }
}


- (void) updateModelVendor:(NSString*)newVendor
{
  _subcircuitData->vendor = (__bridge CFStringRef)newVendor;
}


- (void) performUndo:(FXSubcircuitDataCapture*)stateData
{
  { // Setting the redo state
    FXSubcircuitDataCapture* currentState = [[FXSubcircuitDataCapture alloc] initWithSubcircuitData:[self subcircuitData]];
    [_undoManager registerUndoWithTarget:self selector:@selector(performUndo:) object:currentState];
    FXRelease(currentState)
  }
  [self setSubcircuitData:[stateData subcircuitData]];
  [self updateUIFromModel];
}


- (void) createUndoPointForActionName:(NSString*)actionName
{
  FXSubcircuitDataCapture* currentState = [[FXSubcircuitDataCapture alloc] initWithSubcircuitData:[self subcircuitData]];
  [_undoManager registerUndoWithTarget:self selector:@selector(performUndo:) object:currentState];
  [_undoManager setActionName:actionName];
  FXRelease(currentState)
}


#pragma mark NSTableViewDataSource


- (NSInteger) numberOfRowsInTableView:(NSTableView*)tableView
{
  NSAssert( tableView = _nodeAssignmentTable, @"Wrong table!");
  return [_pinNodePairs count];
}

- (id) tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  NSAssert( tableView = _nodeAssignmentTable, @"Wrong table!");
  NSAssert( rowIndex < [_pinNodePairs count], @"node assignment table row index out of bounds" );
  FXSubcircuitData_PinNodePair* pinNodePair = _pinNodePairs[rowIndex];
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
    FXSubcircuitData_PinNodePair* pinNodePair = _pinNodePairs[rowIndex];
    [self createUndoPointForActionName:FXLocalizedString(@"Action_node_assignment")];
    [pinNodePair setNode:anObject];
    _subcircuitData->externals[ (__bridge CFStringRef)[pinNodePair pin] ] = (__bridge CFStringRef)[pinNodePair node]; // store in model
  }
}


#pragma mark NSTableViewDelegate


- (BOOL) tableView:(NSTableView*)tableView shouldEditTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  NSAssert( tableView = _nodeAssignmentTable, @"Wrong table!");
  return [[tableColumn identifier] isEqualToString:sNodeAssignmentTable_NodesColumn];
}


#pragma mark NSControlTextEditingDelegate


- (BOOL) control:(NSControl*)control textShouldBeginEditing:(NSText*)fieldEditor
{
  // Note: this delegate method is also called when editing table text cells.
  NSString* actionName = nil;
  if ( control == _titleField )
  {
    actionName = FXLocalizedString(@"Action_edit_title");
  }
  else if ( control == _vendorField )
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
  if ( control == _titleField )
  {
    [self updateModelName:[_titleField stringValue]];
    [self updateUIShapePreviewFromModel];
  }
  else if ( control == _vendorField )
  {
    [self updateModelVendor:[_vendorField stringValue]];
  }
}


- (BOOL) control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector
{
  BOOL handled = NO;
  if ( textView == _nodeAssignmentTable.currentEditor )
  {
    if ( (commandSelector == @selector(insertTab:))
        || (commandSelector == @selector(insertBacktab:)) )
    {
      NSInteger const lastRow = _nodeAssignmentTable.numberOfRows - 1;
      if ( lastRow > 0 )
      {
        NSInteger const currentRow = _nodeAssignmentTable.editedRow;
        NSInteger const currentColumn = _nodeAssignmentTable.editedColumn;
        NSInteger nextRow = 0;
        if (commandSelector == @selector(insertTab:))
        {
          nextRow = (currentRow < lastRow) ? currentRow + 1 : 0;
        }
        else
        {
          nextRow = (currentRow > 0) ? currentRow - 1 : lastRow;
        }
        [_nodeAssignmentTable editColumn:currentColumn row:nextRow withEvent:nil select:YES];
        handled = YES;
      }
    }
    else if ( commandSelector == @selector(cancelOperation:) )
    {
      [[[_nodeAssignmentTable tableColumnWithIdentifier:sNodeAssignmentTable_NodesColumn] dataCell] endEditing:textView];
      handled = YES;
    }
  }
  return handled;
}


@end
