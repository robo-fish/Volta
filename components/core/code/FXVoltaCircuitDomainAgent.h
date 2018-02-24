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

#import "VoltaPersistentTypes.h"

/// Abstracts compatibility with the ngspice ( http://ngspice.sourceforge.net ) simulator.
struct FXVoltaCircuitDomainAgent
{
  /// @return Ngspice netlist element parameters for the given Volta model.
  static VoltaPTPropertyVector circuitElementParametersForModel(VoltaPTModelPtr model);

  /// @return a list of parameters that apply to all elements (or analyses commands) of an Ngspice netlist.
  static VoltaPTPropertyVector circuitParameters();

  /// @return Ngspice name prefix of a netlist element with for the given Volta model.
  static FXString circuitElementNamePrefixForModel(VoltaPTModelPtr model);

  /// @return the model type name of the given model. For example, "NPN" for an n-channel BJT model.
  static FXString netlistModelTypeStringForModel(VoltaPTModelPtr model);

  static std::pair<VoltaModelType, FXString> VoltaModelTypeAndSubtypeForSPICEModelType(FXString const & SPICEModelType);

};

