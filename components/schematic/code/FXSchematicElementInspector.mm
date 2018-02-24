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

#import "FXSchematicElementInspector.h"
#import "FXSchematicPropertiesTableView.h"
#import "VoltaSchematicElement.h"
#import "VoltaSchematic.h"
#import <VoltaCore/VoltaLibraryProtocol.h>
#import "FXVoltaLibraryUtilities.h"
#import "FXSchematicUndoManager.h"
#import "FXPositionSelectorView.h"
#import "FXSchematicInspectorUtilities.h"
#import "FXTableView.h"
#import "FXModel.h"
#import "FXVoltaCircuitDomainAgent.h"
#include <math.h>
#include <limits>

#define MODEL_CHOOSER_MENU_IS_PULL_DOWN (0)

@implementation FXSchematicElementInspector
{
@private
  NSMutableSet* mInspectables;          ///< current inspected set of schematic elements
  
  /// Set of inspected elements which share one or more property.
  NSMutableSet* mElementsWithCommonProperties;
  
  /// Stores the properties of both the element and its model.
  /// Used to fill the properties table if mShowModelDefaultProperties == YES
  NSMutableArray* mPropertyWrappers;
  
  NSTextField* mElementNameField;
  FXSchematicPropertiesTableView* mPropertiesTableView;
  FXPositionSelectorView* mPositionSelectorView;
  NSPopUpButton* mModelChooser;

  /// Maps menu item titles (in the chooser menu) to FXModel instances
  NSMutableDictionary* mModelChooserModelDictionary;
}


- (id) init
{
  self = [super initWithNibName:nil bundle:nil];
  if ( self != nil )
  {
    mInspectables = [[NSMutableSet alloc] initWithCapacity:32];
    mElementsWithCommonProperties = [[NSMutableSet alloc] initWithCapacity:32];
    mPropertyWrappers = [[NSMutableArray alloc] init];
    mModelChooserModelDictionary = [[NSMutableDictionary alloc] init];
  }
  return self;
}


- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  FXRelease(mModelChooserModelDictionary)
  FXRelease(mInspectables)
  FXRelease(mPropertyWrappers)
  FXRelease(mElementsWithCommonProperties)
  FXDeallocSuper
}


#pragma mark Public


- (void) loadView
{
  NSView* inspectorView = [self newInspectorView];
  [self setView:inspectorView];
  FXRelease(inspectorView)
}


- (void) inspect:(NSSet*)inspectedElements
{
  @synchronized(self)
  {
    // The set of inspected elements may not have changed.
    // This is the case if the method is called to update the properties table.
    if ( mInspectables != inspectedElements )
    {
      [mInspectables setSet:inspectedElements];
    }

    [self updateElementNameField];
    [self updateDisplayedProperties];
    [self updateModelChooserMenu];
    [self updateLabelPositionIndicator];
  }
  [mPropertiesTableView reloadData];
}


- (BOOL) isInspecting
{
  return [mInspectables count] > 0;
}


- (void) rotateInspectedElementsPlus90:(id)sender
{
  [self rotateInspectedElements:M_PI_2];
}

- (void) rotateInspectedElementsMinus90:(id)sender
{
  [self rotateInspectedElements:-M_PI_2];
}

- (void) flipInspectedElementsVertically:(id)sender
{
  // Flipping vertically is like flipping horizontally plus turning 180 degrees.
  [self flipInspectedElementsHorizontallyAndRotate:M_PI];
}

- (void) flipInspectedElementsHorizontally:(id)sender
{
  [self flipInspectedElementsHorizontallyAndRotate:0];
}


#pragma mark NSControlTextEditingDelegate


- (BOOL) control:(NSControl*)control textShouldEndEditing:(NSText*)fieldEditor
{
  if ( control == mElementNameField )
  {
    if ( [mInspectables count] == 1 )
    {
      NSString* proposedName = [fieldEditor string];
      [self changeElementName:proposedName];
    }
  }
  return YES;
}


#pragma mark NSTableViewDataSource


- (NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView
{
  NSAssert( aTableView == mPropertiesTableView, @"expected another table view" );
  return [mPropertyWrappers count];
}


- (id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
  NSAssert( aTableView == mPropertiesTableView, @"expected another table view" );
  if ( rowIndex < [mPropertyWrappers count] )
  {
    if ( [(NSString*)[aTableColumn identifier] isEqualToString:FXSchematicPropertiesTableNamesColumnIdentifier] )
    {
      return [(FXSchematicPropertyWrapper*)(mPropertyWrappers[rowIndex]) name];
    }
    else if ( [(NSString*)[aTableColumn identifier] isEqualToString:FXSchematicPropertiesTableValuesColumnIdentifier] )
    {
      FXSchematicPropertyWrapper* propertyWrapper = mPropertyWrappers[rowIndex];
      if ( [propertyWrapper hasMultipleValues] )
      {
        return FXLocalizedString(@"Multiple values");
      }
      if ( [propertyWrapper value] == nil )
      {
        return [propertyWrapper defaultValue];
      }
      return [propertyWrapper value];
    }
  }
  return nil;
}


- (void) tableView:(NSTableView*)aTableView
    setObjectValue:(id)valueObject
    forTableColumn:(NSTableColumn*)aTableColumn
               row:(NSInteger)rowIndex
{
  if ( [[aTableColumn identifier] isEqualToString:FXSchematicPropertiesTableValuesColumnIdentifier] )
  {
    NSAssert( rowIndex >= 0, @"Invalid table row index" );
    if ( rowIndex < [mPropertyWrappers count] )
    {
      NSString* value = nil;
      if ( [valueObject isKindOfClass:[NSString class]] )
      {
        value = valueObject;
      }
      else if ( [valueObject isKindOfClass:[NSNumber class]] )
      {
        value = [(NSNumber*)valueObject stringValue];
      }
      if ( ![value isEqualToString:FXLocalizedString(@"Multiple values")] )
      {
        [self setValue:value ofPropertyNamed:[(FXSchematicPropertyWrapper*)(mPropertyWrappers[rowIndex]) name]];
      }
    }
  }
}


#pragma mark NSTableViewDelegate


- (BOOL) tableView:(NSTableView*)aTableView shouldEditTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  return [[tableColumn identifier] isEqualToString:FXSchematicPropertiesTableValuesColumnIdentifier] ? YES : NO;
}


