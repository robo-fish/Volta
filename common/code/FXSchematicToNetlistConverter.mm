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
#import "FXSchematicToNetlistConverter.h"
#import "FXVoltaPersistentMetaKeys.h"
#import "FXVoltaCircuitDomainAgent.h"
#import "FXVoltaLibraryUtilities.h"
#import "FXString.h"
#include <map>
#include <sstream>
#include <memory>

#if VOLTA_DEBUG
#include <iostream>
#endif

////////////////////////////////////////////////////////////////////////////////
#pragma mark Data structures

/// A pin is a specific connection point of a specific element
/// @pre element names must be unique
struct FXConverter_Pin
{
  FXString elementName;
  FXString connectionPointName;

  FXConverter_Pin() {}

  FXConverter_Pin( FXString const & element, FXString const & point ) :
    elementName(element),
    connectionPointName(point) {}

  bool operator< (FXConverter_Pin const & otherPin) const
  {
    return (elementName == otherPin.elementName) ?
      (connectionPointName < otherPin.connectionPointName) :
      (elementName < otherPin.elementName);
  }

  bool operator== (FXConverter_Pin const & otherPin) const
  {
    return (elementName == otherPin.elementName) && (connectionPointName == otherPin.connectionPointName);
  }

  bool operator!= (FXConverter_Pin const & otherPin) const
  {
    return (elementName != otherPin.elementName) || (connectionPointName != otherPin.connectionPointName);
  }
};

static std::ostream& operator<< (std::ostream& out, FXConverter_Pin const & pin)
{
  out << "{" << pin.elementName << "," << pin.connectionPointName << "}";
  return out;
}


struct FXConverter_Node
{
  int32_t nodeNumber;
  FXString nodeName;

  FXConverter_Node() : nodeNumber(-1) {}
  
  FXConverter_Node( int32_t nodeNum, FXString const & name = "" ) : nodeNumber(nodeNum), nodeName(name) {}

  bool operator< (FXConverter_Node const & otherNode) const
  {
    return nodeNumber < otherNode.nodeNumber;
  }
  
  bool operator== (FXConverter_Node const & otherNode) const
  {
    return nodeNumber == otherNode.nodeNumber;
  }

  bool operator!= (FXConverter_Node const & otherNode) const
  {
    return nodeNumber != otherNode.nodeNumber;
  }
};

typedef std::shared_ptr<FXConverter_Node> FXConverter_NodePtr;

static std::ostream& operator<< (std::ostream& out, FXConverter_NodePtr node)
{
  out << "(" << node->nodeNumber << ",\"" << node->nodeName << "\")";
  return out;
}


/// Support class for schematic to netlist conversion
typedef std::map<FXConverter_Pin, FXConverter_NodePtr> FXConverter_NodeAssignmentTable;

static std::ostream& operator<< (std::ostream& out, FXConverter_NodeAssignmentTable const & assignmentTable)
{
  for ( auto tableItem : assignmentTable )
  {
    out << tableItem.first << " --> " << tableItem.second << std::endl;
  }
  return out;
}


/// Connector with additional traversal information
struct FXConverter_Connector
{
  FXConverter_Pin startPin;
  FXConverter_Pin endPin;
  bool traversed;

  FXConverter_Connector(VoltaPTConnector const & connector) :
      traversed(false)
  {
    startPin.elementName = connector.startElementName;
    startPin.connectionPointName = connector.startPinName;
    endPin.elementName = connector.endElementName;
    endPin.connectionPointName = connector.endPinName;
  }

  bool isConnectedToPin( FXConverter_Pin const & pin ) const
  {
    return (startPin == pin) || (endPin == pin);
  }

  bool operator== (FXConverter_Connector const & otherConnector) const
  {
    return (startPin == otherConnector.startPin) && (endPin == otherConnector.endPin);
  }
  
  bool operator!= (FXConverter_Connector const & otherConnector) const
  {
    return (startPin != otherConnector.startPin) || (endPin != otherConnector.endPin);
  }
};

static std::ostream& operator<< (std::ostream& out, FXConverter_Connector const & connector)
{
  out << "[ " << connector.startPin << ", " << connector.endPin << " ]";
  return out;
}




/// Maps element names to their model data
typedef std::map<FXString, VoltaPTModelPtr> FXConverter_ElementToModelMap;
typedef std::pair<FXString, VoltaPTModelPtr> FXConverter_ElementToModelMapItem;

static std::ostream& operator<< (std::ostream& out, FXConverter_ElementToModelMap const & modelMap)
{
  std::ostringstream oss;
  for ( auto mapItem : modelMap )
  {
    oss << mapItem.first << " --> " << mapItem.second->name << ", ";
    oss << " pins:";
    for( VoltaPTPin const & pin :  mapItem.second->pins )
    {
      oss << " " << pin.name;
    }
    oss << std::endl;
  }
  out << oss.str();
  return out;
}



struct FXConverter_ConverterData
{
  FXConverter_NodeAssignmentTable       nodeTable;
  FXConverter_ElementToModelMap         elementToModelMap;
  std::vector<FXConverter_Connector>    connectors;
  VoltaPTSchematicPtr                   schematicData;
  VoltaPTSubcircuitDataPtr              subcircuitData;
  std::ostringstream                    out;
  std::set<VoltaPTModelPtr>             deviceModels;
  std::vector<std::pair<VoltaPTElement const,VoltaPTModelPtr>> meterElements;
  FXStringVector                        commands;
  FXStringVector                        errors;
};


////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Operations

static size_t sNodeNameNumberCounter = 1;

static FXString createUniqueNodeName(FXConverter_ElementToModelMap const & elementToModelMap)
{
  bool isUnique = true;
  do
  {
    isUnique = true;

    std::ostringstream oss;
    oss << sNodeNameNumberCounter++;
    FXString newNodeName( oss.str() );

    for( FXConverter_ElementToModelMapItem const & mapItem : elementToModelMap )
    {
      if ( mapItem.first == newNodeName )
      {
        isUnique = false;
        break;
      }
    }
    if (isUnique)
    {
      return newNodeName;
    }
  } while (!isUnique);
  return "";
}


