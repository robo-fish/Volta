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

#import "FXCircuitSimulator.h"
#import "FXCircuitSimulationInfo.h"
#if SimulatorOutputParser == FXSpiceOutputParser
  #import "FXSpiceOutputParser.h"
#endif
#import "VoltaSimulationObserver.h"
#import "FXSystemUtils.h"


@implementation FX(FXCircuitSimulator)
{
@private
  FXSimulatorData* mData;
}


- (id) init
{
  self = [super init];
  mData = new FXSimulatorData;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppTermination:) name:NSApplicationWillTerminateNotification object:nil];
#if 0 // SimulatorOutputParser == FXSpiceOutputParser
  [self checkAndInstallNgspiceResources];
#endif
  return self;
}


- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self]; FXIssue(98)
  [self cleanupData];
  FXDeallocSuper
}


#pragma mark VoltaPlugin


- (NSString*) pluginIdentifier
{
  return SimulatorIdentifier;
}


- (NSObject*) newPluginImplementer
{
  FXRetain(self)
  return self;
}


- (NSString*) pluginName
{
  return SimulatorName;
}


- (NSString*) pluginVendor
{
  return SimulatorVendor;
}


- (NSString*) pluginVersion
{
  return [[NSString stringWithFormat:@"%s", FXStringizeValue(SimulatorVersion)] stringByReplacingOccurrencesOfString:@"_" withString:@"."];
}


- (VoltaPluginType) pluginType
{
  return VoltaPluginType_Simulator;
}


+ (NSArray*) mainMenuItems
{
  return @[];
}


#pragma mark CircuitSimulatorPlugin


- (VoltaSimulatorCircuitDescriptionType) circuitDescriptionType
{
  return SimulatorCircuitDescriptionType;
}


- (VoltaCircuitID) createCircuit
{
  VoltaCircuitID newCircuitID = VoltaInvalidCircuitID;
  @synchronized( self )
  {
    static VoltaCircuitID circuitID = VoltaInvalidCircuitID;
    newCircuitID = ++circuitID;
    FXCircuitMetaInfo newCircuitInfo;
    mData->currentCircuits[newCircuitID] = newCircuitInfo;
  }
  return newCircuitID;
}


- (BOOL) setDescription:(void*)data forCircuit:(VoltaCircuitID)circuitID error:(NSError**)errorObject
{
  @synchronized( self )
  {
    if ( (data == nil) || (circuitID == VoltaInvalidCircuitID) )
    {
      @throw [NSException exceptionWithName:@"VoltaException" reason:@"Invalid parameters." userInfo:nil];
    }
    FXSimulatorDataCircuitMap::iterator it = mData->currentCircuits.find(circuitID);
    if ( it != mData->currentCircuits.end() )
    {
      FXCircuitMetaInfo& circuitInfo = mData->currentCircuits[circuitID];
      NSString* netlistData = (__bridge NSString*)data;
      circuitInfo.netlist = (__bridge CFStringRef)netlistData;
    }
  }
  return YES;
}


- (VoltaSimulationID) createSimulation:(VoltaCircuitID)circuitID
{
  VoltaSimulationID result = VoltaInvalidSimulationID;
  @synchronized( self )
  {
    if ( mData->currentCircuits.find(circuitID) != mData->currentCircuits.end() )
    {
      static VoltaSimulationID sSimID = VoltaInvalidSimulationID; // simulation ID counter
      result = ++sSimID;
      FXSimulationMetaInfo simInfo;
      simInfo.circuitID = circuitID;
      mData->currentSimulations[result] = simInfo;
    }
  }
  return result;
}


- (BOOL) simulationExists:(VoltaSimulationID)simulationID
{
  BOOL result = NO;
  @synchronized( self )
  {
		result = (mData->currentSimulations.find(simulationID) != mData->currentSimulations.end());
  }
  return result;  
}


