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

#import <SenTestingKit/SenTestingKit.h>
#import "FXVoltaLibraryData.h"
#import "FXVoltaLibraryStorage.h"


@interface test_library_storage : SenTestCase
@end


@implementation test_library_storage
{
@private
  FXVoltaLibraryData mData;
  FXVoltaLibraryStorage* mStorage;
  VoltaPTElementGroupPtr mTestElementGroup;
}


- (id) initWithInvocation:(NSInvocation*)anInvocation
{
  self = [super initWithInvocation:anInvocation];
  mStorage = [[FXVoltaLibraryStorage alloc] initWithRootLocation:[FXVoltaLibraryStorage testRootLocation]];
  [self createTestElementGroup];
  return self;
}


- (void) dealloc
{
  FXRelease(mStorage)
  FXDeallocSuper
}


#pragma mark Loading and Storing Elements


- (void) test_loadItemsOfType_Element
{
  mData.clearElementGroups();
  FXUTAssert([self removeItemsInFolder:[self elementGroupsStorageFolder]]);
  [mStorage loadStoredItemsOfType:FXVoltaLibraryStorageItem_Element intoLibraryData:&mData];
  FXUTAssertEqual(mData.numElementGroups(), (size_t)0);

  FXUTAssert([self copyTestFilesIntoElementGroupsStorageFolder]);
  [mStorage loadStoredItemsOfType:FXVoltaLibraryStorageItem_Element intoLibraryData:&mData];
  FXUTAssertEqual(mData.numElementGroups(), (size_t)1);
  mData.iterateElementGroups(^(const VoltaPTElementGroup &group, BOOL *stop) {
    FXUTAssert( group.name == "TestElementGroup" );
  });
}


- (void) test_storeItemsOfType_Element
{
  FXUTAssert([self removeItemsInFolder:[self elementGroupsStorageFolder]]);
  FXUTAssertEqual([self numberOfVoltaFilesInFolder:[self elementGroupsStorageFolder]], (NSUInteger)0);
  mData.clearElementGroups();
  [self addTestElementGroups];
  [mStorage storeItemsOfType:FXVoltaLibraryStorageItem_Element fromLibraryData:&mData];
  FXUTAssertEqual([self numberOfVoltaFilesInFolder:[self elementGroupsStorageFolder]], (NSUInteger)1);
  __block NSUInteger numStoredGroups = 0;
  [self iterateElementGroupsFolder:^(NSString* filePath, BOOL* stop) {
    if ( numStoredGroups == 0 )
    {
      NSString* expectedName = [NSString stringWithString:(__bridge NSString*)mTestElementGroup->name.cfString()];
      FXUTAssert([[[filePath lastPathComponent] stringByDeletingPathExtension] isEqualToString:expectedName]);
    }
    numStoredGroups++;
  }];
  FXUTAssertEqual(numStoredGroups, (NSUInteger)1);
}


#pragma mark Loading and Storing Models


- (void) test_loadItemsOfType_Model
{
  mData.clearModelGroups();
  FXUTAssertEqual(mData.numModels(), (size_t)0);
  mData.addModelGroup(VoltaPTModelGroupPtr(new VoltaPTModelGroup("Diodes", VMT_D)));
  mData.addModelGroup(VoltaPTModelGroupPtr(new VoltaPTModelGroup("Resistors", VMT_R)));
  mData.addModelGroup(VoltaPTModelGroupPtr(new VoltaPTModelGroup("N-Channel MOSFETs", VMT_MOSFET)));
  FXUTAssert([self removeItemsInFolder:[self modelGroupsStorageFolder]]);
  FXUTAssertEqual([self numberOfVoltaFilesInFolder:[self modelGroupsStorageFolder]], (NSUInteger)0);
  FXUTAssert([self copyTestFilesIntoModelGroupsStorageFolder]);
  FXUTAssertEqual([self numberOfVoltaFilesInFolder:[self modelGroupsStorageFolder]], (NSUInteger)1);
  [mStorage loadStoredItemsOfType:FXVoltaLibraryStorageItem_Model intoLibraryData:&mData];
  FXUTAssertEqual(mData.numModels(), (size_t)4);
  mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
    for ( auto model : group->models )
    {
      FXUTAssert(model->source.endsWith("TestModelGroup.volta"));
    }
  });
}


- (void) test_storeItemsOfType_Model
{
  mData.clearModelGroups();
  NSString* modelsStorageFolder = [self modelGroupsStorageFolder];
  [self removeItemsInFolder:modelsStorageFolder];
  FXUTAssertEqual( [self numberOfVoltaFilesInFolder:modelsStorageFolder], (NSUInteger)0 );

  FXUTAssert(mData.addModelGroup(VoltaPTModelGroupPtr(new VoltaPTModelGroup("Diodes", VMT_D))));
  [mStorage storeItemsOfType:FXVoltaLibraryStorageItem_Model fromLibraryData:&mData];
  FXUTAssertEqual( [self numberOfVoltaFilesInFolder:modelsStorageFolder], (NSUInteger)0 );

  FXUTAssert(mData.addModel(VoltaPTModelPtr( new VoltaPTModel(VMT_D, "MyDiode", "fish.robo.test") )));
  [mStorage storeItemsOfType:FXVoltaLibraryStorageItem_Model fromLibraryData:&mData];
  FXUTAssertEqual( [self numberOfVoltaFilesInFolder:modelsStorageFolder], (NSUInteger)1 );
}