/// Creates a node for a connector that connects two pins which are neither electrically transparent nor electric ground.
/// Nonrecursive.
static void createNodeForConnector( FXConverter_Connector & connector, int32_t& nodeCounter, FXConverter_ConverterData & data )
{
  if ( !connector.traversed )
  {
    FXConverter_NodeAssignmentTable::iterator it = data.nodeTable.find(connector.startPin);
    if( it != data.nodeTable.end() )
    {
      data.nodeTable[connector.endPin] = it->second;
    }
    else
    {
      it = data.nodeTable.find(connector.endPin);
      if( it != data.nodeTable.end() )
      {
        data.nodeTable[connector.startPin] = it->second;
      }
      else
      {
        // Create a new node by assigning a valid node number to the result.
        FXConverter_NodePtr node( new FXConverter_Node(nodeCounter++) );
        node->nodeName = createUniqueNodeName(data.elementToModelMap);
        data.nodeTable[ connector.startPin ] = node;
        data.nodeTable[ connector.endPin ] = node;
      }
    }
    connector.traversed = true;
  }
}


// Apply the given node to all pins electrically connected to the given connector.
// Uses a recursive traversal algorithm.
static void applyNodeToConnector(FXConverter_NodePtr node, FXConverter_Connector & connector, FXConverter_ConverterData & data)
{
  if ( !connector.traversed )
  {
    connector.traversed = true; // prevents infinite recursion

    // If one of the connected elements is electrically transparent
    // we need to recurse into the connectors connected to the other pins of the element.
    FXConverter_ElementToModelMap::const_iterator e2mIt;
    std::vector<FXString> connectedElements = { connector.startPin.elementName, connector.endPin.elementName };
    for( FXString const & connectedElement : connectedElements )
    {
      e2mIt = data.elementToModelMap.find( connectedElement );
      if ( e2mIt == data.elementToModelMap.end() )
      {
        DebugLog(@"Could not find model for element \"%@\"", connectedElement.cfString() );
        continue;
      }
      VoltaPTModelPtr model = e2mIt->second;
      
      if ( model->type == VMT_Node )
      {
        for( FXConverter_Connector & otherConnector : data.connectors )
        {
          if ( (otherConnector != connector) &&
            ( (otherConnector.startPin.elementName == connectedElement) || (otherConnector.endPin.elementName == connectedElement) ) )
          {
            applyNodeToConnector( node, otherConnector, data );
          }
        }
        
        if ( node->nodeName.empty() )
        {
          FXIssue(80)
          node->nodeName = connectedElement;
        }
      }
    }

    data.nodeTable[connector.endPin] = node;
    data.nodeTable[connector.startPin] = node;
  }
}


static void validateNetlistName(VoltaPTElement const & element, VoltaPTModelPtr model, FXConverter_ConverterData & data)
{
  FXString prefix = FXVoltaCircuitDomainAgent::circuitElementNamePrefixForModel(model).upperCase();
  if ( !prefix.empty() && !element.name.upperCase().startsWith(prefix) )
  {
    data.errors.push_back( FXString("wrong name prefix").localize("ConversionErrors", element.name.cfString(), prefix.cfString()) );
  }
}


/// @return a whitespace-delimited sequence of node numbers corresponding to the given list of pin names.
/// @param orderedPinNames must be NULL-terminated
static void nodeListingForElement(
  VoltaPTElement const & element,
  const char* orderedPinNames[],
  FXConverter_ConverterData & data)
{
  int i = 0;
  for ( ; orderedPinNames[i] != NULL; i++ )
  {
    FXConverter_NodeAssignmentTable::const_iterator it = data.nodeTable.find(FXConverter_Pin(element.name, orderedPinNames[i]));
    if ( it != data.nodeTable.end() )
    {
      FXIssue(80)
      data.out << " " << it->second->nodeName;
    }
    else
    {
      data.errors.push_back( FXString("pin not wired").localize("ConversionErrors", orderedPinNames[i], element.name.cfString()) );
    }
  }
}


static FXString getValueOfProperty(
  FXString const & propertyName,
  FXString const & defaultValue,
  FXString const & errorMessage,
  VoltaPTPropertyVector const & propertyList,
  FXStringVector& errorCollection,
  FXString const & elementName )
{
  FXString result;
  for( VoltaPTProperty const & property : propertyList )
  {
    if ( property.name == propertyName )
    {
      result = property.value;
      break;
    }
  }
  if ( result.empty() )
  {
    if ( !defaultValue.empty() )
    {
      result = defaultValue;
    }
    else if ( !errorMessage.empty() )
    {
      errorCollection.push_back(errorMessage.localize("ConversionErrors", elementName.cfString()));
    }
  }
  return result;
}


static void streamNonEmptyProperties(std::ostream & stream, VoltaPTPropertyVector const & properties)
{
  for( VoltaPTProperty const & property : properties )
  {
    if ( !property.value.empty() )
    {
      stream << " " << property.name << "=" << property.value;
    }
  }
}


static FXString replaceSpecialCharacters(FXString const & input)
{
  FXString result = input;
  result.trimWhitespace();
  result.replaceAll(" ", ".");
  result.replaceAll("+", "~");
  result.replaceAll("-", "_");
  return result;
}


#define PROPERTY_VALUE(propertyName, defaultValue, errorMessage) \
  getValueOfProperty( propertyName , defaultValue , errorMessage , element.properties, data.errors, element.name )


static void processMeterElement_VDC(VoltaPTElement const & element, VoltaPTModelPtr model, FXConverter_ConverterData & data, FXStringVector & outCommands, FXString & outPrint)
{
  FXConverter_NodeAssignmentTable::const_iterator itAnode = data.nodeTable.find(FXConverter_Pin(element.name, "Anode"));
  if ( itAnode != data.nodeTable.end() )
  {
    FXString const analysisCommand = PROPERTY_VALUE("source", "", "missing voltage source")
      + " " + PROPERTY_VALUE("start", "", "missing start voltage")
      + " " + PROPERTY_VALUE("stop", "", "missing stop voltage")
      + " " + PROPERTY_VALUE("step", "", "missing voltage step size");
    bool commandAlreadyExists = false;
    for ( FXString const & existingCommand : outCommands )
    {
      if ( existingCommand == analysisCommand )
      {
        commandAlreadyExists = true;
        break;
      }
    }
    if ( !commandAlreadyExists )
    {
      outCommands.push_back(analysisCommand);
    }
    FXString referenceNode = PROPERTY_VALUE("ref. node", "", "");
    outPrint = outPrint + " V(" + itAnode->second->nodeName + (referenceNode.empty() ? ")" : ("," + referenceNode + ")"));
  }
}


