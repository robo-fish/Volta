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
#import "FXSPICELibParser.h"


static void addModelToGroup(VoltaPTModel const & model, VoltaPTModelGroupPtr & group)
{
  if (group.get() == nullptr)
  {
    group = VoltaPTModelGroupPtr( new VoltaPTModelGroup );
  }
  VoltaPTModelPtr modelPtr( new VoltaPTModel );
  *modelPtr = model;
  modelPtr->elementNamePrefix = FXVoltaCircuitDomainAgent::circuitElementNamePrefixForModel(modelPtr);
  group->models.push_back(modelPtr);
}


static void extractNameAndVendorString(VoltaPTModel & model, FXString const & nameAndVendorString)
{
  FXStringVector nameTokens = nameAndVendorString.tokenize(".");
  size_t numNameTokens = nameTokens.size();
  if ( numNameTokens > 1 )
  {
    FXString vendor;
    for ( size_t i = 0; i < (numNameTokens - 1); i++ )
    {
      vendor = vendor + nameTokens.at(i);
      if ( i < (numNameTokens - 2) )
      {
        vendor = vendor + " ";
      }
    }
    model.vendor = vendor;
  }
  model.name = nameTokens.back().upperCase();
}


static void extractModelType(VoltaPTModel & model, FXString const & typeString)
{
  std::pair<VoltaModelType, FXString> modelTypeAndSubtype = FXVoltaCircuitDomainAgent::VoltaModelTypeAndSubtypeForSPICEModelType(typeString);
  model.type = modelTypeAndSubtype.first;
  model.subtype = modelTypeAndSubtype.second;
}


static void extractParams(VoltaPTModel & model, FXStringVector const & paramTokens)
{
  for ( FXString paramToken : paramTokens )
  {
    FXStringVector paramParts = paramToken.tokenize("=");
    if ( paramParts.size() == 2 )
    {
      model.properties.push_back( VoltaPTProperty(paramParts.at(0).upperCase(), paramParts.at(1)) );
    }
  }
}


VoltaPTModelGroupPtr FXSPICELibParser::parseLib(FXString const & libContent)
{
  VoltaPTModelGroupPtr result;
  if ( !libContent.empty() )
  {
    bool nowParsingModel = false;
    VoltaPTModel currentModel;
    FXStringVector const lines = libContent.getLines();
    for ( FXString const & line : lines )
    {
      FXString trimmedLine = line;
      trimmedLine.trimWhitespace();
      //NSLog(@"%@", trimmedLine.cfString());
      if (trimmedLine.empty())
      {
        if (nowParsingModel)
        {
          addModelToGroup(currentModel, result);
          nowParsingModel = false;
        }
      }
      if (trimmedLine.lowerCase().startsWith(".model "))
      {
        FXStringVector tokens = trimmedLine.tokenize();
        if ( tokens.size() >= 3 )
        {
          VoltaPTModel newModel;
          extractNameAndVendorString(newModel, tokens.at(1));
          extractModelType(newModel, tokens.at(2));
          if ( tokens.size() > 3 )
          {
            FXStringVector paramTokens;
            std::copy( tokens.begin() + 3, tokens.end(), paramTokens.begin() );
            extractParams(newModel, paramTokens);
          }
          currentModel = newModel;
          nowParsingModel = true;
        }
      }
      else if ( trimmedLine.startsWith("+") && nowParsingModel )
      {
        FXString paramLine = trimmedLine.substring(1);
        FXStringVector paramTokens = paramLine.tokenize();
        extractParams(currentModel, paramTokens);
      }
    }
    if ( nowParsingModel )
    {
      addModelToGroup(currentModel, result);
    }
  }
  return result;
}