#pragma mark NSControlTextEditingDelegate


- (BOOL) control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector
{
  BOOL handled = NO;
  if ( textView == mPropertiesTableView.currentEditor )
  {
    if ( (commandSelector == @selector(insertTab:))
      || (commandSelector == @selector(insertBacktab:)) )
    {
      NSInteger const lastRow = mPropertiesTableView.numberOfRows - 1;
      if ( lastRow > 0 )
      {
        NSInteger const currentRow = mPropertiesTableView.editedRow;
        NSInteger const currentColumn = mPropertiesTableView.editedColumn;
        NSInteger nextRow = 0;
        if (commandSelector == @selector(insertTab:))
        {
          nextRow = (currentRow < lastRow) ? currentRow + 1 : 0;
        }
        else
        {
          nextRow = (currentRow > 0) ? currentRow - 1 : lastRow;
        }
        [mPropertiesTableView editColumn:currentColumn row:nextRow withEvent:nil select:YES];
        handled = YES;
      }
    }
    else if ( commandSelector == @selector(cancelOperation:) )
    {
      [[[mPropertiesTableView tableColumnWithIdentifier:FXSchematicPropertiesTableValuesColumnIdentifier] dataCell] endEditing:textView];
      handled = YES;
    }
  }
  return handled;
}


#pragma mark Private