static void processMeterElement_VAC(VoltaPTElement const & element, VoltaPTModelPtr model, FXConverter_ConverterData & data, FXStringVector & outCommands, FXString & outPrint)
{
  FXConverter_NodeAssignmentTable::const_iterator itAnode = data.nodeTable.find(FXConverter_Pin(element.name, "Anode"));
  if ( itAnode != data.nodeTable.end() )
  {
    FXString scaleType = PROPERTY_VALUE("scale type", "dec", "missing scale type").lowerCase();
    if ( !scaleType.empty() && (scaleType != "dec") && (scaleType != "oct") && (scaleType != "lin") )
    {
      data.errors.push_back( FXString("Unknown scale type.").localize("ConversionErrors", element.name.cfString()) );
    }
    else
    {
      FXString const analysisCommand = scaleType
        + " " + PROPERTY_VALUE("# points", "", "missing number of analysis points")
        + " " + PROPERTY_VALUE("start frequency", "", "missing start frequency")
        + " " + PROPERTY_VALUE("stop frequency", "", "missing stop frequency");
      bool commandAlreadyExists = false;
      for ( FXString const & existingCommand : outCommands )
      {
        if ( existingCommand == analysisCommand )
        {
          commandAlreadyExists = true;
          break;
        }
      }
      if ( !commandAlreadyExists )
      {
        outCommands.push_back(analysisCommand);
      }
      FXString referenceNode = PROPERTY_VALUE("ref. node", "", "");
      outPrint = outPrint + " V(" + itAnode->second->nodeName + (referenceNode.empty() ? ")" : ("," + referenceNode + ")"));
    }
  }
}


static void processMeterElement_VTRAN(VoltaPTElement const & element, VoltaPTModelPtr model, FXConverter_ConverterData & data, FXStringVector & outCommands, FXString & outPrint)
{
  FXConverter_NodeAssignmentTable::const_iterator itAnode = data.nodeTable.find(FXConverter_Pin(element.name, "Anode"));
  if ( itAnode != data.nodeTable.end() )
  {
    FXString step = PROPERTY_VALUE("tstep", "", "missing step time interval");
    FXString stop = PROPERTY_VALUE("tstop", "", "missing stop time");
    if ( !step.empty() && !stop.empty() )
    {
      FXString analysisCommand = step + " " + stop;
      FXString start = PROPERTY_VALUE("tstart", "", "");
      if ( !start.empty() )
      {
        analysisCommand = analysisCommand + " " + start;
        FXString max = PROPERTY_VALUE("tmax", "", "");
        if ( !max.empty() )
        {
          analysisCommand = analysisCommand + " " + max;
        }
      }
      FXString useInitialCondition = PROPERTY_VALUE("use ic", "", "");
      if ( !useInitialCondition.empty() )
      {
        analysisCommand = analysisCommand + " UIC";
      }
      bool commandAlreadyExists = false;
      for ( FXString const & existingCommand : outCommands )
      {
        if ( existingCommand == analysisCommand )
        {
          commandAlreadyExists = true;
          break;
        }
      }
      if ( !commandAlreadyExists )
      {
        outCommands.push_back(analysisCommand);
      }
      FXString referenceNode = PROPERTY_VALUE("ref. node", "", "");
      outPrint = outPrint + " V(" + itAnode->second->nodeName + (referenceNode.empty() ? ")" : ("," + referenceNode + ")"));
    }
  }
}


/// @return a unique voltage source name obtained by suffixing the given base name
static FXString uniqueVoltageSourceName(FXString const & baseName, FXConverter_ConverterData & data)
{
  FXString result;
  bool nameExists = false;
  int nameCounter = 1;
  do
  {
    std::ostringstream ossName;
    ossName << baseName << nameCounter++;
    result = ossName.str();
    nameExists = false;
    for( FXConverter_ElementToModelMapItem const & modelMapItem : data.elementToModelMap )
    {
      if (modelMapItem.first == result)
      {
        nameExists = true;
        break;
      }
    }
    // Also check previous command lines.
    if ( !nameExists )
    {
      for( FXString const & previousCommand : data.commands )
      {
        if ( previousCommand.find( result ) == 0 )
        {
          nameExists = true;
          break;
        }
      }
    }
  } while ( nameExists );
  return result;
}


static void processMeterElement_ADC(VoltaPTElement const & element, VoltaPTModelPtr model, FXConverter_ConverterData & data, FXStringVector & outCommands, FXString & outPrint)
{
  FXString const voltageSourceName = uniqueVoltageSourceName("Vamm", data);
  FXConverter_NodeAssignmentTable::const_iterator itAnode = data.nodeTable.find(FXConverter_Pin(element.name, "Anode"));
  FXConverter_NodeAssignmentTable::const_iterator itCathode = data.nodeTable.find(FXConverter_Pin(element.name, "Cathode"));
  if ( (itAnode != data.nodeTable.end()) && (itCathode != data.nodeTable.end()) )
  {
    data.commands.push_back( voltageSourceName + " " + itAnode->second->nodeName + " " + itCathode->second->nodeName + " 0" );
    FXString const analysisCommand = PROPERTY_VALUE("source", "", "missing current source")
      + " " + PROPERTY_VALUE("start", "", "missing start current")
      + " " + PROPERTY_VALUE("stop", "", "missing stop current")
      + " " + PROPERTY_VALUE("step", "", "missing current step size");
    bool commandAlreadyExists = false;
    for ( FXString const & existingCommand : outCommands )
    {
      if ( existingCommand == analysisCommand )
      {
        commandAlreadyExists = true;
        break;
      }
    }
    if ( !commandAlreadyExists )
    {
      outCommands.push_back(analysisCommand);
    }
    outPrint = outPrint + " I(" + voltageSourceName + ")";
  }
}


