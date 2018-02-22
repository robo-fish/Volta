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
#pragma once

#import "VoltaSimulationTypes.h"

@protocol VoltaCircuitSimulator;

@protocol VoltaSimulationObserver <NSObject>

/// This method is called when the simulator finishes the simulation.
/// The observer (i.e., the receiver) should now evaluate the results and later remove the simulation.
/// @param simulationID the ID of the simulation task which has finished.
/// @param simulator the simulator finishing the simulation (useful in case multiple simulators are controlled)
- (void) simulator:(id<VoltaCircuitSimulator>)theSimulator finishedSimulation:(VoltaSimulationID)simulationID;

/// @param outputMessage new available process output messages generated by the simulation with the given ID since this message was last received.
/// @param simulationID ID of the simulation generating the output message
/// @param theSimulator the circuit simulator running the simulation that generates the output message
- (void) simulator:(id<VoltaCircuitSimulator>)theSimulator incrementalRawSimulationOutput:(NSString*)outputMessage forSimulation:(VoltaSimulationID)simulationID;

/// @return the absolute path to the folder in which temporary files should be stored.
- (NSString*) simulationTemporariesFolderPath;

@end
