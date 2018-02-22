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

#import "FXVoltaLibrary.h"
#import "FXVoltaLibraryNotifier.h"
#import "FXVoltaLibraryData.h"
#import "FXVoltaLibraryStorage.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXVoltaLibraryShapeRepository.h"
#import "FXPath.h"
#import "FXCircle.h"
#import "FXShapeConnectionPoint.h"
#import "FXShapeFactory.h"
#import <CoreServices/CoreServices.h>


@implementation FXVoltaLibrary
{
@private
  FXVoltaLibraryShapeRepository* mShapeRepository;
  FXVoltaLibraryData mData;
  FXVoltaLibraryNotifier* mNotifier;
  FXVoltaLibraryStorage* mStorage;
  FSEventStreamRef mSubcircuitsFolderWatcher;
  FSEventStreamRef mPaletteFolderWatcher;
  FSEventStreamRef mModelsFolderWatcher;

  BOOL mInTestMode;

  BOOL mNowBatchEditingPalette; // handling palette changes is blocked during batch editing
  BOOL mNeedsHandlingPaletteChanged; // used in combination with mNowBatchEditingPalette

  BOOL mNowBatchEditingModels;
  BOOL mNeedsHandlingModelsChanged; // used in combination with mNowBatchEditingModels
}


/// Designated initializer
- (id) initWithStorage:(FXVoltaLibraryStorage*)storage testMode:(BOOL)inTestMode
{
  self = [super init];
  mNowBatchEditingPalette = NO;
  mNeedsHandlingPaletteChanged = NO;
  mNowBatchEditingModels = NO;
  mNeedsHandlingModelsChanged = NO;
  mInTestMode = inTestMode;
  mShapeRepository = [FXVoltaLibraryShapeRepository new];
  [self createModelGroups];
  mStorage = storage;
  FXRetain(mStorage)
  [mStorage loadAllItemsIntoLibraryData:&mData];
  [self createShapes];
  mNotifier = [[FXVoltaLibraryNotifier alloc] initWithLibrary:self];
  if ( !mInTestMode )
  {
    [self setUpAutomaticReloadingOfSubcircuits]; FXIssue(101)
    [self setUpAutomaticReloadingOfPalette];
    [self setUpAutomaticReloadingOfCustomModels];
  }
  return self;
}


- (id) initWithRootLocation:(NSURL*)rootLocation
{
  if (rootLocation == nil)
  {
    rootLocation = [[self class] localStandardRootLocation];
  }
  FXVoltaLibraryStorage* storage = [[FXVoltaLibraryStorage alloc] initWithRootLocation:rootLocation];
  id result = [self initWithStorage:storage testMode:NO];
  FXRelease(storage)
  return result;
}


- (id) init
{
  return [self initWithRootLocation:nil];
}


- (void) dealloc
{
  [self shutDown];
  FXDeallocSuper
}


- (void) shutDown
{
  if ( mSubcircuitsFolderWatcher != NULL )
  {
    [self releaseEventStream:mSubcircuitsFolderWatcher];
    mSubcircuitsFolderWatcher = NULL;
  }
  if ( mPaletteFolderWatcher != NULL )
  {
    [self releaseEventStream:mPaletteFolderWatcher];
    mPaletteFolderWatcher = NULL;
  }
  if ( mModelsFolderWatcher != NULL )
  {
    [self releaseEventStream:mModelsFolderWatcher];
    mModelsFolderWatcher = NULL;
  }

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  FXRelease(mNotifier)
  mNotifier = nil;
  FXRelease(mStorage) // Important: Release before FXVoltaLibraryData
  mStorage = nil;
  FXRelease(mShapeRepository)
  mShapeRepository = nil;
}


#pragma mark Public methods


+ (FXVoltaLibrary*) newTestLibrary
{
  FXVoltaLibraryStorage* storage = [[FXVoltaLibraryStorage alloc] initWithRootLocation:[FXVoltaLibraryStorage testRootLocation]];
  id result = [[FXVoltaLibrary alloc] initWithStorage:storage testMode:YES];
  FXRelease(storage)
  return result;
}