static void processMeterElement_AAC(VoltaPTElement const & element, VoltaPTModelPtr model, FXConverter_ConverterData & data, FXStringVector & outCommands, FXString & outPrint)
{
  FXString const voltageSourceName = uniqueVoltageSourceName("Vamm", data);
  FXConverter_NodeAssignmentTable::const_iterator itAnode = data.nodeTable.find(FXConverter_Pin(element.name, "Anode"));
  FXConverter_NodeAssignmentTable::const_iterator itCathode = data.nodeTable.find(FXConverter_Pin(element.name, "Cathode"));
  if ( (itAnode != data.nodeTable.end()) && (itCathode != data.nodeTable.end()) )
  {
    data.commands.push_back( voltageSourceName + " " + itAnode->second->nodeName + " " + itCathode->second->nodeName + " 0" );
    FXString scaleType = PROPERTY_VALUE("scale type", "dec", "").lowerCase();
    if ( (scaleType != "dec") && (scaleType != "oct") && (scaleType != "lin") )
    {
      data.errors.push_back( FXString("Unknown scale type.").localize("ConversionErrors", element.name.cfString()) );
    }
    else
    {
      FXString const analysisCommand = scaleType
        + " " + PROPERTY_VALUE("# points", "", "missing number of analysis points")
        + " " + PROPERTY_VALUE("start frequency", "", "missing start frequency")
        + " " + PROPERTY_VALUE("stop frequency", "", "missing stop frequency");
      bool commandAlreadyExists = false;
      for ( FXString const & existingCommand : outCommands )
      {
        if ( existingCommand == analysisCommand )
        {
          commandAlreadyExists = true;
          break;
        }
      }
      if ( !commandAlreadyExists )
      {
        outCommands.push_back(analysisCommand);
      }
      outPrint = outPrint + " I(" + voltageSourceName + ")";
    }
  }
}
  

static void processMeterElements( FXConverter_ConverterData & data )
{
  FXStringVector analyses_DC, analyses_AC, analyses_TRAN;
  FXString print_DC, print_AC, print_TRAN;

  for ( std::pair<VoltaPTElement const, VoltaPTModelPtr> & meterInfo : data.meterElements )
  {
    VoltaPTElement const & element = meterInfo.first;
    VoltaPTModelPtr const & model = meterInfo.second;

    if ( (element.type != VMT_METER)
      || (model.get() == nullptr)
      || (model->type != VMT_METER) )
      return;

    FXString const meterType = model->subtype.lowerCase();

         if ( meterType == "vdc" )   processMeterElement_VDC(element, model, data, analyses_DC, print_DC);
    else if ( meterType == "vac" )   processMeterElement_VAC(element, model, data, analyses_AC, print_AC);
    else if ( meterType == "vtran" ) processMeterElement_VTRAN(element, model, data, analyses_TRAN, print_TRAN);
    else if ( meterType == "adc" )   processMeterElement_ADC(element, model, data, analyses_DC, print_DC);
    else if ( meterType == "aac" )   processMeterElement_AAC(element, model, data, analyses_AC, print_AC);
  }

  if ( !analyses_AC.empty() && !print_AC.empty() )
  {
    for ( FXString const & analysis : analyses_AC )
    {
      data.commands.push_back(".AC " + analysis);
    }
    data.commands.push_back(".PRINT AC" + print_AC);
  }

  if ( !analyses_TRAN.empty() && !print_TRAN.empty() )
  {
    for ( FXString const & analysis : analyses_TRAN )
    {
      data.commands.push_back(".TRAN " + analysis);
    }
    data.commands.push_back(".PRINT TRAN" + print_TRAN);
  }

  if ( !analyses_DC.empty() && !print_DC.empty() )
  {
    for ( FXString const & analysis : analyses_DC )
    {
      data.commands.push_back(".DC " + analysis);
    }
    data.commands.push_back(".PRINT DC" + print_DC);
  }
}


