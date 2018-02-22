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

#include "FXVoltaCircuitDomainAgent.h"


VoltaPTPropertyVector FXVoltaCircuitDomainAgent::circuitElementParametersForModel(VoltaPTModelPtr model)
{
  VoltaPTPropertyVector properties;
  if ( model.get() == nullptr )
    return properties;

  switch ( model->type )
  {
    case VMT_R:
      if ( model->subtype.lowerCase() == "semi" )
        properties = {
          VoltaPTProperty("resistance"),
          VoltaPTProperty("l"),
          VoltaPTProperty("w"),
          VoltaPTProperty("temp"),
          VoltaPTProperty("dtemp"),
          VoltaPTProperty("m"),
          VoltaPTProperty("ac"),
          VoltaPTProperty("scale"),
          VoltaPTProperty("noisy") };
      else
        properties = { VoltaPTProperty("resistance", "1k") };
      break;
    case VMT_L:
      if ( model->properties.empty() )
        properties = { VoltaPTProperty("inductance", "1m") };
      else
        properties = {
          VoltaPTProperty("nt"),
          VoltaPTProperty("m"),
          VoltaPTProperty("scale"),
          VoltaPTProperty("temp"),
          VoltaPTProperty("dtemp"),
          VoltaPTProperty("ic") };
      break;
    case VMT_C:
      if ( model->subtype.lowerCase() == "semi" )
        properties = {
          VoltaPTProperty("l"),
          VoltaPTProperty("w"),
          VoltaPTProperty("m"),
          VoltaPTProperty("scale"),
          VoltaPTProperty("temp"),
          VoltaPTProperty("dtemp"),
          VoltaPTProperty("ic") };
      else
        properties = {
          VoltaPTProperty("capacitance", "1u"),
          VoltaPTProperty("ic") }; FXIssue(257)
      break;
    case VMT_D:
      properties = {
        VoltaPTProperty("area"),
        VoltaPTProperty("m"),
        VoltaPTProperty("pj"),
        VoltaPTProperty("ic"),
        VoltaPTProperty("temp"),
        VoltaPTProperty("dtemp") };
      break;
    case VMT_BJT:
      properties = {
        VoltaPTProperty("area"),
        VoltaPTProperty("areac"),
        VoltaPTProperty("areab"),
        VoltaPTProperty("m"),
        VoltaPTProperty("ic"),
        VoltaPTProperty("temp"),
        VoltaPTProperty("dtemp") };
      break;
    case VMT_JFET:
      properties = {
        VoltaPTProperty("area"),
        VoltaPTProperty("ic"),
        VoltaPTProperty("temp") };
      break;
    case VMT_MESFET:
      properties = {
        VoltaPTProperty("area"),
        VoltaPTProperty("ic") };
      break;
    case VMT_MOSFET:
      properties = {
        VoltaPTProperty("m"),
        VoltaPTProperty("l"),
        VoltaPTProperty("w"),
        VoltaPTProperty("ad"),
        VoltaPTProperty("as"),
        VoltaPTProperty("pd"),
        VoltaPTProperty("ps"),
        VoltaPTProperty("nrd"),
        VoltaPTProperty("nrs"),
        VoltaPTProperty("ic"),
        VoltaPTProperty("temp") };
      break;
    case VMT_V:
    case VMT_I:
      {
        FXString const subtype = model->subtype.lowerCase();
        if ( subtype == "dc" )
          properties = { (model->type == VMT_V) ? VoltaPTProperty("voltage", "5") : VoltaPTProperty("current", "1m") };
        else if ( subtype == "ac" )
          properties = {
            VoltaPTProperty("magnitude", "1"),
            VoltaPTProperty("phase", "0") };
        else if ( subtype == "pulse" )
          properties = {
            VoltaPTProperty("initial"),
            VoltaPTProperty("pulsed"),
            VoltaPTProperty("delay"),
            VoltaPTProperty("rise"),
            VoltaPTProperty("fall"),
            VoltaPTProperty("pulse width"),
            VoltaPTProperty("period") };
        else if ( subtype == "sin" )
          properties = {
            VoltaPTProperty("offset"),
            VoltaPTProperty("amplitude"),
            VoltaPTProperty("frequency"),
            VoltaPTProperty("delay"),
            VoltaPTProperty("damping factor") };
        else if ( subtype == "exp" )
          properties = {
            VoltaPTProperty("v1"),
            VoltaPTProperty("v2"),
            VoltaPTProperty("delay1"),
            VoltaPTProperty("delay2"),
            VoltaPTProperty("tau1"),
            VoltaPTProperty("tau2") };
        else if ( subtype == "pwl" )
          properties = {
            VoltaPTProperty("pairs"),
            VoltaPTProperty("repeat point"),
            VoltaPTProperty("delay") };
        else if ( subtype == "vc" )
          properties = { (model->type == VMT_V) ? VoltaPTProperty("gain") : VoltaPTProperty("transconductance") };
        else if ( subtype == "cc" )
        {
          if (model->type == VMT_V)
            properties = { VoltaPTProperty("transresistance"), VoltaPTProperty("vnam") };
          else
            properties = { VoltaPTProperty("gain"), VoltaPTProperty("vnam") };
        }
        else if ( subtype == "nonlin" )
          properties = { (model->type == VMT_V ) ? VoltaPTProperty("v =") : VoltaPTProperty("i =") };
      }
      break;
    case VMT_LM:
      properties = {
        VoltaPTProperty("inductance1"),
        VoltaPTProperty("inductance2"),
        VoltaPTProperty("coupling", "1.0") };
      break;
    case VMT_METER:
      {
        FXString const meterType = model->subtype.lowerCase();
        if ((meterType == "vac") || (meterType == "aac"))
          properties = {
            VoltaPTProperty("scale type"),
            VoltaPTProperty("# points"),
            VoltaPTProperty("start frequency"),
            VoltaPTProperty("stop frequency") };
        else if ( (meterType == "vdc") || (meterType=="adc") )
          properties = {
            VoltaPTProperty("source"),
            VoltaPTProperty("start"),
            VoltaPTProperty("stop"),
            VoltaPTProperty("step") };
        else if ( meterType == "vtran" )
          properties = {
            VoltaPTProperty("tstep"),
            VoltaPTProperty("tstop"),
            VoltaPTProperty("tstart"),
            VoltaPTProperty("tmax"),
            VoltaPTProperty("use ic") };
        if ( (meterType == "vac")
          || (meterType == "vdc")
          || (meterType == "vtran") )
        {
          properties.push_back(VoltaPTProperty("ref. node"));
        }
      }
      break;
    case VMT_SW:
      if ( model->subtype.lowerCase() == "csw" )
        properties = {
          VoltaPTProperty("vctrl"),
          VoltaPTProperty("on-off") };
      else
        properties = { VoltaPTProperty("on-off") };
      break;
    case VMT_XL:
      {
        FXString const subtype = model->subtype.lowerCase();
      #if 0
        if ( subtype == "urc" )
          properties = {
            VoltaPTProperty("l"),
            VoltaPTProperty("n") };
        else if ( subtype == "tra" )
          properties = {
            VoltaPTProperty("z0"),
            VoltaPTProperty("td"),
            VoltaPTProperty("f"),
            VoltaPTProperty("nl"),
            VoltaPTProperty("ic") };
        else
      #endif
          if ((subtype == "txl") || (subtype == "cpl"))
          properties = { VoltaPTProperty("length") };
      }
    case VMT_DECO:
      if ( model->subtype.lowerCase() == "text" )
        properties = { VoltaPTProperty("text", "Text") };
      break;
    default: ;
  }
  return properties;
}


