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

#import "FXLibraryEditorPaletteCellView.h"
#import "FXElement.h"
#import "FXShapeView.h"
#import "VoltaLibrary.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXVoltaCircuitDomainAgent.h"

@implementation FXLibraryEditorPaletteCellView
{
@private
  FXElement* mElement;
  id<VoltaLibrary> mLibrary;
}

@synthesize client;
@synthesize element = mElement;


- (id) initWithFrame:(NSRect)frame
{
  if ( (self = [super initWithFrame:frame]) != nil )
  {
  }
  return self;
}


- (void) dealloc
{
  self.client = nil;
  self.library = nil;
  self.element = nil;
  FXDeallocSuper
}


- (void) setElement:(FXElement*)element
{
  @synchronized(self)
  {
    if ( mElement != element )
    {
      FXRelease(mElement)
      mElement = element;
      FXRetain(mElement)

      if (mElement != nil)
      {
        self.primaryField.stringValue = mElement.name;
        self.primaryField.editable = YES;

        NSAssert( mElement.modelName != nil, @"The element must have a model name." );
        NSString* modelString = [FXVoltaLibraryUtilities userVisibleNameForModelName:mElement.modelName];
        if ( (modelString != nil) && ([modelString length]>0) )
        {
          if ( (mElement.modelVendor != nil) && ([mElement.modelVendor length] > 0) )
          {
            modelString = [modelString stringByAppendingFormat:@" (%@)", mElement.modelVendor];
          }
        }
        self.secondaryField.stringValue = (modelString != nil) ? modelString : @"";
        [self updateElementPropertyKeys];
        id<FXShape> shape = [self.library shapeForModelType:element.type name:element.modelName vendor:element.modelVendor];
        [self setShape:shape];
        if ([shape doesOwnDrawing])
        {
          shape.attributes = element.properties;
        }
      }
    }
  }
  [super updateDisplay];
}


#pragma mark FXLibraryEditorCellView overrides


- (NSString*) valueOfPropertyForKey:(id)key
{
  @synchronized(self)
  {
    return mElement.properties[key];
  }
}


- (void) setValue:(NSString*)value ofPropertyForKey:(id)key
{
  @synchronized(self)
  {
    mElement.properties[key] = value;
  }
}


- (void) handleNewPrimaryFieldValue:(NSString*)value
{
  @synchronized(self)
  {
    [self.client handleNewName:value forElement:mElement inPaletteCellView:self];
  }
}


- (void) handleNewSecondaryFieldValue:(NSString*)value
{
}


- (void) handleNewSinglePropertyFieldValue:(NSString*)value forKey:(id)key
{
  @synchronized(self)
  {
    mElement.properties[key] = value;
    [self.client handleChangedPropertiesOfElement:mElement inPaletteCellView:self];
  }
}


- (void) handleApplyPropertyTableChanges
{
  @synchronized(self)
  {
    [self.client handleChangedPropertiesOfElement:mElement inPaletteCellView:self];
  }
}


- (void) setValue:(id)value forDisplaySettingWithName:(NSString*)settingName
{
  @synchronized(self)
  {
    if ( mElement.displaySettings == nil )
    {
      mElement.displaySettings = [NSMutableDictionary dictionaryWithCapacity:2];
    }
    mElement.displaySettings[settingName] = value;
  }
}


- (id) valueForDisplaySettingWithName:(NSString*)settingName
{
  @synchronized(self)
  {
    return mElement.displaySettings[settingName];
  }
}


#pragma mark Private


- (void) updateElementPropertyKeys
{
  @synchronized(self)
  {
    if ( self.library != nil )
    {
      VoltaPTModelPtr model = [self.library modelForType:mElement.type name:(CFStringRef)mElement.modelName vendor:(CFStringRef)mElement.modelVendor];
      if ( model.get() != nullptr )
      {
        VoltaPTPropertyVector properties = FXVoltaCircuitDomainAgent::circuitElementParametersForModel(model);
        NSMutableArray* propertyNames = [NSMutableArray arrayWithCapacity:properties.size()];
        for ( VoltaPTProperty const & property : properties )
        {
          [propertyNames addObject:[NSString stringWithString:(__bridge NSString*)property.name.cfString()]];
        }
        [propertyNames sortUsingSelector:@selector(compare:)];

        [super setPropertyKeys:propertyNames];

        if ( [propertyNames count] == 1 )
        {
          NSString* value = mElement.properties[[propertyNames lastObject]];
          self.singlePropertyField.stringValue = [NSString stringWithString:((value != nil) ? value : @"")];
        }
      }
    }
  }
}


@end