/// @param[out] output The output stream for writing the netlist line for the given element.
/// @param[out] errors A list of error messages that can be appended to.
/// @param[out] deviceModels Container for collecting the semiconductor device models used by the given element.
/// @param[out] commands Container for collecting SPICE commands resulting, for example, from the presence of meter elements.
static void processElement( VoltaPTElement const & element, FXConverter_ConverterData & data )
{
  FXConverter_ElementToModelMap::const_iterator it = data.elementToModelMap.find( element.name );
  if ( it == data.elementToModelMap.end() )
  {
    DebugLog(@"Could not find model for element %@", element.name.cfString());
    data.out << element.name << " ?";
    return;
  }
  VoltaPTModelPtr model = it->second;
  if ( (model.get() == nullptr)
    || (model->type == VMT_Node)
    || (model->type == VMT_Ground)
    || (model->type == VMT_DECO) )
  {
    return;
  }

  if ( element.type == VMT_METER )
  {
    data.meterElements.push_back(std::make_pair(element,model));
    return;
  }

  validateNetlistName(element, model, data); FXIssue(81)

  data.out << replaceSpecialCharacters(element.name);

  FXString const subtype = model->subtype.lowerCase();

  switch ( model->type )
  {
    case VMT_R:
      {
        static const char* pins[] = { "A", "B", NULL };
        nodeListingForElement(element, pins, data);
        if ( subtype == "semi" )
        {
          data.out << " " << PROPERTY_VALUE("resistance", "", "") << " " << replaceSpecialCharacters(model->fullName());
          for( VoltaPTProperty const & property : element.properties )
          {
            if ( (property.name != "resistance") && !property.value.empty() )
            {
              data.out << " " << property.name << "=" << property.value;
            }
          }
          data.deviceModels.insert(model);
        }
        else
        {
          data.out << " " << PROPERTY_VALUE("resistance", "1k", "");
        }
        break;
      }
    case VMT_L:
      {
        static const char* pins[] = { "A", "B", NULL };
        nodeListingForElement(element, pins, data);
        if ( model->properties.empty() )
        {
          data.out << " " << PROPERTY_VALUE("inductance", "1m", "");
        }
        else
        {
          data.out << " " << replaceSpecialCharacters(model->fullName());
          streamNonEmptyProperties(data.out, element.properties);
          data.deviceModels.insert(model);
        }
        break;
      }
    case VMT_C:
      {
        static const char* pins[] = { "A", "B", NULL };
        nodeListingForElement(element, pins, data);
        if ( subtype == "semi" )
        {
          data.out << " " << replaceSpecialCharacters(model->fullName());
          streamNonEmptyProperties(data.out, element.properties);
          data.deviceModels.insert(model);
        }
        else
        {
          data.out << " " << PROPERTY_VALUE("capacitance", "1u", "");
          FXString const initialCondition = PROPERTY_VALUE("ic", "", "");
          if ( !initialCondition.empty() )
          {
            data.out << " IC=" << initialCondition;
          }
        }
        break;
      }
    case VMT_D:
      {
        static const char* pins[] = { "Anode", "Cathode", NULL };
        nodeListingForElement(element, pins, data);
        data.out << " " << replaceSpecialCharacters(model->fullName());
        streamNonEmptyProperties(data.out, element.properties);
        data.deviceModels.insert(model);
        break;
      }
    case VMT_BJT:
      {
        static const char* pins[] = {  "Collector", "Base", "Emitter", NULL };
        nodeListingForElement(element, pins, data);
        data.out << " " << replaceSpecialCharacters(model->fullName());
        streamNonEmptyProperties(data.out, element.properties);
        data.deviceModels.insert(model);
        break;
      }
    case VMT_JFET:
    case VMT_MESFET:
      {
        static const char* pins[] = {  "Drain", "Gate", "Source", NULL };
        nodeListingForElement(element, pins, data);
        data.out << " " << replaceSpecialCharacters(model->fullName());
        streamNonEmptyProperties(data.out, element.properties);
        data.deviceModels.insert(model);
        break;
      }
    case VMT_MOSFET:
      {
        if ( model->pins.size() == 4 )
        {
          static const char* pins[] = {  "Drain", "Gate", "Source", "Bulk", NULL };
          nodeListingForElement(element, pins, data);
        }
        else
        {
          // No bulk pin specified. Source is connected to bulk.
          static const char* pins[] = {  "Drain", "Gate", "Source", "Source", NULL };
          nodeListingForElement(element, pins, data);
        }
        data.out << " " << replaceSpecialCharacters(model->fullName());
        streamNonEmptyProperties(data.out, element.properties);
        data.deviceModels.insert(model);
        break;
      }
    case VMT_V:
    case VMT_I:
      if ( subtype == "vc" )
      {
          static const char* pins[] = { "N+", "N-", "NC+", "NC-", NULL };
          nodeListingForElement(element, pins, data);
          data.out << " " << ((model->type == VMT_V) ? PROPERTY_VALUE( "gain", "1", "missing gain value" ) : PROPERTY_VALUE("transconductance", "", "missing transconductance value"));
      }
      else if ( subtype == "cc" )
      {
        static const char* pins[] = { "N+", "N-", NULL };
        nodeListingForElement(element, pins, data);
        if (model->type == VMT_V)
        {
          data.out << " " << PROPERTY_VALUE("vnam", "", "missing voltage source name")
            << " " << PROPERTY_VALUE("transresistance", "", "missing transresistance value");
        }
        else
        {
          data.out << " " << PROPERTY_VALUE("vnam", "", "missing voltage source name")
            << " " << PROPERTY_VALUE("gain", "", "missing current gain");
        }
      }
      else if ( subtype == "nonlin" )
      {
        static const char* pins[] = { "N+", "N-", NULL };
        nodeListingForElement(element, pins, data);
        if ( model->type == VMT_V )
          data.out << " V = " << PROPERTY_VALUE("v =", "", "missing nonlinear voltage expression");
        else
          data.out << " I = " << PROPERTY_VALUE("i =", "", "missing nonlinear current expression");
      }
      else
      {
        static const char* pins[] = { "Anode", "Cathode", NULL };
        nodeListingForElement(element, pins, data);
        if ( subtype == "dc" )
        {
          if ( model->type == VMT_V )
          {
          #if 0
            data.out << " DC"; // For voltage sources that are always constant. However, not suitable for transient analysis.
          #endif
            data.out << " " << PROPERTY_VALUE("voltage", "", "missing voltage value");
          }
          else
          {
            data.out << " " << PROPERTY_VALUE( "current", "", "missing current value" );
          }
        }
        else if ( subtype == "ac" )
        {
          data.out << " 0" /* printing a DC value of 0 to suppress warnings */ << " AC "
            << PROPERTY_VALUE( "magnitude", "1", "" ) << " "
            << PROPERTY_VALUE( "phase", "0", "" );
        }
        else if ( subtype == "sin" )
        {
          data.out << " 0 SIN("
            << PROPERTY_VALUE( "offset", "", "missing offset" ) << " "
            << PROPERTY_VALUE( "amplitude", "", "missing amplitude" ) << " "
            << PROPERTY_VALUE( "frequency", "50", "" ) << " "
            << PROPERTY_VALUE( "delay", "0.0", "" ) << " "
            << PROPERTY_VALUE( "damping factor", "0.0", "" ) << ")";
        }
        else if ( subtype == "pulse" )
        {
          data.out << " 0 PULSE("
            << PROPERTY_VALUE( "initial", "", "missing initial value" ) << " "
            << PROPERTY_VALUE( "pulsed", "", "missing pulsed value" ) << " "
            << PROPERTY_VALUE( "delay", "0", "" ) << " "
            << PROPERTY_VALUE( "rise", "", "" ) << " "
            << PROPERTY_VALUE( "fall", "", "" ) << " "
            << PROPERTY_VALUE( "pulse width", "", "" ) << " "
            << PROPERTY_VALUE( "period", "", "" ) << ")";
        }
      }
      break;
    case VMT_LM:
      {
        static const char* pins[] = { "L1+", "L1-", "L2+", "L2-", NULL };
        FXString const inductance1 = PROPERTY_VALUE("inductance1", "", "missing inductance value for first inductor");
        FXString const inductance2 = PROPERTY_VALUE("inductance2", "", "missing inductance value for second inductor");
        FXString const inductor1 = "L1" + element.name;
        FXString const inductor2 = "L2" + element.name;
        data.out << " " << inductor1 << " " << inductor2 << " " << PROPERTY_VALUE("coupling", "", "missing coupling factor between the two inductors") << std::endl;
        FXString const & pin1 = data.nodeTable[FXConverter_Pin(element.name, pins[0])]->nodeName;
        FXString const & pin2 = data.nodeTable[FXConverter_Pin(element.name, pins[1])]->nodeName;
        FXString const & pin3 = data.nodeTable[FXConverter_Pin(element.name, pins[2])]->nodeName;
        FXString const & pin4 = data.nodeTable[FXConverter_Pin(element.name, pins[3])]->nodeName;
        data.out << inductor1 << " " << pin1 << " " << pin2 << " " << inductance1;
        data.out << std::endl;
        data.out << inductor2 << " " << pin3 << " " << pin4 << " " << inductance2;
        break;
      }
    case VMT_SW:
      if ( subtype == "sw" )
      {
        static const char* pins[] = { "Terminal1", "Terminal2", "ControlPlus", "ControlMinus", NULL };
        nodeListingForElement(element, pins, data);
        data.out << " " << replaceSpecialCharacters(model->fullName());
        FXString onOrOff = PROPERTY_VALUE( "on-off", "", "" ).upperCase();
        if ( !onOrOff.empty() )
        {
          if ( (onOrOff != "ON") || (onOrOff != "OFF") )
          {
            data.out << " ?";
            data.errors.push_back( FXString("Expected ON or OFF.").localize("ConversionErrors", element.name.cfString()) );
          }
          else
          {
            data.out << " " << onOrOff;
          }
        }
      }
      else if ( subtype == "csw" )
      {
        static const char* pins[] = { "Terminal1", "Terminal2", NULL };
        nodeListingForElement(element, pins, data);
        data.out << " " << PROPERTY_VALUE( "vctrl", "", "missing control voltage source name" );
        data.out << " " << replaceSpecialCharacters(model->fullName());
        FXString onOrOff = PROPERTY_VALUE( "on-off", "", "Expected ON or OFF." ).upperCase();
        if ( !onOrOff.empty() )
        {
          if ( (onOrOff != "ON") || (onOrOff != "OFF") )
          {
            data.out << " ?";
            data.errors.push_back( FXString("Expected ON or OFF.").localize("ConversionErrors", element.name.cfString()) );
          }
          else
          {
            data.out << " " << onOrOff;
          }
        }
      }
      break;
    case VMT_SUBCKT:
      {
        for( VoltaPTPin const & pin : model->pins )
        {
          FXConverter_NodeAssignmentTable::const_iterator it = data.nodeTable.find(FXConverter_Pin(element.name, pin.name));
          if ( it == data.nodeTable.end() )
          {
            // Checking if the external pin of the subcircuit maps to an internal node.
            for( VoltaPTMetaDataItem const & item : model->metaData )
            {
              if ( item.first == pin.name )
              {
                if ( !item.second.empty() )
                {
                  data.errors.push_back( FXString("subcircuit pin not wired").localize("ConversionErrors", pin.name.cfString(), element.name.cfString()) );
                }
                break;
              }
            }
          }
          else
          {
            // Checking if the external pin of the subcircuit maps to an internal node.
            bool foundInternalNode = false;
            for( VoltaPTMetaDataItem const & item : model->metaData )
            {
              if ( item.first == pin.name )
              {
                if ( !item.second.empty() )
                {
                  foundInternalNode = true;
                  break;
                }
              }
            }
            if (!foundInternalNode)
            {
              data.errors.push_back( FXString("subcircuit pin no internal wiring").localize("ConversionErrors", pin.name.cfString(), element.name.cfString()) );
            }
            data.out << " " << it->second->nodeName;
          }
        }
        data.out << " " << replaceSpecialCharacters(model->fullName());
        data.deviceModels.insert(model);
        break;
      }
    case VMT_XL:
    #if 0
      if ( subtype == "urc" )
      {
      }
      else if ( subtype == "tra" )
      {
        static const char* pins[] = { "Port1+", "Port1-", "Port2+", "Port2-", NULL };
        nodeListingForElement(element, pins, data);
        for( VoltaPTProperty const & property : element.properties )
        {
          if ( !property.value.empty() )
          {
            data.out << " " << property.name << "=" << property.value;
          }
          else if ( property.name == "z0" )
          {
            data.errors.push_back( FXString("invalid impedance value").localize("ConversionErrors", element.name.cfString()) );
          }
        }
      }
      else
    #endif
      if ( subtype == "ltra" )
      {
        static const char* pins[] = { "Port1+", "Port1-", "Port2+", "Port2-", NULL };
        nodeListingForElement(element, pins, data);
        data.out << " " << replaceSpecialCharacters(model->fullName());
        data.deviceModels.insert(model);
      }
      else if ( subtype == "txl" )
      {
        FXConverter_NodeAssignmentTable::const_iterator itA = data.nodeTable.find(FXConverter_Pin(element.name, "A"));
        FXConverter_NodeAssignmentTable::const_iterator itB = data.nodeTable.find(FXConverter_Pin(element.name, "B"));
        if ( (itA != data.nodeTable.end()) && (itB != data.nodeTable.end()) )
        {
          data.out << " " << itA->second->nodeName << " 0 " << itB->second->nodeName << " 0 " << replaceSpecialCharacters(model->fullName());
          FXString lineLength = PROPERTY_VALUE( "length", "", "" );
          if ( !lineLength.empty() )
          {
            data.out << " LEN=" << lineLength;
          }
        }
        data.deviceModels.insert(model);
      }
    #if 0
      else if ( subtype == "cpl" )
      {
        static const char* pins[] = { "NI1", "NI2", "NI3", "NI4", "NI5", "NI6", "NI7", "NI8", "GND1", "NO1", "NO2", "NO3", "NO4", "NO5", "NO6", "NO7", "NO8", "GND2", NULL };
        nodeListingForElement(element, pins, data);
        data.out << " " << replaceSpecialCharacters(model->fullName());
        FXString lineLength = PROPERTY_VALUE( "length", "", "" );
        if ( !lineLength.empty() )
        {
          data.out << " LEN=" << lineLength;
        }
      }
    #endif
      break;
    default:
      {
        for( VoltaPTProperty const & prop : element.properties )
        {
          if ( !prop.value.empty() )
          {
            data.out << " " << prop.name << "=" << prop.value;
          }
        }
      }
  }

  data.out << std::endl;
}



