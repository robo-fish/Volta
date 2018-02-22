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

#import "FXFileBrowser.h"
#import "FXFileBrowserFileData.h"
#import "FXFileBrowserTableView.h"

NSString* const FXFileBrowserTableColumnIdentifier_Name = @"name";
NSString* const FXFileBrowserTableColumnIdentifier_Size = @"size";
NSString* const FXFileBrowserTableColumnIdentifier_LastModified = @"modified";


@interface FXFileBrowser () <FXFileBrowserTableViewClient, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
@property (weak) IBOutlet FXFileBrowserTableView* fileTable;
@property BOOL handlingDeleteKey;
@property NSString* identifier;
@end


@implementation FXFileBrowser
{
@private
  NSURL* mRootLocation;
  NSString* mIdentifier;
  NSMutableArray* mFiles;
  FSEventStreamRef mFileEventStream;
}

@synthesize rootFolderLocation = mRootLocation;
@synthesize identifier = mIdentifier;


- (id) initWithIdentifier:(NSString*)identifier
{
  self = [super initWithNibName:@"FXFileBrowser" bundle:[NSBundle bundleForClass:[self class]]];
  if (self != nil)
  {
    self.identifier = identifier;
    mFiles = [[NSMutableArray alloc] init];
    self.handlingDeleteKey = NO;
  }
  return self;
}


- (id) init
{
  return [self initWithIdentifier:nil];
}


- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.rootFolderLocation = nil;
  FXRelease(mFiles)
  mFiles = nil;
  FXDeallocSuper
}


- (void) loadView
{
  [super loadView];
  [self initializeUI];
}


#pragma mark Public


- (void) setRootFolderLocation:(NSURL *)rootFolderLocation
{
  @synchronized(self)
  {
    if ( mRootLocation != rootFolderLocation )
    {
      FXRelease(mRootLocation)
      mRootLocation = [rootFolderLocation copy];
      [self refresh];
      [self setUpFolderMonitoring];
    }
  }
}


- (void) refresh
{
  @synchronized(self)
  {
    [self buildFolderData];
    [self.fileTable reloadData];
  }
}


- (void) highlightFiles:(NSArray*)fileNames
{
  if ( fileNames != nil )
  {
    __block NSMutableIndexSet* highlightedItems = [NSMutableIndexSet new];
    [mFiles enumerateObjectsUsingBlock:^(FXFileBrowserFileData* fileData, NSUInteger index, BOOL *stop) {
      if ([fileNames containsObject:fileData.fileName])
      {
        [highlightedItems addIndex:index];
      }
    }];
    if ( [highlightedItems count] > 0 )
    {
      [self.fileTable selectRowIndexes:highlightedItems byExtendingSelection:NO];
    }
    FXRelease(highlightedItems)
  }
}


#pragma mark NSResponder overwrites

NSString* const nameColumnWidthKey = @"Name column width";
NSString* const sizeColumnWidthKey = @"Size column width";
NSString* const dateColumnWidthKey = @"Date column width";


- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  [super encodeRestorableStateWithCoder:state];
  [self.fileTable encodeRestorableStateWithCoder:state];
  [state encodeFloat:[[self.fileTable tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_Name] width] forKey:nameColumnWidthKey];
  [state encodeFloat:[[self.fileTable tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_LastModified] width] forKey:dateColumnWidthKey];
  [state encodeFloat:[[self.fileTable tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_Size] width] forKey:sizeColumnWidthKey];
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  [super restoreStateWithCoder:state];
  [self.fileTable restoreStateWithCoder:state];
  if ( [state containsValueForKey:nameColumnWidthKey] )
  {
    [[self.fileTable tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_Name] setWidth:[state decodeFloatForKey:nameColumnWidthKey]];
  }
  if ( [state containsValueForKey:sizeColumnWidthKey] )
  {
    [[self.fileTable tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_Size] setWidth:[state decodeFloatForKey:sizeColumnWidthKey]];
  }
  if ( [state containsValueForKey:dateColumnWidthKey] )
  {
    [[self.fileTable tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_LastModified] setWidth:[state decodeFloatForKey:dateColumnWidthKey]];
  }
}


#pragma mark NSTableViewDataSource


- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [mFiles count];
}


- (NSDragOperation) tableView:(NSTableView*)tableView
                 validateDrop:(id<NSDraggingInfo>)info
                  proposedRow:(NSInteger)row
        proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSArray* draggedItems = [[info draggingPasteboard] pasteboardItems];
  if ( (draggedItems != nil)
    && ([draggedItems count] > 0)
    && ([info draggingSourceOperationMask] & NSDragOperationCopy)
    && ([info draggingSource] != self.fileTable) )
  {
    if ([self validateDroppedItems:draggedItems])
    {
      return NSDragOperationCopy;
    }
  }
  return NSDragOperationNone;
}


