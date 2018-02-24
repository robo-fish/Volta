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

#import "FXElement.h"

NSString* FXPasteboardDataTypeElement = @"fish.robo.volta.library.element";


@interface FXElement ()
@property (nonatomic, copy) NSString* name;
@property (nonatomic) VoltaModelType type;
@property (nonatomic, copy) NSString* modelName;
@property (nonatomic, copy) NSString* modelVendor;
@property (nonatomic) NSMutableDictionary* properties;
@property (nonatomic) VoltaPTLabelPosition labelPosition;
@end


@implementation FXElement


- (id) initWithElement:(VoltaPTElement)element
{
  self = [super init];
  self.name = [NSString stringWithString:(__bridge NSString*)element.name.cfString()];
  self.type = element.type;
  self.modelName = [NSString stringWithString:(__bridge NSString*)element.modelName.cfString()];
  self.modelVendor = [NSString stringWithString:(__bridge NSString*)element.modelVendor.cfString()];
  self.labelPosition = element.labelPosition;
  NSMutableDictionary* properties = [[NSMutableDictionary alloc] initWithCapacity:10];
  for ( VoltaPTProperty property : element.properties )
  {
    if ( !property.value.empty() )
    {
      NSString* propertyValue = [NSString stringWithString:(__bridge NSString*)property.value.cfString()];
      NSString* propertyKey = [NSString stringWithString:(__bridge NSString*)property.name.cfString()];
      properties[propertyKey] = propertyValue;
    }
  }
  self.properties = properties;
  FXRelease(properties)
  return self;
}


- (void) dealloc
{
  self.name = nil;
  self.modelName = nil;
  self.modelVendor = nil;
  self.properties = nil;
  self.displaySettings = nil;
  FXDeallocSuper
}


- (NSString*) description
{
  return [NSString stringWithFormat:@"<%@ 0x%qx: %@ [model: %@ (%@)]>", [self className], (unsigned long long)self, [self name], [self modelName], [self modelVendor]];
}


- (VoltaPTElement) toElement
{
  VoltaPTElement result;
  result.name = (__bridge CFStringRef)self.name;
  result.type = self.type;
  result.modelName = (__bridge CFStringRef)self.modelName;
  result.modelVendor = (__bridge CFStringRef)self.modelVendor;
  result.labelPosition = self.labelPosition;
  for ( NSString* key in self.properties.allKeys )
  {
    result.properties.push_back(VoltaPTProperty((__bridge CFStringRef)key, (__bridge CFStringRef)self.properties[key]));
  }
  return result;
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:self.name forKey:@"name"];
  [encoder encodeInt:self.type forKey:@"type"];
  [encoder encodeObject:self.modelName forKey:@"modelName"];
  [encoder encodeObject:self.modelVendor forKey:@"modelVendor"];
  [encoder encodeObject:self.properties forKey:@"properties"];
  [encoder encodeInt:(int)self.labelPosition forKey:@"labelPosition"];
  [encoder encodeObject:self.displaySettings forKey:@"displaySettings"];
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  self.name = [decoder decodeObjectForKey:@"name"];
  self.type = (VoltaModelType)[decoder decodeIntForKey:@"type"];
  self.modelName = [decoder decodeObjectForKey:@"modelName"];
  self.modelVendor = [decoder decodeObjectForKey:@"modelVendor"];
  self.labelPosition = (VoltaPTLabelPosition)[decoder decodeIntForKey:@"labelPosition"];
  _properties = [decoder decodeObjectForKey:@"properties"];
  FXRetain(_properties)
  self.displaySettings = (NSMutableDictionary*)[decoder decodeObjectForKey:@"displaySettings"];
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXElement* copy = [[[self class] alloc] init];
  copy.name = self.name;
  copy.type = self.type;
  copy.modelName = self.modelName;
  copy.modelVendor = self.modelVendor;
  copy.labelPosition = self.labelPosition;
  copy.properties = self.properties;
  return copy;
}


#pragma mark NSPasteboardWriting


- (id) pasteboardPropertyListForType:(NSString*)type
{
  return [NSKeyedArchiver archivedDataWithRootObject:self];
}


- (NSArray*) writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
  return @[FXPasteboardDataTypeElement];
}


- (NSPasteboardWritingOptions) writingOptionsForType:(NSString*)type pasteboard:(NSPasteboard*)pasteboard
{
  return NSPasteboardWritingPromised;
}


#pragma mark NSPasteboardReading


+ (NSArray*) readableTypesForPasteboard:(NSPasteboard*)pasteboard
{
  return @[FXPasteboardDataTypeElement];
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
