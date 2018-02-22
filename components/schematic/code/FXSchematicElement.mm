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

#import "FXSchematicElement.h"
#import "VoltaSchematic.h"
#import "VoltaLibrary.h"
#import "FXShape.h"
#import "FXVector.h"

NSString* VoltaSchematicElementUpdateNotification = @"VoltaSchematicElementUpdateNotification";
NSString* FXPasteboardDataTypeSchematicElement = @"fish.robo.volta.schematic.element";

@interface FXSchematicElement ()
@property (nonatomic) id<FXShape> shape;
@property NSDictionary* properties;
@end


@implementation FXSchematicElement
{
@private
  NSString*                 mName;
  NSString*                 mModelName;
  id<FXShape>               mShape;
  NSString*                 mModelVendor;
  CGFloat                   mRotation;
  BOOL                      mFlipped;
  FXPoint                   mLocation;
  VoltaModelType            mType;
  SchematicRelativePosition mLabelPosition;
  NSMutableDictionary*      mProperties;               ///< model properties
  id<VoltaSchematic> __weak mSchematic;
}

- (id) init
{
  if ( (self = [super init]) != nil )
  {
    mProperties = [[NSMutableDictionary alloc] init];
    mLocation.x = 0.0f;
    mLocation.y = 0.0f;
    mRotation = 0.0f;
    mType = VMT_Unknown;
    mFlipped = NO;
    mLabelPosition = SchematicRelativePosition_None;
  }
  return self;
}

- (void) dealloc
{
  self.shape = nil;
  self.name = nil;
  self.modelName = nil;
  self.modelVendor = nil;
  FXRelease(mProperties)
  mProperties = nil;
  FXDeallocSuper
}

@synthesize name = mName;
@synthesize modelName = mModelName;
@synthesize modelVendor = mModelVendor;
@synthesize shape = mShape;
@synthesize rotation = mRotation;
@synthesize flipped = mFlipped;
@synthesize location = mLocation;
@synthesize type = mType;
@synthesize schematic = mSchematic;
@synthesize labelPosition = mLabelPosition;
@synthesize properties = mProperties;


#pragma mark Public


- (void) setModelName:(NSString*)modelName
{
  if (modelName != mModelName)
  {
    FXRelease(mModelName)
    mModelName = [modelName copy];
    self.shape = nil;
  }
}


- (void) setModelVendor:(NSString*)modelVendor
{
  if (modelVendor != mModelVendor)
  {
    FXRelease(mModelVendor)
    mModelVendor = [modelVendor copy];
    self.shape = nil;
  }
}


- (NSUInteger) numberOfProperties
{
  return [mProperties count];
}


- (void) enumeratePropertiesUsingBlock:(void (^)(NSString* key, id value, BOOL* stop))block
{
  [mProperties enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL* stop) {
    block((NSString*)key, value, stop);
  }];
}


- (id) propertyValueForKey:(NSString*)key
{
  return [mProperties objectForKey:key];
}


- (void) setPropertyValue:(id)value forKey:(NSString*)key;
{
  if (key != nil)
  {
    if ( value == nil )
    {
      [mProperties removeObjectForKey:key];
    }
    else
    {
      [mProperties setObject:value forKey:key];
    }
  }
}


- (void) removeAllProperties
{
  [mProperties removeAllObjects];
}


- (CGSize) size
{
  CGSize result = CGSizeZero;
  id<FXShape> shape = [self shape];
  if ( shape != nil )
  {
    FXVector v1( 0.0f, shape.size.height );
    FXVector v2( shape.size.width, 0.0f );
    v1.rotate( mRotation );
    v2.rotate( mRotation );
    result = CGSizeMake( abs(v1.x - v2.x), abs(v1.y - v2.y) );
  }
  return result;
}


- (CGRect) boundingBox
{
  CGRect result = CGRectZero;

  CGSize const shapeSize = self.shape.size;

  FXVector v1( -shapeSize.width/2.0, -shapeSize.height/2.0 );
  FXVector v2( shapeSize.width/2.0, -shapeSize.height/2.0 );
  FXVector v3( shapeSize.width/2.0, shapeSize.height/2.0 );
  FXVector v4( -shapeSize.width/2.0, shapeSize.height/2.0 );

  v1.rotate(mRotation);
  v2.rotate(mRotation);
  v3.rotate(mRotation);
  v4.rotate(mRotation);

  result.origin.x = MIN( v1.x, MIN( v2.x, MIN( v3.x, v4.x ) ) );
  result.origin.y = MIN( v1.y, MIN( v2.y, MIN( v3.y, v4.y ) ) );
  result.size.width = MAX( v1.x, MAX( v2.x, MAX( v3.x, v4.x ) ) ) - result.origin.x;
  result.size.height = MAX( v1.y, MAX( v2.y, MAX( v3.y, v4.y ) ) ) - result.origin.y;
  result.origin.x += mLocation.x;
  result.origin.y += mLocation.y;

  return result;
}


