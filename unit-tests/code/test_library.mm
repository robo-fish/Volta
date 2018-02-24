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

#import <XCTest/XCTest.h>
#import "FXVoltaLibrary.h"
#import "FXVoltaLibraryStorage.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXVoltaArchiver.h"

static int64_t const oneSecondInNanoSeconds = 1000000000;


@interface test_library : XCTestCase <VoltaLibraryObserver>

@property BOOL receivedPaletteChangedNotification;
@property BOOL receivedModelsChangedNotification;

@end


#pragma mark -


@implementation test_library
{
@private
  id<VoltaLibrary> mLibrary;
}


- (void) setUp
{
  if ( mLibrary == nil )
  {
    mLibrary = [FXVoltaLibrary newTestLibrary];
    [mLibrary addObserver:self];
  }

  self.receivedPaletteChangedNotification = NO;
  self.receivedModelsChangedNotification = NO;
}


- (void) tearDown
{
}


#pragma mark Tests


- (void) test_has_all_model_groups
{
  __block NSMutableIndexSet* types = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, (int)VMT_Count)];
  [mLibrary iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
    NSUInteger const typeIndex = (NSUInteger)group->modelType;
    FXUTAssert([types containsIndex:typeIndex]);
    [types removeIndex:typeIndex];
  }];
  FXUTAssertEqual([types count], (NSUInteger)1);
  FXUTAssert([types firstIndex] == (int)VMT_SUBCKT); // Subcircuits are stored in a separate group.
  types = nil;
}


- (void) test_unarchiving_custom_models_from_persistent_library
{
  // Creating a persistent model library
  VoltaPTLibraryPtr persistentLibrary( new VoltaPTLibrary );
  persistentLibrary->title = "Test Library";
  persistentLibrary->modelGroup = VoltaPTModelGroupPtr( new VoltaPTModelGroup() );
  persistentLibrary->modelGroup->models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_BJT, "TestModel1", "fish.robo.test") ) );
  persistentLibrary->modelGroup->models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_BJT, "TestModel2", "fish.robo.test") ) );
  persistentLibrary->modelGroup->models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_R, "TestModel3", "fish.robo.test") ) );
  persistentLibrary->modelGroup->models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_METER, "TestModel4", "fish.robo.test") ) );

  FXVoltaLibraryData libraryData;
  libraryData.addModelGroup( VoltaPTModelGroupPtr( new VoltaPTModelGroup("Transistors", VMT_BJT) ) );
  libraryData.addModelGroup( VoltaPTModelGroupPtr( new VoltaPTModelGroup("Resistors", VMT_R) ) );
  libraryData.addModelGroup( VoltaPTModelGroupPtr( new VoltaPTModelGroup("DC Voltmeters", VMT_METER) ) );
  FXVoltaLibraryStorage* storage = [[FXVoltaLibraryStorage alloc] initWithRootLocation:[FXVoltaLibraryStorage testRootLocation]];
  [storage loadAllItemsIntoLibraryData:&libraryData];

  // Making sure that the library does not contain the models from the persistent library.
  __block BOOL foundEquivalentExistingModel = NO;
  libraryData.iterateModelGroups( ^(VoltaPTModelGroupPtr group, BOOL* stop) {
    for ( VoltaPTModelPtr const & libModel : persistentLibrary->modelGroup->models )
    {
      for ( VoltaPTModelPtr const & groupModel : group->models )
      {
        if ( *groupModel == *libModel )
        {
          foundEquivalentExistingModel = YES;
          *stop = YES;
          return;
        }
      }
    }
  });
  FXUTAssert(!foundEquivalentExistingModel);
  libraryData.addLibraryModels(persistentLibrary, "http://test.kulfx.com", true);

  // Checking if the models in the library can be found
  BOOL foundAllPersistentModelsInLibrary = YES;
  for ( VoltaPTModelPtr const & libModel : persistentLibrary->modelGroup->models )
  {
    __block BOOL foundCurrentModelInLibrary = NO;
    libraryData.iterateModelGroups( ^(VoltaPTModelGroupPtr group, BOOL* stop) {
      if ( group->modelType == libModel->type )
      {
        for ( VoltaPTModelPtr const & systemModel : group->models )
        {
          if ( *systemModel == *libModel )
          {
            foundCurrentModelInLibrary = YES;
            *stop = YES;
            return;
          }
        }
        *stop = YES;
      }
    });
    foundAllPersistentModelsInLibrary &= foundCurrentModelInLibrary;
  }
  FXUTAssert(foundAllPersistentModelsInLibrary);

  FXRelease(storage)
}