- (BOOL) removeSimulation:(VoltaSimulationID)simulationID
{
  BOOL result = NO;
  @synchronized( self )
  {
    FXSimulatorDataSimulationMap::iterator it = mData->currentSimulations.find(simulationID);
    NSAssert( it != mData->currentSimulations.end(), @"The simulation to be removed does not exist." );
    if( it != mData->currentSimulations.end() )
    {
      FXSimulationMetaInfo& simInfo = it->second;
      if ( ![simInfo.task isRunning] )
      {
        if ( simInfo.task != nil )
        {
          [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:[simInfo.pipe fileHandleForReading]];
          [self cleanupSimulation:simInfo];
        }
      }
      mData->currentSimulations.erase(it);
      result = YES;
    }
  }
  return result;
}


- (BOOL) startSimulation:(VoltaSimulationID)simID error:(NSError**)errorObject
{
  BOOL result = NO;
  @synchronized( self )
  {
    FXSimulatorDataSimulationMap::iterator it = mData->currentSimulations.find(simID);
    if ( it != mData->currentSimulations.end() )
    {
      FXSimulationMetaInfo& simInfo = it->second;
      
      // Make sure the simulator executable exists
      NSBundle* pluginBundle = [NSBundle bundleForClass:[self class]];
      NSString* resourcePath = [pluginBundle resourcePath];
      NSString* launchPath = [resourcePath stringByAppendingPathComponent:SimulatorExecutableString];
      NSString* tmpFilePath = [[simInfo.observer simulationTemporariesFolderPath]
        stringByAppendingPathComponent:[NSString stringWithFormat:@"sim_%d_input", simID]];
      
      // Create input file after deleting any existing file with the same name
      NSFileManager* defaultFileManager = [NSFileManager defaultManager];
      [defaultFileManager removeItemAtPath:tmpFilePath error:nil];
      [defaultFileManager createFileAtPath:tmpFilePath contents:nil attributes:nil];
      // The input file must contain the circuit netlist data
      FXSimulatorDataCircuitMap::iterator circuitsIt = mData->currentCircuits.find(simInfo.circuitID);
      if ( circuitsIt != mData->currentCircuits.end() )
      {
        FXCircuitMetaInfo& circuitInfo = circuitsIt->second;
        
        NSError* fileWriteError;
        NSString* netlistString = (__bridge NSString*)circuitInfo.netlist.cfString();
        if ( ![netlistString writeToFile:tmpFilePath atomically:YES encoding:NSASCIIStringEncoding error:&fileWriteError] )
        {
          [NSApp presentError:fileWriteError];
          return VoltaInvalidSimulationID;
        }
        
        simInfo.task = [[NSTask alloc] init];
        [simInfo.task setLaunchPath:launchPath];
        [simInfo.task setArguments:@[@"-b", tmpFilePath]];
        if ( [SimulatorExecutableString isEqualToString:@"ngspice"] )
        {
          simInfo.task.environment = @{
            @"SPICE_LIB_DIR" : resourcePath,
            @"TMPDIR"        : NSTemporaryDirectory(),  // Making sure it's inside the sandbox. Ngspice queries it through the C library function 'tmpfile()'
           };
        }
        simInfo.pipe = [[NSPipe alloc] init];
        [simInfo.task setStandardOutput:simInfo.pipe];
        [simInfo.task setStandardError:simInfo.pipe];
        simInfo.inputFilePath = tmpFilePath;
        FXRetain(simInfo.inputFilePath)
        simInfo.rawOut = [[NSMutableString alloc] initWithCapacity:256];
        
        NSFileHandle* fh = [simInfo.pipe fileHandleForReading];
        NSNotificationCenter* notifCenter = [NSNotificationCenter defaultCenter];
        [notifCenter addObserver:self selector:@selector(dataReady:) name:NSFileHandleReadCompletionNotification object:fh];
        [notifCenter addObserver:self selector:@selector(dataReady:) name:NSFileHandleReadToEndOfFileCompletionNotification object:fh];
        
        [simInfo.task launch];
        [fh readInBackgroundAndNotify];
        
        //DebugLog( @"Simulation task %d has process ID = %d", simID, [simInfo.task processIdentifier] );
        result = YES;
      }
    }
    else
    {
      DebugLog( @"A simulation with ID %d does not exist", simID );
    }        
  }    
  return result;
}


