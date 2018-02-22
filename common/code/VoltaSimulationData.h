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

#include <vector>
#include <memory>
#include "FXComplexNumber.h"
#include "FXString.h"

// Simulation data is shared by simulator and plotter modules.

/// Data for one analysis entity, like node voltage or current.
struct VoltaPTEntityData
{
  FXString title;
  FXString unit;
  std::vector<FXComplexNumber> samples;
};
typedef std::shared_ptr<VoltaPTEntityData> VoltaPTEntityDataPtr;


enum class VoltaPTAnalysisType
{
  Unknown = -1,
  Transient,
  DC,            // DC operating point
  DC_TRANS,      // DC voltage sweep, transfer characterstic
  AC,
};


struct VoltaPTAnalysisData
{
  FXString title;
  VoltaPTAnalysisType type;
  std::vector< VoltaPTEntityDataPtr > entities;

  VoltaPTAnalysisData() : type(VoltaPTAnalysisType::Unknown) {}

  void addEntityValues(std::vector<FXComplexNumber> const & values)
  {
    if ( entities.size() == values.size() )
    {
      for ( size_t entityIndex = 0; entityIndex < values.size(); entityIndex++ )
      {
        entities.at(entityIndex)->samples.push_back( values.at(entityIndex) );
      }
    }
  }

  bool operator< (VoltaPTAnalysisData const & p) const { return title < p.title; }
  bool operator== (VoltaPTAnalysisData const & p) const { return title == p.title; }
  bool operator!= (VoltaPTAnalysisData const & p) const { return title != p.title; }
};


struct VoltaPTSimulationData
{
  FXString title;
  std::vector<VoltaPTAnalysisData> analyses;
  
  bool operator< (VoltaPTSimulationData const & s) const { return title < s.title; }
  bool operator== (VoltaPTSimulationData const & s) const { return title == s.title; }
  bool operator!= (VoltaPTSimulationData const & s) const { return title != s.title; }
};
typedef std::shared_ptr<VoltaPTSimulationData> VoltaPTSimulationDataPtr;
