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

#import "FXVoltaLibraryShapeRepository.h"
#import "FXShape.h"
#import "FXShapeFactory.h"


@interface FXVoltaLibraryShapeKey : NSObject <NSCopying>

@property VoltaModelType modelType;
@property (copy) NSString* subtype;
@property (copy) NSString* modelName;
@property (copy) NSString* modelVendor;

/// designated initializer
- (id) initWithType:(VoltaModelType)type subtype:(NSString*)subtype name:(NSString*)name vendor:(NSString*)vendor;

+ (id) keyWithType:(VoltaModelType)type subtype:(NSString*)subtype name:(NSString*)name vendor:(NSString*)vendor;

@end


@implementation FXVoltaLibraryShapeKey

- (id) initWithType:(VoltaModelType)type subtype:(NSString*)subtype name:(NSString*)name  vendor:(NSString*)vendor
{
  self = [super init];
  self.subtype = subtype;
  self.modelName = name;
  self.modelType = type;
  self.modelVendor = vendor;
  return self;
}

+ (id) keyWithType:(VoltaModelType)type subtype:(NSString*)subtype name:(NSString*)name  vendor:(NSString*)vendor
{
  FXVoltaLibraryShapeKey* key = [[self alloc] initWithType:type subtype:subtype name:name vendor:vendor];
  FXAutorelease(key)
  return key;
}

- (void) dealloc
{
  self.subtype = nil;
  self.modelName = nil;
  self.modelVendor = nil;
  FXDeallocSuper
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
  FXVoltaLibraryShapeKey* aKey = anObject;
  if ( (self.modelVendor == nil) || ([anObject modelVendor] == nil) )
  {
    return (self.modelType == aKey.modelType) && [self.subtype isEqualToString:aKey.subtype] && [self.modelName isEqualToString:aKey.modelName];
  }
  return (self.modelType == aKey.modelType) && [self.subtype isEqualToString:aKey.subtype] && [self.modelName isEqualToString:aKey.modelName] && [self.modelVendor isEqualToString:aKey.modelVendor];
}

- (NSUInteger) hash
{
  return [self.modelName hash] + [self.subtype hash] + (NSUInteger)self.modelType;
}

- (id) copyWithZone:(NSZone*)zone
{
  FXVoltaLibraryShapeKey* newCopy = [[[self class] allocWithZone:zone] init];
  newCopy.modelType = self.modelType;
  newCopy.subtype = self.subtype;
  newCopy.modelName = self.modelName;
  newCopy.modelVendor = self.modelVendor;
  return newCopy;
};

- (NSString*) description
{
  return [NSString stringWithFormat:@"type:%2d \tsubtype:%@ \tname:%@ \tvendor:%@",
    (int)self.modelType,
    self.subtype ? self.subtype : @"",
    self.modelName ? self.modelName : @"",
    self.modelVendor ? self.modelVendor : @""];
}

@end


#pragma mark -


@interface FXVoltaLibraryDefaultShapeKey : NSObject <NSCopying>

@property VoltaModelType modelType;
@property (copy) NSString* subtype;

/// designated initializer
- (id) initWithType:(VoltaModelType)type subtype:(NSString*)subtype;

+ (id) keyWithType:(VoltaModelType)type subtype:(NSString*)subtype;

@end


@implementation FXVoltaLibraryDefaultShapeKey

- (id) initWithType:(VoltaModelType)type subtype:(NSString*)subtype
{
  self = [super init];
  self.subtype = subtype;
  self.modelType = type;
  return self;
}

+ (id) keyWithType:(VoltaModelType)type subtype:(NSString*)subtype
{
  FXVoltaLibraryDefaultShapeKey* key = [[self alloc] initWithType:type subtype:subtype];
  FXAutorelease(key)
  return key;
}

- (void) dealloc
{
  self.subtype = nil;
  FXDeallocSuper
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
  FXVoltaLibraryDefaultShapeKey* aKey = anObject;
  return (self.modelType == aKey.modelType) && [self.subtype isEqualToString:aKey.subtype];
}

- (NSUInteger) hash
{
  return [self.subtype hash] + (NSUInteger)self.modelType;
}

- (id) copyWithZone:(NSZone*)zone
{
  FXVoltaLibraryShapeKey* newCopy = [[[self class] allocWithZone:zone] init];
  newCopy.modelType = self.modelType;
  newCopy.subtype = self.subtype;
  return newCopy;
}

@end


#pragma mark -


@implementation FXVoltaLibraryShapeRepository
{
@private
  NSMutableDictionary* mShapes;
  NSMutableDictionary* mDefaultShapes;
}

- (id) init
{
  if ( (self = [super init]) != nil )
  {
    mShapes = [[NSMutableDictionary alloc] init];
    mDefaultShapes = [[NSMutableDictionary alloc] init];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mDefaultShapes)
  FXRelease(mShapes)
  FXDeallocSuper
}


#pragma mark Public


- (void) addShape:(id<FXShape>)shape
     forModelType:(VoltaModelType)type
          subtype:(NSString*)subtype
             name:(NSString*)modelName
           vendor:(NSString*)vendorName;
{
  @synchronized(self)
  {
    [mShapes setValue:shape forKey:[FXVoltaLibraryShapeKey keyWithType:type subtype:subtype name:modelName vendor:vendorName]];
  }
}


