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

#import "FXLibraryEditorCellView.h"
#import "FXShape.h"
#import "FXShapeView.h"
#import "FXImageUtils.h"
#import "FXViewUtils.h"


static const CGFloat FXLibraryEditorCellViewHeight = 60.0;
static const CGFloat FXLibraryEditorCellViewPropertiesTableHeight = 80.0;

NSString* const FXLibraryEditorCell_PropertiesAreExpanded      = @"FXLibraryEditorCell_PropertiesExpanded";
NSString* const FXLibraryEditorCell_PropertiesHaveBeenEdited   = @"FXLibraryEditorCell_PropertiesEdited";
NSString* const FXLibraryEditorCell_PropertyValuesTableColumnIdentifier = @"Value";
NSString* const FXLibraryEditorCell_PropertyNamesTableColumnIdentifier = @"Name";

@interface FXLibraryEditorCellView () <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate>
@end


@implementation FXLibraryEditorCellView
{
@private
  NSTextField* mPrimaryField;
  NSTextField* mSecondaryField;
  NSTextField* mSinglePropertyField;
  NSTableView* mPropertiesTable;
  NSScrollView* mTableScrollView;
  NSTextField* mPropertiesButtonLabel;
  NSButton* mPropertiesExpanderButton;
  NSButton* mActionButton;
  NSImageView* mLockView;
  BOOL mIsEditable;
  BOOL mPropertiesHaveBeenEdited;
  BOOL mIsPropertiesExpanded;
  BOOL mBeganEditingName;
  BOOL mBeganEditingVendor;
  BOOL mBeganEditingProperty;
  BOOL mHasMultipleProperties;
  NSArray* mPropertyKeys;
}
@synthesize primaryField = mPrimaryField;
@synthesize secondaryField = mSecondaryField;
@synthesize singlePropertyField = mSinglePropertyField;
@synthesize actionButton = mActionButton;
@synthesize isEditable = mIsEditable;


- (id) initWithFrame:(NSRect)frame
{
  if ( (self = [super initWithFrame:frame]) != nil )
  {
    mBeganEditingName = NO;
    mBeganEditingProperty = NO;
    mPropertiesHaveBeenEdited = NO;
    mHasMultipleProperties = YES;
    mIsPropertiesExpanded = NO;
    self.leftIndentation = 0;
    [self buildUI];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mPropertyKeys)
  FXDeallocSuper
}


- (void) setPropertyKeys:(NSArray*)propertyKeys
{
  if ( propertyKeys != mPropertyKeys )
  {
    FXRelease(mPropertyKeys)
    mPropertyKeys = propertyKeys;
    FXRetain(mPropertyKeys)
  }
  mHasMultipleProperties = ([propertyKeys count] > 1);
  BOOL const hasSingleProperty = ([propertyKeys count] == 1);
  mPropertiesExpanderButton.hidden = !mHasMultipleProperties;
  mSinglePropertyField.hidden = !hasSingleProperty;
}


- (void) setShape:(id<FXShape>)newShape
{
  mShapeView.shape = newShape;
}


- (void) setIsEditable:(BOOL)isEditable
{
  mIsEditable = isEditable;
  mPrimaryField.editable = mIsEditable;
  mSecondaryField.editable = mIsEditable;
  mSinglePropertyField.editable = mIsEditable;
}


- (CGFloat) height
{
  CGFloat result = FXLibraryEditorCellViewHeight;
  if ( mIsPropertiesExpanded )
  {
    result += FXLibraryEditorCellViewPropertiesTableHeight;
  }
  return result;
}


- (BOOL) showsLockSymbol
{
  return !mLockView.isHidden;
}


- (void) setShowsLockSymbol:(BOOL)showsLockSymbol
{
  mLockView.hidden = !showsLockSymbol;
}


- (BOOL) showsActionButton
{
  return !mActionButton.isHidden;
}


- (void) setShowsActionButton:(BOOL)showsActionButton
{
  mActionButton.hidden = !showsActionButton;
  mActionButton.enabled = showsActionButton;
}


