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

#import "FXVoltaLibraryUtilities.h"
#import "FXModel.h"
#import "FXElement.h"

@implementation FX(FXVoltaLibraryUtilities)


+ (VoltaModelType) modelTypeForString:(FXString const &)modelTypeName
{
  if ( modelTypeName == "SUBCKT")        return VMT_SUBCKT;
  else if ( modelTypeName == "R" )       return VMT_R;
  else if ( modelTypeName == "C" )       return VMT_C;
  else if ( modelTypeName == "L" )       return VMT_L;
  else if ( modelTypeName == "LM" )      return VMT_LM;
  else if ( modelTypeName == "D" )       return VMT_D;
  else if ( modelTypeName == "BJT" )     return VMT_BJT;
  else if ( modelTypeName == "JFET" )    return VMT_JFET;
  else if ( modelTypeName == "MOSFET" )  return VMT_MOSFET;
  else if ( modelTypeName == "MESFET" )  return VMT_MESFET;
  else if ( modelTypeName == "METER" )   return VMT_METER;
  else if ( modelTypeName == "NODE" )    return VMT_Node;
  else if ( modelTypeName == "GRND" )    return VMT_Ground;
  else if ( modelTypeName == "V" )       return VMT_V;
  else if ( modelTypeName == "I" )       return VMT_I;
  else if ( modelTypeName == "SW" )      return VMT_SW;
  else if ( modelTypeName == "XL" )      return VMT_XL;
  else if ( modelTypeName == "DECO" )    return VMT_DECO;
  else                                   DebugLog(@"Unknown model type name: %@", modelTypeName.cfString()); return VMT_Unknown;
};


+ (FXString) codeStringForModelType:(VoltaModelType)modelType
{
  switch ( modelType )
  {
    case VMT_SUBCKT:   return "SUBCKT";
    case VMT_R :       return "R";
    case VMT_C :       return "C";
    case VMT_L :       return "L";
    case VMT_LM :      return "LM";
    case VMT_D :       return "D";
    case VMT_BJT :     return "BJT";
    case VMT_JFET :    return "JFET";
    case VMT_MOSFET :  return "MOSFET";
    case VMT_MESFET :  return "MESFET";
    case VMT_METER :   return "METER";
    case VMT_Node :    return "NODE";
    case VMT_Ground :  return "GRND";
    case VMT_V :       return "V";
    case VMT_I :       return "I";
    case VMT_SW :      return "SW";
    case VMT_XL :      return "XL";
    case VMT_DECO:     return "DECO";
    default :          DebugLog(@"Encountered unknown model type: %d", (int)modelType); return "";
  }
};


+ (NSString*) userVisibleNameForModelName:(NSString*)modelName
{
  return [[NSBundle bundleForClass:[self class]] localizedStringForKey:modelName value:modelName table:@"BuiltinModelNames"];
}


+ (NSString*) userVisibleNameForModelGroupOfType:(VoltaModelType)type
{
  FXString modelTypeCode = [self codeStringForModelType:type];
  NSString* modelTypeCodeStr = [NSString stringWithString:(__bridge NSString*)modelTypeCode.cfString()];
  return [[NSBundle bundleForClass:[self class]] localizedStringForKey:modelTypeCodeStr value:nil table:@"BuiltinModelGroupNames"];
}


+ (NSString*) userVisibleNameForModelType:(VoltaModelType)type
{
  FXString modelTypeCode = [self codeStringForModelType:type];
  NSString* modelTypeCodeStr = [NSString stringWithString:(__bridge NSString*)modelTypeCode.cfString()];
  return [[NSBundle bundleForClass:[self class]] localizedStringForKey:modelTypeCodeStr value:nil table:@"ModelTypeNames"];
}


+ (FXElement*) elementFromModel:(FXModel*)modelWrapper
{
  VoltaPTModelPtr model = [modelWrapper persistentModel];
  VoltaPTElement element(model->elementNamePrefix, model->type, model->name, model->vendor);
  element.labelPosition = model->labelPosition;
  FXElement* elementWrapper = [[FXElement alloc] initWithElement:element];
  FXAutorelease(elementWrapper)
  return elementWrapper;
}

@end