- (void) renameShapeWithType:(VoltaModelType)modelType
                     subtype:(FXString const &)subtype
                     oldName:(FXString const &)oldName
                   oldVendor:(FXString const &)oldVendor
                     newName:(FXString const &)newName
                   newVendor:(FXString const &)newVendor
{
  @synchronized(self)
  {
    FXVoltaLibraryShapeKey* oldKey = [FXVoltaLibraryShapeKey keyWithType:modelType subtype:(__bridge NSString*)subtype.cfString() name:(__bridge NSString*)oldName.cfString() vendor:(__bridge NSString*)oldVendor.cfString()];
    id<FXShape> existingShape = mShapes[oldKey];
    if ( existingShape != nil )
    {
      FXRetain(existingShape)
      [mShapes removeObjectForKey:oldKey];
      FXVoltaLibraryShapeKey* newKey = [FXVoltaLibraryShapeKey keyWithType:modelType subtype:(__bridge NSString*)subtype.cfString() name:(__bridge NSString*)newName.cfString() vendor:(__bridge NSString*)newVendor.cfString()];
      mShapes[newKey] = existingShape;
      FXRelease(existingShape)
    }
  }
}


- (id<FXShape>) findShapeForModelType:(VoltaModelType)modelType
                              subtype:(NSString*)subtype
                                 name:(NSString*)modelName
                               vendor:(NSString*)vendor
                             strategy:(FXShapeSearchStrategy)strategy
{
  __block NSObject<FXShape> * result = nil;
  @synchronized(self)
  {
    if ( strategy == FXShapeSearch_AnySubtype )
    {
      [mShapes enumerateKeysAndObjectsUsingBlock:^(FXVoltaLibraryShapeKey* key, id value, BOOL* stop) {
        if ( (key.modelType == modelType) && [key.modelName isEqualToString:modelName] )
        {
          if ( (vendor != nil) && [key.modelVendor isEqualToString:vendor] )
          {
            result = mShapes[key];
            *stop = YES;
          }
        }
      }];
    }
    else
    {
      result = [mShapes objectForKey:[FXVoltaLibraryShapeKey keyWithType:modelType subtype:subtype name:modelName vendor:vendor]];
    }

    if ( result == nil )
    {
      if ( modelType == VMT_SUBCKT )
      {
        NSLog(@"No shape found for subcircuit \"%@\"%@.", modelName, ([vendor length] > 0) ? [NSString stringWithFormat:@" from \"%@\".", vendor] : @"" );
      }
      else if (modelType != VMT_DECO)
      {
        result = mDefaultShapes[[FXVoltaLibraryDefaultShapeKey keyWithType:modelType subtype:subtype]];
        if ( result == nil )
        {
          DebugLog(@"No shape found for model (%d %@ %@ %@). Every model should have a default shape.", modelType, subtype ? subtype : @"", modelName ? modelName : @"", vendor ? vendor : @"" );
        }
      }
    }
  }
  if ( !result.isReusable )
  {
    result = [result copy];
    FXAutorelease(result)
  }
  return result;
}


- (void) removeShapeForModelType:(VoltaModelType)modelType
                         subtype:(NSString*)subtype
                            name:(NSString*)modelName
                          vendor:(NSString*)vendor
{
  @synchronized(self)
  {
    FXVoltaLibraryShapeKey* key = [FXVoltaLibraryShapeKey keyWithType:modelType subtype:subtype name:modelName vendor:vendor];
    [mShapes removeObjectForKey:key];
  }
}


- (void) createAndStoreShapeForModel:(VoltaPTModelPtr)model
                  makeDefaultForType:(BOOL)makeDefaultShape
{
  @synchronized(self)
  {
    VoltaModelType modelType = model->type;
    id<FXShape> newShape = nil;

    if ( modelType == VMT_SUBCKT )
    {
      newShape = [FXShapeFactory shapeFromMetaData:model->metaData];
    }
    else if ( modelType == VMT_DECO )
    {
      if ( model->subtype == "TEXT" )
      {
        newShape = [FXShapeFactory shapeFromText:FXLocalizedString(@"TextElementDefaultText")];
      }
    }

    if ( newShape == nil )
    {
      newShape = [FXShapeFactory shapeWithPersistentShape:model->shape persistentPins:model->pins];
    }

    NSString* modelSubtype = (__bridge NSString*) model->subtype.cfString();
    if ( modelType != VMT_SUBCKT )
    {
      if ( (newShape != nil) && makeDefaultShape )
      {
        mDefaultShapes[[FXVoltaLibraryDefaultShapeKey keyWithType:modelType subtype:modelSubtype]] = newShape;
      }
      else if ( (newShape == nil) && !makeDefaultShape )
      {
        newShape = mDefaultShapes[[FXVoltaLibraryDefaultShapeKey keyWithType:modelType subtype:modelSubtype]];
      }
    }

    if ( newShape != nil )
    {
      NSString* modelName = (__bridge NSString*) model->name.cfString();
      NSString* vendorName = (__bridge NSString*) model->vendor.cfString();
      [self addShape:newShape forModelType:modelType subtype:modelSubtype name:modelName vendor:vendorName];
    }
  }
}


- (void) removeShapesOfType:(VoltaModelType)targetType
                    subtype:(NSString*)subtype
{
  @synchronized(self)
  {
    NSMutableArray* keysOfShapesToRemove = [NSMutableArray array];
    for ( FXVoltaLibraryShapeKey* key in [mShapes allKeys] )
    {
      if ( (key.modelType == targetType) && [key.subtype isEqualToString:subtype] )
      {
        [keysOfShapesToRemove addObject:key];
      }
    }
    [mShapes removeObjectsForKeys:keysOfShapesToRemove];
  }
}


- (id<FXShape>) defaultShapeForModelType:(VoltaModelType)type subtype:(NSString*)subtype
{
  return mDefaultShapes[[FXVoltaLibraryDefaultShapeKey keyWithType:type subtype:subtype]];
}


@end