+ (NSURL*) localStandardRootLocation
{
  return [FXVoltaLibraryStorage standardRootLocation];
}


- (NSURL*) rootLocation
{
  return mStorage.rootLocation;
}


- (void) reloadSubcircuits
{
  @synchronized(self)
  {
    [mShapeRepository removeShapesOfType:VMT_SUBCKT subtype:nil];
    mData.clearSubcircuits();
    if ( mStorage != nil )
    {
      [mStorage loadStoredItemsOfType:FXVoltaLibraryStorageItem_Subcircuit intoLibraryData:&mData];
      [self createSubcircuitShapes];
      [mNotifier notifySubcircuitsChanged];
    }
  }
}


- (void) reloadPalette
{
  @synchronized(self)
  {
    mData.clearElementGroups();
    if ( mStorage != nil )
    {
      [mStorage loadStoredItemsOfType:FXVoltaLibraryStorageItem_Element intoLibraryData:&mData];
      [mNotifier notifyPaletteChanged];
    }
  }
}


#pragma mark VoltaLibrary implementation


- (void) beginEditingPalette
{
  @synchronized(self)
  {
    mData.lockElements();
    mNowBatchEditingPalette = YES;
  }
}


- (void) endEditingPalette
{
  @synchronized(self)
  {
    mNowBatchEditingPalette = NO;
    mData.unlockElements();
    if ( mNeedsHandlingPaletteChanged )
    {
      [self handlePaletteChanged];
      mNeedsHandlingPaletteChanged = NO;
    }
  }
}


- (void) beginEditingModels
{
  @synchronized(self)
  {
    mData.lockModels();
    mNowBatchEditingModels = YES;
  }
}


- (void) endEditingModels
{
  @synchronized(self)
  {
    mNowBatchEditingModels = NO;
    mData.unlockModels();
    if ( mNeedsHandlingModelsChanged )
    {
      [self handleModelsChanged];
      mNeedsHandlingModelsChanged = NO;
    }
  }
}


- (void) iterateOverModelGroupsByApplyingBlock:(void(^)(VoltaPTModelGroupPtr, BOOL*))block
{
  @synchronized(self)
  {
    mData.iterateModelGroups(block);
  }
}

- (void) iterateOverElementGroupsByApplyingBlock:(void(^)(VoltaPTElementGroup const &, BOOL*))block
{
  @synchronized(self)
  {
    mData.iterateElementGroups(block);
  }
}

- (void) iterateOverSubcircuitsByApplyingBlock:(void(^)(VoltaPTModelPtr, BOOL*))block
{
  @synchronized(self)
  {
    mData.iterateSubcircuits(block);
  }
}


- (void) createAndStoreShapeForModel:(VoltaPTModelPtr)model makeDefaultForType:(BOOL)isDefaultShape
{
  @synchronized(mShapeRepository)
  {
    [mShapeRepository createAndStoreShapeForModel:model makeDefaultForType:isDefaultShape];
  }
}


- (id<FXShape>) shapeForModelType:(VoltaModelType)modelType name:(NSString*)modelName vendor:(NSString*)vendor
{
  @synchronized(mShapeRepository)
  {
    id<FXShape> result = nil;
    if ( modelType == VMT_DECO )
    {
      __block FXString modelSubtype;
      mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
        if ( group->modelType == VMT_DECO )
        {
          for ( auto model : group->models )
          {
            if ( (model->name == FXString((__bridge CFStringRef)modelName)) && (model->vendor == FXString((__bridge CFStringRef)vendor))  )
            {
              modelSubtype = model->subtype;
              break;
            }
          }
          *stop = YES;
        }
      });
      if ( modelSubtype == "TEXT" )
      {
        result = [FXShapeFactory shapeFromText:FXLocalizedString(@"TextElementDefaultText")];
      }
    }
    else
    {
      result = [mShapeRepository findShapeForModelType:modelType subtype:nil name:modelName vendor:vendor strategy:FXShapeSearch_AnySubtype];
    }
    return result;
  }
}