- (void) test_archiving_custom_models_to_file
{
//  NSString* customModelsFileName = @"CustomModels.volta";
//  NSString* customModelsFolderPath = [NSHomeDirectory() stringByAppendingFormat:@"/Library/Application Support/Volta/Models/"];
//  NSString* customModelsFilePath = [customModelsFolderPath stringByAppendingString:customModelsFileName];
//  NSString* customModelsBackupFilePath = [customModelsFolderPath stringByAppendingFormat:@"%@.backup", customModelsFileName];
//
//  NSFileManager* fm = [NSFileManager defaultManager];
//  NSError* fileOperationError = nil;
//  BOOL originalCustomModelsStoredInBackup = NO;
//  BOOL isDir = NO;
//
//  // Creating a backup of the custom models file
//  if ( [fm fileExistsAtPath:customModelsFilePath isDirectory:&isDir] && !isDir )
//  {
//    if ( [fm fileExistsAtPath:customModelsBackupFilePath isDirectory:&isDir] && !isDir )
//    {
//      if ( ![fm removeItemAtPath:customModelsBackupFilePath error:&fileOperationError] )
//      {
//        STAssertTrue(NO, @"%@", [fileOperationError localizedDescription]);
//      }
//    }
//    if ( [fm moveItemAtPath:customModelsFilePath toPath:customModelsBackupFilePath error:&fileOperationError] )
//    {
//      originalCustomModelsStoredInBackup = YES;
//    }
//    STAssertTrue(originalCustomModelsStoredInBackup, @"%@", [fileOperationError localizedDescription]);
//  }
//  
//  FXVoltaLibraryData libraryData;
//  FXUTAssert( libraryData.addModelGroup( VoltaPTModelGroupPtr(new VoltaPTModelGroup("Capacitors", VMT_C)) ) );
//  FXUTAssert( libraryData.addModelGroup( VoltaPTModelGroupPtr(new VoltaPTModelGroup("Voltage Source", VMT_VSDC)) ) );
//  FXVoltaLibraryStorage* libraryArchiver = [[FXVoltaLibraryStorage alloc] initWithRootLocation:[FXVoltaLibraryStorage testRootLocation]];
//  [libraryArchiver loadAllItemsIntoLibraryData:&libraryData];
//
//  {
//    VoltaPTModelPtr customModel1( new VoltaPTModel(VMT_C, "Test Model 1", "fish.robo.test", true) );
//    FXUTAssert( libraryData.addModel(customModel1, FXVoltaLibraryItemAddingPolicy::RenameNewItem) );
//
//    VoltaPTModelPtr customModel2( new VoltaPTModel(VMT_VSDC, "Test Model 2", "fish.robo.test", true) );
//    FXUTAssert( libraryData.addModel( customModel2, FXVoltaLibraryItemAddingPolicy::RenameNewItem) );
//
//    FXUTAssert( ![fm fileExistsAtPath:customModelsFilePath] );
//    [libraryArchiver storeCustomModelsFromLibraryData:&libraryData];
//    FXUTAssert( [fm fileExistsAtPath:customModelsFilePath isDirectory:&isDir] && !isDir );
//
//    NSStringEncoding fileTextEncoding = 0;
//    NSString* customModelsFileContent = [NSString stringWithContentsOfFile:customModelsFilePath usedEncoding:&fileTextEncoding error:&fileOperationError];
//    STAssertTrue(customModelsFileContent != nil, @"%@", [fileOperationError localizedDescription] );
//    FXUTAssert(fileTextEncoding == NSUTF8StringEncoding);
//
//    VoltaPTLibraryPtr voltaLibrary = [FXVoltaArchiver unarchiveLibraryFromString:customModelsFileContent formatUpgradedWhileUnarchiving:nil error:nil];
//    FXUTAssert(voltaLibrary.get() != nullptr);
//    FXUTAssert(voltaLibrary->modelGroup.get() != nullptr);
//    FXUTAssert(voltaLibrary->modelGroup->models.size() == 2);
//
//    FXString expectedName = customModel1->name;
//    FXString observedName = voltaLibrary->modelGroup->models.at(0)->name;
//    STAssertTrue(expectedName == observedName, @"Expected \"%@\" but got \"%@\".", expectedName.cfString(), observedName.cfString());
//
//    VoltaModelType expectedType = customModel1->type;
//    VoltaModelType observedType = voltaLibrary->modelGroup->models.at(0)->type;
//    STAssertTrue(expectedType == observedType, @"Expected %d but got %d.", expectedType, observedType);
//
//    FXString expectedVendor = customModel1->vendor;
//    FXString observedVendor = voltaLibrary->modelGroup->models.at(0)->vendor;
//    STAssertTrue(expectedVendor == observedVendor, @"Expected \"%@\" but got \"%@\".", expectedVendor.cfString(), observedVendor.cfString());
//
//    expectedName = customModel2->name;
//    observedName = voltaLibrary->modelGroup->models.at(1)->name;
//    STAssertTrue(expectedName == observedName, @"Expected \"%@\" but got \"%@\".", expectedName.cfString(), observedName.cfString());
//
//    expectedType = customModel2->type;
//    observedType = voltaLibrary->modelGroup->models.at(1)->type;
//    STAssertTrue(expectedType == observedType, @"Expected %d but got %d.", expectedType, observedType);
//
//    expectedVendor = customModel2->vendor;
//    observedVendor = voltaLibrary->modelGroup->models.at(1)->vendor;
//    STAssertTrue(expectedVendor == observedVendor, @"Expected \"%@\" but got \"%@\".", expectedVendor.cfString(), observedVendor.cfString());
//  }
//
//  FXRelease(libraryArchiver)
//
//  // Restoring the original custom models file from backup.
//  if ( originalCustomModelsStoredInBackup )
//  {
//    STAssertTrue([fm removeItemAtPath:customModelsFilePath error:&fileOperationError], @"%@", [fileOperationError localizedDescription]);
//    STAssertTrue([fm moveItemAtPath:customModelsBackupFilePath toPath:customModelsFilePath error:&fileOperationError], @"%@", [fileOperationError localizedDescription]);
//  }
}


