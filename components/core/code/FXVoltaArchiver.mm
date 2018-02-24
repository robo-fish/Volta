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

//
// See the Relax NG schema file at
// https://github.com/robo-fish/Volta/tree/master/components/library/resources/volta-v2.rng
//

#import "FXVoltaArchiver.h"
#import "FXVoltaArchiveValidator.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXVoltaCircuitDomainAgent.h"
#import "FXXMLDocument.h"
#import "FXString.h"
#include <map>
#include <cassert>
#include <tuple>
#include <iostream>

#define VOLTA_ARCHIVES_SIMULATION_DATA (1)


/// The version of the Volta file format that is used for archiving.
static const NSUInteger skFormatVersion_Output = 2;

static FXString FXArchiverNewLineCodeSequence("{FX_newline}");
static FXString FXArchiverQuoteCodeSequence("{FX_quote}");

static FXString skVoltaRootElementName = "volta";
static FXString skVoltaCircuitElementName = "circuit";
static FXString skVoltaLibraryElementName = "library";
static FXString skVoltaVersionAttributeName = "version";

FXString encodeTextForVoltaXML(FXString const & input)
{
  FXString result( input );
  result.replaceAll("\n", FXArchiverNewLineCodeSequence);
  result.replaceAll("\"", FXArchiverQuoteCodeSequence);
  return result;
}


FXString decodeTextFromXML(FXString const & input)
{
  FXString result( input );
  result.replaceAll(FXArchiverNewLineCodeSequence, "\n");
  result.replaceAll(FXArchiverQuoteCodeSequence, "\"");
  return result;
}


static NSString* getVoltaHeader()
{
  return [NSString stringWithFormat:
    @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
    @"<volta xmlns=\"http://kulfx.com/volta\" version=\"%ld\">",
    skFormatVersion_Output];
};


static NSString* getVoltaFooter()
{
  return @"\n</volta>\n";
};


#pragma mark - Unarchiving Helpers -


static std::vector<VoltaPTPath> unarchiveShapePaths( FXXMLElementPtr xmlElement )
{
  std::vector<VoltaPTPath> paths;
  FXXMLElementPtrVector pathElements;
  xmlElement->collectChildrenWithName( "path", pathElements );
  for( FXXMLElementPtr const & pathElement : pathElements )
  {
    FXString pathData = pathElement->valueOfAttribute("d");
    if ( pathData.empty() ) { DebugLog(@"Path data is empty"); }

    FXString filledString = pathElement->valueOfAttribute("fill");

    paths.push_back( VoltaPTPath(pathData, filledString == "true") );
  }
  return paths;
}


static std::vector<VoltaPTCircle> unarchiveShapeCircles( FXXMLElementPtr xmlElement )
{
  std::vector<VoltaPTCircle> circles;
  FXXMLElementPtrVector circleElements;
  xmlElement->collectChildrenWithName( "circle", circleElements );
  for( FXXMLElementPtr const & circleElement : circleElements )
  {
    float fCenterX = 0.0f;
    float fCenterY = 0.0f;
    float fRadius = 3.0f;
    FXString strCenterX = circleElement->valueOfAttribute("cx");
    FXString strCenterY = circleElement->valueOfAttribute("cy");
    FXString strRadius = circleElement->valueOfAttribute("r");
    FXString strFilled = circleElement->valueOfAttribute("fill");
    try
    {
      fCenterX = strCenterX.extractFloat();
      fCenterY = strCenterY.extractFloat();
      fRadius = strRadius.extractFloat();
    }
    catch ( std::runtime_error & ) {}
    VoltaPTCircle newCircle;
    newCircle.centerX = fCenterX;
    newCircle.centerY = fCenterY;
    newCircle.radius = fRadius;
    newCircle.filled = (strFilled == "true");
    circles.push_back( newCircle );
  }
  return circles;
}


static std::tuple<float,float> unarchiveShapeSize( FXXMLElementPtr xmlElement )
{
  std::tuple<float,float> result = std::make_tuple(0.0f, 0.0f);
  FXString shapeWidth = xmlElement->valueOfAttribute("width");
  if (shapeWidth.empty()) { DebugLog(@"Shape width attribute is empty"); }
  FXString shapeHeight = xmlElement->valueOfAttribute("height");
  if (shapeHeight.empty()) { DebugLog(@"Shape height attribute is empty"); }
  try
  {
    std::get<0>(result) = shapeWidth.extractFloat();
    std::get<1>(result) = shapeHeight.extractFloat();
  }
  catch ( std::runtime_error & )
  {
    std::cerr << "Could not parse shape size data of element \"" << xmlElement->getName() << "\"" << std::endl;
  }
  return result;
}


