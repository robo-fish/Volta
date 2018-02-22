#import "FXVoltaArchiveConverterV1To2.h"

@implementation FXVoltaArchiveConverterV1To2


+ (std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector>) convertRootElement:(FXXMLElementPtr)rootElement
{
  std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> result;
  std::get<0>(result) = rootElement->copyTreeWithElementFilter( ^(FXXMLElement const & source, FXXMLElementPtr target) {
    FXString const & n = target->getName();
    if ( (n == "circuit") || (n == "library") )
    {
      FXString title = target->valueOfAttribute("name");
      target->removeAttribute("name");
      target->addAttribute( FXXMLAttribute("title", title) );
    }
    else if ( n == "shape" )
    {
      target->removeAttribute("flipped");
    }
    else if ( (n == "element") || (n == "model") )
    {
      FXString const labelPosition = target->valueOfAttribute("labelPosition").lowerCase();
      [self convertFromLabelPosition:labelPosition toElement:target];

      FXString const type = target->valueOfAttribute("type");
      [self convertFromType:type toElement:target elementIsVoltaModel:(n=="model")];

      if ((n == "element") && target->hasAttribute("rotation"))
      {
        try
        {
          long rotation = target->valueOfAttribute("rotation").extractLong();
          rotation = -rotation;
          target->setValueOfAttribute("rotation", (__bridge CFNumberRef)@(rotation));
        }
        catch (std::runtime_error)
        {
          target->removeAttribute("rotation");
        }
      }
    }
  });
  return result;
}


+ (void) convertFromLabelPosition:(FXString const &)oldLabelPosition toElement:(FXXMLElementPtr)target
{
  if ( oldLabelPosition == "north" )
    target->setValueOfAttribute("labelPosition", "top");
  else if ( oldLabelPosition == "east" )
    target->setValueOfAttribute("labelPosition", "right");
  else if ( oldLabelPosition == "south" )
    target->setValueOfAttribute("labelPosition", "bottom");
  else if ( oldLabelPosition == "west" )
    target->setValueOfAttribute("labelPosition", "left");
}


void updateTypeAndSubtype(FXXMLElementPtr xmlElement, bool isModel, FXString const & newType, FXString const & newSubtype)
{
  xmlElement->setValueOfAttribute("type", newType);
  if ( isModel )
  {
    xmlElement->setValueOfAttribute("subtype", newSubtype);
  }
}


#define UTST( x, y, m ) updateTypeAndSubtype( target, m, x, y )


void convertNonlinearPowerSourceElement(FXXMLElementPtr xmlElement)
{
  bool isCurrentSource = false;
  FXXMLElementPtrVector propertiesList;
  xmlElement->collectChildrenWithName( "p", propertiesList );
  for( FXXMLElementPtr const & propertyElement : propertiesList )
  {
    if ( propertyElement->valueOfAttribute("n") == "expression" )
    {
      FXString const powerExpression = propertyElement->valueOfAttribute("v").trimWhitespace();
      if ( powerExpression.lowerCase().startsWith("i") )
      {
        isCurrentSource = true;
        propertyElement->setValueOfAttribute("n", "i =");
      }
      else
      {
        propertyElement->setValueOfAttribute("n", "v =");
      }
      FXString newExpression = powerExpression.substring(1);
      int pos = newExpression.find("=");
      if ( pos >= 0 )
        newExpression = newExpression.substring(pos + 1);
      propertyElement->setValueOfAttribute("v", newExpression);
      break;
    }
  }
  if ( isCurrentSource )
  {
    xmlElement->setValueOfAttribute("type", "I");
    xmlElement->setValueOfAttribute("modelName", "NonlinearDependentCurrent");
  }
  else
  {
    xmlElement->setValueOfAttribute("type", "V");
    xmlElement->setValueOfAttribute("modelName", "NonlinearDependentVoltage");
  }
  xmlElement->setValueOfAttribute("modelVendor", "");
}


+ (void) convertFromType:(FXString const &)oldType
               toElement:(FXXMLElementPtr)target
     elementIsVoltaModel:(BOOL)isModel
{
  if ( oldType == "NPN" )        UTST("BJT", "NPN", isModel);
  else if (oldType == "PNP")     UTST("BJT", "PNP", isModel);
  else if (oldType == "NJF")     UTST("JFET", "NJF", isModel);
  else if (oldType == "PJF")     UTST("JFET", "PJF", isModel);
  else if (oldType == "NMOS")    UTST("MOSFET", "NMOS", isModel);
  else if (oldType == "PMOS")    UTST("MOSFET", "PMOS", isModel);
  else if (oldType == "NMF")     UTST("MESFET", "NMF", isModel);
  else if (oldType == "PMF")     UTST("MESFET", "PMF", isModel);
  else if (oldType == "MTVDC")   UTST("METER", "VDC", isModel);
  else if (oldType == "MTVAC")   UTST("METER", "VAC", isModel);
  else if (oldType == "MTVTRAN") UTST("METER", "VTRAN", isModel);
  else if (oldType == "MTAAC")   UTST("METER", "AAC", isModel);
  else if (oldType == "MTADC")   UTST("METER", "ADC", isModel);
  else if (oldType == "VSDC")    UTST("V", "DC", isModel);
  else if (oldType == "VSAC")    UTST("V", "AC", isModel);
  else if (oldType == "VSSIN")   UTST("V", "SIN", isModel);
  else if (oldType == "VSPLS")   UTST("V", "PULSE", isModel);
  else if (oldType == "VSVC")    UTST("V", "VC", isModel);
  else if (oldType == "VSCC")    UTST("V", "CC", isModel);
  else if (oldType == "CSDC")    UTST("I", "DC", isModel);
  else if (oldType == "CSAC")    UTST("I", "AC", isModel);
  else if (oldType == "CSSIN")   UTST("I", "SIN", isModel);
  else if (oldType == "CSPLS")   UTST("I", "PULSE", isModel);
  else if (oldType == "CSVC")    UTST("I", "VC", isModel);
  else if (oldType == "CSCC")    UTST("I", "CC", isModel);
  else if (oldType == "SWVC")    UTST("SW", "SW", isModel);
  else if (oldType == "SWCC")    UTST("SW", "CSW", isModel);
  else if (oldType == "RSEM")    UTST("R", "SEMI", isModel);
  else if (oldType == "CSEM")    UTST("C", "SEMI", isModel);
  else if (oldType == "URC")     UTST("XL", "URC", isModel);
  else if (oldType == "TRA")     UTST("XL", "TRA", isModel);
  else if (oldType == "TRAL")    UTST("XL", "LTRA", isModel);
  else if (oldType == "TRALS")   UTST("XL", "TXL", isModel);
  else if (oldType == "CPL")     UTST("XL", "CPL", isModel);
  else if (oldType == "PSNLIN")
  {
    if ( isModel )
    {
      UTST("V", "NONLIN", true);
    }
    else
    {
      convertNonlinearPowerSourceElement(target);
    }
  }
}


@end