/// @return first model in the given model collection matching the type and model of the given 
static VoltaPTModelPtr modelForElement( VoltaPTElement const & element, id<VoltaLibrary> library)
{
  __block VoltaPTModelPtr result;
  if ( library != nil )
  {
    [library iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
      if ( group->modelType == element.type )
      {
        for( VoltaPTModelPtr model : group->models )
        {
          if ( (model->name == element.modelName) && (model->vendor == element.modelVendor) )
          {
            result = model;
            *stop = YES;
            break;
          }
        }
      }
    }];
    if ( result.get() == nullptr )
    {
      // Checking subcircuits
      [library iterateOverSubcircuitsByApplyingBlock:^(VoltaPTModelPtr subcircuitModel, BOOL* stop) {
        if ( (subcircuitModel->name == element.modelName) && (subcircuitModel->vendor == element.modelVendor) )
        {
          result = subcircuitModel;
          *stop = YES;
        }
      }];
    }
  }

  if ( result.get() == nullptr )
  {
    DebugLog(@"Could not find model with name \"%@\" and vendor \"%@\" for element \"%@\".", element.modelName.cfString(), element.modelVendor.cfString(), element.name.cfString());
    // Creating a model that is not in the library
    result = VoltaPTModelPtr( new VoltaPTModel(element.type, element.modelName, element.modelVendor) );
  }

  return result;
}