- (id) tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  NSString* result = nil;
  if ( tableView == self.fileTable )
  {
    if ( (rowIndex >= 0) && (rowIndex < [mFiles count]) )
    {
      FXFileBrowserFileData* fileData = mFiles[rowIndex];

      if ( [[tableColumn identifier] isEqualToString:FXFileBrowserTableColumnIdentifier_Name] )
      {
        result = fileData.fileName;
      }
      else if ( [[tableColumn identifier] isEqualToString:FXFileBrowserTableColumnIdentifier_Size] )
      {
        result = [self fileSizeStringForBytes:fileData.sizeInBytes];
      }
      else if ( [[tableColumn identifier] isEqualToString:FXFileBrowserTableColumnIdentifier_LastModified] )
      {
        result = [self dateStringForDate:fileData.lastModified];
      }
    }
  }
  return result;
}


- (id<NSPasteboardWriting>) tableView:(NSTableView*)tableView pasteboardWriterForRow:(NSInteger)row
{
  return mFiles[row];
}


- (void) tableView:(NSTableView*)tableView draggingSession:(NSDraggingSession*)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet*)rowIndexes
{
  [session enumerateDraggingItemsWithOptions:0 forView:self.fileTable classes:@[[FXFileBrowserFileData class], [NSPasteboardItem class]] searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop) {
    if ([draggingItem.item isKindOfClass:[FXFileBrowserFileData class]])
    {
      NSTableCellView* tableCellView = [self.fileTable makeViewWithIdentifier:FXFileBrowserTableColumnIdentifier_Name owner:self];
      tableCellView.textField.stringValue = [(FXFileBrowserFileData*)(draggingItem.item) fileName];
      draggingItem.imageComponentsProvider = ^(void) { return [tableCellView draggingImageComponents]; };
    }
    else
    {
      DebugLog(@"Something is fishy. The dragged item should be a FXFileBrowserFileData instance.");
      draggingItem.imageComponentsProvider = nil;
    }
  }];
}


#pragma mark NSTableViewDelegate


- (NSView*) tableView:(NSTableView*)tableView viewForTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)row
{
  NSTableCellView* cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
  FXFileBrowserFileData* fileData = mFiles[row];
  if ( [tableColumn.identifier isEqualToString:FXFileBrowserTableColumnIdentifier_Name] )
  {
    cellView.textField.stringValue = fileData.fileName;
    cellView.textField.editable = YES;
    cellView.textField.delegate = self;
  }
  else if ( [tableColumn.identifier isEqualToString:FXFileBrowserTableColumnIdentifier_Size] )
  {
    cellView.textField.stringValue = [self fileSizeStringForBytes:fileData.sizeInBytes];
  }
  else if ( [tableColumn.identifier isEqualToString:FXFileBrowserTableColumnIdentifier_LastModified] )
  {
    cellView.textField.stringValue = [self dateStringForDate:fileData.lastModified];
  }
  return cellView;
}


#pragma mark NSControl delegate


- (void) controlTextDidEndEditing:(NSNotification *)notification
{
  NSTextField* editedTextField = [notification object];
  if ( [editedTextField isKindOfClass:[NSTextField class]] )
  {
    NSInteger rowIndex = [self.fileTable rowForView:editedTextField];
    if ( rowIndex >= 0 )
    {
      FXFileBrowserFileData* fileData = mFiles[rowIndex];
      if ( ![fileData.fileName isEqualToString:editedTextField.stringValue] )
      {
        NSURL* originalURL = [mRootLocation URLByAppendingPathComponent:fileData.fileName];
        NSURL* newURL = [mRootLocation URLByAppendingPathComponent:editedTextField.stringValue];
        NSError* fileError = nil;
        if ( [[NSFileManager defaultManager] moveItemAtURL:originalURL toURL:newURL error:&fileError] )
        {
          [self refresh];
        }
        else
        {
          if (fileError != nil)
          {
            [[self.view window] presentError:fileError];
          }
        }
      }
    }
  }
}


#pragma mark FXFileBrowserTableViewClient