- (void) updateDisplay
{
  NSNumber* expanded_ = [self valueForDisplaySettingWithName:FXLibraryEditorCell_PropertiesAreExpanded];
  BOOL const expanded = (expanded_ != nil) && [expanded_ boolValue];
  mIsPropertiesExpanded = expanded;
  mPropertiesExpanderButton.state = expanded ? NSOnState : NSOffState;

  NSNumber* edited_ = [self valueForDisplaySettingWithName:FXLibraryEditorCell_PropertiesHaveBeenEdited];
  BOOL const edited = (edited_ != nil) && [edited_ boolValue];
  mPropertiesHaveBeenEdited = edited;
  mPropertiesButtonLabel.hidden = !edited;

  [self updateTableForMode];
  [self layOutUI];
}


- (NSArray*) draggingImageComponents
{
  NSImage* shapeViewImage = [FXViewUtils imageOfView:mShapeView];
  NSDraggingImageComponent* shapeViewDraggingImageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
  shapeViewDraggingImageComponent.contents = shapeViewImage;
  shapeViewDraggingImageComponent.frame = mShapeView.frame;
  NSImage* primaryFieldImage = [FXViewUtils imageOfView:mPrimaryField];
  NSDraggingImageComponent* primaryFieldDraggingImageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentLabelKey];
  primaryFieldDraggingImageComponent.contents = primaryFieldImage;
  primaryFieldDraggingImageComponent.frame = mPrimaryField.frame;
  NSImage* secondaryFieldImage = [FXViewUtils imageOfView:mSecondaryField];
  NSDraggingImageComponent* secondaryFieldDraggingImageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentLabelKey];
  secondaryFieldDraggingImageComponent.contents = secondaryFieldImage;
  secondaryFieldDraggingImageComponent.frame = mSecondaryField.frame;
  return @[ shapeViewDraggingImageComponent, primaryFieldDraggingImageComponent, secondaryFieldDraggingImageComponent ];
}


#pragma mark NSControlTextEditingDelegate


- (void) controlTextDidBeginEditing:(NSNotification*)notification
{
  // The user starts modifying the text field content.
  id notificationObject = [notification object];
  mBeganEditingName = (notificationObject == mPrimaryField);
  mBeganEditingVendor = (notificationObject == mSecondaryField);
  mBeganEditingProperty = (notification.object == mSinglePropertyField);
}


- (void) controlTextDidEndEditing:(NSNotification*)notification
{
  // The user is leaving text edit mode.
  if ( (notification.object == mPrimaryField) && mBeganEditingName )
  {
    // The user actually made changes.
    [self handleNewPrimaryFieldValue:[mPrimaryField stringValue]];
  }
  else if ( (notification.object == mSecondaryField) && mBeganEditingVendor )
  {
    [self handleNewSecondaryFieldValue:[mSecondaryField stringValue]];
  }
  else if ( (notification.object == mSinglePropertyField) && mBeganEditingProperty )
  {
    NSAssert([mPropertyKeys count] == 1, @"This code should execute only if the element has a single property");
    if ( [mPropertyKeys count] > 0 )
    {
      NSString* value = [mSinglePropertyField stringValue];
      NSString* key = [mPropertyKeys lastObject];
      if ( (key != nil) && (value != nil) )
      {
        [self handleNewSinglePropertyFieldValue:value forKey:key];
      }
    }
  }
  mBeganEditingName = NO;
  mBeganEditingProperty = NO;
}


- (BOOL) control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector
{
  BOOL handled = NO;
  if ( textView == mPropertiesTable.currentEditor )
  {
    if ( (commandSelector == @selector(insertTab:))
        || (commandSelector == @selector(insertBacktab:)) )
    {
      NSInteger const lastRow = mPropertiesTable.numberOfRows - 1;
      if ( lastRow > 0 )
      {
        NSInteger const currentRow = mPropertiesTable.editedRow;
        NSInteger const currentColumn = mPropertiesTable.editedColumn;
        NSInteger nextRow = 0;
        if (commandSelector == @selector(insertTab:))
        {
          nextRow = (currentRow < lastRow) ? currentRow + 1 : 0;
        }
        else
        {
          nextRow = (currentRow > 0) ? currentRow - 1 : lastRow;
        }
        [mPropertiesTable editColumn:currentColumn row:nextRow withEvent:nil select:YES];
        handled = YES;
      }
    }
    else if ( commandSelector == @selector(cancelOperation:) )
    {
      [[[mPropertiesTable tableColumnWithIdentifier:FXLibraryEditorCell_PropertyValuesTableColumnIdentifier] dataCell] endEditing:textView];
      handled = YES;
    }
  }
  return handled;
}