VoltaPTPropertyVector FXVoltaCircuitDomainAgent::circuitParameters()
{
  static const VoltaPTPropertyVector skCircuitProperties = {
    VoltaPTProperty("temp"),
    VoltaPTProperty("tnom"),
    VoltaPTProperty("abstol"),
    VoltaPTProperty("gmin"),
    VoltaPTProperty("itl1"),
    VoltaPTProperty("itl2"),
    VoltaPTProperty("reltol"),
    VoltaPTProperty("vntol"),
    VoltaPTProperty("chgtol"),
    VoltaPTProperty("defad"),
    VoltaPTProperty("defas"),
    VoltaPTProperty("defl"),
    VoltaPTProperty("defw") };
  return skCircuitProperties;
}


FXString FXVoltaCircuitDomainAgent::circuitElementNamePrefixForModel(VoltaPTModelPtr model)
{
  switch ( model->type )
  {
    case VMT_Ground:                    return "GND";
    case VMT_Node:                      return ""; FXIssue(80) // Important: Nodes must have no prefix. The user must be able to assign any unused name.
    case VMT_R:                         return "R";
    case VMT_C:                         return "C";
    case VMT_L:                         return "L";
    case VMT_LM:                        return "K";
    case VMT_D:                         return "D";
    case VMT_BJT:                       return "Q";
    case VMT_JFET:                      return "J";
    case VMT_MESFET:                    return "Z";
    case VMT_MOSFET:                    return "M";
    case VMT_V:
      if ( model->subtype == "NONLIN" ) return "B";
      if ( model->subtype == "CC" )     return "H";
      if ( model->subtype == "VC" )     return "E";
                                        return "V";
    case VMT_I:
      if ( model->subtype == "NONLIN" ) return "B";
      if ( model->subtype == "CC" )     return "F";
      if ( model->subtype == "VC" )     return "G";
                                        return "I";
    case VMT_SW:
      if ( model->subtype == "CSW" )    return "W";
                                        return "S";
    case VMT_METER:                     return "MT";
    case VMT_SUBCKT:                    return "X";
    case VMT_XL:
      if ( model->subtype == "URC" )    return "U";
      if ( model->subtype == "TRA" )    return "T";
      if ( model->subtype == "LTRA" )   return "O";
      if ( model->subtype == "TXL" )    return "Y";
      if ( model->subtype == "CPL" )    return "P";
    case VMT_DECO:                      return "";

    default: DebugLog(@"Prefix for unknown model type requested."); return "";
  }
}


