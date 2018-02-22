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

//
// Volta Plugin SDK Protocol
//

#import "VoltaSimulationData.h"
#import "VoltaSimulationTypes.h"
#import "VoltaSimulationObserver.h"

@protocol VoltaCircuitSimulator <NSObject>

/// the type of circuit description the simulator expects
@property (nonatomic, readonly) VoltaSimulatorCircuitDescriptionType circuitDescriptionType;

/// @return \c VoltaInvalidCircuitID if there was an error
- (VoltaCircuitID) createCircuit;

/// @return \c NO if there was an error
/// @param data the format of the data depends on the circuit description type expected by the circuit simulator.
/// For circuit simulators expecting textual input the data will be ASCII encoded.
- (BOOL) setDescription:(void*)data forCircuit:(VoltaCircuitID)circuitID error:(NSError**)errorObject;

/// @param circuitID the ID of the circuit which to simulate
/// @return \c VoltaInvalidSimulationID if there was an error
- (VoltaSimulationID) createSimulation:(VoltaCircuitID)circuitID;

/// @param simID the ID of the simulation which is queried.
/// @return YES if a simulation with the given ID exists, NO otherwise.
- (BOOL) simulationExists:(VoltaSimulationID)simID;

/// Removes the simulation from the registry and deletes associated data
/// @param simID the ID of the simulation to be deleted
/// @return \c YES if found and successfully removed, \c NO otherwise
- (BOOL) removeSimulation:(VoltaSimulationID)simID;

/// @param[in] simID the ID of the simulation which to start
/// @param[out] errorObject upon return, contains an error object if the return value is \c NO
/// @return \c NO if there was an error
- (BOOL) startSimulation:(VoltaSimulationID)simID error:(NSError**)errorObject;

/// After stopping the simulation the caller must make sure the simulation is removed.
/// @return whether the simulation was stopped successfully
/// @param[in] simID the ID of the simulation to be stopped
/// @param[out] error upon return, contains an error object if the return value is NO
- (BOOL) stopSimulation:(VoltaSimulationID)simID error:(NSError**)errorObject;

/// @return shared pointer to simulation data, empty pointer if not simulation data is available.
/// @param[in] simID the ID of the simulation whose results are requested
- (VoltaPTSimulationDataPtr) resultsForSimulation:(VoltaSimulationID)simID;

/// @return the results as raw string output from the simulator or nil if not supported.
/// @param[in] simID the ID of the simulation whose results are requested
- (NSString*) rawOutputForSimulation:(VoltaSimulationID)simID;

- (void) setObserver:(id<VoltaSimulationObserver>)observer forSimulation:(VoltaSimulationID)simID;

@end
