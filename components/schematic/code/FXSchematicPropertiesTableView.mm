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

#import "FXSchematicPropertiesTableView.h"


NSString* FXSchematicPropertiesTableNamesColumnIdentifier = @"names";
NSString* FXSchematicPropertiesTableValuesColumnIdentifier = @"values";


#pragma mark FXSchematicPropertyWrapper


@implementation FXSchematicPropertyWrapper

- (id) init
{
  self = [super init];
  self.hasMultipleValues = NO;
  return self;
}

- (BOOL) isEqual:(id)anObject
{
  if (anObject == self)
  {
    return YES;
  }
  if ((anObject == nil) || ![anObject isKindOfClass:[self class]])
  {
    return NO;
  }
  return [self.name isEqualToString:[(FXSchematicPropertyWrapper*)anObject name]];
}

@end


#pragma mark - FXPropertiesTableNameCell


@implementation FXPropertiesTableNameCell

- (id) init
{
  self = [super initTextCell:@""];
  if ( self != nil )
  {
    [self setType:NSTextCellType];
    [self setBezeled:NO];
    [self setBordered:NO];
    [self setEditable:NO];
    [self setUsesSingleLineMode:YES];
    [self setBackgroundColor:[NSColor colorWithDeviceRed:0.7 green:0.74 blue:0.7 alpha:0.60]];
    [self setDrawsBackground:YES];
    [self setTextColor:[NSColor blackColor]];
  }
  return self;
}

@end


#pragma mark - FXPropertiesTableValueCell


@implementation FXPropertiesTableValueCell
{
@private
  BOOL mRepresentsMultiValueProperty;
}

@synthesize representsMultiValueProperty = mRepresentsMultiValueProperty;

- (id) init
{
  self = [super initTextCell:@""];
  if ( self != nil )
  {
    mRepresentsMultiValueProperty = NO;
    [self setType:NSTextCellType];
    [self setFocusRingType:NSFocusRingTypeNone];
    [self setBezeled:NO];
    [self setBordered:NO];
    [self setEditable:YES];
    [self setUsesSingleLineMode:YES];
    [self setSendsActionOnEndEditing:YES];
    [self setFocusRingType:NSFocusRingTypeNone];
    [self setAllowsEditingTextAttributes:NO];
    [self setDrawsBackground:NO];
    [self setTextColor:[NSColor blackColor]];
  }
  return self;
}

#if 0 && VOLTA_DEBUG
- (void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  if ( mRepresentsMultiValueProperty )
  {
    [[NSColor yellowColor] set];
    NSRectFill(cellFrame);
  }
  else
  {
    [super drawInteriorWithFrame:cellFrame inView:controlView];
  }
}
#endif

@end


#pragma mark - FXSchematicPropertiesTableView


@implementation FXSchematicPropertiesTableView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];

  NSTableColumn* propertyNameTableColumn = [[NSTableColumn alloc] initWithIdentifier:FXSchematicPropertiesTableNamesColumnIdentifier];
  [[propertyNameTableColumn headerCell] setStringValue:FXLocalizedString(@"Attribute")];
  [propertyNameTableColumn setResizingMask:NSTableColumnUserResizingMask];
  FX(FXPropertiesTableNameCell)* nameColumnCell = [[FX(FXPropertiesTableNameCell) alloc] init];
  [propertyNameTableColumn setDataCell:nameColumnCell];
  FXRelease(nameColumnCell)
  [propertyNameTableColumn setEditable:NO];
  [self addTableColumn:propertyNameTableColumn];
  FXRelease(propertyNameTableColumn)
  
  NSTableColumn* propertyValueTableColumn = [[NSTableColumn alloc] initWithIdentifier:FXSchematicPropertiesTableValuesColumnIdentifier];
  [[propertyValueTableColumn headerCell] setStringValue:FXLocalizedString(@"Value")];
  [propertyValueTableColumn setResizingMask:NSTableColumnAutoresizingMask];
  FX(FXPropertiesTableValueCell)* valueColumnCell = [[FX(FXPropertiesTableValueCell) alloc] init];
  [propertyValueTableColumn setDataCell:valueColumnCell];
  FXRelease(valueColumnCell)
  [propertyValueTableColumn setEditable:YES];
  [self addTableColumn:propertyValueTableColumn];
  FXRelease(propertyValueTableColumn)
  
  [self setHeaderView:nil];
  [self setFocusRingType:NSFocusRingTypeNone];
  [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
  [self setBackgroundColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.0]];
  [self setIntercellSpacing:NSMakeSize(1,0)];
  [self setAllowsEmptySelection:YES];
  [self setAllowsMultipleSelection:YES];

  return self;
}

@end