static void initializeConverterData(FXConverter_ConverterData & data, id<VoltaLibrary> library)
{
  sNodeNameNumberCounter = 1;

  for( VoltaPTElement const & element : data.schematicData->elements )
  {
    VoltaPTModelPtr model = modelForElement(element, library);
    data.elementToModelMap[element.name] = model;
  }
  
#if 0
  {
    std::cerr << std::endl << "Element To Model Mapping" << std::endl << data.elementToModelMap << std::endl;
  }
#endif
  
  for( VoltaPTConnector const & voltaConnector : data.schematicData->connectors )
  {
    data.connectors.push_back(FXConverter_Connector(voltaConnector));
  }
}


// For all elements representing electric ground, applies the ground node to all pins reachable without skipping over elements.
static void assignZeroToGroundNodes(FXConverter_ConverterData & data)
{
  for( VoltaPTElement const & currentElement : data.schematicData->elements )
  {
    FXConverter_ElementToModelMap::const_iterator it = data.elementToModelMap.find( currentElement.name );
    if ( it == data.elementToModelMap.end() )
    {
      DebugLog(@"Could not find a model for element %@", currentElement.name.cfString());
    }
    else
    {
      VoltaPTModelPtr model = it->second;
      if ( model->type == VMT_Ground )
      {
        for( VoltaPTPin const & currentPin : model->pins )
        {
          FXConverter_Pin const converterPin( currentElement.name, currentPin.name );
          for( FXConverter_Connector & converterConnector : data.connectors )
          {
            if ( converterConnector.isConnectedToPin( converterPin ) )
            {
              FXConverter_NodePtr groundNode( new FXConverter_Node(0, "0") );
              applyNodeToConnector( groundNode, converterConnector, data );
            }
          }
        }
      }
    }
  }
}


// For all node elements not assigned to ground create a new node number and assign to all pins reachable from the node.
static void assignNumbersToNonGroundNodes(FXConverter_ConverterData & data)
{
  int32_t nodeCounter = 1; // Note: Node 0 is reserved for ground.

  for( VoltaPTElement const & currentElement : data.schematicData->elements )
  {
    FXConverter_ElementToModelMap::const_iterator it = data.elementToModelMap.find( currentElement.name );
    if ( it == data.elementToModelMap.end() )
    {
      DebugLog(@"Could not find model for element %@", currentElement.name.cfString());
      continue;
    }
    VoltaPTModelPtr model = it->second;
    if ( model->type == VMT_Node )
    {
      FXConverter_NodePtr newNode( new FXConverter_Node(nodeCounter) );
      bool newNodeWasUsed = false;
      // Continue only if none of the pins are assigned to a node yet.
      for( VoltaPTPin const & currentPin : model->pins )
      {
        FXConverter_Pin const converterPin( currentElement.name, currentPin.name );
        if ( data.nodeTable.find( converterPin ) != data.nodeTable.end() )
        {
          break;
        }
        for( FXConverter_Connector & converterConnector : data.connectors )
        {
          if ( converterConnector.isConnectedToPin( converterPin ) )
          {
            applyNodeToConnector( newNode, converterConnector, data );
            newNodeWasUsed = true;
            break; // a pin can be connected to only one connector
          }
        }
      }
      if ( newNodeWasUsed )
      {
        if ( newNode->nodeName.empty() )
        {
          // No named node was encountered. Therefore this node needs its own unique name.
          FXIssue(80);
          newNode->nodeName = createUniqueNodeName(data.elementToModelMap);
        }
        nodeCounter++;
      }
    }
  }

  // All connectors that have not been traversed yet represent direct connections
  // between elements that are neither ground nor electrically transparent.
  for( FXConverter_Connector & connector : data.connectors )
  {
    createNodeForConnector( connector, nodeCounter, data );
  }
}


static void buildNodeAssignmentTable(FXConverter_ConverterData & data)
{
  assignZeroToGroundNodes(data);
  assignNumbersToNonGroundNodes(data);

#if 0 && VOLTA_DEBUG
  {
    std::cerr << std::endl << "Node Assignment Table" << std::endl << data.nodeTable << std::endl;
  }
#endif
}


static void processElements(FXConverter_ConverterData & data)
{
  for( VoltaPTElement const & currentElement : data.schematicData->elements )
  {
    processElement( currentElement, data );
  }
  processMeterElements(data);
}


