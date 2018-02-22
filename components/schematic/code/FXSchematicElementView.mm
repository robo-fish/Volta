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

#import "FXSchematicElementView.h"
#import "FXSchematicElement.h"
#import "FXShapeView.h"
#import "FXShape.h"


@interface FXSchematicElementView () <FXShapeViewDelegate>
@end


@implementation FXSchematicElementView
{
@private
  id<VoltaSchematicElement> mSchematicElement;
  SchematicRelativePosition mCachedElementLabelPosition; // stores the original label position
  BOOL mShowName;
  BOOL mShowProperty;
  NSTextField* mNameField;
  NSTextField* mValueField;
  FXShapeView* mShapeView;
}

@synthesize schematicElement = mSchematicElement;
@synthesize showName = mShowName;
@synthesize showSinglePropertyValue = mShowProperty;

- (id) initWithFrame:(FXRect)frame
{
  if ( (self = [super initWithFrame:frame]) != nil )
  {
    mSchematicElement = nil;
    [self createViews];
    [self layOutViews];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mSchematicElement)
  FXDeallocSuper
}


#pragma mark Public


- (void) setSchematicElement:(id<VoltaSchematicElement>)element
{
  if ( mSchematicElement != element )
  {
    FXRetain(element)
    FXRelease(mSchematicElement)
    mSchematicElement = element;
    mCachedElementLabelPosition = [element labelPosition];
    id<FXShape> shape = [mSchematicElement shape];
    if ( [shape doesOwnDrawing] )
    {
      __block NSMutableDictionary* shapeAttributes = [[NSMutableDictionary alloc] initWithCapacity:mSchematicElement.numberOfProperties];
      [mSchematicElement enumeratePropertiesUsingBlock:^(NSString* key, id value, BOOL* stop) {
        shapeAttributes[key] = value;
      }];
      shape.attributes = shapeAttributes;
      FXRelease(shapeAttributes)
    }
    mShapeView.shape = shape;
    mNameField.stringValue = element.name;
    if ( [mSchematicElement numberOfProperties] == 1 )
    {
      [mSchematicElement enumeratePropertiesUsingBlock:^(NSString* key, id value, BOOL* stop) {
        if ( [value isKindOfClass:[NSString class]] )
        {
          mValueField.stringValue = value;
          *stop = YES;
        }
      }];
    }
  }
}


- (void) setShowName:(BOOL)showName
{
  if ( mShowName != showName )
  {
    mShowName = showName;
    mNameField.hidden = !mShowName;
  }
}


- (void) setShowSinglePropertyValue:(BOOL)showSinglePropertyValue
{
  if ( mShowProperty != showSinglePropertyValue )
  {
    mShowProperty = showSinglePropertyValue;
    mValueField.hidden = !mShowProperty;
  }
}


#pragma NSView overrides


// Needed for forwarding the context menu action to the parent.
- (NSMenu*) menuForEvent:(NSEvent*)mouseDownEvent
{
  if ( [self nextResponder] && [[self nextResponder] isKindOfClass:[NSView class]] )
  {
    return [(NSView*)[self nextResponder] menuForEvent:mouseDownEvent];
  }
  return [[self class] defaultMenu];
}


#pragma FXShapeViewDelegate


- (NSArray*) provideObjectsForDragging
{
  id<VoltaSchematicElement> schematicElement = [(NSObject*)mSchematicElement copy];
  FXAutorelease(schematicElement)
  schematicElement.labelPosition = mCachedElementLabelPosition;
  return @[schematicElement];
}


#pragma mark Private


- (void) configureLabel:(NSTextField*)textField
{
  textField.textColor = [NSColor colorWithDeviceRed:0.4 green:0.5 blue:0.4 alpha:1.0];
  textField.font = [NSFont systemFontOfSize:10];
  textField.bezeled = NO;
  textField.bordered = NO;
  textField.selectable = NO;
  textField.editable = NO;
  textField.drawsBackground = NO;
  textField.alignment = NSTextAlignmentCenter;
  [[textField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
}


- (void) createShapeView
{
  mShapeView = [[FXShapeView alloc] initWithFrame:NSMakeRect(0, 0, 30, 30)];
  mShapeView.scaleMode = FXShapeViewScaleMode_ScaleDownToFit;
  mShapeView.delegate = self;
  [self addSubview:mShapeView];
  FXRelease(mShapeView)
}


- (void) createViews
{
  mNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 50, 20)];
  [self configureLabel:mNameField];
  [self addSubview:mNameField];
  FXRelease(mNameField)

  mValueField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 50, 20)];
  [self configureLabel:mValueField];
  [self addSubview:mValueField];
  FXRelease(mValueField)

  [self createShapeView];
}


- (void) layOutViews
{
  mValueField.translatesAutoresizingMaskIntoConstraints = NO;
  mNameField.translatesAutoresizingMaskIntoConstraints = NO;
  mShapeView.translatesAutoresizingMaskIntoConstraints = NO;
  NSDictionary* views = NSDictionaryOfVariableBindings(mValueField, mNameField, mShapeView);
  [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[mNameField(15)][mShapeView(>=20)][mValueField(15)]|" options:NSLayoutFormatAlignAllCenterX metrics:nil views:views]];
  [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[mNameField]|" options:0 metrics:nil views:views]];
  [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[mValueField]|" options:0 metrics:nil views:views]];
  [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[mShapeView]|" options:0 metrics:nil views:views]];
}

@end