FXString FXVoltaCircuitDomainAgent::netlistModelTypeStringForModel(VoltaPTModelPtr model)
{
  FXString result;
  switch (model->type)
  {
    case VMT_D: result = "D"; break;
    case VMT_R: result = "R"; break;
    case VMT_C: result = "C"; break;
    case VMT_L: result = "L"; break;
    default:    result = model->subtype; break;
  }
  return result;
}


std::pair<VoltaModelType, FXString> FXVoltaCircuitDomainAgent::VoltaModelTypeAndSubtypeForSPICEModelType(FXString const & SPICEModelType)
{
  std::pair<VoltaModelType, FXString> result;
  result.first = VMT_Unknown;
  FXString type = SPICEModelType.lowerCase();
       if ( type == "r" )     result = std::make_pair(VMT_R,      "SEMI");
  else if ( type == "c" )     result = std::make_pair(VMT_C,      "SEMI");
  else if ( type == "d" )     result = std::make_pair(VMT_D,      "");
  else if ( type == "npn" )   result = std::make_pair(VMT_BJT,    "NPN");
  else if ( type == "pnp" )   result = std::make_pair(VMT_BJT,    "PNP");
  else if ( type == "njf" )   result = std::make_pair(VMT_JFET,   "NJF");
  else if ( type == "pjf" )   result = std::make_pair(VMT_JFET,   "PJF");
  else if ( type == "nmf" )   result = std::make_pair(VMT_MESFET, "NMF");
  else if ( type == "pmf" )   result = std::make_pair(VMT_MESFET, "PMF");
  else if ( type == "nmos" )  result = std::make_pair(VMT_MOSFET, "NMOS");
  else if ( type == "pmos" )  result = std::make_pair(VMT_MOSFET, "PMOS");
  else if ( type == "sw" )    result = std::make_pair(VMT_SW,     "SW");
  else if ( type == "csw" )   result = std::make_pair(VMT_SW,     "CSW");
  else if ( type == "ltra" )  result = std::make_pair(VMT_XL,     "LTRA");
  else if ( type == "txl" )   result = std::make_pair(VMT_XL,     "TXL");
  else if ( type == "urc" )   result = std::make_pair(VMT_XL,     "URC");
  return result;
}