- (BOOL) handleDroppedFiles:(NSArray*)fileURLs
{
  BOOL handled = NO;
  NSFileManager* fm = [NSFileManager defaultManager];
  for (NSURL* fileURL in fileURLs)
  {
    BOOL isDir = NO;
    if ( [fm fileExistsAtPath:[fileURL path] isDirectory:&isDir] && !isDir )
    {
      NSString* sourceFileName = [fileURL lastPathComponent];
      NSURL* destinationURL = [mRootLocation URLByAppendingPathComponent:sourceFileName];
      if ( [fm fileExistsAtPath:[destinationURL path]] )
      {
        self.handlingDeleteKey = NO;
        CFURLRef alertHandlerInfo = CFURLCreateWithString(NULL, (__bridge CFStringRef)[fileURL absoluteString], NULL);
        [self showAlertWithMessage:[NSString stringWithFormat:FXLocalizedString(@"FileBrowserAlert_OverwriteFile_Message"), sourceFileName]
                       acceptTitle:FXLocalizedString(@"FileBrowserAlert_OverwriteFile_Accept")
                        abortTitle:FXLocalizedString(@"FileBrowserAlert_Cancel")
                              info:(void*)alertHandlerInfo];
      }
      else
      {
        [self copyFile:fileURL];
      }
      handled = YES;
    }
  }
  [self refresh];
  return handled;
}


#pragma mark Private


- (void) showAlertWithMessage:(NSString*)message acceptTitle:(NSString*)accept abortTitle:(NSString*)abort info:(void*)contextInfo
{
  NSAlert *alert = [[NSAlert alloc] init];
  FXAutorelease(alert)
  [alert addButtonWithTitle:accept];
  [alert addButtonWithTitle:abort];
  alert.messageText = message;
  alert.alertStyle = NSAlertStyleWarning;
  [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
    [[alert window] orderOut:self];
    if ( returnCode == NSAlertFirstButtonReturn )
    {
      if (self.handlingDeleteKey)
      {
        [self deleteSelectedFiles];
      }
      else if ( contextInfo != NULL )
      {
        CFURLRef sourceFileLocation = (CFURLRef)contextInfo;
        [self copyFile:(__bridge NSURL*)sourceFileLocation];
        CFRelease(sourceFileLocation);
      }
    }
  }];
}


- (void) copyFile:(NSURL*)fileLocation
{
  NSFileManager* fm = [NSFileManager defaultManager];
  NSURL* destinationLocation = [mRootLocation URLByAppendingPathComponent:[fileLocation lastPathComponent]];
  BOOL isDir = NO;
  NSError* fileError = nil;
  if ( [fm fileExistsAtPath:[destinationLocation path] isDirectory:&isDir] )
  {
    if (![fm removeItemAtURL:destinationLocation error:&fileError])
    {
      if (fileError != nil)
      {
        [[self.view window] presentError:fileError];
      }
      return;
    }
  }
  if (![fm copyItemAtURL:fileLocation toURL:destinationLocation error:&fileError])
  {
    if ( fileError != nil )
    {
      [[self.view window] presentError:fileError];
    }
  }
}


- (void) initializeUI
{
  FXFileBrowserTableView* table = self.fileTable;
  [[[table tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_Name] headerCell] setStringValue:FXLocalizedString(@"FileBrowserColumnTitle_Name")];
  [[[table tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_LastModified] headerCell] setStringValue:FXLocalizedString(@"FileBrowserColumnTitle_LastModified")];
  [[[table tableColumnWithIdentifier:FXFileBrowserTableColumnIdentifier_Size] headerCell] setStringValue:FXLocalizedString(@"FileBrowserColumnTitle_Size")];
  table.columnAutoresizingStyle = NSTableViewNoColumnAutoresizing;
  table.delegate = self;
  table.dataSource = self;
  table.client = self;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTableViewDeleteKey:) name:FXTableViewDeleteKeyNotification object:table];
}


- (void) buildFolderData
{
  [mFiles removeAllObjects];
  if ( mRootLocation != nil )
  {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSError* fileError = nil;
    NSArray* fileURLs = [fm contentsOfDirectoryAtURL:mRootLocation includingPropertiesForKeys:nil options:0 error:&fileError];
    if ( fileURLs == nil )
    {
      if ( fileError != nil )
      {
        NSLog(@"%@", [fileError localizedDescription]);
      }
    }
    else
    {
      for (NSURL* fileURL in fileURLs)
      {
        if ( [fileURL isFileURL] )
        {
          NSString* fileName = [fileURL lastPathComponent];
          if ( ![fileName hasPrefix:@"."] ) // hidden file
          {
            NSUInteger fileSize = 0;
            NSDate* modificationDate = [NSDate distantPast];
            NSDictionary* fileAttributes = [fm attributesOfItemAtPath:[fileURL path] error:&fileError];
            if ( fileAttributes != nil )
            {
              fileSize = [(NSNumber*)fileAttributes[NSFileSize] unsignedLongLongValue];
              modificationDate = fileAttributes[NSFileModificationDate];
            }
            FXFileBrowserFileData* fileData = [FXFileBrowserFileData fileDataWithLocation:fileURL modificationDate:modificationDate size:fileSize];
            [mFiles addObject:fileData];
          }
        }
      }
      [mFiles sortUsingSelector:@selector(compare:)];
    }
  }
}


