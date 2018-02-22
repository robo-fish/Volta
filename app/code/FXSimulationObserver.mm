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

#import "FXSimulationObserver.h"
#import "VoltaCircuitSimulator.h"

NSString* FXSimulationHasFinishedNotification = @"FXSimulationHasFinishedNotification";

@interface FXSimulationObserver()
@property NSString* currentSimulationRawResults;
@end


@implementation FXSimulationObserver
{
@private
  VoltaSimulationID mCurrentSimulation;
  VoltaPTSimulationDataPtr mCurrentSimulationResults;
  NSString* mCurrentSimulationRawResults;
}

@synthesize currentSimulation = mCurrentSimulation;
@synthesize currentSimulationResults = mCurrentSimulationResults;
@synthesize currentSimulationRawResults = mCurrentSimulationRawResults;

- (id) init
{
  if ( (self = [super init]) != nil )
  {
    mCurrentSimulation = VoltaInvalidSimulationID;
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mCurrentSimulationRawResults)
  FXDeallocSuper
}



#pragma mark VoltaCircuitSimulatorObserver


- (void) simulator:(id<VoltaCircuitSimulator>)theSimulator finishedSimulation:(VoltaSimulationID)simulationID
{
  NSAssert( mCurrentSimulation == simulationID, @"Simulator observer called with wrong simulation ID." );
  if ( mCurrentSimulation == simulationID )
  {
    [self setCurrentSimulationRawResults:[theSimulator rawOutputForSimulation:mCurrentSimulation]];
    mCurrentSimulationResults = [theSimulator resultsForSimulation:mCurrentSimulation];
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSimulationHasFinishedNotification object:self];    
    [theSimulator removeSimulation:mCurrentSimulation];
    mCurrentSimulation = VoltaInvalidSimulationID;
  }
}


- (void) simulator:(id<VoltaCircuitSimulator>)theSimulator incrementalRawSimulationOutput:(NSString*)outputMessage forSimulation:(VoltaSimulationID)simulationID
{
  // This handler can be used to add simulation results as soon as they are provided by the simulator.
  // Makes sense for simulations that run for a long duration and produce little output per unit time.
  NSAssert( mCurrentSimulation == simulationID, @"Simulator observer called with wrong simulation ID." );
  if ( mCurrentSimulation == simulationID )
  {
  }
}


- (NSString*) simulationTemporariesFolderPath
{
  NSString* dir = NSTemporaryDirectory();
	return (dir != nil) ? dir : NSHomeDirectory();
}


#pragma mark Public


- (void) reset
{
  mCurrentSimulationResults.reset();
  [self setCurrentSimulationRawResults:@""];
  mCurrentSimulation = VoltaInvalidSimulationID;
}


@end