#pragma mark NSTableViewDelegate


- (BOOL) tableView:(NSTableView*)tableView shouldEditTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  return self.isEditable;
}


#pragma mark NSTableViewDataSource


- (NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [mPropertyKeys count];
}


- (id) tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  if ( [tableColumn.identifier isEqualToString:FXLibraryEditorCell_PropertyNamesTableColumnIdentifier] )
  {
    return mPropertyKeys[rowIndex];
  }
  else return [self valueOfPropertyForKey:mPropertyKeys[rowIndex]];
}


- (void) tableView:(NSTableView*)tableView setObjectValue:(id)value forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  if ( [value isKindOfClass:[NSString class]] )
  {
    NSString* key = mPropertyKeys[rowIndex];
    NSAssert( key != nil, @"The cached property names should not have changed." );
    if ( key != nil )
    {
      [self setValue:value ofPropertyForKey:key];
      mPropertiesHaveBeenEdited = YES;
      mPropertiesButtonLabel.hidden = NO;
      [self setValue:@YES forDisplaySettingWithName:FXLibraryEditorCell_PropertiesHaveBeenEdited];
    }
  }
}


#pragma mark Subclass Methods


- (NSString*) valueOfPropertyForKey:(id)key
{
  NSAssert(NO, @"Do not use instances of this class. Use a subclass, which implements this method.");
  return nil;
}


- (void) setValue:(NSString*)value ofPropertyForKey:(id)key
{
  NSAssert(NO, @"Do not use instances of this class. Use a subclass, which implements this method.");
}


- (void) handleNewPrimaryFieldValue:(NSString*)value
{
  NSAssert(NO, @"Do not use instances of this class. Use a subclass, which implements this method.");
}


- (void) handleNewSecondaryFieldValue:(NSString*)value
{
  NSAssert(NO, @"Do not use instances of this class. Use a subclass, which implements this method.");
}


- (void) handleNewSinglePropertyFieldValue:(NSString*)value forKey:(id)key
{
  NSAssert(NO, @"Do not use instances of this class. Use a subclass, which implements this method.");
}


- (void) handleApplyPropertyTableChanges
{
  NSAssert(NO, @"Do not use instances of this class. Use a subclass, which implements this method.");
}


- (void) setValue:(id)value forDisplaySettingWithName:(NSString*)settingName
{
  NSAssert(NO, @"Do not use instances of this class. Use a subclass, which implements this method.");
}


- (id) valueForDisplaySettingWithName:(NSString*)settingName
{
  NSAssert(NO, @"Do not use instances of this class. Use a subclass, which implements this method.");
  return nil;
}


#pragma mark Private


static NSRect const dummyRect = { 0, 0, 100, 100 };


- (void) createAndConfigureShapeView
{
  mShapeView = [[FXShapeView alloc] initWithFrame:dummyRect];
  mShapeView.translatesAutoresizingMaskIntoConstraints = NO;
  mShapeView.isBordered = NO;
  mShapeView.scaleMode = FXShapeViewScaleMode_ScaleDownToFit;
  mShapeView.isDraggable = NO;
  mShapeView.verticalAlignment = FXShapeViewVerticalAlignment_Top;
  [self addSubview:mShapeView];
  FXRelease(mShapeView)
}


- (void) createAndConfigureNameField
{
  mPrimaryField = [[NSTextField alloc] initWithFrame:dummyRect];
  mPrimaryField.translatesAutoresizingMaskIntoConstraints = NO;
  mPrimaryField.font = [NSFont fontWithName:@"Arial Black" size:13];
  [(NSTextFieldCell*)mPrimaryField.cell setLineBreakMode:NSLineBreakByTruncatingTail];
  mPrimaryField.textColor = [NSColor blackColor];
  mPrimaryField.bordered = NO;
  mPrimaryField.drawsBackground = NO;
  mPrimaryField.selectable = NO;
  mPrimaryField.editable = NO;
  mPrimaryField.focusRingType = NSFocusRingTypeNone;
  mPrimaryField.bezeled = NO;
  mPrimaryField.allowsEditingTextAttributes = NO;
  mPrimaryField.delegate = self;
  [self addSubview:mPrimaryField];
  FXRelease(mPrimaryField)
}