- (BOOL) stopSimulation:(VoltaSimulationID)simulationID error:(NSError**)errorObject
{
  BOOL result = NO;
  @synchronized( self )
  {
    FXSimulatorDataSimulationMap::iterator it = mData->currentSimulations.find(simulationID);
    if ( it != mData->currentSimulations.end() )
    {
      FXSimulationMetaInfo& simInfo = it->second;
      if ( [simInfo.task isRunning] )
      {
        [simInfo.task terminate];
        [simInfo.task waitUntilExit];
      }
      result = YES;
    }
    else
    {
      //*errorObject = [NSError errorWithDomain:FXVoltaErrorDomain code:FXSimulationDataError userInfo:nil]; // is waiting for FXIssue(83)
      DebugLog( @"Simulation task does not exist." );
    }
  }
  return result;
}


- (VoltaPTSimulationDataPtr) resultsForSimulation:(VoltaSimulationID)simID
{
  VoltaPTSimulationDataPtr result;
#ifdef SimulatorOutputParser
  FXSimulatorDataSimulationMap::iterator it = mData->currentSimulations.find(simID);
  if ( it != mData->currentSimulations.end() )
  {
    FXSimulationMetaInfo& simInfo = it->second;
    result = SimulatorOutputParser::parse([simInfo.rawOut cStringUsingEncoding:NSASCIIStringEncoding]);
  }
#endif
  return result;
}


- (NSString*) rawOutputForSimulation:(VoltaSimulationID)simID;
{
  FXSimulatorDataSimulationMap::iterator it = mData->currentSimulations.find(simID);
  if ( it != mData->currentSimulations.end() )
  {
    FXSimulationMetaInfo& simInfo = it->second;
    return [NSString stringWithString:simInfo.rawOut];
  }
  return nil;
}


- (void) setObserver:(id<VoltaSimulationObserver>)observer forSimulation:(VoltaSimulationID)simID
{
  FXSimulatorDataSimulationMap::iterator it = mData->currentSimulations.find(simID);
  if ( it != mData->currentSimulations.end() )
  {
    it->second.observer = observer;
  }
  else
  {
    DebugLog( @"Unknown simulation ID." );
  }
}


#pragma mark Private


- (void) cleanupData
{
  if ( mData != nullptr )
  {
    delete mData;
  }
}


- (void) cleanupSimulation:(FXSimulationMetaInfo&)simInfo
{
  if ( [simInfo.task isRunning] )
  {
    [simInfo.task terminate];
    [simInfo.task waitUntilExit];
  }
  if ( simInfo.inputFilePath != nil )
  {
    FXIssue(20)
    NSFileManager* fm = [NSFileManager defaultManager];
    NSAssert( [fm fileExistsAtPath:simInfo.inputFilePath], @"lost the simulation input file" );
    [fm removeItemAtPath:simInfo.inputFilePath error:NULL];
  }

  FXRelease(simInfo.task)
  simInfo.task = nil;
  FXRelease(simInfo.pipe)
  simInfo.pipe = nil;
  FXRelease(simInfo.rawOut)
  simInfo.rawOut = nil;
  FXRelease(simInfo.inputFilePath)
  simInfo.inputFilePath = nil;
}


