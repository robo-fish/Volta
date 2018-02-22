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

#import "FXElementGroup.h"
#import "FXElement.h"


NSString* FXPasteboardDataTypeElementGroup = @"fish.robo.volta.library.element-group";

@interface FXElementGroup ()
@property (nonatomic, copy) NSString* name;
@property (nonatomic) NSMutableArray* elements;
@end


@implementation FXElementGroup
{
@private
  NSMutableArray* mElements;
  NSString* mName;
}

@synthesize elements = mElements;
@synthesize name = mName;

- (id) initWithElementGroup:(VoltaPTElementGroup)elementGroup
{
  self = [super init];
  mElements = [[NSMutableArray alloc] initWithCapacity:elementGroup.elements.size()];
  mName = [[NSString alloc] initWithString:(__bridge NSString*)elementGroup.name.cfString()];
  for ( VoltaPTElement element : elementGroup.elements )
  {
    FXElement* elementWrapper = [[FXElement alloc] initWithElement:element];
    [mElements addObject:elementWrapper];
    FXRelease(elementWrapper)
  }
  return self;
}

- (void) dealloc
{
  FXRelease(mElements)
  FXRelease(mName)
  FXDeallocSuper
}


- (NSString*) description
{
  return [NSString stringWithFormat:@"%@ 0x%qx %@\n%@>", [self className], (unsigned long long)self, [self name], [self elements]];
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:mElements forKey:@"elements"];
  [encoder encodeObject:mName forKey:@"name"];
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  mName = [decoder decodeObjectForKey:@"name"];
  FXRetain(mName)
  mElements = [decoder decodeObjectForKey:@"elements"];
  FXRetain(mElements)
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXElementGroup* copy = [[[self class] alloc] init];
  copy.name = self.name;
  copy.elements = self.elements;
  return copy;
}


#pragma mark NSPasteboardWriting


- (id) pasteboardPropertyListForType:(NSString*)type
{
  return [NSKeyedArchiver archivedDataWithRootObject:self];
}


- (NSArray*) writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
  return @[FXPasteboardDataTypeElementGroup];
}


- (NSPasteboardWritingOptions) writingOptionsForType:(NSString*)type pasteboard:(NSPasteboard*)pasteboard
{
  return NSPasteboardWritingPromised;
}


#pragma mark NSPasteboardReading


+ (NSArray*) readableTypesForPasteboard:(NSPasteboard*)pasteboard
{
  return @[FXPasteboardDataTypeElementGroup];
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