- (void) createAndConfigureVendorField
{
  mSecondaryField = [[NSTextField alloc] initWithFrame:dummyRect];
  mSecondaryField.translatesAutoresizingMaskIntoConstraints = NO;
  mSecondaryField.font = [NSFont systemFontOfSize:12];
  [(NSTextFieldCell*)mSecondaryField.cell setLineBreakMode:NSLineBreakByTruncatingTail];
  mSecondaryField.textColor = [NSColor colorWithDeviceWhite:0.32 alpha:1.0];
  mSecondaryField.bordered = NO;
  mSecondaryField.drawsBackground = NO;
  mSecondaryField.selectable = NO;
  mSecondaryField.editable = NO;
  mSecondaryField.focusRingType = NSFocusRingTypeNone;
  mSecondaryField.delegate = self;
  [self addSubview:mSecondaryField];
  FXRelease(mSecondaryField)
}


- (void) createAndConfigureSinglePropertyEditField
{
  mSinglePropertyField = [[NSTextField alloc] initWithFrame:dummyRect];
  mSinglePropertyField.translatesAutoresizingMaskIntoConstraints = NO;
  mSinglePropertyField.font = [NSFont fontWithName:@"Arial" size:10];
  mSinglePropertyField.bordered = NO;
  mSinglePropertyField.bezeled = NO;
  mSinglePropertyField.editable = YES;
  mSinglePropertyField.delegate = self;
  mSinglePropertyField.drawsBackground = NO;
  mSinglePropertyField.allowsEditingTextAttributes = NO;
  mSinglePropertyField.focusRingType = NSFocusRingTypeNone;
  [self addSubview:mSinglePropertyField];
  FXRelease(mSinglePropertyField)
}


- (void) createAndConfigurePropertiesButton
{
  mPropertiesExpanderButton = [[NSButton alloc] initWithFrame:dummyRect];
  mPropertiesExpanderButton.translatesAutoresizingMaskIntoConstraints = NO;
#if 1
  mPropertiesExpanderButton.buttonType = NSOnOffButton;
  mPropertiesExpanderButton.bezelStyle = NSDisclosureBezelStyle;
  mPropertiesExpanderButton.imagePosition = NSImageOnly;
#else
  mPropertiesExpanderButton.buttonType = NSMomentaryPushButton;
  mPropertiesExpanderButton.bezelStyle = NSSmallSquareBezelStyle;
  mPropertiesExpanderButton.showsBorderOnlyWhileMouseInside = YES;
  mPropertiesExpanderButton.font = [NSFont systemFontOfSize:9.0];
  mPropertiesExpanderButton.title = FXLocalizedString(@"PaletteCellEditButtonInactiveTitle");
#endif
  mPropertiesExpanderButton.action = @selector(handlePropertiesExpanderButton:);
  mPropertiesExpanderButton.target = self;
  [self addSubview:mPropertiesExpanderButton];
  FXRelease(mPropertiesExpanderButton)
}


- (void) createAndConfigurePropertiesButtonLabel
{
  NSString* messageString = FXLocalizedString(@"PaletteCellPropertiesApplyMessage");
  NSDictionary* messageStringAttributes = @{ NSForegroundColorAttributeName : [NSColor colorWithDeviceWhite:0.5 alpha:1.0] };
  NSAttributedString* messageAttributedString = [[NSAttributedString alloc] initWithString:messageString attributes:messageStringAttributes];
  mPropertiesButtonLabel = [[NSTextField alloc] initWithFrame:dummyRect];
  mPropertiesButtonLabel.translatesAutoresizingMaskIntoConstraints = NO;
  mPropertiesButtonLabel.font = [NSFont systemFontOfSize:9.0];
  mPropertiesButtonLabel.attributedStringValue = messageAttributedString;
  mPropertiesButtonLabel.selectable = NO;
  mPropertiesButtonLabel.editable = NO;
  mPropertiesButtonLabel.bordered = NO;
  mPropertiesButtonLabel.drawsBackground = NO;
  mPropertiesButtonLabel.hidden = YES;
  [self addSubview:mPropertiesButtonLabel];
  FXRelease(mPropertiesButtonLabel)
  FXRelease(messageAttributedString)
}


