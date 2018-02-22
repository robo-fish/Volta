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

typedef NS_ENUM(short, VoltaModelType)
{
  VMT_Unknown  = -1,
  VMT_First    =  0,

  VMT_Ground   = VMT_First,
  VMT_Node     ,
  VMT_SUBCKT   , // Subcircuit
  VMT_R        , // Resistor
  VMT_C        , // Capacitor
  VMT_L        , // Inductor
  VMT_D        , // Diode
  VMT_BJT      , // Bipolar Junction Transistors
  VMT_JFET     , // Junction Field-Effect Transistors
  VMT_MOSFET   , // MOSFET
  VMT_MESFET   , // MESFET
  VMT_V        , // Voltage sources. Allowed subtypes: DC, AC, PULSE, SIN, VC, CC
  VMT_I        , // Current sources. Allowed subtypes: DC, AC, PULSE, SIN, VC, CC
  VMT_LM       , // Mutual (coupled) inductor pair
  VMT_METER    , // Meter (Voltmeter, Ammeter)
  VMT_SW       , // Switches. Allowed subtypes: SW (voltage controlled), CSW (current controlled)
  VMT_XL       , // Transmission lines. Allowed subtypes: URC, TRA, LTRA, TXL, CPL
  VMT_DECO     , // Non-electric decorative elements. Allowed subtypes: TEXT

  VMT_Count
};