static VoltaPTShape unarchiveShape( FXXMLElementPtr xmlElement )
{
  VoltaPTShape shape;

  FXXMLElementPtrVector shapeElements;
  xmlElement->collectChildrenWithName( "shape", shapeElements );
  if ( shapeElements.size() > 1 ) { DebugLog(@"Found multiple shape elements. Expected at most one."); }
  if ( !shapeElements.empty() )
  {
    FXXMLElementPtr shapeElement = shapeElements.front();
    std::tie<float,float>(shape.width, shape.height) = unarchiveShapeSize( shapeElement );
    shape.paths = unarchiveShapePaths( shapeElement );
    shape.circles = unarchiveShapeCircles( shapeElement );
  }

  return shape;
}


static std::vector<VoltaPTPin> unarchivePins( FXXMLElementPtr xmlElement )
{
  std::vector<VoltaPTPin> pins;
  FXXMLElementPtrVector pinElements;
  xmlElement->collectChildrenWithName( "pin", pinElements );
  for( FXXMLElementPtr const & pinElement : pinElements )
  {
    VoltaPTPin pin;
    pin.posX = 0.0f;
    pin.posY = 0.0f;
    pin.name = "";
    try
    {
      pin.posX = pinElement->valueOfAttribute("x").extractFloat();
      pin.posY = pinElement->valueOfAttribute("y").extractFloat();
      pin.name = decodeTextFromXML(pinElement->valueOfAttribute("name"));
    }
    catch ( std::runtime_error & )
    {
      std::cout << "Error while parsing attributes of pin" << std::endl;
      continue;
    }
    pins.push_back( pin ); // Note: pins must be added in the same order they will be printed to a netlist
  }
  return pins;
}


static std::vector<VoltaPTMetaDataItem> unarchiveMeta( FXXMLElementPtr xmlElement )
{
  std::vector<VoltaPTMetaDataItem> result;
  FXXMLElementPtrVector schematicMetaData;
  xmlElement->collectChildrenWithName( "m", schematicMetaData );
  for( FXXMLElementPtr const & metaDataItem : schematicMetaData )
  {
    VoltaPTMetaDataItem voltaMetaDataItem;
    voltaMetaDataItem.first = metaDataItem->valueOfAttribute("k");
    voltaMetaDataItem.second = decodeTextFromXML(metaDataItem->valueOfAttribute("v"));
    result.push_back( voltaMetaDataItem );
  }
  return result;
}


static VoltaPTLabelPosition unarchiveLabelPosition(FXXMLElementPtr xmlElement )
{
  VoltaPTLabelPosition result = VoltaPTLabelPosition::None; // default value
  FXString strPosition = xmlElement->valueOfAttribute("labelPosition");
  if ( !strPosition.empty() )
  {
    if      ( strPosition == "top" )     { result = VoltaPTLabelPosition::Top; }
    else if ( strPosition == "bottom" )  { result = VoltaPTLabelPosition::Bottom; }
    else if ( strPosition == "right" )   { result = VoltaPTLabelPosition::Right; }
    else if ( strPosition == "left" )    { result = VoltaPTLabelPosition::Left; }
    else if ( strPosition == "center" )  { result = VoltaPTLabelPosition::Center; }
  }
  return result;
}


static VoltaPTPropertyVector unarchiveProperties(FXXMLElementPtr xmlElement, bool skipEmptyProperties = false)
{
  VoltaPTPropertyVector result;
  FXXMLElementPtrVector propertiesList;
  xmlElement->collectChildrenWithName( "p", propertiesList );
  for( FXXMLElementPtr const & propertyElement : propertiesList )
  {
    VoltaPTProperty property;
    property.name = decodeTextFromXML(propertyElement->valueOfAttribute("n"));
    if ( !property.name.empty() )
    {
      property.value = decodeTextFromXML(propertyElement->valueOfAttribute("v"));
      if ( !skipEmptyProperties || !property.value.empty() )
      {
        result.push_back( property );
      }
    }
  }
  return result;
}


/// Makes sure that the given target properties contain all the properties of the given source properties.
/// For properties that exist in both the target and the source, the value of the target is retained.
/// @return merged properties
static VoltaPTPropertyVector mergeWithDefaultProperties( VoltaPTPropertyVector const & properties, VoltaPTPropertyVector const & defaults )
{
  VoltaPTPropertyVector mergedProperties = defaults;
  for( VoltaPTProperty const & currentProperty : properties )
  {
    for( VoltaPTProperty& currentMergedProperty : mergedProperties )
    {
      if ( currentProperty.name == currentMergedProperty.name )
      {
        currentMergedProperty.value = currentProperty.value;
        break;
      }
    }
  }
  return mergedProperties;
}


