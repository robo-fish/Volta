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

#import "FXLibraryEditorModelsCellView.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXShapeView.h"
#import "FXShapeRenderer.h"
#import "FXVoltaLibrary.h"
#import "FXVoltaLibraryUtilities.h"

NSString* const FXLibraryEditorCell_EditedProperties           = @"FXLibraryEditorCell_EditedProperties";


@implementation FXLibraryEditorModelsCellView
{
@private
  id<FXLibraryEditorModelsCellViewClient> __weak mClient;
  VoltaPTModel mModel;
  FXModel* mRepresentedModel;
  NSMutableArray* mPropertyKeys;
}
@synthesize client = mClient;


- (id) initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if ( self != nil )
  {
    self.showsLockSymbol = YES;
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mRepresentedModel)
  FXDeallocSuper
}


#pragma mark Public


- (void) setModel:(FXModel*)model
{
  @synchronized(self)
  {
    if ( (mRepresentedModel != model) && ([model persistentModel].get() != nullptr) )
    {
      FXRelease(mRepresentedModel)
      mRepresentedModel = model;
      FXRetain(mRepresentedModel)

      mModel = *[model persistentModel];

      self.isEditable = self.isEditable && mModel.isMutable;
      self.primaryField.stringValue = [FXVoltaLibraryUtilities userVisibleNameForModelName:(__bridge NSString*)mModel.name.cfString()];
      self.primaryField.editable = self.isEditable;
      self.secondaryField.stringValue = [NSString stringWithString:(__bridge NSString*)mModel.vendor.cfString()];
      self.secondaryField.editable = self.isEditable;
      id<FXShape> shape = [model shape];
      if ( shape == nil )
      {
        if ( model.library != nil )
        {
          shape = [model.library shapeForModelType:model.type name:model.name vendor:model.vendor];
        }
      }
      if ( (model.type == VMT_DECO) && [model.subtype isEqualToString:@"TEXT"] )
      {
        mShapeView.shapeAttributes = @{ @"text" : FXLocalizedString(@"SingleLineTextModelText") };
      }
      [self setShape:shape];
      [self updateModelPropertyKeys];
      [self addShapeAttributesToDisplaySettingsOfRepresentedModel];
    }
  }
  [super updateDisplay];

  NSNumber* edited_ = [self valueForDisplaySettingWithName:FXLibraryEditorCell_PropertiesHaveBeenEdited];
  BOOL const edited = (edited_ != nil) && [edited_ boolValue];
  if ( edited )
  {
    NSMutableDictionary* editedProperties = (NSMutableDictionary*)[self valueForDisplaySettingWithName:FXLibraryEditorCell_EditedProperties];
    if ( editedProperties != nil )
    {
      for ( NSString* propertyName in editedProperties.allKeys )
      {
        [self setValue:editedProperties[propertyName] ofPropertyForKey:propertyName];
      }
    }
  }
}


#pragma mark FXLibraryEditorCellView overrides


- (NSString*) valueOfPropertyForKey:(id)key
{
  @synchronized(self)
  {
    for ( VoltaPTProperty const & property : mModel.properties )
    {
      if ( [(NSString*)key isEqualToString:(__bridge NSString*)property.name.cfString()] )
      {
        return [NSString stringWithString:(__bridge NSString*)property.value.cfString()];
      }
    }
    return nil;
  }
}


- (void) setValue:(NSString*)value ofPropertyForKey:(id)key
{
  @synchronized(self)
  {
    for ( VoltaPTProperty & property : mModel.properties )
    {
      if ( [(NSString*)key isEqualToString:(__bridge NSString*)property.name.cfString()] )
      {
        property.value = (__bridge CFStringRef)value;
        break;
      }
    }

    NSMutableDictionary* editedProperties = (NSMutableDictionary*)[self valueForDisplaySettingWithName:FXLibraryEditorCell_EditedProperties];
    if ( editedProperties == nil )
    {
      editedProperties = [NSMutableDictionary dictionaryWithCapacity:5];
    }
    editedProperties[key] = value;
    [self setValue:editedProperties forDisplaySettingWithName:FXLibraryEditorCell_EditedProperties];
  }
}


- (void) handleNewPrimaryFieldValue:(NSString*)value
{
  [self.client handleNewName:value forModel:mRepresentedModel inCellView:self];
}


- (void) handleNewSecondaryFieldValue:(NSString*)value
{
  [self.client handleNewVendor:value forModel:mRepresentedModel inCellView:self];
}


- (void) handleNewSinglePropertyFieldValue:(NSString*)value forKey:(id)key
{
  // ignore
}


- (void) handleApplyPropertyTableChanges
{
  @synchronized(self)
  {
    [self.client handleNewProperties:mModel.properties forModel:mRepresentedModel inCellView:self];
    NSMutableDictionary* editedProperties = (NSMutableDictionary*)[self valueForDisplaySettingWithName:FXLibraryEditorCell_EditedProperties];
    [editedProperties removeAllObjects];
  }
}


- (void) setValue:(id)value forDisplaySettingWithName:(NSString*)settingName
{
  if ( mRepresentedModel.displaySettings == nil )
  {
    mRepresentedModel.displaySettings = [NSMutableDictionary dictionaryWithCapacity:2];
  }
  mRepresentedModel.displaySettings[settingName] = value;
}


- (id) valueForDisplaySettingWithName:(NSString*)settingName
{
  return mRepresentedModel.displaySettings[settingName];
}


#pragma mark Private


- (void) updateModelPropertyKeys
{
  @synchronized(self)
  {
    NSMutableArray* keys = [NSMutableArray arrayWithCapacity:mModel.properties.size()];
    for ( VoltaPTProperty const & property : mModel.properties )
    {
      [keys addObject:[NSString stringWithString:(__bridge NSString*)property.name.cfString()]];
    }
    [super setPropertyKeys:keys];
  }
}


- (void) addShapeAttributesToDisplaySettingsOfRepresentedModel
{
  if (mRepresentedModel.displaySettings == nil)
  {
    mRepresentedModel.displaySettings = [NSMutableDictionary dictionaryWithDictionary:mShapeView.shape.attributes];
  }
  else
  {
    [mRepresentedModel.displaySettings addEntriesFromDictionary:mShapeView.shape.attributes];
  }
}


@end