- (void) createAndConfigurePropertiesTable
{
  NSRect const dummyFrame = {0, 0, 100, 50};
  mPropertiesTable = [[NSTableView alloc] initWithFrame:dummyFrame];
  NSTableColumn* propertyNameColumn = [[NSTableColumn alloc] initWithIdentifier:FXLibraryEditorCell_PropertyNamesTableColumnIdentifier];
  [mPropertiesTable addTableColumn:propertyNameColumn];
  FXRelease(propertyNameColumn)
  NSTextFieldCell* dataCell = [[NSTextFieldCell alloc] initTextCell:@""];
  dataCell.bezeled = NO;
  dataCell.bordered = NO;
  dataCell.editable = NO;
  dataCell.usesSingleLineMode = YES;
  dataCell.usesSingleLineMode = YES;
  dataCell.backgroundColor = [NSColor colorWithDeviceRed:0.7 green:0.74 blue:0.7 alpha:0.60];
  dataCell.drawsBackground = YES;
  dataCell.textColor = [NSColor blackColor];
  [propertyNameColumn setDataCell:dataCell];
  FXRelease(dataCell)

  NSTableColumn* propertyValueColumn = [[NSTableColumn alloc] initWithIdentifier:FXLibraryEditorCell_PropertyValuesTableColumnIdentifier];
  [mPropertiesTable addTableColumn:propertyValueColumn];
  FXRelease(propertyValueColumn)
  dataCell = [[NSTextFieldCell alloc] initTextCell:@""];
  dataCell.type = NSTextCellType;
  dataCell.bezeled = NO;
  dataCell.bordered = NO;
  dataCell.editable = YES;
  dataCell.usesSingleLineMode = YES;
  dataCell.drawsBackground = NO;
  dataCell.focusRingType =  NSFocusRingTypeNone;
  dataCell.textColor = [NSColor blackColor];
  [propertyValueColumn setDataCell:dataCell];
  FXRelease(dataCell)

  mPropertiesTable.translatesAutoresizingMaskIntoConstraints = NO;
  mPropertiesTable.headerView = nil;
  mPropertiesTable.allowsColumnResizing = YES;
  mPropertiesTable.backgroundColor = [NSColor clearColor];
  mPropertiesTable.focusRingType = NSFocusRingTypeNone;
  mPropertiesTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
  mPropertiesTable.gridStyleMask = NSTableViewGridNone;
  mPropertiesTable.intercellSpacing = NSMakeSize( 0, 0 );
  mPropertiesTable.delegate = self;

  mTableScrollView = [[NSScrollView alloc] initWithFrame:dummyFrame];
  [mTableScrollView setDocumentView:mPropertiesTable];
  mTableScrollView.hidden = YES;
  mTableScrollView.borderType = NSLineBorder;
  mTableScrollView.drawsBackground = NO;
  mTableScrollView.hasVerticalScroller = YES;
  mTableScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
  mTableScrollView.translatesAutoresizingMaskIntoConstraints = NO;

  [self addSubview:mTableScrollView];
  FXRelease(mPropertiesTable)
  FXRelease(mTableScrollView)
}


- (void) createAndConfigureLockView
{
  mLockView = [[NSImageView alloc] initWithFrame:dummyRect];
  mLockView.translatesAutoresizingMaskIntoConstraints = NO;
  [mLockView setImage:[[self class] lockImage]];
  [self addSubview:mLockView];
  FXRelease(mLockView)
}


