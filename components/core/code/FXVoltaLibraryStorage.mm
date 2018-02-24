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

#import "FXVoltaLibraryStorage.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXVoltaPersistentMetaKeys.h"
#import "FXVoltaCircuitDomainAgent.h"
#import "FXVoltaArchiver.h"
#import "FXSPICELibParser.h"
#import "FXSystemUtils.h"


typedef NS_ENUM(NSInteger, FXVoltaLibraryStorageLocationType)
{
  FXVoltaLibraryStorageLocation_Invalid = -1,

  FXVoltaLibraryStorageLocation_Root,
  FXVoltaLibraryStorageLocation_Plugins,
  FXVoltaLibraryStorageLocation_Models,
  FXVoltaLibraryStorageLocation_Palette,
  FXVoltaLibraryStorageLocation_Subcircuits
};


static NSString* const skCustomModelGroupsKey = @"CustomModelGroups";
static NSString* const skCustomModelsFileName = @"CustomModels.volta";
static NSString* const skVoltaFileNameExtension = @"volta";
static NSString* const skSPICELibFileNameExtension = @"lib";

@implementation FXVoltaLibraryStorage
{
@private
  NSURL* mRootLocation;
  NSRecursiveLock* mModelsAccessLock;
  NSRecursiveLock* mPaletteAccessLock;
  NSRecursiveLock* mSubcircuitsAccessLock;
}

@synthesize rootLocation = mRootLocation;


- (id) init
{
  NSAssert(NO, @"Initialization requires a storage location.");
  FXDeallocSuper
  return nil;
}


- (id) initWithRootLocation:(NSURL*)rootLocation
{
  self = [super init];
  if ( self != nil )
  {
    mRootLocation = rootLocation;
    FXRetain(mRootLocation)
    mModelsAccessLock = [NSRecursiveLock new];
    mPaletteAccessLock = [NSRecursiveLock new];
    mSubcircuitsAccessLock = [NSRecursiveLock new];
  }
  return self;  
}


- (void) dealloc
{
  FXRelease(mRootLocation)
  FXRelease(mModelsAccessLock)
  FXRelease(mPaletteAccessLock)
  FXRelease(mSubcircuitsAccessLock)
  FXDeallocSuper
}


#pragma mark Public


+ (NSURL*) standardRootLocation
{
  return [FXSystemUtils appSupportFolder];
}


+ (NSURL*) testRootLocation
{
  return [FXSystemUtils appSupportAlternativeFolderWithName:@"VoltaTest"];
}


- (void) loadStoredItemsOfType:(FXVoltaLibraryStorageItemType)type
               intoLibraryData:(FXVoltaLibraryData*)data
{
  if (type == FXVoltaLibraryStorageItem_Model )
  {
    [self loadModelsIntoLibraryData:data];
  }
  else if ( type == FXVoltaLibraryStorageItem_Subcircuit )
  {
    [self loadSubcircuitsIntoLibraryData:data];
  }
  else if ( type == FXVoltaLibraryStorageItem_Element )
  {
    [self loadPaletteIntoLibraryData:data];
  }
}


- (void) loadModelItemsIntoLibraryData:(FXVoltaLibraryData*)data
{
  [self loadBuiltInModelsIntoLibraryData:data];
  [self loadStoredItemsOfType:FXVoltaLibraryStorageItem_Model intoLibraryData:data];
}


- (void) loadAllItemsIntoLibraryData:(FXVoltaLibraryData*)data
{
  [self loadModelItemsIntoLibraryData:data];
  [self loadStoredItemsOfType:FXVoltaLibraryStorageItem_Element intoLibraryData:data];
  [self loadStoredItemsOfType:FXVoltaLibraryStorageItem_Subcircuit intoLibraryData:data];
}


- (void) storeItemsOfType:(FXVoltaLibraryStorageItemType)type
          fromLibraryData:(FXVoltaLibraryData*)data
{
  if ( type == FXVoltaLibraryStorageItem_Model )
  {
    [self storeMutableModelsFromLibraryData:data];
  }
  else if ( type == FXVoltaLibraryStorageItem_Element )
  {
    [self storePaletteFromLibraryData:data];
  }
}