- (void) test_add_remove_custom_group
{
  FXVoltaLibrary* library = mLibrary;
  FXUTAssert( library != nil );

  __block NSUInteger numCustomGroups = 0;
  [library iterateOverElementGroupsByApplyingBlock: ^(VoltaPTElementGroup const &, BOOL *) { numCustomGroups++; }];
  NSUInteger const initialGroupCount = numCustomGroups;

  FXString const newGroupName = [library createElementGroup];
  FXUTAssert( [self checkReceivedPaletteChangedNotificationAndClear] );

  numCustomGroups = 0;
  [library iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const &, BOOL *) { numCustomGroups++; }];
  FXUTAssert( numCustomGroups == (initialGroupCount + 1) );

  __block BOOL paletteContainsNewGroup = NO;
  [library iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const & group, BOOL* stop) {
    if ( group.name == newGroupName )
    {
      paletteContainsNewGroup = YES;
      *stop = YES;
    }
  }];
  FXUTAssert(paletteContainsNewGroup);

  FXStringVector groupsToRemove;
  groupsToRemove.push_back(newGroupName);
  NSUInteger const numGroupsRemoved = [library removeElementGroups:groupsToRemove];
  FXUTAssert(numGroupsRemoved == 1);
  FXUTAssert( [self checkReceivedPaletteChangedNotificationAndClear] );

  paletteContainsNewGroup = NO;
  numCustomGroups = 0;
  [library iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const & group, BOOL* stop) {
    if ( group.name == newGroupName )
    {
      paletteContainsNewGroup = YES;
    }
    numCustomGroups++;
  }];
  FXUTAssert(!paletteContainsNewGroup);
  FXUTAssert(numCustomGroups == initialGroupCount);
}