- (NSString*) fileSizeStringForBytes:(NSUInteger)fileSize
{
  static NSUInteger const KiloByte = 1024;
  static NSUInteger const MegaByte = KiloByte * KiloByte;
  NSString* result = nil;
  if (fileSize < KiloByte)
  {
    result = [NSString stringWithFormat:@"%ld", fileSize];
  }
  else if (fileSize < MegaByte)
  {
    NSUInteger kiloBytes = fileSize/KiloByte;
    result = [NSString stringWithFormat:@"%ld KB", kiloBytes];
  }
  else
  {
    NSUInteger megaBytes = fileSize/MegaByte;
    result = [NSString stringWithFormat:@"%ld MB", megaBytes];
  }
  return result;
}


- (NSString*) dateStringForDate:(NSDate*)date
{
  NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
  dateFormatter.dateStyle = NSDateFormatterMediumStyle;
  dateFormatter.timeStyle = NSDateFormatterShortStyle;
  dateFormatter.locale = [NSLocale currentLocale];
  NSString* result = [dateFormatter stringFromDate:date];
  FXRelease(dateFormatter)
  return result;
}


static void folderChangeHandler(
  ConstFSEventStreamRef streamRef,
  void* clientCallBackInfo,
  size_t numEvents,
  void* eventPaths,
  const FSEventStreamEventFlags eventFlags[],
  const FSEventStreamEventId eventIds[])
{
  @autoreleasepool
  {
    [(__bridge FXFileBrowser*)clientCallBackInfo refresh];
  }
}


- (void) setUpFolderMonitoring
{
  if ( mFileEventStream != NULL )
  {
    FSEventStreamStop(mFileEventStream);
    FSEventStreamInvalidate(mFileEventStream);
    FSEventStreamRelease(mFileEventStream);
    mFileEventStream = NULL;
  }
  if ( mRootLocation != nil )
  {
    CFStringRef cfFolderPath = (__bridge CFStringRef)[mRootLocation path];
    CFArrayRef monitoredFolders = CFArrayCreate(kCFAllocatorDefault, (const void **)&cfFolderPath, 1, &kCFTypeArrayCallBacks);
    CFTimeInterval const eventDelay = 0.1;
    FSEventStreamCreateFlags const creationFlags = kFSEventStreamCreateFlagNone;
    FSEventStreamContext* streamContext = (FSEventStreamContext*) calloc(1, sizeof(FSEventStreamContext)); // FSEventStreamCreate crashes in Release build if the context is not a heap variable
    streamContext->info = (__bridge void*)self;
    mFileEventStream = FSEventStreamCreate(NULL, folderChangeHandler, streamContext, monitoredFolders, kFSEventStreamEventIdSinceNow, eventDelay, creationFlags);
    CFRelease(monitoredFolders);
    FSEventStreamScheduleWithRunLoop(mFileEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(mFileEventStream);
    free(streamContext);
  }
}


- (void) handleTableViewDeleteKey:(NSNotification*)notification
{
  NSIndexSet* selectedRows = [self.fileTable selectedRowIndexes];
  if ( [selectedRows count] > 0 )
  {
    self.handlingDeleteKey = YES;
    [self showAlertWithMessage:FXLocalizedString(@"FileBrowserAlert_DeleteSelected_Message")
                   acceptTitle:FXLocalizedString(@"FileBrowserAlert_DeleteSelected_Accept")
                    abortTitle:FXLocalizedString(@"FileBrowserAlert_Cancel")
                          info:NULL];
  }
}


- (void) deleteSelectedFiles
{
  NSIndexSet* selectedRows = [self.fileTable selectedRowIndexes];
  [selectedRows enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger rowIndex, BOOL *stop) {
    FXFileBrowserFileData* fileData = mFiles[rowIndex];
    NSFileManager* fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:[mRootLocation URLByAppendingPathComponent:fileData.fileName] error:nil];
  }];
  [self refresh];
}


- (BOOL) validateDroppedItems:(NSArray*)items
{
  BOOL hasValidItem = NO;
  for (NSPasteboardItem* item in items)
  {
    NSString* fileURLType = (__bridge NSString*)kUTTypeFileURL;
    NSString* availableType = [item availableTypeFromArray:@[fileURLType]];
    if ( availableType != nil )
    {
      NSString* fileURLString = [item stringForType:fileURLType];
      NSURL* fileURL = [NSURL URLWithString:fileURLString];
      BOOL isDir = NO;
      if ( [[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:&isDir] && !isDir )
      {
        hasValidItem = YES;
        break;
      }
    }
  }
  return hasValidItem;
}


@end
