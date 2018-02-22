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
#import "VoltaPersistentTypes.h"
#import "VoltaLibrary.h"


struct FXSchematicToNetlistConversionResult
{
  FXString output; // the resulting netlist (SPICE deck)
  std::vector< FXString > errors; // errors occurring during conversion
};


FXIssue(2)
/// Converts a schematic to a netlist string
class FXSchematicToNetlistConverter
{
public:

  /// Creates a SPICE deck (i.e., netlist and commands)
  static FXSchematicToNetlistConversionResult convert(VoltaPTSchematicPtr schematicData, id<VoltaLibrary> library);

  /// Use this variant if the given schematic belongs to a subcircuit.
  static FXSchematicToNetlistConversionResult convert(VoltaPTSchematicPtr schematicData, VoltaPTSubcircuitDataPtr subcircuitData, id<VoltaLibrary> library);

  FXSchematicToNetlistConverter(FXSchematicToNetlistConverter const &) = delete;
  FXSchematicToNetlistConverter& operator= (FXSchematicToNetlistConverter const &) = delete;
};