- (void) test_rename_element_group
{
  FXVoltaLibrary* library = mLibrary;
  FXString const oldName = [library createElementGroup];
  FXString const newName = [self uniqueName];
  
  __block VoltaPTElementGroup const * newElementGroup = NULL;
  [library iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const & elementGroup, BOOL* stop) {
    if ( elementGroup.name == oldName )
    {
      newElementGroup = &elementGroup;
      *stop = YES;
    }
  }];
  FXUTAssert(newElementGroup != NULL);
  FXUTAssert([library renameElementGroup:newElementGroup->name proposedName:newName]);
  FXUTAssert([self checkReceivedPaletteChangedNotificationAndClear]);
  FXUTAssert(newElementGroup->name == newName);
  FXUTAssert([library renameElementGroup:newElementGroup->name proposedName:oldName]);
  FXUTAssert([self checkReceivedPaletteChangedNotificationAndClear]);
  FXUTAssert(newElementGroup->name == oldName);
}


- (void) test_inserting_and_removing_an_element_into_element_group
{
#if 0
  __block VoltaPTModelPtr someModel;
  [mLibrary iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
    if ( group->modelType == VMT_CSVC )
    {
      someModel = group->models.front();
      *stop = YES;
    }
  }];
  FXUTAssert(someModel.get() != nullptr);
  
  __block VoltaPTElementGroup const * someElementGroup = NULL;
  [mLibrary iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const & group, BOOL* stop) {
    someElementGroup = &group;
    *stop = YES;
  }];
  FXUTAssert(someElementGroup != NULL);
#endif
}


- (void) test_adding_an_element_that_already_exists_in_group
{
  [self checkReceivedPaletteChangedNotificationAndClear];

  FXString const groupName = [mLibrary createElementGroup];
  VoltaPTElementVector elements;
  VoltaPTElement someResistor("R999", VMT_R, "Resistor", "fish.robo.test");
  elements.push_back( someResistor );
  FXUTAssert([mLibrary addElements:elements toGroup:groupName]);
  FXUTAssert([self checkReceivedPaletteChangedNotificationAndClear]);

  [mLibrary iterateOverElementGroupsByApplyingBlock:^(const VoltaPTElementGroup & group, BOOL *stop) {
    if ( group.name == groupName )
    {
      FXUTAssertEqual( group.elements.size(), (size_t)1 );
      FXUTAssert( group.elements.at(0).name == someResistor.name );
      *stop = YES;
    }
  }];

  FXUTAssert([mLibrary addElements:elements toGroup:groupName]);
  FXUTAssert([self checkReceivedPaletteChangedNotificationAndClear]);

  [mLibrary iterateOverElementGroupsByApplyingBlock:^(const VoltaPTElementGroup & group, BOOL *stop) {
    if ( group.name == groupName )
    {
      FXUTAssertEqual( group.elements.size(), (size_t)2 );
      FXUTAssert( group.elements.at(0).name == someResistor.name );
      FXUTAssert( group.elements.at(1).name != someResistor.name );
      *stop = YES;
    }
  }];
}