- (void) addObserver:(id<VoltaLibraryObserver>)observer
{
  @synchronized(mNotifier)
  {
    [mNotifier addObserver:observer];
  }
}


- (void) removeObserver:(id<VoltaLibraryObserver>)observer
{
  @synchronized(mNotifier)
  {
    [mNotifier removeObserver:observer];
  }
}


- (void) openEditor
{
  @synchronized(mNotifier)
  {
    [mNotifier notifyOpenEditor];
  }
}


- (VoltaPTModelPtr) modelForElement:(VoltaPTElement const &)element
{
  @synchronized(self)
  {
    __block VoltaPTModelPtr result;
    if ( element.type == VMT_SUBCKT )
    {
      mData.iterateSubcircuits(^(VoltaPTModelPtr subcircuit, BOOL *stop) {
        if ( (subcircuit->name == element.modelName) && (subcircuit->vendor == element.modelVendor) )
        {
          result = subcircuit;
          *stop = YES;
        }
      });
    }
    else
    {
      mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
        if ( group->modelType == element.type )
        {
          for ( auto model : group->models )
          {
            if ( (model->name == element.modelName) && (model->vendor == element.modelVendor) )
            {
              result = model;
              break;
            }
          }
          *stop = YES;
        }
      });
    }
    return result;
  }
}


- (VoltaPTModelPtr) defaultModelForType:(VoltaModelType)modelType
{
  @synchronized(self)
  {
    return mData.defaultModelForType(modelType);
  }
}


- (VoltaPTModelPtr) modelForType:(VoltaModelType)modelType name:(FXString const &)modelName vendor:(FXString const &)vendorString
{
  __block VoltaPTModelPtr result;
  @synchronized(self)
  {
    if ( modelType == VMT_SUBCKT )
    {
      mData.iterateSubcircuits(^(VoltaPTModelPtr subcircuit, BOOL *stop) {
        if ( (subcircuit->name == modelName) && (subcircuit->vendor == vendorString) )
        {
          result = subcircuit;
          *stop = YES;
        }
      });
    }
    else
    {
      result = mData.findModel(modelType, modelName, vendorString, FXVoltaLibrarySearchStrategy::MatchAll);
    }
  }
  return result;
}


- (FXString) createElementGroup
{
  @synchronized(self)
  {
    NSString* defaultGroupName = FXLocalizedString(@"UntitledPaletteGroup");
    FXString const newGroupName = mData.createElementGroup((__bridge CFStringRef)defaultGroupName);
    [self setNeedsHandlingPaletteChanged];
    return newGroupName;
  }
}


- (FXString) copyElementGroup:(FXString const &)groupName
{
  @synchronized(self)
  {
    FXString const newGroupName = mData.copyElementGroup(groupName);
    [self setNeedsHandlingPaletteChanged];
    return newGroupName;
  }
}


- (BOOL) removeElementGroups:(FXStringVector const &)elementGroupsToRemove
{
  @synchronized(self)
  {
    BOOL result = NO;

    mData.lockElements();

    BOOL groupNotFound = NO;
    for( FXString const & groupName : elementGroupsToRemove )
    {
      if ( !mData.hasElementGroup(groupName) )
      {
        groupNotFound = YES;
        break;
      }
    }

    if ( !groupNotFound )
    {
      bool removedAllGroups = true;
      for ( FXString const & groupName : elementGroupsToRemove )
      {
        removedAllGroups = removedAllGroups && mData.removeElementGroup(groupName);
      }
      NSAssert( removedAllGroups, @"Could not remove all groups although all of them should have existed." );
      result = YES;
    }

    mData.unlockElements();

    if ( result )
    {
      [self setNeedsHandlingPaletteChanged];
    }

    return result;
  }
}