- (void) dataReady:(NSNotification*)notification
{
  @synchronized( self )
  {
    NSFileHandle* fh = [notification object];

    for( FXSimulatorDataSimulationMapItem const & simInfoItem : mData->currentSimulations )
    {
      if ( [simInfoItem.second.pipe fileHandleForReading] == fh )
      {
        VoltaSimulationID simID = simInfoItem.first;
        // Append to result string
        NSData* tempData = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
        if ( [tempData length] > 0 )
        {
          NSString* tempString = [[NSString alloc] initWithData:tempData encoding:NSASCIIStringEncoding];
          if ( tempString != nil )
          {
            [simInfoItem.second.rawOut appendString:tempString];
            [simInfoItem.second.observer simulator:self incrementalRawSimulationOutput:tempString forSimulation:simID];
            FXRelease(tempString)
          }

          [[simInfoItem.second.pipe fileHandleForReading] readInBackgroundAndNotify];
        }
        else
        {
          [simInfoItem.second.observer simulator:self finishedSimulation:simInfoItem.first];
        }
        break;
      }
    }
  }
}


- (void) handleAppTermination:(NSNotification*)notification
{
  // Note: This message will not be received if NSSupportsSuddenTermination == YES. Check the Application plist.
  [self removeAllSimulations];
}


- (void) removeAllSimulations
{
  while ( !mData->currentSimulations.empty() )
  {
    VoltaSimulationID firstAvailableSimID = mData->currentSimulations.begin()->first;
    [self removeSimulation:firstAvailableSimID];
  }
}


FXIssue(244)
#if 0

- (NSURL*) NgspiceResourcesInstallationLocation
{
  return [[FXSystemUtils appSupportFolder] URLByAppendingPathComponent:@"Ngspice"];
}


- (void) checkAndInstallNgspiceResources
{
  NSURL* installationLocation = [self NgspiceResourcesInstallationLocation];
  NSFileManager* fm = [NSFileManager defaultManager];
  NSString* filePath = [installationLocation path];
  BOOL isDir = NO;
  NSError* fileError = nil;
  BOOL needsCopyingCodemodels = NO;
  BOOL needsCreatingSpinit = NO;
  BOOL const exists = [fm fileExistsAtPath:filePath isDirectory:&isDir];
  if ( exists )
  {
    if ( !isDir)
    {
      if ( [fm removeItemAtPath:filePath error:&fileError] )
      {
        if ( [fm createDirectoryAtPath:filePath withIntermediateDirectories:NO attributes:nil error:&fileError] )
        {
          needsCopyingCodemodels = YES;
          needsCreatingSpinit = YES;
        }
      }
    }
    else
    {
      needsCreatingSpinit = ![self checkHasNgspiceInitScriptAtLocation:installationLocation];
      needsCopyingCodemodels = ![self checkHasAllAvailableNgspiceCodemodelsAtLocation:installationLocation];
    }
  }
  else if ( [fm createDirectoryAtURL:installationLocation withIntermediateDirectories:NO attributes:nil error:&fileError] )
  {
    needsCopyingCodemodels = YES;
    needsCreatingSpinit = YES;
  }

  if ( fileError != nil )
  {
    NSLog(@"Could not create %@", [fileError localizedDescription]);
  }
  else
  {
    if ( needsCopyingCodemodels )
    {
      [self copyNgspiceCodemodelsToLocation:installationLocation];
    }
    if ( needsCreatingSpinit )
    {
      [self createNgspiceInitFileAtLocation:installationLocation];
    }
  }

}


- (NSArray*) availableNgspiceCodemodelLocationsForInstallation
{
  NSMutableArray* result = nil;
  NSString* NgspiceResourcesSourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
  NSArray* resourceFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NgspiceResourcesSourcePath error:NULL];
  if ( resourceFiles != nil )
  {
    result = [NSMutableArray arrayWithCapacity:[resourceFiles count]];
    for ( NSString* resourceFile in resourceFiles )
    {
      if ( [[resourceFile pathExtension] isEqualToString:@"cm"] )
      {
        NSURL* resourceFileLocation = [NSURL fileURLWithPath:[NgspiceResourcesSourcePath stringByAppendingPathComponent:resourceFile]];
        [result addObject:resourceFileLocation];
      }
    }
  }
  return result;
}