- (void) test_reordering_elements_in_element_group
{
  [self checkReceivedPaletteChangedNotificationAndClear];

  FXString const groupName = [mLibrary createElementGroup];
  VoltaPTElementVector elements = {
    VoltaPTElement("R1", VMT_R, "Resistor", "fish.robo.test"),
    VoltaPTElement("R2", VMT_R, "Resistor", "fish.robo.test"),
    VoltaPTElement("R3", VMT_R, "Resistor", "fish.robo.test") };
  FXUTAssert([mLibrary addElements:elements toGroup:groupName]);
  FXUTAssert( [self checkReceivedPaletteChangedNotificationAndClear] );
  
  __block VoltaPTElementGroup const * someElementGroup = NULL;
  __block VoltaPTElement const * someElementInElementGroup = NULL;
  [mLibrary iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const & group, BOOL* stop) {
    if ( group.elements.size() > 2 )
    {
      someElementGroup = &group;
      someElementInElementGroup = &(group.elements.back());
      *stop = YES;
    }
  }];
  FXUTAssert( someElementGroup != NULL );
  FXUTAssert( someElementInElementGroup != NULL );
  FXUTAssertEqual( someElementGroup->elements.size(), (size_t)3 );

  VoltaPTElementVector elementsToInsert;
  elementsToInsert.push_back(*someElementInElementGroup);
  FXUTAssert( [mLibrary insertElements:elementsToInsert intoGroup:someElementGroup->name atIndex:0 dueToReordering:YES] );
  FXUTAssert( [self checkReceivedPaletteChangedNotificationAndClear] );
  FXUTAssert( [mLibrary insertElements:elementsToInsert intoGroup:someElementGroup->name atIndex:someElementGroup->elements.size() dueToReordering:YES] );
  FXUTAssert( [self checkReceivedPaletteChangedNotificationAndClear] );
  FXUTAssert( someElementGroup->elements.back() == *someElementInElementGroup );
}


- (void) test_adding_removing_a_custom_model
{
  VoltaPTModelGroupPtr diodeGroup = [self modelGroupForType:VMT_D];
  FXUTAssert(diodeGroup.get() != nullptr);

  VoltaPTModelPtr newModel( new VoltaPTModel(VMT_D, "TestModel", "fish.robo", true) );

  FXVoltaLibrary* library = mLibrary;

  // Adding
  FXUTAssert(![self checkReceivedModelsChangedNotificationAndClear]);
  newModel = [library createModelFromTemplate:newModel];
  FXUTAssert([self checkReceivedModelsChangedNotificationAndClear]);
  FXUTAssert([self modelGroup:diodeGroup containsModel:newModel]);

  // Removing
  VoltaPTModelPtrSet modelsToRemove;
  modelsToRemove.insert(newModel);
  [library removeModels:modelsToRemove];
  FXUTAssert(![self modelGroup:diodeGroup containsModel:newModel]);
}


- (void) test_refreshing_the_list_of_subircuits
{
  NSFileManager* fm = [NSFileManager defaultManager];
  FXVoltaLibrary* library = mLibrary;
  NSURL* subcircuitsRootURL = [library subcircuitsLocation];
  FXUTAssert( [subcircuitsRootURL isFileURL] );
  NSString* bundleResourcesPath = [[NSBundle bundleForClass:[self class]] resourcePath];
  NSString* subcircuitFileName = @"test_subcircuit.volta";
  NSString* sourcePath = [bundleResourcesPath stringByAppendingPathComponent:subcircuitFileName];
  NSURL* targetURL = [subcircuitsRootURL URLByAppendingPathComponent:subcircuitFileName];
  NSString* targetPath = [targetURL path];

  {
    BOOL isDir = NO;
    FXUTAssert( [fm fileExistsAtPath:sourcePath isDirectory:&isDir] && !isDir );
    FXUTAssert( ![fm fileExistsAtPath:targetPath isDirectory:&isDir] );
    FXUTAssert( ![self libraryContainsTestSubcircuit] );
  }

  {
    NSError* fileOperationError = nil;

    XCTAssertTrue([fm copyItemAtPath:sourcePath toPath:targetPath error:&fileOperationError], @"%@", [fileOperationError localizedDescription]);
    [library reloadSubcircuits];
    FXUTAssert([self libraryContainsTestSubcircuit]);

    XCTAssertTrue([fm removeItemAtPath:targetPath error:&fileOperationError], @"%@", [fileOperationError localizedDescription]);
    [library reloadSubcircuits];
    FXUTAssert(![self libraryContainsTestSubcircuit]);
  }
}


