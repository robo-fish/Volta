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

#import "FXFileBrowserFileData.h"

@interface FXFileBrowserFileData ()
@property NSString* fileName;
@property NSDate* lastModified;
@property NSUInteger sizeInBytes;
@property NSURL* location; // NSURL implements NSPasteboardWriting
@end


@implementation FXFileBrowserFileData


#pragma mark Public

- (id) initWithLocation:(NSURL*)fileLocation modificationDate:(NSDate*)lastModified size:(NSUInteger)fileSize
{
  self = [super init];
  self.fileName = [fileLocation lastPathComponent];
  self.lastModified = lastModified;
  self.sizeInBytes = fileSize;
  self.location = fileLocation;
  return self;
}


+ (id) fileDataWithLocation:(NSURL*)fileLocation modificationDate:(NSDate*)lastModified size:(NSUInteger)fileSize
{
  FXFileBrowserFileData* fileData = [[FXFileBrowserFileData alloc] initWithLocation:fileLocation modificationDate:lastModified size:fileSize];
  FXAutorelease(fileData)
  return fileData;
}


- (NSComparisonResult) compare:(FXFileBrowserFileData*)other
{
  return [self.fileName localizedCaseInsensitiveCompare:other.fileName];
}


- (NSString *)description
{
  return [NSString stringWithFormat:@"%@ : %@", [super description], [self.location path]];
}


#pragma mark NSPasteboardWriting


- (id) pasteboardPropertyListForType:(NSString*)type
{
  return [self.location pasteboardPropertyListForType:type];
}


- (NSArray*) writableTypesForPasteboard:(NSPasteboard*)pasteboard
{
  return [self.location writableTypesForPasteboard:pasteboard];
}


- (NSPasteboardWritingOptions) writingOptionsForType:(NSString*)type pasteboard:(NSPasteboard*)pasteboard
{
  if ([self.location respondsToSelector:@selector(writingOptionsForType:pasteboard:)])
  {
    return [self.location writingOptionsForType:type pasteboard:pasteboard];
  }
  return 0;
}


#pragma mark NSPasteboardReading


+ (NSArray*) readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
  return @[(__bridge NSString*)kUTTypeFileURL, NSURLPboardType];
}


+ (NSPasteboardReadingOptions) readingOptionsForType:(NSString*)type pasteboard:(NSPasteboard*)pasteboard
{
  return NSPasteboardReadingAsString;
}


- (id) initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type
{
  FXRelease(self)
  NSURL* someURL = [[NSURL alloc] initWithPasteboardPropertyList:propertyList ofType:type];
  self = [[FXFileBrowserFileData alloc] initWithLocation:someURL modificationDate:nil size:0];
  FXRetain(someURL)
  return self;
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:self.fileName forKey:@"file name"];
  [coder encodeObject:self.lastModified forKey:@"last modified"];
  [coder encodeObject:self.location forKey:@"location"];
  [coder encodeInteger:self.sizeInBytes forKey:@"size"];
}


- (id) initWithCoder:(NSCoder *)decoder
{
  self = [super init];
  self.fileName = [decoder decodeObjectForKey:@"file name"];
  self.lastModified = [decoder decodeObjectForKey:@"last modified"];
  self.location = [decoder decodeObjectForKey:@"location"];
  self.sizeInBytes = [decoder decodeIntegerForKey:@"size"];
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXFileBrowserFileData* copy = [[[self class] alloc] initWithLocation:self.location modificationDate:self.lastModified size:self.sizeInBytes];
  return copy;
}



@end