/// For performance reasons the output is provided as a parameter by reference.
/// @param[in] xmlElement
/// @param[out] voltaSchematic
static void unarchiveConnectors( FXXMLElementPtr xmlElement, VoltaPTSchematicPtr voltaSchematic )
{
  FXXMLElementPtrVector schematicConnectorList;
  xmlElement->collectChildrenWithName("connector", schematicConnectorList);
  for( FXXMLElementPtr const & connectorElement : schematicConnectorList )
  {
    VoltaPTConnector connectorData;
    connectorData.startElementName = decodeTextFromXML(connectorElement->valueOfAttribute("start"));
    connectorData.endElementName = decodeTextFromXML(connectorElement->valueOfAttribute("end"));
    connectorData.startPinName = decodeTextFromXML(connectorElement->valueOfAttribute("startPin"));
    connectorData.endPinName = decodeTextFromXML(connectorElement->valueOfAttribute("endPin"));
    
    FXXMLElementPtrVector jointElements;
    connectorElement->collectChildrenWithName("joint", jointElements);
    for( FXXMLElementPtr const & jointElement : jointElements )
    {
      VoltaSchematicConnectorJointData jointData;
      jointData.first = jointElement->valueOfAttribute("x").extractFloat();
      jointData.second = jointElement->valueOfAttribute("y").extractFloat();
      connectorData.joints.push_back( jointData );
    }
    
    connectorData.metaData = unarchiveMeta(connectorElement);
    
    voltaSchematic->connectors.insert(connectorData);
  }
}


VoltaPTElement unarchiveElement(FXXMLElementPtr xmlElement)
{
  VoltaPTElement result;
  if ( xmlElement.get() != nullptr )
  {
    result.name = decodeTextFromXML(xmlElement->valueOfAttribute("name"));
    FXString modelTypeString = xmlElement->valueOfAttribute("type");
    result.type = [FXVoltaLibraryUtilities modelTypeForString:modelTypeString];
    result.modelName = decodeTextFromXML(xmlElement->valueOfAttribute("modelName"));
    result.modelVendor = decodeTextFromXML(xmlElement->valueOfAttribute("modelVendor"));
    
    result.posX = 0.0f; // default value
    try { result.posX = xmlElement->valueOfAttribute("x").extractFloat(); }
    catch ( std::runtime_error & ste ) {}
    
    result.posY = 0.0f; // default value
    try { result.posY = xmlElement->valueOfAttribute("y").extractFloat(); }
    catch ( std::runtime_error & ste ) {}
    
    result.rotation = 0.0f; // default value
    try { result.rotation = (M_PI/180.0f) * xmlElement->valueOfAttribute("rotation").extractFloat(); }
    catch ( std::runtime_error & ste ) {}
    
    result.flipped = false; // default value
    FXString flippedStr = xmlElement->valueOfAttribute("flipped");
    if ( !flippedStr.empty() )
    {
      try { result.flipped = flippedStr.extractBoolean(); }
      catch ( std::runtime_error & ste ) {}
    }
    
    result.labelPosition = unarchiveLabelPosition(xmlElement);
    result.properties = unarchiveProperties(xmlElement);
    result.metaData = unarchiveMeta(xmlElement);
  }
  return result;
}


/// For performance reasons the output is provided as a parameter by reference.
/// @param[in] xmlElement
/// @param[out] voltaSchematic
static void unarchiveElements( FXXMLElementPtr xmlElement, VoltaPTSchematicPtr voltaSchematic )
{
  FXXMLElementPtrVector schematicElementList;
  xmlElement->collectChildrenWithName("element", schematicElementList);
  for( FXXMLElementPtr schematicElement : schematicElementList )
  {
    VoltaPTElement unarchivedElement = unarchiveElement(schematicElement);
    voltaSchematic->elements.insert(unarchivedElement);
  }
}