static void appendDeviceModels(FXConverter_ConverterData & data)
{
  for( VoltaPTModelPtr deviceModel : data.deviceModels )
  {
    if ( deviceModel->type == VMT_SUBCKT )
    {
      for( VoltaPTMetaDataItem const & metaDataItem : deviceModel->metaData )
      {
        if ( metaDataItem.first == FXVolta_SubcircuitNetlist )
        {
          data.out << metaDataItem.second; // Subcircuit netlists should already have a newline at the end.
          break;
        }
      }
    }
    else
    {
      FXString const modelTypeString = FXVoltaCircuitDomainAgent::netlistModelTypeStringForModel(deviceModel);
      data.out << ".MODEL " << deviceModel->fullName() << " " << modelTypeString;
    #if 0
      data.out << " (";
    #endif
      streamNonEmptyProperties(data.out, deviceModel->properties);
    #if 0
      data.out << " )";
    #endif
      data.out << std::endl;
    }
  }
}


static void appendAnalysisCommands(FXConverter_ConverterData & data)
{
  if ( !data.subcircuitData->enabled )
  {
    for(FXString const & command : data.commands)
    {
      data.out << command << std::endl;
    }
  }
}


static void appendCircuitOptions(FXConverter_ConverterData & data)
{
  if ( !data.subcircuitData->enabled && !data.commands.empty() )
  {
    data.out << ".OPTIONS nopage noacct keepopinfo";
    for( VoltaPTProperty const & property : data.schematicData->properties )
    {
      if ( !property.value.empty() )
      {
        data.out << " " << property.name << "=" << property.value;
      }
    }
    data.out << std::endl;
  }
}


static void openNetlist(FXConverter_ConverterData & data)
{
  if ( data.subcircuitData->enabled )
  {
    data.out << "*" << std::endl; // because the syntax highlighter interprets the first line of a netlist as a comment
    if ( data.subcircuitData->name.empty() )
    {
      data.errors.push_back(FXString("Subcircuit name is missing.").localize("ConversionErrors"));
    }
    data.out << ".SUBCKT " << replaceSpecialCharacters(data.subcircuitData->fullName());
    for( VoltaPTPin const & pin : data.subcircuitData->pins )
    {
      FXString& nodeName = data.subcircuitData->externals[pin.name];
      if ( !nodeName.empty() )
      {
        data.out << " " << nodeName;
      }
    }
    data.out << std::endl;
  }
  else
  {
    data.out << [[[NSDate date] description] cStringUsingEncoding:NSASCIIStringEncoding] << std::endl;
  }
}


static void closeNetlist(FXConverter_ConverterData & data)
{
  if ( data.subcircuitData->enabled )
  {
    data.out << ".ENDS " << data.subcircuitData->fullName() << std::endl;
  }
  else
  {
    data.out << ".END" << std::endl;
  }
}


static void collectElementsReachableViaElement(FXString const & startElementName, std::set<FXString> & collectedElementNames, FXConverter_ConverterData & data)
{
  VoltaPTModelPtr model = data.elementToModelMap[startElementName];
  if ( (model->type != VMT_Ground)
      && (model->type != VMT_Node)
      && (model->type != VMT_DECO) )
  {
    collectedElementNames.insert(startElementName);
  }
  for ( FXConverter_Connector & connector : data.connectors)
  {
    if ( !connector.traversed )
    {
      if ( (connector.startPin.elementName == startElementName)
        || (connector.endPin.elementName == startElementName) )
      {
        connector.traversed = true;
        FXString const otherElementName = (connector.startPin.elementName == startElementName) ? connector.endPin.elementName : connector.startPin.elementName;
        collectElementsReachableViaElement(otherElementName, collectedElementNames, data);
      }
    }
  }
}


// Checks if all non-ground elements are reachable starting from the ground nodes.
static void checkCircuitIsGrounded(FXConverter_ConverterData & data)
{
  // Resetting the 'traversed' attribute of each connector
  for ( FXConverter_Connector & connector : data.connectors )
  {
    connector.traversed = false;
  }

  if ( !data.subcircuitData->enabled )
  {
    std::set<FXString> groundedElementNames;
    size_t numSecondaryElements = 0;
    FXConverter_ElementToModelMap::iterator it = data.elementToModelMap.begin();
    FXConverter_ElementToModelMap::const_iterator itEnd = data.elementToModelMap.end();
    for ( ; it != itEnd; ++it )
    {
      if (it->second->type == VMT_Ground)
      {
        numSecondaryElements++;
        collectElementsReachableViaElement(it->first, groundedElementNames, data);
      }
    }
    
    bool hasUngroundedElement = false;
    for ( it = data.elementToModelMap.begin(); it != itEnd; it++ )
    {
      if ( (it->second->type != VMT_Ground)
        && (it->second->type != VMT_Node)
        && (it->second->type != VMT_DECO) )
      {
        if ( groundedElementNames.find(it->first) == groundedElementNames.end() )
        {
          DebugLog(@"Element %@ not grounded", it->first.cfString());
          hasUngroundedElement = true;
          break;
        }
      }
    }
    if ( hasUngroundedElement )
    {
      data.errors.push_back(FXString("The circuit is not grounded.").localize("ConversionErrors"));
    }
  }
}


// At the moment this is not thread-safe because of sNodeNameNumberCounter.
FXSchematicToNetlistConversionResult FXSchematicToNetlistConverter::convert(
  VoltaPTSchematicPtr schematicData,
  VoltaPTSubcircuitDataPtr subcircuitData,
  id<VoltaLibrary> library )
{
  FXSchematicToNetlistConversionResult result;
  if ( (schematicData.get() != nullptr) && (subcircuitData.get() != nullptr) )
  {
    FXConverter_ConverterData data;
    data.schematicData = schematicData;
    data.subcircuitData = subcircuitData;

    initializeConverterData(data, library);
    buildNodeAssignmentTable(data);
    openNetlist(data);
    processElements(data);
    appendDeviceModels(data);
    appendAnalysisCommands(data);
    appendCircuitOptions(data);
    closeNetlist(data);

    checkCircuitIsGrounded(data);

    result.output = data.out.str();
    result.errors = data.errors;
  }
  return result;
}


FXSchematicToNetlistConversionResult FXSchematicToNetlistConverter::convert(VoltaPTSchematicPtr schematicData, id<VoltaLibrary> library)
{
  VoltaPTSubcircuitDataPtr subcircuitData( new VoltaPTSubcircuitData );
  subcircuitData->enabled = false;
  return FXSchematicToNetlistConverter::convert(schematicData, subcircuitData, library);
}