- (NSView*) newInspectorView
{
  static const CGFloat kHeight = 200.0;
  static const CGFloat kWidth = 200.0;
  static const CGFloat kHMargin = 10.0;
  static const CGFloat kVMargin = 5.0; FXIssue(131)

  CGFloat currentPosY = 0;

  const CGFloat kWidth_ElementNameField = 120.0;
  const CGFloat kHeight_ElementNameField = 18.0;
  const CGFloat kPosX_ElementNameField = 0;
  const CGFloat kPosY_ElementNameField = kHeight - kHeight_ElementNameField;

  currentPosY = kPosY_ElementNameField;

  const CGFloat kSize_PositionSelector = 32.0;
  const CGFloat kPosX_PositionSelector = 4.0;
  const CGFloat kPosY_PositionSelector = currentPosY - kVMargin - kSize_PositionSelector;

  currentPosY = kPosY_PositionSelector;

  const CGFloat kSize_RotateLeft = 24.0;
  const CGFloat kPosX_RotateLeft = kPosX_PositionSelector + kSize_PositionSelector + kHMargin;
  const CGFloat kPosY_RotateLeft = currentPosY + 4.0;

  const CGFloat kSize_RotateRight = kSize_RotateLeft;
  const CGFloat kPosX_RotateRight = kPosX_RotateLeft + kSize_RotateLeft + kHMargin;
  const CGFloat kPosY_RotateRight = kPosY_RotateLeft;

  const CGFloat kSize_FlipHorizontally = kSize_RotateLeft;
  const CGFloat kPosX_FlipHorizontally = kPosX_RotateRight + kSize_RotateRight + kHMargin;
  const CGFloat kPosY_FlipHorizontally = kPosY_RotateLeft;

  const CGFloat kSize_FlipVertically = kSize_RotateLeft;
  const CGFloat kPosX_FlipVertically = kPosX_FlipHorizontally + kSize_FlipHorizontally + kHMargin;
  const CGFloat kPosY_FlipVertically = kPosY_RotateLeft;

  const CGFloat kWidth_ModelChooser = kWidth;
  const CGFloat kHeight_ModelChooser = 24;
  const CGFloat kPosX_ModelChooser = 0;
  const CGFloat kPosY_ModelChooser = currentPosY - kVMargin - kHeight_ModelChooser;

  currentPosY = kPosY_ModelChooser;

  const CGFloat kPosX_PropertiesTable = 0;
  const CGFloat kPosY_PropertiesTable = 0;
  const CGFloat kWidth_PropertiesTable = kWidth;
  const CGFloat kHeight_PropertiesTable = currentPosY;

  ////////////////////////////////////////////////////////////////////////////

  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  NSString* bundleResourcePath = [bundle resourcePath];
  NSAssert( bundleResourcePath != nil, @"No resource path for bundle exists." );

  NSView* inspectorView = [[NSView alloc] initWithFrame:NSMakeRect(0,0,kWidth,kHeight)];
  [inspectorView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];

  const NSRect kElementNameFieldFrame = NSMakeRect(kPosX_ElementNameField, kPosY_ElementNameField, kWidth_ElementNameField, kHeight_ElementNameField);
  mElementNameField = [[NSTextField alloc] initWithFrame:kElementNameFieldFrame];
  [mElementNameField setEditable:YES];
  [mElementNameField setFocusRingType:NSFocusRingTypeNone];
  [mElementNameField setSelectable:YES];
  [mElementNameField setBordered:NO];
  [mElementNameField setBezeled:NO];
  [mElementNameField setDrawsBackground:NO];
  [mElementNameField setStringValue:@""];
  [[mElementNameField cell] setPlaceholderString:FXLocalizedString(@"No name")];
  [mElementNameField setAllowsEditingTextAttributes:NO];
  [mElementNameField setFont:[NSFont fontWithName:@"Lucida Grande" size:14.0]];
  [mElementNameField setAutoresizingMask:(NSViewMinYMargin | NSViewMaxXMargin)];
  [mElementNameField setDelegate:self];
  [inspectorView addSubview:mElementNameField];
  FXRelease(mElementNameField)

  const NSRect kPositionSelectorFrame = NSMakeRect(kPosX_PositionSelector, kPosY_PositionSelector, kSize_PositionSelector, kSize_PositionSelector);
  mPositionSelectorView = [[FX(FXPositionSelectorView) alloc] initWithFrame:kPositionSelectorFrame];
  [mPositionSelectorView setAction:@selector(changeLabelPosition:)];
  [mPositionSelectorView setTarget:self];
  [mPositionSelectorView setAutoresizingMask:(NSViewMinYMargin | NSViewMaxXMargin)];
  [inspectorView addSubview:mPositionSelectorView];
  FXRelease(mPositionSelectorView)

  const NSRect kRotateLeftButtonFrame = NSMakeRect(kPosX_RotateLeft, kPosY_RotateLeft, kSize_RotateLeft, kSize_RotateLeft);
  NSButton* rotateLeftButton = [[NSButton alloc] initWithFrame:kRotateLeftButtonFrame];
  [rotateLeftButton setBordered:NO];
  [rotateLeftButton setAutoresizingMask:(NSViewMinYMargin | NSViewMaxXMargin)];
  NSString* rotateLeftImageFilePath = [bundleResourcePath stringByAppendingPathComponent:@"schematic_inspector_rotate_left.tiff"];
  NSImage* rotateLeftImage = [[NSImage alloc] initWithContentsOfFile:rotateLeftImageFilePath];
  [rotateLeftButton setImage:rotateLeftImage];
  [[rotateLeftButton cell] setImageScaling:NSImageScaleNone];
  FXRelease(rotateLeftImage)
  [rotateLeftButton setImagePosition:NSImageOnly];
  [rotateLeftButton setAction:@selector(rotateInspectedElementsPlus90:)];
  [rotateLeftButton setTarget:self];
  [inspectorView addSubview:rotateLeftButton];
  FXRelease(rotateLeftButton)

  const NSRect kRotateRightButtonFrame = NSMakeRect(kPosX_RotateRight, kPosY_RotateRight, kSize_RotateRight, kSize_RotateRight);
  NSButton* rotateRightButton = [[NSButton alloc] initWithFrame:kRotateRightButtonFrame];
  [rotateRightButton setBordered:NO];
  [rotateRightButton setAutoresizingMask:(NSViewMinYMargin | NSViewMaxXMargin)];
  NSString* rotateRightImageFilePath = [bundleResourcePath stringByAppendingPathComponent:@"schematic_inspector_rotate_right.tiff"];
  NSImage* rotateRightImage = [[NSImage alloc] initWithContentsOfFile:rotateRightImageFilePath];
  [rotateRightButton setImage:rotateRightImage];
  [[rotateRightButton cell] setImageScaling:NSImageScaleNone];
  FXRelease(rotateRightImage)
  [rotateRightButton setImagePosition:NSImageOnly];
  [rotateRightButton setAction:@selector(rotateInspectedElementsMinus90:)];
  [rotateRightButton setTarget:self];
  [inspectorView addSubview:rotateRightButton];
  FXRelease(rotateRightButton)

  const NSRect kFlipHButtonFrame = NSMakeRect(kPosX_FlipHorizontally, kPosY_FlipHorizontally, kSize_FlipHorizontally, kSize_FlipHorizontally);
  NSButton* flipHButton = [[NSButton alloc] initWithFrame:kFlipHButtonFrame];
  [flipHButton setBordered:NO];
  [flipHButton setAutoresizingMask:(NSViewMinYMargin | NSViewMaxXMargin)];
  NSString* flipHImageFilePath = [bundleResourcePath stringByAppendingPathComponent:@"schematic_inspector_flip_horizontally.tiff"];
  NSImage* flipHImage = [[NSImage alloc] initWithContentsOfFile:flipHImageFilePath];
  [flipHButton setImage:flipHImage];
  [[flipHButton cell] setImageScaling:NSImageScaleNone];
  FXRelease(flipHImage)
  [flipHButton setImagePosition:NSImageOnly];
  [flipHButton setAction:@selector(flipInspectedElementsHorizontally:)];
  [flipHButton setTarget:self];
  [inspectorView addSubview:flipHButton];
  FXRelease(flipHButton)

  const NSRect kFlipVButtonFrame = NSMakeRect(kPosX_FlipVertically, kPosY_FlipVertically, kSize_FlipVertically, kSize_FlipVertically);
  NSButton* flipVButton = [[NSButton alloc] initWithFrame:kFlipVButtonFrame];
  [flipVButton setBordered:NO];
  [flipVButton setAutoresizingMask:(NSViewMinYMargin | NSViewMaxXMargin)];
  NSString* flipVImageFilePath = [bundleResourcePath stringByAppendingPathComponent:@"schematic_inspector_flip_vertically.tiff"];
  NSImage* flipVImage = [[NSImage alloc] initWithContentsOfFile:flipVImageFilePath];
  [flipVButton setImage:flipVImage];
  [[flipVButton cell] setImageScaling:NSImageScaleNone];
  FXRelease(flipVImage)
  [flipVButton setImagePosition:NSImageOnly];
  [flipVButton setAction:@selector(flipInspectedElementsVertically:)];
  [flipVButton setTarget:self];
  [inspectorView addSubview:flipVButton];
  FXRelease(flipVButton)

  const NSRect kModelChooserFrame = NSMakeRect(kPosX_ModelChooser, kPosY_ModelChooser, kWidth_ModelChooser, kHeight_ModelChooser);
#if MODEL_CHOOSER_MENU_IS_PULL_DOWN
  mModelChooser = [[NSPopUpButton alloc] initWithFrame:kModelChooserFrame pullsDown:YES];
#else
  mModelChooser = [[NSPopUpButton alloc] initWithFrame:kModelChooserFrame pullsDown:NO];
#endif
  [mModelChooser setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin | NSViewMaxXMargin)];
  [mModelChooser setBordered:NO];
  [mModelChooser setAction:@selector(selectModel:)];
  [mModelChooser setTarget:self];
  [mModelChooser setTitle:@""];
  [inspectorView addSubview:mModelChooser];
  FXRelease(mModelChooser)

  const NSRect attributesTableFrame = NSMakeRect(kPosX_PropertiesTable, kPosY_PropertiesTable, kWidth_PropertiesTable, kHeight_PropertiesTable);
  mPropertiesTableView = [[FXSchematicPropertiesTableView alloc] initWithFrame:attributesTableFrame];
  [mPropertiesTableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  NSScrollView* tableScrollView = [[NSScrollView alloc] initWithFrame:attributesTableFrame];
  [tableScrollView setHasVerticalScroller:YES];
  [[tableScrollView verticalScroller] setControlSize:NSControlSizeSmall];
  [tableScrollView setHasHorizontalScroller:NO];
  [tableScrollView setAutohidesScrollers:YES];
  [tableScrollView setDocumentView:mPropertiesTableView];
  FXRelease(mPropertiesTableView)
  [tableScrollView setAutoresizingMask:[mPropertiesTableView autoresizingMask]];
  [tableScrollView setDrawsBackground:NO];
  [tableScrollView setBorderType:NSBezelBorder];
  [tableScrollView setFocusRingType:NSFocusRingTypeNone];
  [inspectorView addSubview:tableScrollView];
  FXRelease(tableScrollView)

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleElementModelsChange:) name:VoltaSchematicElementModelsDidChangeNotification object:nil];

  [mPropertiesTableView setDataSource:self];
  [mPropertiesTableView setDelegate:self];

  return inspectorView;
}