VoltaPTModelPtr unarchiveModel( FXXMLElementPtr modelElement )
{
  VoltaPTModelPtr result;
  if ( modelElement.get() != nullptr )
  {    
    FXString const modelTypeName = modelElement->valueOfAttribute("type");
    VoltaModelType const modelType = [FXVoltaLibraryUtilities modelTypeForString:modelTypeName];
    FXString const modelName = decodeTextFromXML(modelElement->valueOfAttribute("name"));
    if ( modelName.empty() )
    {
      DebugLog(@"Model element without name attribute.");
    }
    else
    {
      result = VoltaPTModelPtr(new VoltaPTModel);
      result->type = modelType;
      result->name = modelName;
      result->subtype = modelElement->valueOfAttribute("subtype");
      result->vendor = decodeTextFromXML(modelElement->valueOfAttribute("vendor"));
      FXString modelRevisionString = modelElement->valueOfAttribute("revision");
      if ( !modelRevisionString.empty() )
      {
        result->revision = modelRevisionString.extractLong();
      }      
      result->elementNamePrefix = FXVoltaCircuitDomainAgent::circuitElementNamePrefixForModel(result);
      result->shape = unarchiveShape( modelElement );
      result->pins = unarchivePins( modelElement );
      result->labelPosition = unarchiveLabelPosition( modelElement );
      result->properties = unarchiveProperties( modelElement );
    }
  }
  return result;
}


VoltaPTLibraryPtr unarchiveLibraryFromXML( FXXMLElementPtr& rootElement )
{
  VoltaPTLibrary* result_ = new VoltaPTLibrary;
  VoltaPTModelGroup* modelGroup_ = new VoltaPTModelGroup;
  VoltaPTLibraryPtr result( result_ );
  result->modelGroup = VoltaPTModelGroupPtr( modelGroup_ );

  result->title = decodeTextFromXML(rootElement->valueOfAttribute("title"));
  result->modelGroup->name = result->title;

  FXXMLElementPtrVector modelElements;
  rootElement->collectChildrenWithName( "model", modelElements );
  for( FXXMLElementPtr modelElement : modelElements )
  {
    VoltaPTModelPtr newModel = unarchiveModel(modelElement);
    if ( newModel.get() != nullptr )
    {
      result->modelGroup->models.push_back( newModel );
    }
  }

  FXXMLElementPtrVector elementElements;
  rootElement->collectChildrenWithName( "element", elementElements );
  for ( FXXMLElementPtr elementElement : elementElements )
  {
    VoltaPTElement const newElement = unarchiveElement(elementElement);
    result->elementGroup.elements.push_back(newElement);
  }

  result->metaData = unarchiveMeta(rootElement);

  return result;
}


#if VOLTA_ARCHIVES_SIMULATION_DATA
static VoltaPTSimulationDataPtr unarchiveSimulationData( FXXMLElementPtr xmlElement )
{
  VoltaPTSimulationDataPtr simulationData;
  FXXMLElementPtrVector simulationList;
  xmlElement->collectChildrenWithName("simulation", simulationList);
  if ( simulationList.size() > 1 ) { DebugLog(@"Found multiple simulation results. Expected at most one."); }
  if ( !simulationList.empty() )
  {
    simulationData = VoltaPTSimulationDataPtr( new VoltaPTSimulationData );
  }
  return simulationData;
}
#endif


static VoltaPTSchematicPtr unarchiveSchematic( FXXMLElementPtr xmlElement )
{
  VoltaPTSchematicPtr schematicData;
  FXXMLElementPtrVector schematicList;
  xmlElement->collectChildrenWithName("schematic", schematicList);
  if ( schematicList.size() > 1 ) { DebugLog(@"Found multiple schematics. Expected at most one."); }
  if ( !schematicList.empty() )
  {
    schematicData = VoltaPTSchematicPtr( new VoltaPTSchematic );
    FXXMLElementPtr & schematic = schematicList.front();
    unarchiveElements(schematic, schematicData);
    unarchiveConnectors(schematic, schematicData);
    schematicData->properties = unarchiveProperties(schematic);
    schematicData->properties = mergeWithDefaultProperties(schematicData->properties, FXVoltaCircuitDomainAgent::circuitParameters());
    schematicData->metaData = unarchiveMeta(schematic);
  }
  return schematicData;
}