- (void) storeItemsFromLibraryData:(FXVoltaLibraryData*)libraryData
{
  [self storeItemsOfType:FXVoltaLibraryStorageItem_Model fromLibraryData:libraryData];
  [self storeItemsOfType:FXVoltaLibraryStorageItem_Element fromLibraryData:libraryData];
}


- (NSURL*) subcircuitsLocation
{
  return [NSURL fileURLWithPath:[self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Subcircuits createIfNecessary:YES]];
}


- (NSURL*) paletteLocation
{
  return [NSURL fileURLWithPath:[self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Palette createIfNecessary:YES]];
}


- (NSURL*) modelsLocation
{
  return [NSURL fileURLWithPath:[self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Models createIfNecessary:YES]];
}


#pragma mark Private


- (NSString*) pathOfStorageFolderForType:(FXVoltaLibraryStorageLocationType)folderType createIfNecessary:(BOOL)create
{
  NSError* fileOperationError = nil;
  BOOL fileIsADirectory = NO;
  NSString* result = nil;

  NSAssert([mRootLocation isFileURL], @"The root location needs to be on the filesystem.");
  NSString* basePath = [mRootLocation path];

  NSFileManager* fm = [NSFileManager defaultManager];
  
  // Checking and creating the base application support directory
  BOOL fileExists = [fm fileExistsAtPath:basePath isDirectory:&fileIsADirectory];
  if ( fileExists && !fileIsADirectory )
  {
    if ( !create || ![fm moveItemAtPath:basePath toPath:[basePath stringByAppendingPathExtension:@".old"] error:&fileOperationError] )
    {
      [NSApp presentError:fileOperationError];
      return nil;
    }
  }
  else if ( !fileExists )
  {
    if ( !create )
    {
      return nil;
    }

    if ( ![fm createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:nil error:&fileOperationError] )
    {
      [NSApp presentError:fileOperationError];
    }
  }
  
  switch( folderType )
  {
    case FXVoltaLibraryStorageLocation_Models: result = [basePath stringByAppendingPathComponent:@"Models"]; break;
    case FXVoltaLibraryStorageLocation_Palette: result = [basePath stringByAppendingPathComponent:@"Palette"]; break;
    case FXVoltaLibraryStorageLocation_Subcircuits: result = [basePath stringByAppendingPathComponent:@"Subcircuits"]; break;
    case FXVoltaLibraryStorageLocation_Plugins: result = [basePath stringByAppendingPathComponent:@"Plugins"]; break;
    default: /* do nothing */ ;
  }
  if ( result && create )
  {
    fileExists = [fm fileExistsAtPath:result isDirectory:&fileIsADirectory];
    if ( fileExists && !fileIsADirectory )
    {
      // Delete the file that has the same name and create the folder.
      if ( [fm removeItemAtPath:result error:&fileOperationError] )
      {
        fileExists = NO;
      }
      else
      {
        result = nil;
        NSLog( @"Volta support folder blocked by existing file. Couldn't resolve. %@", [fileOperationError localizedDescription] );
        [NSApp presentError:fileOperationError];
      }
    }
    if ( !fileExists )
    {
      if ( ![fm createDirectoryAtPath:result withIntermediateDirectories:NO attributes:nil error:&fileOperationError] )
      {
        NSLog(@"Volta could not create the required support folder at \"%@\". %@", result, [fileOperationError localizedDescription]);
        result = nil;
        [NSApp presentError:fileOperationError];
      }
    }
  }
  return result;
}