- (void) reset
{
  @synchronized( self )
  {
    [mPropertyWrappers removeAllObjects];
    [mElementsWithCommonProperties removeAllObjects];
    [mInspectables removeAllObjects];
  }
}


- (void) setValue:(NSString*)newValue ofPropertyNamed:(NSString*)attributeName
{
  if ( [mInspectables count] > 0 )
  {
    // Create undo point
    id <VoltaSchematicElement> anyElement = [mInspectables anyObject];
    id <VoltaSchematic> inspectedSchematic = [anyElement schematic];
    NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_attribute_value_change") };
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:inspectedSchematic userInfo:undoUserInfo];
    
    for ( id<VoltaSchematicElement> element in mInspectables )
    {
      [element setPropertyValue:newValue forKey:attributeName];
    }

    [self inspect:mInspectables];
    
    // Request view update
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementUpdateNotification object:inspectedSchematic];
  }
}


/// Tests if two CGFloat (= double) are within the epsilon of 32-bit float numbers.
static BOOL floatsAreEqual(CGFloat a, CGFloat b)
{
  static const CGFloat skEpsilon = std::numeric_limits<float>::epsilon();
  return fabs(a - b) < skEpsilon;
}


- (void) rotateInspectedElements:(CGFloat)angle
{
  if ( [mInspectables count] > 0 )
  {
    // Create undo point
    id <VoltaSchematicElement> anyElement = [mInspectables anyObject];
    id <VoltaSchematic> inspectedSchematic = [anyElement schematic];
    NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_rotation") };
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:inspectedSchematic userInfo:undoUserInfo];

    // Apply rotation
    static const CGFloat kFullRot = 2 * M_PI;
    for ( id<VoltaSchematicElement> element in mInspectables )
    {
      CGFloat newRotation = [element rotation] + angle;
      newRotation = (newRotation > kFullRot) ? (newRotation - kFullRot) : ( (newRotation < 0) ? (newRotation + kFullRot) : newRotation );
      [element setRotation:newRotation];

      FXIssue(66)
      if ( floatsAreEqual(angle,M_PI_2) || floatsAreEqual(angle,-M_PI_2) )
      {
        BOOL rotateLeft = floatsAreEqual(angle,M_PI_2);
        SchematicRelativePosition newLabelPosition = SchematicRelativePosition_None;
        switch ( element.labelPosition )
        {
          case SchematicRelativePosition_Top:    newLabelPosition = (rotateLeft ? SchematicRelativePosition_Left : SchematicRelativePosition_Right); break;
          case SchematicRelativePosition_Left:   newLabelPosition = (rotateLeft ? SchematicRelativePosition_Bottom : SchematicRelativePosition_Top); break;
          case SchematicRelativePosition_Bottom: newLabelPosition = (rotateLeft ? SchematicRelativePosition_Right : SchematicRelativePosition_Left); break;
          case SchematicRelativePosition_Right:  newLabelPosition = (rotateLeft ? SchematicRelativePosition_Top : SchematicRelativePosition_Bottom); break;
          default: break;
        }
        element.labelPosition = newLabelPosition;
      }
    }

    [self updateLabelPositionIndicator];

    // Request view update
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementUpdateNotification object:inspectedSchematic];
  }
}


