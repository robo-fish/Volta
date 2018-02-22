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

#import "FXSchematicSchematicInspector.h"
#import "FXSchematicPropertiesTableView.h"
#import "FXSchematicInspectorUtilities.h"
#import "FXSchematicUndoManager.h"

#define SCHEMATIC_INSPECTOR_SHOWS_SCHEMATIC_NAME (0)


@implementation FX(FXSchematicSchematicInspector)
{
@private
  __weak id<VoltaSchematic>         mSchematic;
  NSTextField*                      mElementsCountField;
  NSTextField*                      mConnectorCountField;
  NSTextField*                      mSchematicTitleField;
  FXSchematicPropertiesTableView*   mPropertiesTableView;
  NSMutableArray*                   mPropertyWrappers;
  BOOL                              mPropertiesTableIsCollapsed;
}

- (id) init
{
  self = [super initWithNibName:nil bundle:nil];
  if ( self != nil )
  {
    mPropertiesTableIsCollapsed = YES;
    mPropertyWrappers = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void) dealloc
{
  FXRelease(mPropertyWrappers)
  FXDeallocSuper
}


#pragma mark NSViewController overrides


- (void) loadView
{
  NSView* inspectorView = [self newInspectorView];
  [self setView:inspectorView];
  FXRelease(inspectorView)
}


#pragma mark Public


- (void) inspect:(id<VoltaSchematic>)schematic
{
  if ( mSchematic != schematic )
  {
  #if SCHEMATIC_INSPECTOR_SHOWS_SCHEMATIC_NAME
    [mSchematicTitleField setStringValue:[mSchematic schematicTitle]];
  #endif
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    if ( mSchematic != nil )
    {
      [notificationCenter removeObserver:self name:VoltaSchematicElementAddedToSchematicNotification object:mSchematic];
      [notificationCenter removeObserver:self name:VoltaSchematicElementRemovedFromSchematicNotification object:mSchematic];
      [notificationCenter removeObserver:self name:VoltaSchematicConnectionMadeNotification object:mSchematic];
      [notificationCenter removeObserver:self name:VoltaSchematicConnectionCutNotification object:mSchematic];
    }
    mSchematic = schematic;
    if ( mSchematic != nil )
    {
      [notificationCenter addObserver:self selector:@selector(updateElementCount:) name:VoltaSchematicElementAddedToSchematicNotification object:mSchematic];
      [notificationCenter addObserver:self selector:@selector(updateElementCount:) name:VoltaSchematicElementRemovedFromSchematicNotification object:mSchematic];
      [notificationCenter addObserver:self selector:@selector(updateConnectorCount:) name:VoltaSchematicConnectionMadeNotification object:mSchematic];
      [notificationCenter addObserver:self selector:@selector(updateConnectorCount:) name:VoltaSchematicConnectionCutNotification object:mSchematic];
    }
  }
  [self updateElementCount:self];
  [self updateConnectorCount:self];
  [self updateProperties];
}


#pragma mark NSControlTextEditingDelegate


#if SCHEMATIC_INSPECTOR_SHOWS_SCHEMATIC_NAME
- (void) controlTextDidEndEditing:(NSNotification*)notification
{
  if ( [notification object] == mSchematicTitleField )
  {
    [mSchematic setSchematicName:[mSchematicTitleField stringValue]];
  }
}
#endif


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


#pragma mark NSTableViewDataSource


- (NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [mPropertyWrappers count];
}


- (id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
  NSAssert( aTableView == mPropertiesTableView, @"Wrong table." );
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


#pragma mark Private methods


static const CGFloat kHeight = 100.0;
static const CGFloat kWidth = 100.0;
static const CGFloat kMargin = 4.0;


- (CGFloat) createSchematicNameFieldInView:(NSView*)parentView atPosition:(CGFloat)posY
{
  const CGFloat kSchematicNameFieldWidth = kWidth;
  const CGFloat kSchematicNameFieldHeight = 18.0;
  const CGFloat kSchematicNameFieldPosX = 0;
  const CGFloat kSchematicNameFieldPosY = posY - kSchematicNameFieldHeight;
  const NSRect kSchematicNameFieldFrame = NSMakeRect(kSchematicNameFieldPosX, kSchematicNameFieldPosY, kSchematicNameFieldWidth, kSchematicNameFieldHeight);

  mSchematicTitleField = [[NSTextField alloc] initWithFrame:kSchematicNameFieldFrame];
  [mSchematicTitleField setEditable:YES];
  [mSchematicTitleField setFocusRingType:NSFocusRingTypeNone];
  [mSchematicTitleField setSelectable:YES];
  [mSchematicTitleField setBordered:NO];
  [mSchematicTitleField setBezeled:NO];
  [mSchematicTitleField setDrawsBackground:NO];
  [mSchematicTitleField setStringValue:@""];
  [[mSchematicTitleField cell] setPlaceholderString:FXLocalizedString(@"Untitled")];
  [mSchematicTitleField setAllowsEditingTextAttributes:NO];
  [mSchematicTitleField setFont:[NSFont fontWithName:@"Lucida Grande" size:14.0]];
  [mSchematicTitleField setAutoresizingMask:(NSViewMinYMargin | NSViewWidthSizable)];
  [mSchematicTitleField setDelegate:self];
  [parentView addSubview:mSchematicTitleField];
  FXRelease(mSchematicTitleField)

  return kSchematicNameFieldPosY;
}


- (CGFloat) createElementsCountFieldInView:(NSView*)parentView atPosition:(CGFloat)posY
{
  const CGFloat kElementsCountFieldWidth = kWidth;
  const CGFloat kElementsCountFieldHeight = 12.0;
  const CGFloat kElementsCountFieldPosX = 0;
  const CGFloat kElementsCountFieldPosY = posY - kMargin - kElementsCountFieldHeight;
  const NSRect kElementsCountFieldFrame = NSMakeRect(kElementsCountFieldPosX, kElementsCountFieldPosY, kElementsCountFieldWidth, kElementsCountFieldHeight);

  mElementsCountField = [[NSTextField alloc] initWithFrame:kElementsCountFieldFrame];
  [mElementsCountField setEditable:NO];
  [mElementsCountField setFocusRingType:NSFocusRingTypeNone];
  [mElementsCountField setSelectable:NO];
  [mElementsCountField setBordered:NO];
  [mElementsCountField setBezeled:NO];
  [mElementsCountField setDrawsBackground:NO];
  [mElementsCountField setStringValue:@""];
  [[mElementsCountField cell] setPlaceholderString:FXLocalizedString(@"No components")];
  [mElementsCountField setAllowsEditingTextAttributes:NO];
  [mElementsCountField setFont:[NSFont fontWithName:@"Lucida Grande" size:11.0]];
  [mElementsCountField setTextColor:[NSColor darkGrayColor]];
  [mElementsCountField setAutoresizingMask:(NSViewMinYMargin | NSViewWidthSizable)];
  [parentView addSubview:mElementsCountField];
  FXRelease(mElementsCountField)

  return kElementsCountFieldPosY;
}


- (CGFloat) createConnectorCountFieldInView:(NSView*)parentView atPosition:(CGFloat)posY
{
  const CGFloat kConnectorCountFieldWidth = kWidth;
  const CGFloat kConnectorCountFieldHeight = 12.0;
  const CGFloat kConnectorCountFieldPosX = 0;
  const CGFloat kConnectorCountFieldPosY = posY - kMargin - kConnectorCountFieldHeight;
  const NSRect kConnectorCountFieldFrame = NSMakeRect(kConnectorCountFieldPosX, kConnectorCountFieldPosY, kConnectorCountFieldWidth, kConnectorCountFieldHeight);

  mConnectorCountField = [[NSTextField alloc] initWithFrame:kConnectorCountFieldFrame];
  [mConnectorCountField setEditable:NO];
  [mConnectorCountField setFocusRingType:NSFocusRingTypeNone];
  [mConnectorCountField setSelectable:NO];
  [mConnectorCountField setBordered:NO];
  [mConnectorCountField setBezeled:NO];
  [mConnectorCountField setDrawsBackground:NO];
  [mConnectorCountField setStringValue:@""];
  [[mConnectorCountField cell] setPlaceholderString:FXLocalizedString(@"No connections")];
  [mConnectorCountField setAllowsEditingTextAttributes:NO];
  [mConnectorCountField setFont:[NSFont fontWithName:@"Lucida Grande" size:11.0]];
  [mConnectorCountField setTextColor:[NSColor darkGrayColor]];
  [mConnectorCountField setAutoresizingMask:(NSViewMinYMargin | NSViewWidthSizable)];
  [parentView addSubview:mConnectorCountField];
  FXRelease(mConnectorCountField)

  return kConnectorCountFieldPosY;
}


- (CGFloat) createPropertiesHeaderInView:(NSView*)parentView atPosition:(CGFloat)posY
{
  const CGFloat kExpanderButtonWidth = 18;
  const CGFloat kExpanderButtonHeight = 18;
  const CGFloat kExpanderButtonPosX = 0;
  const CGFloat kExpanderButtonPosY = posY - kMargin - kExpanderButtonHeight;
  const NSRect kExpanderButtonFrame = NSMakeRect(kExpanderButtonPosX, kExpanderButtonPosY, kExpanderButtonWidth, kExpanderButtonHeight);

  NSButton* expanderButton = [[NSButton alloc] initWithFrame:kExpanderButtonFrame];
  [expanderButton setAutoresizingMask:(NSViewMaxXMargin|NSViewMinYMargin)];
  [expanderButton setBezelStyle:NSDisclosureBezelStyle];
  [expanderButton setButtonType:NSOnOffButton];
  [expanderButton setImagePosition:NSImageOnly];
  [expanderButton setAction:@selector(handleTableExpanderAction:)];
  [expanderButton setTarget:self];
  [parentView addSubview:expanderButton];
  [expanderButton setState:NSOffState];
  FXRelease(expanderButton)

  const CGFloat kTableLabelWidth = kWidth - kExpanderButtonWidth - kMargin;
  const CGFloat kTextFieldBaselineOffset = 3.0;
  const NSRect kTableLabelFrame = NSMakeRect(kExpanderButtonPosX + kExpanderButtonWidth, kExpanderButtonPosY - kTextFieldBaselineOffset, kTableLabelWidth, kExpanderButtonHeight);
  NSTextField* tableTitle = [[NSTextField alloc] initWithFrame:kTableLabelFrame];
  [tableTitle setAutoresizingMask:(NSViewMinYMargin|NSViewWidthSizable)];
  [tableTitle setStringValue:FXLocalizedString(@"SchematicInspector_CircuitParameters")];
  [tableTitle setBordered:NO];
  [tableTitle setBezelStyle:NSTextFieldSquareBezel];
  [tableTitle setSelectable:NO];
  [tableTitle setEditable:NO];
  [tableTitle setDrawsBackground:NO];
  [tableTitle setFont:[NSFont fontWithName:@"Lucida Grande" size:11.0]];
  [tableTitle setTextColor:[NSColor grayColor]];
  [parentView addSubview:tableTitle];
  FXRelease(tableTitle)

  return kExpanderButtonPosY;
}


- (CGFloat) createPropertiesTableInView:(NSView*)parentView atPosition:(CGFloat)posY
{
  const CGFloat kPropertiesTableWidth = kWidth;
  const CGFloat kPropertiesTableHeight = posY - 2 * kMargin;
  const CGFloat kPropertiesTablePosX = 0;
  const CGFloat kPropertiesTablePosY = kMargin;
  const NSRect kPropertiesTableFrame = NSMakeRect(kPropertiesTablePosX, kPropertiesTablePosY, kPropertiesTableWidth, kPropertiesTableHeight);

  mPropertiesTableView = [[FXSchematicPropertiesTableView alloc] initWithFrame:kPropertiesTableFrame];
  [mPropertiesTableView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
  [mPropertiesTableView setDataSource:self];
  [mPropertiesTableView setDelegate:self];
  NSScrollView* propertiesTableScrollView = [[NSScrollView alloc] initWithFrame:kPropertiesTableFrame];
  [propertiesTableScrollView setHasVerticalScroller:YES];
  [[propertiesTableScrollView verticalScroller] setControlSize:NSControlSizeSmall];
  [propertiesTableScrollView setHasHorizontalScroller:NO];
  [propertiesTableScrollView setAutohidesScrollers:YES];
  [propertiesTableScrollView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
  [propertiesTableScrollView setDocumentView:mPropertiesTableView];
  [propertiesTableScrollView setAutoresizingMask:[mPropertiesTableView autoresizingMask]];
  [propertiesTableScrollView setDrawsBackground:NO];
  [propertiesTableScrollView setBorderType:NSBezelBorder];
  [propertiesTableScrollView setFocusRingType:NSFocusRingTypeNone];
  [parentView addSubview:propertiesTableScrollView];
  FXRelease(propertiesTableScrollView)
  FXRelease(mPropertiesTableView)
  [propertiesTableScrollView setHidden:mPropertiesTableIsCollapsed];

  return kMargin;
}


- (NSView*) newInspectorView
{
  CGRect const kViewFrame = {0, 0, 100, 100};

  NSView* inspectorView = [[NSView alloc] initWithFrame:kViewFrame];
  [inspectorView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

  CGFloat currentPosY = kHeight;

#if SCHEMATIC_INSPECTOR_SHOWS_SCHEMATIC_NAME
  currentPosY = [self createSchematicNameFieldInView:inspectorView atPosition:currentPosY];
#endif
  currentPosY = [self createElementsCountFieldInView:inspectorView atPosition:currentPosY];
  currentPosY = [self createConnectorCountFieldInView:inspectorView atPosition:currentPosY];
  currentPosY = [self createPropertiesHeaderInView:inspectorView atPosition:currentPosY];
  [self createPropertiesTableInView:inspectorView atPosition:currentPosY];

  return inspectorView;
}


- (void) updateElementCount:(id)sender
{
  if ( mSchematic != nil )
  {
    NSUInteger const componentCount = [FXSchematicInspectorUtilities numberOfComponentsInInspectables:[mSchematic elements]];
    [mElementsCountField setStringValue:[NSString stringWithFormat:@"%ld %@", componentCount, (componentCount == 1) ? FXLocalizedString(@"component") : FXLocalizedString(@"components")]];
  }
  else
  {
    [mElementsCountField setStringValue:@""]; // causes placeholder to show
  }
}


- (void) updateConnectorCount:(id)sender
{
  if ( mSchematic != nil )
  {
    NSUInteger connectorCount = [mSchematic numberOfConnectors];
    [mConnectorCountField setStringValue:[NSString stringWithFormat:@"%ld %@", connectorCount, (connectorCount == 1) ? FXLocalizedString(@"connection") : FXLocalizedString(@"connections")]];
  }
  else
  {
    [mConnectorCountField setStringValue:@""]; // causes placeholder to show
  }
}


- (void) updateProperties
{
  [mPropertyWrappers removeAllObjects];
  [[mSchematic properties] enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    FXSchematicPropertyWrapper* propertyWrapper = [FXSchematicPropertyWrapper new];
    [propertyWrapper setName:key];
    [propertyWrapper setValue:value];
    [mPropertyWrappers addObject:propertyWrapper];
    FXRelease(propertyWrapper)
  }];
  [mPropertyWrappers sortUsingComparator:^NSComparisonResult(id obj1, id obj2) { return [[obj1 name] compare:[obj2 name]]; }];
  [mPropertiesTableView reloadData];
}


- (void) setValue:(NSString*)newValue ofPropertyNamed:(NSString*)attributeName
{
  NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_attribute_value_change") };
  [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];
  
  [[mSchematic properties] setValue:newValue forKey:attributeName];
  
  [self inspect:mSchematic];
}


- (void) handleTableExpanderAction:(id)sender
{
  if ( mPropertiesTableIsCollapsed )
  {
    [self expandPropertiesTable];
  }
  else
  {
    [self collapsePropertiesTable];
  }
  mPropertiesTableIsCollapsed = !mPropertiesTableIsCollapsed;
}


- (void) expandPropertiesTable
{
  NSScrollView* scrollView = [mPropertiesTableView enclosingScrollView];
  [scrollView setHidden:NO];
  NSDictionary* animationDictionary = @{
    NSViewAnimationTargetKey : scrollView,
    NSViewAnimationEffectKey : NSViewAnimationFadeInEffect,
  };
  NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:@[animationDictionary]];
  [animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
  [animation setAnimationCurve:NSAnimationLinear];
  [animation setDuration:0.2];
  [animation setFrameRate:0.0];
  [animation setDelegate:self];
  [animation startAnimation];
}


- (void) collapsePropertiesTable
{
  NSDictionary* animationDictionary = @{
    NSViewAnimationTargetKey : [mPropertiesTableView enclosingScrollView],
    NSViewAnimationEffectKey : NSViewAnimationFadeOutEffect
  };
  NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:@[animationDictionary]];
  [animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
  [animation setAnimationCurve:NSAnimationLinear];
  [animation setDuration:0.2];
  [animation setFrameRate:0.0];
  [animation setDelegate:self];
  [animation startAnimation];
}


#pragma mark  NSAnimationDelegate


- (void) animationDidEnd:(NSAnimation*)animation
{
  FXRelease(animation)
}


@end