- (id<FXShape>) shape
{
  if ( mShape == nil )
  {
    mShape = [[mSchematic library] shapeForModelType:mType name:mModelName vendor:mModelVendor];
    FXRetain(mShape)
  }
  return mShape;
}


- (void) prepareShapeForDrawing
{
  if ( self.shape.doesOwnDrawing )
  {
    self.shape.attributes = mProperties;
  }
}


#pragma mark NSObject overrides


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
  return [self isEqualToSchematicElement:anObject];
}


- (NSUInteger) hash
{
  // Note: We can't use [mName hash] because the name of an element can change.
  // The hash must be constant during the lifetime of the object.
  return [super hash];
}


- (NSString*) description
{
  return [NSString stringWithFormat:@"%p %@-%@-%@ at (%.0g,%.0g)", self, mModelVendor, mModelName, mName, mLocation.x, mLocation.y];
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:mName             forKey:@"Name"];
  [encoder encodeObject:mModelName        forKey:@"Model Name"];
  [encoder encodeObject:mModelVendor      forKey:@"Model Vendor"];
  [encoder encodeInteger:(NSInteger)mType forKey:@"Model Type"];
  [encoder encodeFloat:mRotation          forKey:@"Rotation"];
  [encoder encodePoint:mLocation          forKey:@"Location"];
  [encoder encodeObject:mProperties       forKey:@"Model Properties"];
  [encoder encodeInteger:mLabelPosition   forKey:@"Label Position"];
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  mName             = [decoder decodeObjectForKey:@"Name"]; FXRetain(mName)
  mModelName        = [decoder decodeObjectForKey:@"Model Name"]; FXRetain(mModelName)
  mModelVendor      = [decoder decodeObjectForKey:@"Model Vendor"]; FXRetain(mModelVendor)
  mType             = (VoltaModelType)[decoder decodeIntegerForKey:@"Model Type"];
  mRotation         = [decoder decodeFloatForKey:@"Rotation"];
  mLocation         = [decoder decodePointForKey:@"Location"];
  mProperties       = [decoder decodeObjectForKey:@"Model Properties"]; FXRetain(mProperties)
  mLabelPosition    = (SchematicRelativePosition)[decoder decodeIntegerForKey:@"Label Position"];
  mSchematic = nil;
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone *)zone
{
  FX(FXSchematicElement)* newElement = [[[self class] allocWithZone:zone] init];
  [newElement setName: [self name]];
  [newElement setModelName: [self modelName]];
  [newElement setModelVendor: [self modelVendor]];
  [newElement setLocation: [self location]];
  [newElement setRotation: [self rotation]];
  [newElement setType: [self type]];
  NSMutableDictionary* copiedProperties = [[NSMutableDictionary alloc] initWithDictionary:self.properties copyItems:YES];
  [newElement setProperties: copiedProperties];
  FXRelease(copiedProperties)
  [newElement setLabelPosition: [self labelPosition]];
  [newElement setSchematic: [self schematic]];
  return newElement;
}



#pragma mark NSPasteboardWriting


- (id) pasteboardPropertyListForType:(NSString*)type
{
  return [NSKeyedArchiver archivedDataWithRootObject:self];
}


- (NSArray*) writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
  return @[FXPasteboardDataTypeSchematicElement];
}


- (NSPasteboardWritingOptions) writingOptionsForType:(NSString*)type pasteboard:(NSPasteboard*)pasteboard
{
  return NSPasteboardWritingPromised;
}


#pragma mark NSPasteboardReading


+ (NSArray*) readableTypesForPasteboard:(NSPasteboard*)pasteboard
{
  return @[FXPasteboardDataTypeSchematicElement];
}


+ (NSPasteboardReadingOptions) readingOptionsForType:(NSString*)type pasteboard:(NSPasteboard*)pasteboard
{
  return NSPasteboardReadingAsData;
}


- (id) initWithPasteboardPropertyList:(id)data ofType:(NSString *)type
{
  FXRelease(self)
  self = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  FXRetain(self)
  return self;
}


#pragma mark Private


- (BOOL) isEqualToSchematicElement:(id<VoltaSchematicElement>)otherElement
{
  if ( self == otherElement )
  {
    return YES;
  }
  if ( mType != [otherElement type] )
  {
    return NO;
  }
  if ( ![mName isEqualToString:[otherElement name]] )
  {
    return NO;
  }
  return [mModelVendor isEqualToString:[otherElement modelVendor]];
}


@end