#pragma mark Helpers


- (void) createTestElementGroup
{
  mTestElementGroup = VoltaPTElementGroupPtr( new VoltaPTElementGroup("My Element Group") );
  mTestElementGroup->elements.push_back( VoltaPTElement("MyMOS", VMT_MOSFET, "BaMOS", "fish.robo.test") );
}


- (void) addTestElementGroups
{
  mData.createElementGroup(mTestElementGroup->name);
  for ( auto & element : mTestElementGroup->elements )
  {
    mData.addElement(element, mTestElementGroup->name);
  }
}


- (NSString*) elementGroupsStorageFolder
{
  return [[[FXVoltaLibraryStorage testRootLocation] path] stringByAppendingPathComponent:@"Palette"];
}


- (NSString*) modelGroupsStorageFolder
{
  return [[[FXVoltaLibraryStorage testRootLocation] path] stringByAppendingPathComponent:@"Models"];
}


- (NSString*) subcircuitsStorageFolder
{
  return [[[FXVoltaLibraryStorage testRootLocation] path] stringByAppendingPathComponent:@"Subcircuits"];
}


- (BOOL) removeItemsInFolder:(NSString*)folderPath
{
  BOOL success = NO;
  NSFileManager* fm = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if ( [fm fileExistsAtPath:folderPath isDirectory:&isDirectory] && isDirectory )
  {
    for ( NSString* fileName in [fm contentsOfDirectoryAtPath:folderPath error:NULL] )
    {
      NSString* filePath = [folderPath stringByAppendingPathComponent:fileName];
      [fm removeItemAtPath:filePath error:NULL];
    }
    success = ([[fm contentsOfDirectoryAtPath:folderPath error:NULL] count] == 0);
  }
  return success;
}


- (void) removeAllStoredItems
{
  [self removeItemsInFolder:[self elementGroupsStorageFolder]];
  [self removeItemsInFolder:[self modelGroupsStorageFolder]];
  [self removeItemsInFolder:[self subcircuitsStorageFolder]];
}


- (NSUInteger) numberOfVoltaFilesInFolder:(NSString*)folderPath
{
  NSUInteger result = 0;
  NSArray* folderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderPath error:NULL];
  if ( folderContents != nil )
  {
    for ( NSString* fileName in folderContents )
    {
      if ( [[[fileName pathExtension] lowercaseString] isEqualToString:@"volta"] )
      {
        result++;
      }
    }
  }
  return result;
}


- (BOOL) copyTestFilesIntoElementGroupsStorageFolder
{
  BOOL success = NO;
  NSString* bundleResourcesPath = [[NSBundle bundleForClass:[self class]] resourcePath];
  NSFileManager* fm = [NSFileManager defaultManager];
  NSArray* resourceFileNames = [fm contentsOfDirectoryAtPath:bundleResourcesPath error:NULL];
  if ( (resourceFileNames != nil) && ([resourceFileNames count] > 0) )
  {
    for ( NSString* resourceFileName in resourceFileNames )
    {
      if ( [resourceFileName rangeOfString:@"TestElementGroup"].location != NSNotFound )
      {
        NSString* resourceFilePath = [bundleResourcesPath stringByAppendingPathComponent:resourceFileName];
        NSString* destinationFilePath = [[self elementGroupsStorageFolder] stringByAppendingPathComponent:resourceFileName];
        if ( [fm copyItemAtPath:resourceFilePath toPath:destinationFilePath error:NULL] )
        {
          success = YES;
        }
      }
    }
  }
  return success;
}


- (BOOL) copyTestFilesIntoModelGroupsStorageFolder
{
  BOOL success = NO;
  NSString* bundleResourcesPath = [[NSBundle bundleForClass:[self class]] resourcePath];
  NSFileManager* fm = [NSFileManager defaultManager];
  NSArray* resourceFileNames = [fm contentsOfDirectoryAtPath:bundleResourcesPath error:NULL];
  if ( (resourceFileNames != nil) && ([resourceFileNames count] > 0) )
  {
    for ( NSString* resourceFileName in resourceFileNames )
    {
      if ( [resourceFileName rangeOfString:@"TestModelGroup"].location != NSNotFound )
      {
        NSString* resourceFilePath = [bundleResourcesPath stringByAppendingPathComponent:resourceFileName];
        NSString* destinationFilePath = [[self modelGroupsStorageFolder] stringByAppendingPathComponent:resourceFileName];
        if ( [fm copyItemAtPath:resourceFilePath toPath:destinationFilePath error:NULL] )
        {
          success = YES;
        }
      }
    }
  }
  return success;
}


- (void) iterateElementGroupsFolder:( void(^)(NSString* filePath, BOOL* stop) )block
{
  NSFileManager* fm = [NSFileManager defaultManager];
  NSArray* filePaths = [fm contentsOfDirectoryAtPath:[self elementGroupsStorageFolder] error:NULL];
  BOOL stop = NO;
  for ( NSString* currentFilePath in filePaths )
  {
    if ( [[currentFilePath pathExtension] isEqualToString:@"volta"] )
    {
      block( currentFilePath, &stop );
      if ( stop )
        break;
    }
  }
}


@end