- (BOOL) moveElementGroupsAtIndexes:(NSIndexSet*)itemIndexes
       inFrontOfElementGroupAtIndex:(NSUInteger)insertionIndex
{
  @synchronized(self)
  {
    BOOL result = NO;
    __block std::set<unsigned> groupIndexes;
    [itemIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
      groupIndexes.insert((unsigned)index);
    }];
    if ( mData.moveElementGroups( groupIndexes, (unsigned)insertionIndex ) )
    {
      result = YES;
      [self setNeedsHandlingPaletteChanged];
    }
    return result;
  }
}


- (BOOL) renameElementGroup:(FXString const &)groupName proposedName:(FXString const &)newName
{
  @synchronized(self)
  {
    if ( mData.renameElementGroup(groupName, newName) )
    {
      [self setNeedsHandlingPaletteChanged];
      return YES;
    }
    return NO;
  }
}


- (BOOL) addElements:(VoltaPTElementVector const &)elements
             toGroup:(FXString const &)groupName
{
  @synchronized(self)
  {
    mData.lockElements();
    __block size_t groupSize = 0;
    mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
      if ( group.name == groupName )
      {
        groupSize = group.elements.size();
        *stop = YES;
      }
    });
    BOOL const result = [self insertElements:elements intoGroup:groupName atIndex:groupSize dueToReordering:NO];
    mData.unlockElements();
    return result;
  }
}


- (BOOL) insertElements:(VoltaPTElementVector const &)elements
              intoGroup:(FXString const &)groupName
                atIndex:(NSInteger)index
        dueToReordering:(BOOL)reordering
{
  @synchronized(self)
  {
    if ( mData.insertElements(elements, groupName, (unsigned)index, reordering) )
    {
      [self setNeedsHandlingPaletteChanged];
      return YES;
    }
    return NO;
  }
}


- (BOOL) removeElements:(std::vector< std::pair<FXString,FXString> > const &)elementsAndGroups;
{
  @synchronized(self)
  {
    BOOL removedAll = YES;
    BOOL removedAny = NO;
    for ( auto & elementAndGroup : elementsAndGroups )
    {
      bool const removed = mData.removeElement(elementAndGroup.first, elementAndGroup.second);
      removedAll = removedAll && removed;
      removedAny = removedAny || removedAny;
    }
    if ( removedAny )
    {
      [self setNeedsHandlingPaletteChanged];
    }
    return removedAll;
  }
}


- (BOOL) renameElement:(FXString const &)elementName
               inGroup:(FXString const &)groupName
                toName:(FXString const &)newName
{
  BOOL success = NO;
  @synchronized(self)
  {
    if ( mData.renameElement(elementName, groupName, newName) )
    {
      [self setNeedsHandlingPaletteChanged];
      success = YES;
    }
  }
  return success;
}


- (BOOL) updateProperties:(NSDictionary*)elementProperties
                ofElement:(FXString const &)elementName
                  inGroup:(FXString const &)groupName
{
  BOOL success = NO;
  @synchronized(self)
  {
    __block VoltaPTPropertyVector properties;
    [elementProperties enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* value, BOOL* stop) {
      if ( (value != nil) && ([value length] > 0) )
      {
        properties.push_back(VoltaPTProperty((__bridge CFStringRef)key, (__bridge CFStringRef)value));
      }
    }];
    if ( mData.setElementProperties(elementName, groupName, properties) )
    {
      [self setNeedsHandlingPaletteChanged];
      success = YES;
    }
  }
  return success;
}


- (VoltaPTModelPtrSet) removeModels:(VoltaPTModelPtrSet const &)modelsToRemove
{
  VoltaPTModelPtrSet result;
  @synchronized(self)
  {
    if ( !modelsToRemove.empty() )
    {
      for ( VoltaPTModelPtr modelToRemove : modelsToRemove )
      {
        if ( modelToRemove->isMutable && mData.removeModel(modelToRemove) )
        {
          result.insert(modelToRemove);
        }
      }
      if ( !result.empty() )
      {
        [self setNeedsHandlingModelsChanged];
      }
    }
  }
  return result;
}


