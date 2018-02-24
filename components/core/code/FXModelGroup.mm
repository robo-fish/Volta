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

#import "FXModelGroup.h"
#import "FXModel.h"
#import <VoltaCore/VoltaLibraryProtocol.h>

NSString* FXVoltaLibraryPasteboardTypeModelGroup = @"fish.robo.volta.library.model-group";

@implementation FXModelGroup
{
@private
  NSMutableArray* mModels;
  VoltaPTModelGroupPtr mGroup;
}

@synthesize models = mModels;
//@synthesize group = mGroup; // FORBIDDEN because @synthesize and shared_ptr don't play together nicely.

- (id) initWithPersistentGroup:(VoltaPTModelGroupPtr)group library:(id<VoltaLibrary>)modelLibrary
{
  self = [super init];
  mGroup = group;
  mModels = [[NSMutableArray alloc] initWithCapacity:group->models.size()];
  for( VoltaPTModelPtr & model : group->models )
  {
    FX(FXMutableModel)* modelWrapper = [[FX(FXMutableModel) alloc] initWithPersistentModel:model];
    [modelWrapper setLibrary:modelLibrary];
    [mModels addObject:modelWrapper];
    FXRelease(modelWrapper)
  }
  return self;
}

- (void) dealloc
{
  FXRelease(mModels)
  FXDeallocSuper
}


#pragma NSObject overrides


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
  return mGroup == [(FXModelGroup*)anObject persistentGroup];
}

- (NSString*) description
{
  return [self name];
}

- (NSUInteger) hash
{
  return [[self name] hash];
}


#pragma mark Public


- (VoltaPTModelGroupPtr) persistentGroup
{
  return mGroup;
}

- (BOOL) isMutable
{
  NSAssert( mGroup.get() != nullptr, @"VoltaPTModelGroupPtr is empty." );
  if ( mGroup.get() != nullptr )
  {
    return mGroup->isMutable;
  }
  return NO;
}

- (NSString*) name
{
  NSAssert( mGroup.get() != nullptr, @"VoltaPTModelGroupPtr is empty." );
  if ( mGroup.get() != nullptr )
  {
    NSString* nameStr = (__bridge NSString*)mGroup->name.cfString();
    if ( nameStr != nil )
    {
      return [NSString stringWithString:nameStr];
    }
  }
  return nil;
}

- (void) setName:(NSString*)newName
{
  NSAssert( mGroup.get() != nullptr, @"VoltaPTModelGroupPtr is empty." );
  if ( mGroup.get() != nullptr )
  {
    mGroup->name = (__bridge CFStringRef)newName;
  }
}

- (void) setModels:(NSArray*)newModels
{
  [mModels removeAllObjects];
  [mModels addObjectsFromArray:newModels];
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:[self name] forKey:@"Name"];
  [encoder encodeObject:mModels forKey:@"Models"];
  [encoder encodeBool:[self isMutable] forKey:@"IsMutable"];
  [encoder encodeInt64:(int64_t)(&mGroup) forKey:@"Group"]; // Note: Encoding the address of the smart pointer object
}

- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  mModels = [decoder decodeObjectForKey:@"Models"];
  FXRetain(mModels)
  mGroup = *((VoltaPTModelGroupPtr*)[decoder decodeInt64ForKey:@"Group"]);
  [self setName:[decoder decodeObjectForKey:@"Name"]]; // Important: Comes after mGroup is set.
  return self;
}


#pragma mark NSPasteboardWriting


- (id) pasteboardPropertyListForType:(NSString*)type
{
  return [NSKeyedArchiver archivedDataWithRootObject:self];
}

- (NSArray*) writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
  return @[FXVoltaLibraryPasteboardTypeModelGroup];
}

- (NSPasteboardWritingOptions) writingOptionsForType:(NSString*)type pasteboard:(NSPasteboard*)pasteboard
{
  return NSPasteboardWritingPromised;
}


#pragma mark NSPasteboardReading


+ (NSArray*) readableTypesForPasteboard:(NSPasteboard*)pasteboard
{
  return @[FXVoltaLibraryPasteboardTypeModelGroup];
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
