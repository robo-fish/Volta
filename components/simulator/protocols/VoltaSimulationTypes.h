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

typedef unsigned int VoltaSimulationID;
enum { VoltaInvalidSimulationID = 0 };


typedef unsigned int VoltaCircuitID;
enum { VoltaInvalidCircuitID = 0 };


typedef NS_ENUM(NSUInteger, VoltaSimulatorCircuitDescriptionType)
{
  VoltaCDT_Unknown = 0,
  VoltaCDT_Native,       // Binary. Volta Persistent Types. Expected data is pointer to VoltaPTSchematic
  VoltaCDT_SPICE3,       // Text. SPICE 3 netlist. Expected data is pointer to NSString containing netlist.
  VoltaCDT_PSPICE,       // Text. PSPICE netlist. Expected data is pointer to NSString containing netlist.
  VoltaCDT_Gnucap        // Text. Gnucap netlist. Expected data is pointer to NSString containing netlist.
};