- (BOOL) renameModel:(VoltaPTModelPtr)model toName:(FXString const &)newName
{
  @synchronized(self)
  {
    BOOL result = NO;
    if ( (model.get() != nullptr) && model->isMutable )
    {
      BOOL const elementGroupsNeedUpdating = mData.hasElementWithModel(model);
      FXString const oldName = model->name;
      if ( mData.renameModel(model, newName) )
      {
        [mShapeRepository renameShapeWithType:model->type subtype:model->subtype oldName:oldName oldVendor:model->vendor newName:newName newVendor:model->vendor];
        [self setNeedsHandlingModelsChanged];
        if (elementGroupsNeedUpdating)
        {
          [self setNeedsHandlingPaletteChanged];
        }
        result = YES;
      }
    }
    return result;
  }
}


- (VoltaPTModelPtr) createModelFromTemplate:(VoltaPTModelPtr)templateModel
{
  @synchronized(self)
  {
    VoltaPTModelPtr newModel;
    if ( (templateModel.get() != nullptr) && (templateModel->type != VMT_Unknown) )
    {
      newModel = VoltaPTModelPtr( new VoltaPTModel );
      *newModel = *templateModel;
      newModel->isMutable = true;
      newModel->source = "the source must not be empty otherwise it won't be saved as a custom model";

      if ( mData.addModel(newModel, FXVoltaLibraryItemAddingPolicy::RenameNewItem) )
      {
        [mShapeRepository createAndStoreShapeForModel:newModel makeDefaultForType:NO];
        [self setNeedsHandlingModelsChanged];
      }
    }
    return newModel;
  }
}


- (void) setPropertyValueOfModel:(VoltaPTModelPtr)model propertyName:(FXString const &)name propertyValue:(FXString const &)newValue
{
  @synchronized(self)
  {
    BOOL foundProperty = NO;
    for( VoltaPTProperty& property : model->properties )
    {
      if ( property.name == name )
      {
        property.value = newValue;
        foundProperty = YES;
        break;
      }
    }
    if ( foundProperty )
    {
      [self setNeedsHandlingModelsChanged];
    }
  }
}


- (BOOL) setVendor:(FXString const &)newVendorString forModels:(VoltaPTModelPtrVector const &)models
{
  @synchronized(self)
  {
    std::vector<std::pair<VoltaPTModelPtr,FXString>> modelsAndOldVendorStrings;
    for ( VoltaPTModelPtr model : models )
    {
      modelsAndOldVendorStrings.push_back( { model, model->vendor } );
    }

    BOOL result = NO;
    BOOL updateElementGroups = NO;
    if ( mData.setVendorString( models, newVendorString ) )
    {
      size_t modelIndex = 0;
      for ( auto model : models )
      {
        updateElementGroups = updateElementGroups || mData.hasElementWithModel(model);
        NSAssert(model->vendor == newVendorString, @"The vendor string should have changed by now.");
        FXString const & oldVendorString = modelsAndOldVendorStrings.at(modelIndex).second;
        [mShapeRepository renameShapeWithType:model->type subtype:model->subtype oldName:model->name oldVendor:oldVendorString newName:model->name newVendor:newVendorString];
        modelIndex++;
      }
      [self setNeedsHandlingModelsChanged];
      result = YES;
    }
    if (updateElementGroups)
    {
      [self setNeedsHandlingPaletteChanged];
    }
    return result;
  }
}


- (NSURL*) subcircuitsLocation
{
  return [mStorage subcircuitsLocation];
}


- (NSURL*) paletteLocation
{
  return [mStorage paletteLocation];
}


- (NSURL*) modelsLocation
{
  return [mStorage modelsLocation];
}


#pragma mark Private


- (void) setNeedsHandlingPaletteChanged
{
  mNeedsHandlingPaletteChanged = YES;
  if ( !mNowBatchEditingPalette )
  {
    [self handlePaletteChanged];
    mNeedsHandlingPaletteChanged = NO;
  }
}