- (void) copyNgspiceCodemodelsToLocation:(NSURL*)targetLocation
{
  NSArray* availableResources = [self availableNgspiceCodemodelLocationsForInstallation];
  for ( NSURL* availableResource in availableResources )
  {
    NSString* availableResourceFileName = [availableResource lastPathComponent];
    NSURL* targetFileLocation = [targetLocation URLByAppendingPathComponent:availableResourceFileName];
    [[NSFileManager defaultManager] removeItemAtURL:targetFileLocation error:NULL];
    [[NSFileManager defaultManager] copyItemAtURL:availableResource toURL:targetFileLocation error:NULL];
  }
}


- (BOOL) checkHasAllAvailableNgspiceCodemodelsAtLocation:(NSURL*)targetLocation
{
  NSArray* availableResources = [self availableNgspiceCodemodelLocationsForInstallation];
  NSArray* existingFileLocations = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:targetLocation includingPropertiesForKeys:nil options:0 error:NULL];
  for ( NSURL* availableResource in availableResources )
  {
    NSString* availableResourceFileName = [availableResource lastPathComponent];
    BOOL foundInstalledResource = NO;
    for ( NSURL* existingFileLocation in existingFileLocations )
    {
      if ( [availableResourceFileName isEqualToString:[existingFileLocation lastPathComponent]] )
      {
        foundInstalledResource = YES;
        break;
      }
    }
    if ( !foundInstalledResource )
    {
      return NO;
    }
  }
  return YES;
}


NSString* const kSpiceScriptsFolderName = @"scripts";
NSString* const kSpiceInitScriptName = @"spinit";


- (BOOL) checkHasNgspiceInitScriptAtLocation:(NSURL*)targetLocation
{
  BOOL result = NO;
  NSURL* initScriptFolderLocation = [targetLocation URLByAppendingPathComponent:kSpiceScriptsFolderName];
  BOOL isDir = NO;
  if ( [[NSFileManager defaultManager] fileExistsAtPath:[initScriptFolderLocation path] isDirectory:&isDir] && isDir )
  {
    NSString* initFileTargetPath = [[initScriptFolderLocation URLByAppendingPathComponent:kSpiceInitScriptName] path];
    result = [[NSFileManager defaultManager] fileExistsAtPath:initFileTargetPath isDirectory:&isDir] && !isDir;
  }
  return result;
}


- (void) createNgspiceInitFileAtLocation:(NSURL*)targetLocation
{
  NSFileManager* fm = [NSFileManager defaultManager];
  NSURL* initScriptFolderLocation = [targetLocation URLByAppendingPathComponent:kSpiceScriptsFolderName];
  BOOL isDir = NO;
  NSError* fileError = nil;
  BOOL const exists = [fm fileExistsAtPath:[initScriptFolderLocation path] isDirectory:&isDir];
  if ( !exists )
  {
    if ( ![fm createDirectoryAtURL:initScriptFolderLocation withIntermediateDirectories:YES attributes:nil error:&fileError] )
    {
      NSLog(@"%@", [fileError localizedDescription]);
      return;
    }
  }
  NSMutableString* initFileContents = [[NSMutableString alloc] init];
  [initFileContents appendString:@"alias exit quit\n"];
  [initFileContents appendString:@"set filetype=ascii\n"];
  NSArray* existingFileLocations = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:targetLocation includingPropertiesForKeys:nil options:0 error:NULL];
  for ( NSURL* existingFileLocation in existingFileLocations )
  {
    if ( [[existingFileLocation pathExtension] isEqualToString:@"cm"] )
    {
      [initFileContents appendFormat:@"codemodel \"%@\"\n", [existingFileLocation path]];
    }
  }
  NSURL* initScriptTargetLocation = [initScriptFolderLocation URLByAppendingPathComponent:kSpiceInitScriptName];
  [[NSFileManager defaultManager] removeItemAtURL:initScriptTargetLocation error:NULL];
  [initFileContents writeToURL:initScriptTargetLocation atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  FXRelease(initFileContents)
}

#endif


@end