- (void) flipInspectedElementsHorizontallyAndRotate:(CGFloat)angle
{
  if ( [mInspectables count] > 0 )
  {
    // Create collective undo point
    id <VoltaSchematicElement> anyElement = [mInspectables anyObject];
    id <VoltaSchematic> inspectedSchematic = [anyElement schematic];
    NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"flipping") };
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:inspectedSchematic userInfo:undoUserInfo];

    for ( id<VoltaSchematicElement> element in mInspectables )
    {
      // Skip certain elements which can not be flipped
      if ( [element type] == VMT_SUBCKT )
      {
        continue;
      }
      if ( [element type] == VMT_DECO )
      {
        continue;
      }

      [element setFlipped:![element flipped]];
      // Flipping while a rotation is in place is like flipping without the rotation, then applying the inverse rotation.
      CGFloat const existingRotation = [element rotation];
      [element setRotation:(angle - existingRotation)];

      FXIssue(66)
      if ( floatsAreEqual(angle,0) || floatsAreEqual(angle,M_PI) )
      {
        BOOL const flipVertically = floatsAreEqual(angle,M_PI);
        SchematicRelativePosition newLabelPosition = SchematicRelativePosition_None;
        switch ( [element labelPosition] )
        {
          case SchematicRelativePosition_Top:    newLabelPosition = (flipVertically ? SchematicRelativePosition_Bottom : SchematicRelativePosition_Top); break;
          case SchematicRelativePosition_Left:   newLabelPosition = (flipVertically ? SchematicRelativePosition_Left : SchematicRelativePosition_Right); break;
          case SchematicRelativePosition_Bottom: newLabelPosition = (flipVertically ? SchematicRelativePosition_Top : SchematicRelativePosition_Bottom); break;
          case SchematicRelativePosition_Right:  newLabelPosition = (flipVertically ? SchematicRelativePosition_Right : SchematicRelativePosition_Left); break;
          default: break;
        }
        element.labelPosition = newLabelPosition;
      }
    }

    [self updateLabelPositionIndicator];

    // Request view update
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementUpdateNotification object:inspectedSchematic];
  }
}


- (void) changeElementName:(NSString*)proposedName
{
  if ( [mInspectables count] == 1 )
  {
    // Create undo point
    id <VoltaSchematicElement> inspectedElement = [mInspectables anyObject];
    id <VoltaSchematic> inspectedSchematic = [inspectedElement schematic];
    NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_name_change") };
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:inspectedSchematic userInfo:undoUserInfo];

    id<VoltaSchematicElement> element = [mInspectables anyObject];
    [element setName:proposedName];
    [inspectedSchematic checkAndAssignUniqueName:element]; FXIssue(28)
    [mElementNameField setStringValue:[element name]]; // display the final name

    // Request a view update if the label is displayed
    if ( [inspectedElement labelPosition] != SchematicRelativePosition_None )
    {
      [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementUpdateNotification object:inspectedSchematic];
    }
  }
}


- (void) changeLabelPosition:(id)sender
{
  if ( [mInspectables count] > 0 )
  {
    // Create an undo point
    id <VoltaSchematicElement> anyElement = [mInspectables anyObject];
    id <VoltaSchematic> inspectedSchematic = [anyElement schematic];
    NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_reposition_label") };
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:inspectedSchematic userInfo:undoUserInfo];
    
    // set the label position
    SchematicRelativePosition const newPosition = [mPositionSelectorView position];
    for ( id<VoltaSchematicElement> element in mInspectables )
    {
      [element setLabelPosition:newPosition];
    }
    
    // Request view update
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementUpdateNotification object:inspectedSchematic];
  }
}


- (void) updateLabelPositionIndicator
{
  SchematicRelativePosition commonPosition = SchematicRelativePosition_None;
  BOOL firstElement = YES;
  for ( id<VoltaSchematicElement> element : mInspectables )
  {
    if ( firstElement )
    {
      commonPosition = element.labelPosition;
      firstElement = NO;
    }
    else if ( element.labelPosition != commonPosition )
    {
      commonPosition = SchematicRelativePosition_None;
      break;
    }
  }
  mPositionSelectorView.position = commonPosition;
}


- (void) updateElementNameField
{
  NSUInteger const numberOfInspectables = [mInspectables count];
  if ( numberOfInspectables == 0 )
  {
    [[mElementNameField cell] setPlaceholderString:FXLocalizedString(@"No name")];
    [mElementNameField setStringValue:@""];
    [mElementNameField setEditable:YES];
    [mElementNameField setSelectable:YES];
  }
  else if ( numberOfInspectables == 1 )
  {
    id<VoltaSchematicElement> inspectedElement = [mInspectables anyObject];
    NSString* elementName = [inspectedElement name];
    if ( elementName != nil )
    {
      [mElementNameField setStringValue:elementName];
      [mElementNameField setEditable:YES];
      [mElementNameField setSelectable:YES];
    }
    [mPositionSelectorView setPosition:[inspectedElement labelPosition]];
  }
  else // numberOfInspectables > 1
  {
    FXIssue(29)
    NSUInteger const numComponents = [FX(FXSchematicInspectorUtilities) numberOfComponentsInInspectables:mInspectables];
    [[mElementNameField cell] setPlaceholderString:[NSString stringWithFormat:@"%ld %@", numComponents, (numComponents == 1) ? FXLocalizedString(@"component") : FXLocalizedString(@"components")]];
    [mElementNameField setStringValue:@""];
    [mElementNameField setEditable:NO];
    [mElementNameField setSelectable:NO];
  }
}