- (void) handlePaletteChanged
{
  [self storeElements]; // -> filesystem event -> [self reloadPalette] -> [mNotifier notifyPaletteChanged]
  if ( mInTestMode )
  {
    [mNotifier notifyPaletteChanged];
  }
}


- (void) setNeedsHandlingModelsChanged
{
  mNeedsHandlingModelsChanged = YES;
  if ( !mNowBatchEditingModels )
  {
    [self handleModelsChanged];
    mNeedsHandlingModelsChanged = NO;
  }
}


- (void) handleModelsChanged
{
  [self storeModels];
  if ( mInTestMode )
  {
    [mNotifier notifyModelsChanged];
  }
}


- (void) createModelGroupNamed:(NSString*)groupName withType:(VoltaModelType)type
{
  VoltaPTModelGroupPtr group( new VoltaPTModelGroup( (__bridge CFStringRef)groupName, type) );
  mData.addModelGroup(group);
}


- (void) createModelGroups
{
#define CREATE_MODEL_GROUP_(x, y) [self createModelGroupNamed:FXLocalizedString((x)) withType:VMT_##y]
#define CREATE_MODEL_GROUP(z) CREATE_MODEL_GROUP_( @#z, z )
  CREATE_MODEL_GROUP_(@"NODE", Node);
  CREATE_MODEL_GROUP_(@"GRND", Ground);
  CREATE_MODEL_GROUP(R);
  CREATE_MODEL_GROUP(C);
  CREATE_MODEL_GROUP(L);
  CREATE_MODEL_GROUP(LM);
  CREATE_MODEL_GROUP(D);
  CREATE_MODEL_GROUP(BJT);
  CREATE_MODEL_GROUP(JFET);
  CREATE_MODEL_GROUP(MOSFET);
  CREATE_MODEL_GROUP(MESFET);
  CREATE_MODEL_GROUP(METER);
  CREATE_MODEL_GROUP(V);
  CREATE_MODEL_GROUP(I);
  CREATE_MODEL_GROUP(SW);
  CREATE_MODEL_GROUP(XL);
  CREATE_MODEL_GROUP(DECO);
}


- (void) createModelShapes
{
  FXIssue(05)
  mData.iterateModelGroups( ^(VoltaPTModelGroupPtr modelGroup, BOOL* stop) {
    for( VoltaPTModelPtr model : modelGroup->models )
    {
      if ( model->type != VMT_DECO )
      {
        // The first immutable model of a certain type and subtype will determine the default shape
        if ( !model->isMutable )
        {
          BOOL makeDefault = ([mShapeRepository defaultShapeForModelType:model->type subtype:(__bridge NSString*)model->subtype.cfString()] == nil);
          [mShapeRepository createAndStoreShapeForModel:model makeDefaultForType:makeDefault];
        }
        else
        {
          [self createAndStoreShapeForModel:model makeDefaultForType:NO];
        }
      }
    }
  });
}


- (void) createSubcircuitShapes
{
  mData.iterateSubcircuits( ^(VoltaPTModelPtr subcircuitModel, BOOL* stop) {
    [mShapeRepository createAndStoreShapeForModel:subcircuitModel makeDefaultForType:NO];
  });
}


- (void) createShapes
{
  [self createModelShapes];
  [self createSubcircuitShapes];
}


- (void) storeModels
{
  [mStorage storeItemsOfType:FXVoltaLibraryStorageItem_Model fromLibraryData:&mData];
}


- (void) storeElements
{
  [mStorage storeItemsOfType:FXVoltaLibraryStorageItem_Element fromLibraryData:&mData];
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
    void(^handlerBlock)(void) = (__bridge void(^)(void) ) clientCallBackInfo;
    handlerBlock();
  }
}


const void*	retainFSEventHandlerContextInfo(const void *info)
{
  // Do nothing because Block_copy was already called.
  return info;
}