static VoltaPTSubcircuitDataPtr unarchiveSubcircuitData( FXXMLElementPtr xmlElement )
{
  VoltaPTSubcircuitDataPtr subcircuitData( new VoltaPTSubcircuitData );
  FXXMLElementPtrVector subcircuitDataElementList;
  xmlElement->collectChildrenWithName("subcircuit_data", subcircuitDataElementList);
  if ( subcircuitDataElementList.size() > 1 ) { DebugLog(@"Found multiple subcircuit data. Expected at most one."); }
  if ( !subcircuitDataElementList.empty() )
  {
    subcircuitData = VoltaPTSubcircuitDataPtr( new VoltaPTSubcircuitData );
    FXXMLElementPtr subcircuitDataElement = subcircuitDataElementList.front();
    
    try { subcircuitData->enabled = subcircuitDataElement->valueOfAttribute("enabled").extractBoolean(); }
    catch ( std::runtime_error & ste )
    {
      subcircuitData->enabled = false;
    }

    subcircuitData->name = decodeTextFromXML(subcircuitDataElement->valueOfAttribute("name"));
    subcircuitData->vendor = decodeTextFromXML(subcircuitDataElement->valueOfAttribute("vendor"));
    FXString subcircuitRevisionString = subcircuitDataElement->valueOfAttribute("revision");
    if ( !subcircuitRevisionString.empty() )
    {
      subcircuitData->revision = subcircuitRevisionString.extractLong();
    }
    subcircuitData->labelPosition = unarchiveLabelPosition(subcircuitDataElement);
    subcircuitData->shape = unarchiveShape( subcircuitDataElement );
    subcircuitData->pins = unarchivePins( subcircuitDataElement );
    
    FXXMLElementPtrVector externalsList;
    subcircuitDataElement->collectChildrenWithName("external", externalsList);
    for( FXXMLElementPtr external : externalsList )
    {
      FXString nodeID = decodeTextFromXML(external->valueOfAttribute("node"));
      FXString pinID = decodeTextFromXML(external->valueOfAttribute("pin"));
      if ( !pinID.empty() )
      {
        subcircuitData->externals[pinID] = nodeID;
      }
    }
    
    subcircuitData->metaData = unarchiveMeta(subcircuitDataElement);
  }    
  return subcircuitData;
}


VoltaPTCircuitPtr unarchiveCircuitFromXML( FXXMLElementPtr rootElement )
{
  VoltaPTCircuitPtr result( new VoltaPTCircuit );

  result->title = decodeTextFromXML(rootElement->valueOfAttribute("title"));

  result->schematicData = unarchiveSchematic( rootElement );
  if ( result->schematicData.get() != nullptr )
  {
    result->schematicData->title = result->title; // same as circuit name
  }
  result->subcircuitData = unarchiveSubcircuitData( rootElement );

#if VOLTA_ARCHIVES_SIMULATION_DATA
  result->simulationData = unarchiveSimulationData( rootElement );
#endif

  result->metaData = unarchiveMeta(rootElement);
      
  return result;
}


#pragma mark - Archiving Helpers -


static NSString* archiveCircuitMetaData( std::vector<VoltaPTMetaDataItem> const & metaData )
{
  NSMutableString* result = [[NSMutableString alloc] init];
  FXAutorelease(result)
  for( VoltaPTMetaDataItem const & dataItem : metaData )
  {
    [result appendFormat:@"\n\t<m k=\"%@\" v=\"%@\"/>", dataItem.first.cfString(), encodeTextForVoltaXML(dataItem.second).cfString()];
  }
  return result;
}

static NSString* archiveLabelPosition( VoltaPTLabelPosition labelPosition )
{
  NSString* result = @"none";
  switch (labelPosition)
  {
    case VoltaPTLabelPosition::Right:   result = @"right";   break;
    case VoltaPTLabelPosition::Left:    result = @"left";   break;
    case VoltaPTLabelPosition::Top:     result = @"top";  break;
    case VoltaPTLabelPosition::Bottom:  result = @"bottom";  break;
    case VoltaPTLabelPosition::Center:  result = @"center"; break;
    default: break;
  }
  return result;
}

static void archiveShape( NSMutableString* outString, VoltaPTShape & shape )
{
  if ( shape.paths.empty() && shape.circles.empty() && shape.metaData.empty() )
  {
    return;
  }

  [outString appendFormat:@"\n\t\t<shape width=\"%.0f\" height=\"%.0f\">", shape.width, shape.height];
  for( VoltaPTPath const & path : shape.paths )
  {
    [outString appendFormat:@"\n\t\t\t<path d=\"%@\"", path.pathData.cfString()];
    if ( path.strokeWidth != 1 )
    {
      [outString appendFormat:@" strokeWidth=\"%.1f\"", path.strokeWidth];
    }
    if ( path.filled )
    {
      [outString appendString:@" fill=\"true\""];
    }
    [outString appendString:@" />"];
  }
  for( VoltaPTCircle const & circle : shape.circles )
  {
    [outString appendFormat:@"\n\t\t\t<circle cx=\"%f\" cy=\"%f\" r=\"%f\"", circle.centerX, circle.centerY, circle.radius];
    if ( circle.filled )
    {
      [outString appendString:@" fill=\"true\""];
    }
    [outString appendString:@" />"];
  }
  for( VoltaPTMetaDataItem const & dataItem : shape.metaData )
  {
    [outString appendFormat:@"\n\t\t\t<m k=\"%@\" v=\"%@\"/>", dataItem.first.cfString(), encodeTextForVoltaXML(dataItem.second).cfString()];
  }
  [outString appendString:@"\n\t\t</shape>"];
}


