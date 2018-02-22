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

#import "FXModel.h"
#import "FXShape.h"
#import "VoltaLibrary.h"
#import "FXVoltaLibraryUtilities.h"

NSString* FXPasteboardDataTypeModel = @"fish.robo.volta.library.model";
NSString* FXPasteboardDataTypeModelGroup = @"fish.robo.volta.library.model-group";


@interface FXModel ()
@property id<FXShape> shape;
@end


@implementation FXModel
{
@protected
  VoltaPTModelPtr mModel;
  id<VoltaLibrary> mLibrary;
}

//@synthesize persistentModel = mModel; // FORBIDDEN because @synthesize and std::shared_ptr don't play together nicely.
@synthesize library = mLibrary;

- (id) initWithPersistentModel:(VoltaPTModelPtr)model
{
  self = [super init];
  mModel = model;
  return self;
}


- (void) dealloc
{
  self.displaySettings = nil;
  self.shape = nil;
  FXRelease(mLibrary)
  FXDeallocSuper
}


- (NSString*) description
{
  return [NSString stringWithFormat:@"<%@ 0x%qx: %@ (%@)>", [self className], (unsigned long long)self, [self name], [self vendor]];
}


- (VoltaPTModelPtr) persistentModel
{
  return mModel;
}


- (BOOL) isMutable
{
  if ( mModel.get() != nullptr )
  {
    return mModel->isMutable;
  }
  return NO;
}


- (NSString*) name
{
  if ( mModel.get() != nullptr )
  {
    NSString* nameStr = (__bridge NSString*)mModel->name.cfString();
    if ( nameStr != nil )
    {
      return [NSString stringWithString:nameStr];
    }
  }
  return nil;
}


- (VoltaModelType) type
{
  if ( mModel.get() != nullptr )
  {
    return mModel->type;
  }
  return VMT_Unknown;
}


- (NSString*) subtype
{
  if ( mModel.get() != nullptr )
  {
    NSString* subtypeStr = (__bridge NSString*)mModel->subtype.cfString();
    if ( subtypeStr != nil )
    {
      return [NSString stringWithString:subtypeStr];
    }
  }
  return nil;
}


- (NSString*) vendor
{
  if ( mModel.get() != nullptr )
  {
    return [NSString stringWithString:(__bridge NSString*)mModel->vendor.cfString()];
  }
  return nil;
}


- (NSURL*) source
{
  return mModel->source.empty() ? nil : [NSURL URLWithString:(__bridge NSString*)mModel->source.cfString()];
}


- (BOOL) isEqual:(id)anObject
{
  if ( anObject == nil )
    return NO;
  if ( anObject == self )
    return YES;
  if ( ![anObject isKindOfClass:[FXModel class]] )
    return NO;
  FXModel* aModel = anObject;
  return mModel == [aModel persistentModel];
}


#pragma mark NSCoding
#pragma mark Encoding must only be done for copying purposes, like drag&drop.
#pragma mark NOT FOR STORING! POINTERS ARE DECODED!


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeInt64:(int64_t)(&mModel) forKey:@"Model"]; // Note: Encoding the address of the smart pointer object.
  if ( self.displaySettings != nil )
  {
    [encoder encodeObject:self.displaySettings forKey:@"displaySettings"];
  }
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  mModel = *((VoltaPTModelPtr*)[decoder decodeInt64ForKey:@"Model"]);
  self.displaySettings = [decoder decodeObjectForKey:@"displaySettings"];
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXModel* copy = [[[self class] alloc] initWithPersistentModel:mModel];
  copy.shape = self.shape;
  copy->mLibrary = [self library];
  FXRetain(copy->mLibrary)
  return copy;
}


#pragma mark NSPasteboardWriting


- (id) pasteboardPropertyListForType:(NSString*)type
{
  return [NSKeyedArchiver archivedDataWithRootObject:self];
}


- (NSArray*) writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
  return @[FXPasteboardDataTypeModel];
}


- (NSPasteboardWritingOptions) writingOptionsForType:(NSString*)type pasteboard:(NSPasteboard*)pasteboard
{
  return NSPasteboardWritingPromised;
}


#pragma mark NSPasteboardReading


+ (NSArray*) readableTypesForPasteboard:(NSPasteboard*)pasteboard
{
  return @[FXPasteboardDataTypeModel];
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

@end


#pragma mark - 


@implementation FXMutableModel
@dynamic shape;

- (void) setName:(NSString*)newName
{
  if ( mModel.get() != nullptr )
  {
    mModel->name = (__bridge CFStringRef)newName;
  }
}


- (void) setVendor:(NSString*)newVendor
{
  if ( mModel.get() != nullptr )
  {
    mModel->vendor = (__bridge CFStringRef)newVendor;
  }
}


- (void) setLibrary:(id<VoltaLibrary>)library
{
  if ( library != mLibrary )
  {
    FXRelease(mLibrary)
    mLibrary = library;
    FXRetain(mLibrary)
  }
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [super encodeWithCoder:encoder];
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super initWithCoder:decoder];
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXMutableModel* copy = [[[self class] alloc] initWithPersistentModel:mModel];
  copy.shape = self.shape;
  copy.library = self.library;
  return copy;
}


@end