- (BOOL) findMatchingProperty:(FXSchematicPropertyWrapper*)existingPropertyWrapper
                 inProperties:(NSArray*)elementPropertyWrappers
{
  BOOL result = NO;
  for ( FXSchematicPropertyWrapper* newPropertyWrapper in elementPropertyWrappers )
  {
    if ( [[newPropertyWrapper name] isEqualToString:[existingPropertyWrapper name]] )
    {
      result = YES;
      NSString* existingValue = [existingPropertyWrapper value];
      if ( existingValue == nil )
      {
        existingValue = [existingPropertyWrapper defaultValue];
      }
      NSString* newValue = [newPropertyWrapper value];
      if ( newValue == nil )
      {
        newValue = [newPropertyWrapper defaultValue];
      }
      if ( ![existingValue isEqualToString:newValue] )
      {
        FXIssue(29)
        [existingPropertyWrapper setHasMultipleValues:YES];
      }
      break;
    }
  }
  return result;
}


- (void) removePropertiesFromArray:(NSMutableArray*)commonProperties ifNotFoundInProperties:(NSArray*)allProperties
{
  BOOL purgedAProperty = NO;
  do
  {
    purgedAProperty = NO;
    for ( FXSchematicPropertyWrapper* candidateProperty in commonProperties )
    {
      if ( ![self findMatchingProperty:candidateProperty inProperties:allProperties] )
      {
        [commonProperties removeObject:candidateProperty];
        purgedAProperty = YES;
        break;
      }
    }
  }
  while ( purgedAProperty );
}


- (void) updateDisplayedProperties
{
  [mPropertyWrappers removeAllObjects];
  [mElementsWithCommonProperties removeAllObjects];

  BOOL handledFirstElement = NO;
  for ( id<VoltaSchematicElement> element in mInspectables )
  {
    if ( !handledFirstElement )
    {
      NSArray* elementPropertyWrappers = [self propertyWrappersForElement:element];
      [mPropertyWrappers setArray:elementPropertyWrappers];
      [mElementsWithCommonProperties addObject:element];
      handledFirstElement = YES;
    }
    else
    {
      NSArray* elementPropertyWrappers = [self propertyWrappersForElement:element];
      [self removePropertiesFromArray:mPropertyWrappers ifNotFoundInProperties:elementPropertyWrappers];
      if ( [mPropertyWrappers count] > 0 )
      {
        [mElementsWithCommonProperties addObject:element];
      }
    }
  }

  [mPropertyWrappers sortUsingComparator:^NSComparisonResult(id obj1, id obj2) { return [[obj1 name] compare:[obj2 name]]; }];
}


/// @return a dictionary with common model values for the given keys:
///  @"Name" -> Common name, NSString*
///  @"Vendor" -> Common vendor string, NSString*
///  @"TypeCode" -> common model type, NSNumber* containing NSInteger
- (NSDictionary*) commonModelDataOfElements:(NSSet*)elements
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:3];
  NSString* modelName = nil;
  NSString* modelVendor = nil;
  VoltaModelType modelType = VMT_Unknown;
  
  if ( [elements count] > 0 )
  {
    if ( [elements count] == 1 )
    {
      id<VoltaSchematicElement> element = [elements anyObject];
      modelName = [element modelName];
      modelVendor = [element modelVendor];
      modelType = [element type];
    }
    else if ( [elements count] > 1 )
    {
      BOOL processedFirstElement = NO;
      for ( id<VoltaSchematicElement> element in elements )
      {
        if ( !processedFirstElement )
        {
          modelName = [element modelName];
          NSAssert( modelName != nil, @"Every element must have a model name." );
          modelType = [element type];
          NSAssert( modelType != VMT_Unknown, @"Every element must have a model type." );
          modelVendor = [element modelVendor];
          NSAssert( modelVendor != nil, @"Every element must have a model vendor string." );
          processedFirstElement = YES;
        }
        else
        {
          if ( (modelName != [element modelName]) && ![modelName isEqualToString:[element modelName]] )
          {
            modelName = nil;
          }
          if ( (modelVendor != [element modelVendor]) && ![modelVendor isEqualToString:[element modelVendor]] )
          {
            modelVendor = nil;
          }
          if ( modelType != [element type] )
          {
            modelType = VMT_Unknown;
          }
          if ( (modelName == nil) && (modelVendor == nil) && (modelType == VMT_Unknown) )
          {
            break;
          }
        }
      }
    }
  }

  if ( modelName != nil )
    result[@"Name"] = modelName;

  if ( modelVendor != nil )
    result[@"Vendor"] = modelVendor;

  result[@"TypeCode"] = @(modelType);

  return result;
}