void archivePins( NSMutableString* outString, std::vector<VoltaPTPin> const & pins )
{
  for( VoltaPTPin const & pin : pins )
  {
    [outString appendFormat:@"\n\t\t<pin name=\"%@\" x=\"%f\" y=\"%f\"", encodeTextForVoltaXML(pin.name).cfString(), pin.posX, pin.posY];
    if ( pin.metaData.empty() )
    {
      [outString appendString:@" />"];
    }
    else
    {
      [outString appendString:@" >"];
      for( VoltaPTMetaDataItem const & dataItem : pin.metaData )
      {
        [outString appendFormat:@"\n\t\t\t<m k=\"%@\" v=\"%@\"/>", dataItem.first.cfString(), encodeTextForVoltaXML(dataItem.second).cfString()];
      }
      [outString appendString:@"\n\t\t</pin>"];
    }
  }
}


static NSString* archiveSubcircuitData( VoltaPTSubcircuitDataPtr subcircuitData )
{
  if ( subcircuitData.get() == nullptr )
  {
    return @"";
  }

  NSMutableString* result = [[NSMutableString alloc] init];
  FXAutorelease(result)
  
  [result appendString:@"\n\t<subcircuit_data"];
  [result appendFormat:@" enabled=\"%@\"", subcircuitData->enabled ? @"true" : @"false"];
  [result appendFormat:@" name=\"%@\"", encodeTextForVoltaXML(subcircuitData->name).cfString()];
  if ( !subcircuitData->vendor.empty() )
  {
    [result appendFormat:@" vendor=\"%@\"", subcircuitData->vendor.cfString()];
  }
  [result appendFormat:@" revision=\"%lld\"", subcircuitData->revision];
  [result appendFormat:@" labelPosition=\"%@\"", archiveLabelPosition(subcircuitData->labelPosition)];
  [result appendString:@">"];
  
  archiveShape( result, subcircuitData->shape );
  archivePins( result, subcircuitData->pins );
  
  for( VoltaPTSubcircuitExternal const & external : subcircuitData->externals )
  {
    [result appendFormat:@"\n\t\t<external pin=\"%@\" node=\"%@\" />", encodeTextForVoltaXML(external.first).cfString(), encodeTextForVoltaXML(external.second).cfString()];
  }

  for( VoltaPTMetaDataItem const & dataItem : subcircuitData->metaData )
  {
    [result appendFormat:@"\n\t\t<m k=\"%@\" v=\"%@\"/>", dataItem.first.cfString(), encodeTextForVoltaXML(dataItem.second).cfString()];
  }

  [result appendString:@"\n\t</subcircuit_data>"];
  return result;
}


NSString* archiveElement( VoltaPTElement const & elementData, NSString* prefix )
{
  NSMutableString* result = [NSMutableString stringWithCapacity:200];

  [result appendFormat:@"\n%@<element name=\"%@\" type=\"%@\" modelName=\"%@\" modelVendor=\"%@\" x=\"%g\" y=\"%g\"",
    prefix,
    encodeTextForVoltaXML(elementData.name).cfString(),
    [FXVoltaLibraryUtilities codeStringForModelType:elementData.type].cfString(),
    encodeTextForVoltaXML(elementData.modelName).cfString(),
    encodeTextForVoltaXML(elementData.modelVendor).cfString(),
    elementData.posX,
    elementData.posY];
  if ( elementData.rotation != 0.0 )
  {
    [result appendFormat:@" rotation=\"%g\"", (180.0f/M_PI) * elementData.rotation];
  }
  if ( elementData.flipped )
  {
    [result appendString:@" flipped=\"true\""];
  }
  if ( elementData.labelPosition != VoltaPTLabelPosition::None )
  {
    [result appendFormat:@" labelPosition=\"%@\"", archiveLabelPosition(elementData.labelPosition)];
  }
  if ( elementData.properties.size() + elementData.metaData.size() == 0 )
  {
    [result appendString:@" />"];
  }
  else
  {
    [result appendString:@" >"];
    for( VoltaPTProperty const & property : elementData.properties )
    {
      if ( !property.value.empty() && !property.name.empty() )
      {
        [result appendFormat:@"\n\t%@<p n=\"%@\" v=\"%@\" />", prefix, encodeTextForVoltaXML(property.name).cfString(), encodeTextForVoltaXML(property.value).cfString()];
      }
    }
    for( VoltaPTMetaDataItem const & dataItem : elementData.metaData )
    {
      [result appendFormat:@"\n\t%@<m k=\"%@\" v=\"%@\"/>", prefix, dataItem.first.cfString(), encodeTextForVoltaXML(dataItem.second).cfString()];
    }
    [result appendFormat:@"\n%@</element>", prefix];
  }

  return result;
}