- (void) loadModelsFromFolder:(NSString*)folderPath intoLibraryData:(FXVoltaLibraryData*)libraryData makeMutable:(BOOL)isMutable
{
  if ( folderPath != nil )
  {
    NSString* userLibrariesFolder = [self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Models createIfNecessary:NO];
    BOOL const folderIsUserLibrariesFolder = (userLibrariesFolder != nil) && [folderPath hasPrefix:userLibrariesFolder];

    NSString* const kBundlePrefix = [[NSBundle bundleForClass:[self class]] bundlePath];
    NSFileManager* fm = [NSFileManager defaultManager];
    NSArray* libraryFiles = [fm contentsOfDirectoryAtPath:folderPath error:NULL];
    if ( libraryFiles != nil )
    {
      for ( NSString* currentFile in libraryFiles )
      {
        NSString* fileExtension = [[currentFile pathExtension] lowercaseString];
        if ( [fileExtension isEqualToString:skVoltaFileNameExtension]
          || [fileExtension isEqualToString:skSPICELibFileNameExtension] )
        {
          if ( folderIsUserLibrariesFolder && [currentFile isEqualToString:skCustomModelsFileName] )
          {
            // In Volta 1.2 only the models in CustomModels.volta are mutable.
            isMutable = YES;
          }
          
          NSString* fullFilePath = [folderPath stringByAppendingPathComponent:currentFile];
          BOOL fileIsADirectory = NO;
          if ( [fm fileExistsAtPath:fullFilePath isDirectory:&fileIsADirectory] && !fileIsADirectory )
          {
            NSString* libraryString = [NSString stringWithContentsOfFile:fullFilePath encoding:NSUTF8StringEncoding error:NULL];
            if ( libraryString != nil )
            {
              FXString source;
              if ( ![fullFilePath hasPrefix:kBundlePrefix] )
              {
                source = (__bridge CFStringRef)[[NSURL fileURLWithPath:fullFilePath] absoluteString];
              }
              if ( [fileExtension isEqualToString:skVoltaFileNameExtension] )
              {
                VoltaPTLibraryPtr unarchivedLibrary = [FXVoltaArchiver unarchiveLibraryFromString:libraryString formatUpgradedWhileUnarchiving:nil error:nil];
                if ( unarchivedLibrary.get() != nullptr )
                {
                  libraryData->addLibraryModels(unarchivedLibrary, source, isMutable);
                }
              }
              else
              {
                VoltaPTModelGroupPtr libraryModels = FXSPICELibParser::parseLib((__bridge CFStringRef)libraryString);
                if ( libraryModels.get() != nullptr )
                {
                  for ( VoltaPTModelPtr model : libraryModels->models )
                  {
                    model->isMutable = false;
                    model->source = source;
                    libraryData->addModel(model, FXVoltaLibraryItemAddingPolicy::ReplaceOlderVersion);
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}


- (void) loadBuiltInModelsIntoLibraryData:(FXVoltaLibraryData*)libraryData
{
  NSString* bundleResourceFolder = [[NSBundle bundleForClass:[self class]] resourcePath];
  [self loadModelsFromFolder:bundleResourceFolder intoLibraryData:libraryData makeMutable:NO];
}


- (void) loadModelsIntoLibraryData:(FXVoltaLibraryData*)libraryData
{
  NSString* modelsFolder = [self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Models createIfNecessary:NO];
  [self loadModelsFromFolder:modelsFolder intoLibraryData:libraryData makeMutable:NO];
}


- (void) loadSubcircuitsIntoLibraryData:(FXVoltaLibraryData*)data
{
  NSAssert(data != nil, @"Invalid library data object.");
  data->clearSubcircuits();
  NSString* subcircuitsRootFolder = [self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Subcircuits createIfNecessary:NO];
  NSFileManager* fm = [NSFileManager defaultManager];
  BOOL fileIsDirectory = NO;
  if ( [fm fileExistsAtPath:subcircuitsRootFolder isDirectory:&fileIsDirectory] && fileIsDirectory )
  {
    NSError* errorVar = nil;
    NSArray* allSubcircuits = [fm subpathsOfDirectoryAtPath:subcircuitsRootFolder error:&errorVar];
    if ( allSubcircuits == nil )
    {
      DebugLog( @"Error while collecting subcircuits: %@", [errorVar localizedDescription] );
      [NSApp presentError:errorVar];
    }
    else
    {
      for ( NSString* subcircuitFilePath in allSubcircuits )
      {
        if ( ![[[subcircuitFilePath pathExtension] lowercaseString] isEqualToString:skVoltaFileNameExtension] )
        {
          continue;
        }
        NSString* absoluteFilePath = [subcircuitsRootFolder stringByAppendingPathComponent:subcircuitFilePath];
        NSString* subcircuitFileContents = [NSString stringWithContentsOfFile:absoluteFilePath encoding:NSUTF8StringEncoding error:&errorVar];
        if ( subcircuitFileContents == nil )
        {
          DebugLog( @"Error while reading contents of %@ : %@", subcircuitFilePath, [errorVar localizedDescription] );
        }
        else
        {
          VoltaPTCircuitPtr currentCircuit = [FXVoltaArchiver unarchiveCircuitFromString:subcircuitFileContents formatUpgradedWhileUnarchiving:nil error:NULL];
          if ( currentCircuit.get() != nullptr )
          {
            VoltaPTSubcircuitDataPtr subcircuitData = currentCircuit->subcircuitData;
            if ( subcircuitData->enabled )
            {
              VoltaPTModelPtr subcircuitModel( new VoltaPTModel );
              subcircuitModel->name = subcircuitData->name;
              subcircuitModel->vendor = subcircuitData->vendor;
              subcircuitModel->type = VMT_SUBCKT;
              subcircuitModel->source = (__bridge CFStringRef)absoluteFilePath;
              subcircuitModel->metaData = subcircuitData->metaData;
              subcircuitModel->shape = subcircuitData->shape;
              subcircuitModel->pins = subcircuitData->pins;
              subcircuitModel->elementNamePrefix = FXVoltaCircuitDomainAgent::circuitElementNamePrefixForModel(subcircuitModel);
              subcircuitModel->labelPosition = subcircuitData->labelPosition;
              subcircuitModel->isMutable = false;
              
              std::copy( subcircuitData->externals.begin(), subcircuitData->externals.end(), std::back_inserter(subcircuitModel->metaData) );

              // Copying the netlist of the circuit into the model.
              FXString subcircuitNetlist;
              for( VoltaPTMetaDataItem const & metaDataItem : currentCircuit->metaData )
              {
                if ( metaDataItem.first == (__bridge CFStringRef)FXVolta_Netlist )
                {
                  subcircuitNetlist = metaDataItem.second;
                  break;
                }
              }
              subcircuitModel->metaData.push_back( { FXVolta_SubcircuitNetlist, subcircuitNetlist } );
              
              data->addSubcircuit( subcircuitModel, FXVoltaLibraryItemAddingPolicy::ReplaceOlderVersion );
            }
          }
        }
      }
    }
  }
}


- (void) loadPaletteIntoLibraryData:(FXVoltaLibraryData*)data
{
  NSString* paletteStorageFolder = [self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Palette createIfNecessary:NO];
  if ( paletteStorageFolder != nil )
  {
    NSFileManager* fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if ( [fm fileExistsAtPath:paletteStorageFolder isDirectory:&isDir] && isDir )
    {
      NSArray* paletteFiles = [fm contentsOfDirectoryAtPath:paletteStorageFolder error:NULL];
      if ( (paletteFiles != nil) && ([paletteFiles count] > 0) )
      {
        for ( NSString* paletteFile in paletteFiles )
        {
          if ( [[paletteFile pathExtension] isEqualToString:skVoltaFileNameExtension] )
          {
            NSString* paletteFilePath = [paletteStorageFolder stringByAppendingPathComponent:paletteFile];
            NSData* fileData = [fm contentsAtPath:paletteFilePath];
            if ( fileData != nil )
            {
              NSString* fileText = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
              VoltaPTLibraryPtr elementsLibrary = [FXVoltaArchiver unarchiveLibraryFromString:fileText formatUpgradedWhileUnarchiving:NULL error:NULL];
              FXRelease(fileText)
              if ( elementsLibrary.get() != nullptr )
              {
                FXString groupName = (__bridge CFStringRef)[paletteFile stringByDeletingPathExtension];
                groupName = data->createElementGroup(groupName);
                for ( VoltaPTElement const & element : elementsLibrary->elementGroup.elements )
                {
                  data->addElement(element, groupName);
                }
              }
            }
          }
        }
      }
    }
  }
}


- (void) storeMutableModelsFromLibraryData:(FXVoltaLibraryData*)data
{
  NSString* modelsFolderPath = [self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Models createIfNecessary:YES];
  if ( modelsFolderPath == nil )
    return;

  // All mutable models are stored in CustomModels.volta.
  NSString* archiveFilePath = [modelsFolderPath stringByAppendingPathComponent:skCustomModelsFileName];

  // First we delete the file, which covers the case that there are no custom models left in the library.
  [[NSFileManager defaultManager] removeItemAtPath:archiveFilePath error:NULL];

  // Collecting all mutable models into a single library
  VoltaPTModelGroupPtr customModelsGroup( new VoltaPTModelGroup );
  customModelsGroup->name = "Custom Models";
  data->iterateModelGroups( ^(VoltaPTModelGroupPtr modelGroup, BOOL* stop) {
    for( VoltaPTModelPtr model : modelGroup->models )
    {
      if ( model->isMutable )
      {
        customModelsGroup->models.push_back( model );
      }
    }
  });
  if ( !customModelsGroup->models.empty() )
  {
    VoltaPTLibraryPtr customModelsLibrary( new VoltaPTLibrary );
    customModelsLibrary->modelGroup = customModelsGroup;
    customModelsLibrary->title = customModelsGroup->name;
    NSString* archivedCustomModelsLibrary = [FXVoltaArchiver archiveLibrary:customModelsLibrary];
    NSError* fileWriteError = nil;
    if ( ![archivedCustomModelsLibrary writeToFile:archiveFilePath atomically:YES encoding:NSUTF8StringEncoding error:&fileWriteError] )
    {
      NSLog( @"%@", [fileWriteError localizedDescription] );
      [NSApp presentError:fileWriteError];
    }
  }
}


- (void) storePaletteFromLibraryData:(FXVoltaLibraryData*)data
{
  [self removeItemsAtLocation:FXVoltaLibraryStorageLocation_Palette];
  NSString* storageFolderPath = [self pathOfStorageFolderForType:FXVoltaLibraryStorageLocation_Palette createIfNecessary:YES];
  data->iterateElementGroups( ^(VoltaPTElementGroup const & elementGroup, BOOL* stop) {
    VoltaPTLibraryPtr groupLibrary( new VoltaPTLibrary() );
    groupLibrary->title = elementGroup.name;
    groupLibrary->elementGroup = elementGroup;
    NSString* archivedLibrary = [FXVoltaArchiver archiveLibrary:groupLibrary];
    NSString* fileName = [NSString stringWithFormat:@"%@.volta", groupLibrary->title.cfString()];
    NSString* filePath = [storageFolderPath stringByAppendingPathComponent:fileName];
    NSError* fileWriteError = nil;
    if ( ![archivedLibrary writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&fileWriteError] )
    {
      NSLog( @"%@", [fileWriteError localizedDescription] );
      [NSApp presentError:fileWriteError];
    }
  });
}


- (BOOL) removeItemsAtLocation:(FXVoltaLibraryStorageLocationType)locationType
{
  BOOL success = NO;
  NSRecursiveLock* accessLock = nil;
  switch (locationType)
  {
    case FXVoltaLibraryStorageLocation_Subcircuits: accessLock = mSubcircuitsAccessLock; break;
    case FXVoltaLibraryStorageLocation_Palette: accessLock = mPaletteAccessLock; break;
    case FXVoltaLibraryStorageLocation_Models: accessLock = mModelsAccessLock; break;
    default: break;
  }
  NSString* path = [self pathOfStorageFolderForType:locationType createIfNecessary:NO];
  if ( (path != nil) && (accessLock != nil) )
  {
    [accessLock lock];
    NSFileManager* fm = [NSFileManager defaultManager];
    BOOL pathIsDirectory = NO;
    if ( [fm fileExistsAtPath:path isDirectory:&pathIsDirectory] && pathIsDirectory )
    {
      success = YES;
      for ( NSString* fileName in [fm contentsOfDirectoryAtPath:path error:NULL] )
      {
        NSString* filePath = [path stringByAppendingPathComponent:fileName];
        success = success && [fm removeItemAtPath:filePath error:NULL];
      }
      NSAssert(success && ([[fm contentsOfDirectoryAtPath:path error:NULL] count] == 0), @"Could not remove all items in the directory");
    }
    [accessLock unlock];
  }
  return success;
}

@end
