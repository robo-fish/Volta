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

#import "FXFileBrowserTableView.h"


@implementation FXFileBrowserTableView


- (void) awakeFromNib
{
  [self registerForDraggedTypes:@[(__bridge NSString*)kUTTypeFileURL]];
  [self setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
}


#pragma mark NSDraggingDestination


- (BOOL) prepareForDragOperation:(id<NSDraggingInfo>)info
{
  NSArray* droppedItems = [[info draggingPasteboard] pasteboardItems];
  BOOL fileIsDragged = NO;
  for (NSPasteboardItem* item in droppedItems)
  {
    for (NSString* UTIType in [item types])
    {
      if ( [UTIType isEqualToString:(__bridge NSString*)kUTTypeFileURL] )
      {
        fileIsDragged = YES;
        break;
      }
    }
    if ( fileIsDragged )
    {
      break;
    }
  }
  return fileIsDragged;
}


- (BOOL) performDragOperation:(id<NSDraggingInfo>)info
{
  NSArray* droppedItems = [[info draggingPasteboard] pasteboardItems];
  NSMutableArray* fileURLs = [NSMutableArray arrayWithCapacity:[droppedItems count]];
  for (NSPasteboardItem* item in droppedItems)
  {
    BOOL itemIsFile = NO;
    for (NSString* UTIType in [item types])
    {
      if ( [UTIType isEqualToString:(__bridge NSString*)kUTTypeFileURL] )
      {
        itemIsFile = YES;
        break;
      }
    }
    if ( itemIsFile )
    {
      NSString* URLString = [item stringForType:(__bridge NSString*)kUTTypeFileURL];
      NSURL* fileLocation = [NSURL URLWithString:URLString];
      [fileURLs addObject:fileLocation];
    }
  }
  if ( ([fileURLs count] > 0) && (self.client != nil) )
  {
    return [self.client handleDroppedFiles:fileURLs];
  }
  return NO;
}


@end