NSString* archiveSchematicData( VoltaPTSchematicPtr schematicData )
{
  NSMutableString* result = [[NSMutableString alloc] init];
  FXAutorelease(result)
  [result appendString:@"\n\t<schematic>"];
  for( VoltaPTElement const & elementData : schematicData->elements )
  {
    [result appendString:archiveElement( elementData, @"\t\t" )];
  }
  for( VoltaPTConnector const & connectorData : schematicData->connectors )
  {
    [result appendFormat:@"\n\t\t<connector start=\"%@\" startPin=\"%@\" end=\"%@\" endPin=\"%@\">",
      encodeTextForVoltaXML(connectorData.startElementName).cfString(),
      encodeTextForVoltaXML(connectorData.startPinName).cfString(),
      encodeTextForVoltaXML(connectorData.endElementName).cfString(),
      encodeTextForVoltaXML(connectorData.endPinName).cfString()];
    for( VoltaSchematicConnectorJointData const & jointData : connectorData.joints )
    {
      [result appendFormat:@"\n\t\t\t<joint x=\"%g\" y=\"%g\"/>", jointData.first, jointData.second];
    }
    for( VoltaPTMetaDataItem const & dataItem : connectorData.metaData )
    {
      [result appendFormat:@"\n\t\t\t<m k=\"%@\" v=\"%@\"/>", dataItem.first.cfString(), encodeTextForVoltaXML(dataItem.second).cfString()];
    }
    [result appendString:@"\n\t\t</connector>"];
  }
  for( VoltaPTProperty const & property : schematicData->properties )
  {
    // To keep the archived circuit from getting unnecessarily bloated (and unreadable for humans)
    // we only write out properties with values.
    // While unarchiving, the missing properties (for the given device type) are added anyway.
    if ( !property.value.empty() && !property.name.empty() )
    {
      [result appendFormat:@"\n\t\t<p n=\"%@\" v=\"%@\" />", encodeTextForVoltaXML(property.name).cfString(), encodeTextForVoltaXML(property.value).cfString()];
    }
  }
  for( VoltaPTMetaDataItem const & dataItem : schematicData->metaData )
  {
    [result appendFormat:@"\n\t\t<m k=\"%@\" v=\"%@\"/>", dataItem.first.cfString(), encodeTextForVoltaXML(dataItem.second).cfString()];
  }
  [result appendString:@"\n\t</schematic>"];
  return result;    
}


#if VOLTA_ARCHIVES_SIMULATION_DATA
NSString* archiveSimulationData( VoltaPTSimulationDataPtr simulationData )
{
  FXIssue(15)
  NSMutableString* result = [[NSMutableString alloc] init];
  FXAutorelease(result)
  return result;    
}
#endif


NSString* archiveModelGroup( VoltaPTModelGroupPtr modelGroup )
{
  if ( (modelGroup.get() == nullptr) || modelGroup->models.empty() )
  {
    return @"";
  }

  NSMutableString* result = [[NSMutableString alloc] init];
  FXAutorelease(result)
  for( VoltaPTModelPtr model : modelGroup->models )
  {
    [result appendFormat:@"\n\t<model type=\"%@\" subtype=\"%@\" name=\"%@\" vendor=\"%@\" revision=\"%lld\" labelPosition=\"%@\">",
      [FXVoltaLibraryUtilities codeStringForModelType:model->type].cfString(),
      model->subtype.cfString(),
      encodeTextForVoltaXML(model->name).cfString(),
      encodeTextForVoltaXML(model->vendor).cfString(),
      model->revision,
      archiveLabelPosition(model->labelPosition)];

    archiveShape( result, model->shape );
    archivePins( result, model->pins );

    for( VoltaPTProperty const & property : model->properties )
    {
      [result appendFormat:@"\n\t\t<p n=\"%@\" v=\"%@\" />", encodeTextForVoltaXML(property.name).cfString(), encodeTextForVoltaXML(property.value).cfString()];
    }

    for( VoltaPTMetaDataItem const & dataItem : model->metaData )
    {
      [result appendFormat:@"\n\t\t<m k=\"%@\" v=\"%@\"/>", dataItem.first.cfString(), encodeTextForVoltaXML(dataItem.second).cfString()];
    }
    
    [result appendString:@"\n\t</model>"];

  } // for each model

  return result;
}