void releaseFSEventHandlerContextInfo(const void *info)
{
  void(^handlerBlock)(void) = (__bridge void(^)(void) ) info;
  Block_release(handlerBlock);
}


- (void) releaseEventStream:(FSEventStreamRef)eventStream
{
  if (eventStream != NULL)
  {
    FSEventStreamStop(eventStream);
    FSEventStreamInvalidate(eventStream);
    FSEventStreamRelease(eventStream);
  }
}


- (FSEventStreamRef) setUpMonitoringOfFolder:(NSString*)folderPath changeHandler:( void(^ __weak)(void) )handler
{
  FSEventStreamRef eventStream = NULL;
  if ( folderPath != nil )
  {
    CFStringRef cfFolderPath = (__bridge CFStringRef)folderPath;
    CFArrayRef monitoredFolders = CFArrayCreate(kCFAllocatorDefault, (const void **)&cfFolderPath, 1, &kCFTypeArrayCallBacks);
    CFTimeInterval const eventDelay = 0.05;
    FSEventStreamCreateFlags const creationFlags = kFSEventStreamCreateFlagNone;
    FSEventStreamContext* streamContext = (FSEventStreamContext*) calloc(1, sizeof(FSEventStreamContext)); // FSEventStreamCreate crashes in Release build if the context is not a heap variable
    streamContext->info = Block_copy((__bridge void*)handler);
    streamContext->retain = retainFSEventHandlerContextInfo;
    streamContext->release = releaseFSEventHandlerContextInfo;
    eventStream = FSEventStreamCreate(NULL, folderChangeHandler, streamContext, monitoredFolders, kFSEventStreamEventIdSinceNow, eventDelay, creationFlags);
    CFRelease(monitoredFolders);
    FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(eventStream);
    free(streamContext);
  }
  return eventStream;
}


- (void) setUpAutomaticReloadingOfSubcircuits
{
  FXIssue(101)
  if ( [[self subcircuitsLocation] isFileURL] )
  {
    NSString* subcircuitsFolder = [[self subcircuitsLocation] path];
    FXVoltaLibrary* __weak mySelf = self;
    mSubcircuitsFolderWatcher = [self setUpMonitoringOfFolder:subcircuitsFolder changeHandler:^{
      [mySelf reloadSubcircuits];
    }];
  }
}


- (void) setUpAutomaticReloadingOfPalette
{
  if ( [[self paletteLocation] isFileURL] )
  {
    NSString* paletteFolder = [[self paletteLocation] path];
    FXVoltaLibrary* __weak mySelf = self;
    mPaletteFolderWatcher = [self setUpMonitoringOfFolder:paletteFolder changeHandler:^{
      [mySelf reloadPalette];
    }];
  }
}


- (void) setUpAutomaticReloadingOfCustomModels
{
  if ( [[self modelsLocation] isFileURL] )
  {
    NSString* modelsFolder = [[self modelsLocation] path];
    FXVoltaLibrary* __weak mySelf = self;
    mModelsFolderWatcher = [self setUpMonitoringOfFolder:modelsFolder changeHandler:^{
      [mySelf reloadCustomModels];
    }];
  }
}


- (void) reloadCustomModels
{
  VoltaPTModelPtrVector removedModels = mData.removeNonBuiltInModels();
  for ( VoltaPTModelPtr removedModel : removedModels )
  {
    [mShapeRepository removeShapeForModelType:removedModel->type subtype:(__bridge NSString*)removedModel->subtype.cfString() name:(__bridge NSString*)removedModel->name.cfString() vendor:(__bridge NSString*)removedModel->vendor.cfString()];
  }
  if ( mStorage != nil )
  {
    [mStorage loadStoredItemsOfType:FXVoltaLibraryStorageItem_Model intoLibraryData:&mData];
    mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
      for ( VoltaPTModelPtr model : group->models )
      {
        [mShapeRepository createAndStoreShapeForModel:model makeDefaultForType:NO];
      }
    });
    [mNotifier notifyModelsChanged];
  }
}


@end