- (void) populateChooserMenuWithModelsOfType:(VoltaModelType)modelType inLibrary:(id<VoltaLibrary>)library
{
  NSMenu* modelsMenu = [[NSMenu alloc] initWithTitle:@"Models"];
#if MODEL_CHOOSER_MENU_IS_PULL_DOWN
  [modelsMenu addItemWithTitle:@"" action:NULL keyEquivalent:@""]; // required first item for NSPopUpButton in pull-down mode
#endif
  [library iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
    if ( group->modelType == modelType )
    {
      for( VoltaPTModelPtr model : group->models )
      {
        FXModel* modelWrapper = [[FXModel alloc] initWithPersistentModel:model];
        FXAutorelease(modelWrapper)
        NSString* menuItemTitle = [FXVoltaLibraryUtilities userVisibleNameForModelName:[modelWrapper name]];
        if ( [[modelWrapper vendor] length] > 0 )
        {
          FXIssue(173)
          menuItemTitle = [menuItemTitle stringByAppendingFormat:@" (%@)", [modelWrapper vendor]];
        }
        [modelsMenu addItemWithTitle:menuItemTitle action:NULL keyEquivalent:@""];
        self->mModelChooserModelDictionary[menuItemTitle] = modelWrapper;
      }
      *stop = YES;
    }
  }];
  [mModelChooser setMenu:modelsMenu];
  FXRelease(modelsMenu)
}


- (NSString*) determineModelChooserTitleForHeterogeneousInspectablesOfType:(VoltaModelType)modelType
{
  NSString* title = nil;
  NSAssert([mInspectables count] > 1, @"For a single inspected element there must always be full model data.");
  if ( [mInspectables count] > 1 )
  {
    title = FXLocalizedString(@"SchematicElementInspector_MultipleModels");
  }
  else if ( modelType == VMT_Unknown )
  {
    title = FXLocalizedString(@"SchematicElementInspector_UnknownModelType");
  }
  else
  {
    NSAssert(NO, @"All elements should have a model name and a vendor string.");
  }
  return title;
}


- (NSString*) determineModelChooserTitleForHomogeneousInspectablesOfType:(VoltaModelType)modelType
                                                         commonModelName:(NSString*)modelName
                                                       commonModelVendor:(NSString*)modelVendor
{
  NSString* title = nil;
  id<VoltaLibrary> library = [[(id<VoltaSchematicElement>)[mInspectables anyObject] schematic] library];

  __block BOOL foundMatchingModelInLibary = NO;
  __block BOOL matchingModelIsBuiltInModel = NO;
  if ( modelName != nil )
  {
    if ( modelType == VMT_SUBCKT )
    {
      [library iterateOverSubcircuitsByApplyingBlock:^(VoltaPTModelPtr subcircuit, BOOL* stop) {
        if ( subcircuit->name == FXString((__bridge CFStringRef)modelName) && (subcircuit->vendor == FXString((__bridge CFStringRef)modelVendor)) )
        {
          foundMatchingModelInLibary = YES;
          matchingModelIsBuiltInModel = NO;
          *stop = YES;
        }
      }];
    }
    else
    {
      [library iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
        if ( group->modelType == modelType )
        {
          for ( auto model : group->models )
          {
            if ( (model->name == FXString((__bridge CFStringRef)modelName)) && (model->vendor == FXString((__bridge CFStringRef)modelVendor)) )
            {
              foundMatchingModelInLibary = YES;
              matchingModelIsBuiltInModel = !model->isMutable;
              *stop = YES;
              break;
            }
          }
        }
      }];
    }
  }

  title = matchingModelIsBuiltInModel ? [FXVoltaLibraryUtilities userVisibleNameForModelName:modelName] : modelName;
  if ( [modelVendor length] > 0 )
  {
    title = [NSString stringWithFormat:@"%@ (%@)", title, modelVendor];
  }

  if ( !foundMatchingModelInLibary )
  {
    title = [NSString stringWithFormat:@"? %@", title];
  }
  return title;
}


- (void) setModelChooserMenuTitle:(NSString*)title
{
  NSAssert( title != nil, @"The title string for the popup button should be set by now." );
  [mModelChooser setTitle:title];

#if MODEL_CHOOSER_MENU_IS_PULL_DOWN
  BOOL const hasMultipleModels = ([[mModelChooser menu] numberOfItems] > 2);
#else
  BOOL const hasMultipleModels = ([[mModelChooser menu] numberOfItems] > 1);
#endif
  [(NSPopUpButtonCell*)[mModelChooser cell] setArrowPosition:(hasMultipleModels ? NSPopUpArrowAtBottom : NSPopUpNoArrow)];
  [mModelChooser setEnabled:hasMultipleModels];
  if ( hasMultipleModels )
  {
    NSMenuItem* activeMenuItem = [[mModelChooser menu] itemWithTitle:title];
    [activeMenuItem setState:NSOnState];
  }
}


- (void) updateModelChooserMenu
{
  [mModelChooser setEnabled:NO];
  [mModelChooser setMenu:nil];
  [mModelChooserModelDictionary removeAllObjects];

  if ( [mInspectables count] == 0 )
    return;

  NSDictionary* modelData = [self commonModelDataOfElements:mInspectables];
  NSString* modelName = modelData[@"Name"];
  NSString* modelVendor = modelData[@"Vendor"];
  NSNumber* modelTypeNumber = modelData[@"TypeCode"];
  NSAssert(modelTypeNumber != nil, @"The dictionary must always contain a model type entry.");
  if ( modelTypeNumber == nil )
    return;
  
  VoltaModelType const modelType = (VoltaModelType)[modelTypeNumber integerValue];

  NSString* modelChooserTitle = nil;

  if ( (modelName == nil) || (modelVendor == nil) )
  {
    modelChooserTitle = [self determineModelChooserTitleForHeterogeneousInspectablesOfType:modelType];
  }
  else
  {
    modelChooserTitle = [self determineModelChooserTitleForHomogeneousInspectablesOfType:modelType commonModelName:modelName commonModelVendor:modelVendor];
    if ( modelType == VMT_SUBCKT )
    {
      NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Subcircuits"];
      [menu addItemWithTitle:modelChooserTitle action:0 keyEquivalent:@""];
      [mModelChooser setMenu:menu];
      FXRelease(menu)
    }
    else
    {
      id<VoltaLibrary> library = [[(id<VoltaSchematicElement>)[mInspectables anyObject] schematic] library];
      [self populateChooserMenuWithModelsOfType:modelType inLibrary:library];
    }
  }
  [self setModelChooserMenuTitle:modelChooserTitle];
}