- (void) test_thread_safe_access_to_element_groups
{
  FXVoltaLibrary* library = mLibrary;
  FXString const groupName = [library createElementGroup];
  VoltaPTElementVector initialGroupElements = {
    VoltaPTElement("C1", VMT_C, "Capacitor", "fish.robo.test"),
    VoltaPTElement("L1", VMT_L, "Inductor", "fish.robo.test"),
    VoltaPTElement("R1", VMT_R, "Resistor", "fish.robo.test") };
  [library addElements:initialGroupElements toGroup:groupName];

  __block VoltaPTElementGroup const * targetGroup;
  [library iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const & group, BOOL* stop) {
    if ( group.name == groupName )
    {
      targetGroup = &group;
      *stop = YES;
    }
  }];
  FXUTAssert(targetGroup != NULL);

  size_t const threadCount = 5;
  size_t const repeats = 1000;
  
  dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_group_t asyncGroup = dispatch_group_create();

  void(^block)(void) = ^{
    [library beginEditingPalette];
    std::vector< std::pair<FXString,FXString> > elementsToRemove;
    VoltaPTElementVector elementsToInsert;
    for ( size_t i = 0; i < repeats; i++ )
    {
      elementsToRemove.clear();
      elementsToRemove.push_back( { targetGroup->elements.front().name, targetGroup->name } );
      size_t const numElements = targetGroup->elements.size();
      FXUTAssertEqual(numElements, initialGroupElements.size());
      FXUTAssert([library removeElements:elementsToRemove]);
      FXUTAssertEqual(targetGroup->elements.size(), numElements - 1);
      FXUTAssert(targetGroup->elements.front().name != elementsToRemove.front().first);
      elementsToInsert.clear();
      elementsToInsert.push_back(initialGroupElements.front());
      FXUTAssert([library insertElements:elementsToInsert intoGroup:targetGroup->name atIndex:0 dueToReordering:NO]);
      FXUTAssertEqual(targetGroup->elements.size(), numElements);
    }
    [library endEditingPalette];
  };

  for ( size_t t = 0; t < threadCount; t++ )
  {
    dispatch_group_async( asyncGroup, globalQueue, block );
  }
  
  dispatch_group_wait(asyncGroup, dispatch_time(0, oneSecondInNanoSeconds));
}


- (void) test_thread_safe_access_to_custom_models
{
  FXVoltaLibrary* library = mLibrary;

  __block VoltaPTModelGroupPtr targetGroup;
  __block VoltaPTModelPtr baseModel;
  __block size_t originalNumberOfModelsInSystemGroup = 0;
  [library iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
    if ( !group->models.empty() )
    {
      targetGroup = group;
      baseModel = group->models.front();
      originalNumberOfModelsInSystemGroup = group->models.size();
      *stop = YES;
    }
  }];
  FXUTAssert(targetGroup.get() != nullptr);
  FXUTAssert(baseModel.get() != nullptr);

  size_t const threadCount = 3;
  size_t const repeats = 100;
  size_t const numberOfModelsToAddAndRemove = 15;

  void(^block)(void) = ^{

    [library beginEditingModels];

    for ( size_t k = 0; k < repeats; k++ )
    {
      VoltaPTModelPtrSet newModels;
      for ( int j = 0; j < numberOfModelsToAddAndRemove; j++ )
      {
        VoltaPTModelPtr newModel = [library createModelFromTemplate:baseModel];
        newModels.insert(newModel);
      }
      FXUTAssertEqual( targetGroup->models.size(), (size_t)(originalNumberOfModelsInSystemGroup + numberOfModelsToAddAndRemove) );

      [library removeModels:newModels];
      FXUTAssert( targetGroup->models.size() == originalNumberOfModelsInSystemGroup );
    }

    [library endEditingModels];
  };

  dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_group_t asyncGroup = dispatch_group_create();

  for ( size_t t = 0; t < threadCount; t++ )
  {
    dispatch_group_async( asyncGroup, globalQueue, block );
  }

  dispatch_group_wait(asyncGroup, dispatch_time(0, oneSecondInNanoSeconds));
}