NSString* archiveElementGroup( VoltaPTElementGroup const & elementGroup )
{
  NSMutableString* result = [NSMutableString stringWithCapacity:(elementGroup.elements.size() * 128)];
  for ( VoltaPTElement const & element : elementGroup.elements )
  {
    [result appendString:archiveElement(element, @"\t")];
  }
  return result;
}


#pragma mark - FXVoltaArchiver -


@implementation FXVoltaArchiver


#pragma mark Public


+ (NSString*) archiveLibrary:(VoltaPTLibraryPtr)libraryData
{
  FXIssue(14)
  NSMutableString* result = [[NSMutableString alloc] init];
  FXAutorelease(result)
  [result appendString:getVoltaHeader()];
  [result appendFormat:@"\n<library title=\"%@\">", encodeTextForVoltaXML(libraryData->title).cfString()];
  [result appendString:archiveElementGroup(libraryData->elementGroup)];
  [result appendString:archiveModelGroup(libraryData->modelGroup)];
  [result appendString:@"\n</library>"];
  [result appendString:getVoltaFooter()];
  return result;
}


+ (NSString*) archiveCircuit:(VoltaPTCircuitPtr)circuitData
{
  NSMutableString* result = [NSMutableString string];
  if ( circuitData.get() != nullptr )
  {
    [result appendString:getVoltaHeader()];
    [result appendFormat:@"\n<circuit title=\"%@\">", encodeTextForVoltaXML(circuitData->schematicData->title).cfString()];
    [result appendString:archiveSchematicData(circuitData->schematicData)];
    [result appendString:archiveSubcircuitData(circuitData->subcircuitData)];
  #if VOLTA_ARCHIVES_SIMULATION_DATA
    [result appendString:archiveSimulationData(circuitData->simulationData)];
  #endif
    [result appendString:archiveCircuitMetaData(circuitData->metaData)];
    [result appendString:@"\n</circuit>"];
    [result appendString:getVoltaFooter()];
  }
  return result;
}


+ (VoltaPTLibraryPtr) unarchiveLibraryFromString:(NSString*)libraryDescription formatUpgradedWhileUnarchiving:(BOOL*)upgraded error:(NSError**)error
{
  VoltaPTLibraryPtr result;
  NSAssert( libraryDescription != nil, @"Could not create string from unarchived data" );
  if ( libraryDescription != nil )
  {
    FXString archivedLibrary((__bridge CFStringRef)libraryDescription);
    FXXMLDocumentPtr libraryDocument = [FXVoltaArchiveValidator parseAndValidate:archivedLibrary upgradedWhileParsing:upgraded error:error];
    if ( libraryDocument.get() != nullptr )
    {
      FXXMLElementPtr rootElement = libraryDocument->getRootElement();
      if ( rootElement->getName() == skVoltaRootElementName )
      {
        FXXMLElementPtrVector & rootChildren = rootElement->getChildren();
        if ( rootChildren.size() == 1 )
        {
          FXXMLElementPtr & rootChildElement = rootChildren.front();
          if ( rootChildElement->getName() == skVoltaLibraryElementName )
          {
            result = unarchiveLibraryFromXML( rootChildElement );
          }
        }
      }
    }
  }
  return result;
}


+ (VoltaPTCircuitPtr) unarchiveCircuitFromString:(NSString*)circuitDescription formatUpgradedWhileUnarchiving:(BOOL*)upgraded error:(NSError**)error
{
  VoltaPTCircuitPtr result;
  NSAssert( circuitDescription != nil, @"Could not create string from unarchived data" );
  if ( circuitDescription != nil )
  {
    FXString archivedCircuit((__bridge CFStringRef)circuitDescription);
    FXXMLDocumentPtr circuitDocument = [FXVoltaArchiveValidator parseAndValidate:archivedCircuit upgradedWhileParsing:upgraded error:error];
    if ( circuitDocument.get() != nullptr )
    {
      FXXMLElementPtr rootElement = circuitDocument->getRootElement();
      if ( rootElement->getName() == skVoltaRootElementName )
      {
        FXXMLElementPtrVector & rootChildren = rootElement->getChildren();
        if ( rootChildren.size() == 1 )
        {
          FXXMLElementPtr & rootChildElement = rootChildren.front();
          if ( rootChildElement->getName() == skVoltaCircuitElementName )
          {
            result = unarchiveCircuitFromXML( rootChildElement );
          }
        }
      }
    }
  }
  return result;
}


@end