- (void) selectModel:(id)sender
{
  NSAssert( [mInspectables count] >= 1, @"There must be at least one inspected element in order to set the model." );
  NSString* selectedLocalizedModelName = [mModelChooser titleOfSelectedItem];
  FXModel* selectedModel = mModelChooserModelDictionary[selectedLocalizedModelName];
  NSAssert( selectedModel != nil, @"There must be a model name in the library for the localized model name." );
  if ( selectedModel == nil )
    return;

  [mModelChooser setTitle:selectedLocalizedModelName];
  if ( [mInspectables count] > 0 )
  {
    BOOL foundElementsWithModelToChange = NO;

    for ( id<VoltaSchematicElement> element in mInspectables )
    {
      if ( ([element type] == [selectedModel type])
        && !([[element modelName] isEqualToString:[selectedModel name]] && [[element modelVendor] isEqualToString:[selectedModel vendor]]) )
      {
        foundElementsWithModelToChange = YES;
      }
    }

    if ( foundElementsWithModelToChange )
    {
      id<VoltaSchematic> schematic = [(id<VoltaSchematicElement>)[mInspectables anyObject] schematic];
      [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementModelsWillChangeNotification object:schematic];

      for ( id<VoltaSchematicElement> element in mInspectables )
      {
        if ( ([element type] == [selectedModel type])
          && !([[element modelName] isEqualToString:[selectedModel name]] && [[element modelVendor] isEqualToString:[selectedModel vendor]]) )
        {
          // NOTE: The properties of the element are not removed although they may
          // not apply to the new model anymore. This is done so that nothing is
          // lost in case the properties are the same for both models or the user
          // later reverts to the old model again.
          [element setModelName:[selectedModel name]];
          [element setModelVendor:[selectedModel vendor]];
          [self migratePropertiesOfElement:element];
        }
      }

      [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementModelsDidChangeNotification object:schematic];
    }
  }
}


- (NSArray*) propertyWrappersForElement:(id<VoltaSchematicElement>)element
{
  NSMutableArray* result = nil;
  if ( element != nil )
  {
    VoltaPTModelPtr model = [element.schematic.library modelForType:element.type name:(CFStringRef)element.modelName vendor:(CFStringRef)element.modelVendor];
    VoltaPTPropertyVector const & allElementProperties = FXVoltaCircuitDomainAgent::circuitElementParametersForModel(model);
    result = [NSMutableArray arrayWithCapacity:allElementProperties.size()];
    for ( VoltaPTProperty const & property : allElementProperties )
    {
      FXSchematicPropertyWrapper* propertyWrapper = [FXSchematicPropertyWrapper new];
      propertyWrapper.name = (__bridge NSString*)property.name.cfString();
      propertyWrapper.value = (__bridge NSString*)property.value.cfString();
      [result addObject:propertyWrapper];
      FXRelease(propertyWrapper)
    }

    [element enumeratePropertiesUsingBlock:^(NSString* elementPropertyName, id propertyValue, BOOL *stop) {
      for ( FXSchematicPropertyWrapper* propertyWrapper in result )
      {
        if ( [propertyWrapper.name isEqualToString:elementPropertyName] )
        {
          propertyWrapper.value = (NSString*)propertyValue;
        }
      }
    }];
  }
  return result;
}


- (void) handleElementModelsChange:(NSNotification*)notification
{
  [self inspect:mInspectables];
}


- (void) migratePropertiesOfElement:(id<VoltaSchematicElement>)element
{
  // Migrating the current properties of the element to the properties given by its (new) model.
  VoltaPTModelPtr model = [element.schematic.library modelForType:element.type name:(CFStringRef)element.modelName vendor:(CFStringRef)element.modelVendor];
  VoltaPTPropertyVector newProperties = FXVoltaCircuitDomainAgent::circuitElementParametersForModel(model);
  NSMutableDictionary* newPropertiesDictionary = [[NSMutableDictionary alloc] initWithCapacity:newProperties.size()];
  for ( VoltaPTProperty const & newProperty : newProperties )
  {
    NSString* newPropertyName = [NSString stringWithString:(__bridge NSString*)newProperty.name.cfString()];
    NSString* newPropertyValue = nil;
    if ( [element propertyValueForKey:newPropertyName] != nil )
    {
      newPropertyValue = [element propertyValueForKey:newPropertyName];
    }
    else
    {
      newPropertyValue = [NSString stringWithString:(__bridge NSString*)newProperty.value.cfString()];
    }
    [newPropertiesDictionary setObject:newPropertyValue forKey:newPropertyName];
  }
  [element removeAllProperties];
  [newPropertiesDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
    [element setPropertyValue:value forKey:(NSString*)key];
  }];
  FXRelease(newPropertiesDictionary)
}


@end