- (void) test_thread_safe_access_to_subcircuits
{
  FXVoltaLibrary* library = mLibrary;

  __block int originalNumberOfSubcircuits = 0;
  [library iterateOverSubcircuitsByApplyingBlock:^(VoltaPTModelPtr, BOOL*) {
    originalNumberOfSubcircuits++;
  }];

  size_t const threadCount = 15;
  size_t const repeats = 5;
  
  void(^block)(void) = ^{
    for ( size_t k = 0; k < repeats; k++ )
    {
      [library reloadSubcircuits];

      __block int numberOfSubcircuits = 0;
      [library iterateOverSubcircuitsByApplyingBlock:^(VoltaPTModelPtr, BOOL*) {
        numberOfSubcircuits++;
      }];
      FXUTAssert(numberOfSubcircuits == originalNumberOfSubcircuits);
    }
  };
  
  dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_group_t asyncGroup = dispatch_group_create();
  
  for ( size_t t = 0; t < threadCount; t++ )
  {
    dispatch_group_async( asyncGroup, globalQueue, block );
  }
  
  dispatch_group_wait(asyncGroup, dispatch_time(0, oneSecondInNanoSeconds));
}


#pragma mark VoltaLibraryObserver


- (void) handleVoltaLibraryPaletteChanged:(id<VoltaLibrary>)library
{
  self.receivedPaletteChangedNotification = YES;
}

- (void) handleVoltaLibraryModelsChanged:(id<VoltaLibrary>)library
{
  self.receivedModelsChangedNotification = YES;
}

- (void) handleVoltaLibraryChangedSubcircuits:(id<VoltaLibrary>)library
{}

- (void) handleVoltaLibraryOpenEditor:(id<VoltaLibrary>)library
{}

- (void) handleVoltaLibraryWillShutDown:(id<VoltaLibrary>)library
{}


#pragma mark Other


- (BOOL) libraryContainsTestSubcircuit
{
  __block BOOL result = NO;
  [mLibrary iterateOverSubcircuitsByApplyingBlock:^(VoltaPTModelPtr subcircuit, BOOL* stop) {
    if ( subcircuit->name == "Test" && subcircuit->vendor == "fish.robo" )
    {
      result = YES;
      *stop = YES;
    }
  }];
  return result;
}


- (VoltaPTModelGroupPtr) modelGroupForType:(VoltaModelType)targetType
{
  __block VoltaPTModelGroupPtr result;
  [mLibrary iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
    if ( group->modelType == targetType )
    {
      result = group;
      *stop = YES;
    }
  }];
  return result;
}


- (BOOL) modelGroup:(VoltaPTModelGroupPtr)group containsModel:(VoltaPTModelPtr)model
{
  for (VoltaPTModelPtr groupModel : group->models)
  {
    if ( groupModel == model )
    {
      return YES;
    }
  }
  return NO;
}


- (BOOL) checkReceivedModelsChangedNotificationAndClear
{
  BOOL result = NO;
  @synchronized(self)
  {
    result = self.receivedModelsChangedNotification;
    self.receivedModelsChangedNotification = NO;
  }
  return result;
}


- (BOOL) checkReceivedPaletteChangedNotificationAndClear
{
  BOOL result = NO;
  @synchronized(self)
  {
    result = self.receivedPaletteChangedNotification;
    self.receivedPaletteChangedNotification = NO;
  }
  return result;
}


- (FXString) uniqueName
{
  CFUUIDRef uuid = CFUUIDCreate(NULL);
  CFStringRef uniqueName = CFUUIDCreateString(NULL, uuid);
  FXString result( uniqueName );
  CFRelease(uniqueName);
  CFRelease(uuid);
  return result;
}

@end