- (void) createAndConfigureActionButton
{
  mActionButton = [[NSButton alloc] initWithFrame:dummyRect];
  mActionButton.translatesAutoresizingMaskIntoConstraints = NO;
  mActionButton.bordered = NO;
  mActionButton.imagePosition = NSImageOnly;
  mActionButton.image = [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
  mActionButton.hidden = YES;
  mActionButton.enabled = NO;
  [self addSubview:mActionButton];
  FXRelease(mActionButton)
}


- (void) buildUI
{
  [self createAndConfigureShapeView];
  [self createAndConfigureNameField];
  [self createAndConfigureVendorField];
  [self createAndConfigurePropertiesButton];
  [self createAndConfigurePropertiesButtonLabel];
  [self createAndConfigureLockView];
  [self createAndConfigureActionButton];
  [self createAndConfigurePropertiesTable];
  [self createAndConfigureSinglePropertyEditField];
  [self layOutUI];
}


- (void) layOutUI
{
  NSDictionary* viewMap = NSDictionaryOfVariableBindings(mShapeView, mPrimaryField, mSecondaryField, mPropertiesExpanderButton, mPropertiesButtonLabel, mTableScrollView, mSinglePropertyField, mLockView, mActionButton);
  NSDictionary* metrics = @{
    @"tableHeight" : (mIsPropertiesExpanded ? @(FXLibraryEditorCellViewPropertiesTableHeight) : @0),
    @"ind" : @(self.leftIndentation),
    @"shapeInd" : @(16 + self.leftIndentation),
    @"fieldInd" : @(80 + self.leftIndentation)
  };
  NSArray* visualFormats = mHasMultipleProperties ?
    @[@"H:|-ind-[mLockView]",
    @"H:|-shapeInd-[mShapeView(==54)]-10-[mPrimaryField]-|",
    @"H:|-fieldInd-[mSecondaryField]-[mActionButton(12)]-|",
    @"H:|-fieldInd-[mPropertiesExpanderButton]-[mPropertiesButtonLabel]",
    @"H:|-fieldInd-[mTableScrollView]-|",
    @"V:|-8-[mLockView]",
    @"V:|-24-[mActionButton]",
    @"V:|-6-[mShapeView(==54)]",
    @"V:|-2-[mPrimaryField(20)]-2-[mSecondaryField(16)]-2-[mPropertiesExpanderButton(16)][mTableScrollView]|",
    @"V:[mPropertiesButtonLabel]-2-[mTableScrollView]|"]
    :
    @[@"H:|-ind-[mLockView]",
    @"H:|-shapeInd-[mShapeView(==54)]-10-[mPrimaryField]-|",
    @"H:|-fieldInd-[mSecondaryField]-[mActionButton(12)]-|",
    @"H:|-fieldInd-[mSinglePropertyField]-|",
    @"H:|-fieldInd-[mTableScrollView]-|",
    @"V:|-8-[mLockView]",
    @"V:|-24-[mActionButton]",
    @"V:|-6-[mShapeView(==54)]",
    @"V:|-2-[mPrimaryField(20)]-2-[mSecondaryField(16)]-2-[mSinglePropertyField]|"];
  [self removeConstraints:[self constraints]];
  for ( NSString* visualFormat in visualFormats )
  {
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:visualFormat options:0 metrics:metrics views:viewMap]];
  }
}


- (void) updateTableForMode
{
  mTableScrollView.hidden = !mIsPropertiesExpanded;
  if ( mIsPropertiesExpanded )
  {
    mPropertiesTable.dataSource = self;
    [mPropertiesTable reloadData];
  }
  else
  {
    mPropertiesButtonLabel.hidden = YES;
    mPropertiesTable.dataSource = nil;
    if ( mPropertiesHaveBeenEdited )
    {
      [self handleApplyPropertyTableChanges];
      mPropertiesHaveBeenEdited = NO;
    }
  }
}


- (void) handlePropertiesExpanderButton:(id)sender
{
  mIsPropertiesExpanded = !mIsPropertiesExpanded;
  [self setValue:@NO forDisplaySettingWithName:FXLibraryEditorCell_PropertiesHaveBeenEdited];
  [self setValue:[NSNumber numberWithBool:mIsPropertiesExpanded] forDisplaySettingWithName:FXLibraryEditorCell_PropertiesAreExpanded];
  [self updateTableForMode];
  [self layOutUI];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  [self.heightChangeTarget performSelector:self.heightChangeAction withObject:self];
#pragma clang diagnostic pop
}


+ (NSImage*) lockImage
{
  static NSImage* sLockImage = nil;
  if ( sLockImage == nil )
  {
    NSImage* lockImage = [NSImage imageNamed:NSImageNameLockLockedTemplate];
    sLockImage = [FXImageUtils newImageFromImage:lockImage withBrightnessChange:0.05];
  }
  return sLockImage;
}

@end
