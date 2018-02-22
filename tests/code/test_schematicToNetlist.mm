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

#import <SenTestingKit/SenTestingKit.h>
#import "FXSchematicToNetlistConverter.h"
#import "FXVoltaLibrary.h"
#import "FXVoltaLibraryStorage.h"


@interface test_schematicToNetlist : SenTestCase
@end


@implementation test_schematicToNetlist
{
@private
  FXVoltaLibrary* mLibrary;
}


- (id) initWithInvocation:(NSInvocation*)anInvocation
{
  self = [super initWithInvocation:anInvocation];
  mLibrary = [FXVoltaLibrary newTestLibrary];
  return self;
}


- (void) dealloc
{
  FXRelease(mLibrary)
  FXDeallocSuper
}


#pragma mark Tests


- (void) test_simple_circuit
{
  VoltaPTSchematicPtr schematicData = [self schematic1];
  FXSchematicToNetlistConversionResult result = FXSchematicToNetlistConverter::convert(schematicData, mLibrary);
  int titleLineEndPos = result.output.find("\n");
  FXUTAssert( (titleLineEndPos > 0) && (titleLineEndPos < result.output.length() - 1) );
  FXUTAssert( result.output.find("3", titleLineEndPos + 1) == -1 ); // because it's overriden by the ground node
  FXUTAssert( result.output.find("R1 0 1 1k" ) > 0 );
  FXUTAssert( result.output.find("L1 1 2 1m" ) > 0 );
  FXUTAssert( result.output.find("C1 2 0 1m" ) > 0 );
}


- (void) test_prefixing_model_name_with_vendor_string
{
  VoltaPTSchematicPtr schematicData = [self schematic2];

  VoltaPTModelPtr defaultDiodeModel = [mLibrary defaultModelForType:VMT_D];
  FXUTAssert(defaultDiodeModel.get() != nullptr);
  if ( defaultDiodeModel.get() != nullptr )
  {
    VoltaPTModelPtr diodeModel = [mLibrary modelForType:VMT_D name:"SomeDiode" vendor:"fish.robo.test"];
    if ( diodeModel.get() == nullptr )
    {
      VoltaPTModelPtr templateDiodeModel( new VoltaPTModel );
      *templateDiodeModel = *defaultDiodeModel;
      templateDiodeModel->name = "SomeDiode";
      templateDiodeModel->vendor = "fish.robo.test";
      diodeModel = [mLibrary createModelFromTemplate:templateDiodeModel];
    }
    schematicData->elements.insert( VoltaPTElement("D1", diodeModel) );
    FXSchematicToNetlistConversionResult result = FXSchematicToNetlistConverter::convert(schematicData, mLibrary);
    NSLog(@"%@", result.output.cfString());
    FXUTAssert(result.output.find("D1 0 2 fish.robo.test.SomeDiode") > 0);
    FXUTAssert(result.output.find(".MODEL fish.robo.test.SomeDiode D") > 0);
  }
}


- (void) test_check_all_elements_grounded
{
  VoltaPTSchematicPtr schematic = [self schematic1];
  FXSchematicToNetlistConversionResult result = FXSchematicToNetlistConverter::convert(schematic, mLibrary);
  FXUTAssert(result.errors.empty());
  {
    std::set<VoltaPTElement>::const_iterator it = schematic->elements.begin();
    std::set<VoltaPTElement>::const_iterator itEnd = schematic->elements.end();
    for ( ; it != itEnd; it++ )
    {
      if ( it->type == VMT_Ground )
      {
        schematic->elements.erase(it);
        break;
      }
    }
  }
  result = FXSchematicToNetlistConverter::convert(schematic, mLibrary);
  FXUTAssertEqual(result.errors.size(), (size_t)1);
}


- (void) test_merging_duplicate_analysis_commands
{
  VoltaPTSchematicPtr schematic = [self schematic3];

  VoltaPTElement* firstVoltmeter = NULL;
  VoltaPTElement* secondVoltmeter = NULL;
  std::set<VoltaPTElement> & elements = schematic->elements;

  for ( std::set<VoltaPTElement>::iterator it = elements.begin(); it != elements.end(); it++ )
  {
    VoltaPTElement const & element = *it;
    if ( (element.type == VMT_METER) && (element.modelName == "VoltmeterAC") )
    {
      if ( firstVoltmeter == NULL )
      {
        firstVoltmeter = const_cast<VoltaPTElement*>(&element);
      }
      else
      {
        FXUTAssert(secondVoltmeter == NULL);
        secondVoltmeter = const_cast<VoltaPTElement*>(&element);
      }
    }
  }
  FXUTAssert(firstVoltmeter != NULL);
  FXUTAssert(secondVoltmeter != NULL);

  FXSchematicToNetlistConversionResult result = FXSchematicToNetlistConverter::convert(schematic, mLibrary);
  FXUTAssert(result.errors.empty());

  // Verifying that there are two separate .AC commands because the voltmeter parameters are different.
  {
    bool foundFirstAnalysisCommand = false;
    bool foundSecondAnalysisCommand = false;
    bool foundPrintStatement = false;
    FXStringVector const & netlistLines = result.output.getLines();
    FXString param_numAnalysisPoints, param_startFrequency, param_stopFrequency;
    for ( FXString const & line : netlistLines )
    {
      if ( line.startsWith(".AC ") )
      {
        FXStringVector const & commandTokens = line.tokenize();
        FXUTAssertEqual(commandTokens.size(), (size_t)5);
        if ( foundFirstAnalysisCommand )
        {
          foundSecondAnalysisCommand = true;
          FXUTAssert((commandTokens.at(2) != param_numAnalysisPoints)
            || (commandTokens.at(3) != param_startFrequency)
            || (commandTokens.at(4) != param_stopFrequency));
        }
        else
        {
          param_numAnalysisPoints = commandTokens.at(2);
          param_startFrequency = commandTokens.at(3);
          param_stopFrequency = commandTokens.at(4);
        }
        foundFirstAnalysisCommand = true;
      }
      else if ( line.startsWith(".PRINT") )
      {
        FXUTAssert(!foundPrintStatement); // There can be only one .PRINT line per analysis type.
        foundPrintStatement = true;
      }
    }
    FXUTAssert(foundSecondAnalysisCommand);
  }

  secondVoltmeter->properties = firstVoltmeter->properties;
  result = FXSchematicToNetlistConverter::convert(schematic, mLibrary);
  FXUTAssert(result.errors.empty());

  // Verifying that there is now only a single .AC command because the simulation parameters are the same.
  {
    bool foundAnalysisCommand = false;
    bool foundAnotherAnalysisCommand = false;
    FXStringVector const & netlistLines = result.output.getLines();
    FXString param_numAnalysisPoints, param_startFrequency, param_stopFrequency;
    for ( FXString const & line : netlistLines )
    {
      if ( line.startsWith(".AC ") )
      {
        FXStringVector const & commandTokens = line.tokenize();
        FXUTAssertEqual(commandTokens.size(), (size_t)5);
        if ( foundAnalysisCommand )
        {
          foundAnotherAnalysisCommand = true;
          FXUTAssert((commandTokens.at(2) != param_numAnalysisPoints)
                     || (commandTokens.at(3) != param_startFrequency)
                     || (commandTokens.at(4) != param_stopFrequency));
        }
        else
        {
          param_numAnalysisPoints = commandTokens.at(2);
          param_startFrequency = commandTokens.at(3);
          param_stopFrequency = commandTokens.at(4);
        }
        foundAnalysisCommand = true;
      }
    }
    FXUTAssert(foundAnalysisCommand);
    FXUTAssert(!foundAnotherAnalysisCommand);

  }
}


#pragma mark Private


// Using Unicode characters for character-based graphics. See http://wikipedia.org/wiki/List_of_Unicode_characters
// Especially http://wikipedia.org/wiki/Box-drawing_character and http://wikipedia.org/wiki/Code_page_437


- (VoltaPTSchematicPtr) schematic1
{
  /*              1
     ┌────░░░░────♦───████───♦ 2
     │     R1          L1    │
     │                      ─┴─
     │                      ─┬─ C1
     │                       │
     └───────────────────────♦ 3
                             │
                            ─┴─
                             ⎺
  */
  VoltaPTSchematicPtr schematicData( new VoltaPTSchematic );
  schematicData->title = "TestCircuit";

  VoltaPTElement element1( "R1", [mLibrary defaultModelForType:VMT_R] );
  element1.properties.push_back(VoltaPTProperty("resistance", "1k"));
  schematicData->elements.insert(element1);

  VoltaPTElement element2( "L1", [mLibrary defaultModelForType:VMT_L] );
  element2.properties.push_back(VoltaPTProperty("inductance", "1m"));
  schematicData->elements.insert(element2);

  VoltaPTElement element3( "C1", [mLibrary defaultModelForType:VMT_C] );
  element3.properties.push_back(VoltaPTProperty("capacitance", "1m"));
  schematicData->elements.insert(element3);

  VoltaPTModelPtr defaultModel_Node = [mLibrary defaultModelForType:VMT_Node];
  schematicData->elements.insert(VoltaPTElement( "1", defaultModel_Node ));
  schematicData->elements.insert(VoltaPTElement( "2", defaultModel_Node ));
  schematicData->elements.insert(VoltaPTElement( "3", defaultModel_Node ));
  schematicData->elements.insert(VoltaPTElement( "GND", [mLibrary defaultModelForType:VMT_Ground] ));

  schematicData->connectors.insert(VoltaPTConnector("R1", "A", "3", "West"));
  schematicData->connectors.insert(VoltaPTConnector("R1", "B", "1", "West"));
  schematicData->connectors.insert(VoltaPTConnector("L1", "A", "1", "East"));
  schematicData->connectors.insert(VoltaPTConnector("L1", "B", "2", "West"));
  schematicData->connectors.insert(VoltaPTConnector("C1", "A", "2", "South"));
  schematicData->connectors.insert(VoltaPTConnector("C1", "B", "3", "North"));
  schematicData->connectors.insert(VoltaPTConnector("GND", "Ground", "3", "South"));

  return schematicData;
}


- (VoltaPTSchematicPtr) schematic2
{
  /*
            R1
    1 ♦────░░░░───♦ 2
      │           │
      │    D1     │
      ├─────▶├────┘
      │
     ─┴─
      ⎺
  */
  VoltaPTSchematicPtr schematicData( new VoltaPTSchematic );

  VoltaPTElement resistor( "R1", [mLibrary defaultModelForType:VMT_R] );
  resistor.properties.push_back(VoltaPTProperty("resistance", "1k"));
  schematicData->elements.insert(resistor);

  schematicData->elements.insert(VoltaPTElement( "1", [mLibrary defaultModelForType:VMT_Node] ));
  schematicData->elements.insert(VoltaPTElement( "2", [mLibrary defaultModelForType:VMT_Node] ));
  schematicData->elements.insert(VoltaPTElement( "GND", [mLibrary defaultModelForType:VMT_Ground] ));

  schematicData->connectors.insert(VoltaPTConnector("D1", "Anode", "1", "West"));
  schematicData->connectors.insert(VoltaPTConnector("D1", "Cathode", "2", "West"));
  schematicData->connectors.insert(VoltaPTConnector("R1", "A", "1", "East"));
  schematicData->connectors.insert(VoltaPTConnector("R1", "B", "2", "East"));
  schematicData->connectors.insert(VoltaPTConnector("GND", "Ground", "1", "South"));

  return schematicData;
}


- (VoltaPTSchematicPtr) schematic3
{
  /*               ____
                ┌-❰ AC │ MT1
                │  ⎺⎺⎺⎺
    1           │           3     ____
    ♦────░░░░───♦───████────♦────❰ AC │ MT2
    │     R1    2    L1     │     ⎺⎺⎺⎺
    ┴                       │
  ⎛ A ⎞                    ─┴─ C1
  ⎝ C ⎠ V1                 ─┬─
    ┬                       │
    │                       │
   ─┴─                     ─┴─
    ⎺                       ⎺
  */

  VoltaPTSchematicPtr schematicData( new VoltaPTSchematic );

  schematicData->elements.insert(VoltaPTElement( "1", [mLibrary defaultModelForType:VMT_Node] ));
  schematicData->elements.insert(VoltaPTElement( "2", [mLibrary defaultModelForType:VMT_Node] ));
  schematicData->elements.insert(VoltaPTElement( "3", [mLibrary defaultModelForType:VMT_Node] ));
  schematicData->elements.insert(VoltaPTElement( "GND1", [mLibrary defaultModelForType:VMT_Ground] ));
  schematicData->elements.insert(VoltaPTElement( "GND2", [mLibrary defaultModelForType:VMT_Ground] ));

  {
    VoltaPTElement resistor( "R1", [mLibrary defaultModelForType:VMT_R] );
    resistor.properties.push_back(VoltaPTProperty("resistance", "560"));
    schematicData->elements.insert(resistor);
    schematicData->connectors.insert(VoltaPTConnector("R1", "A", "1", "East"));
    schematicData->connectors.insert(VoltaPTConnector("R1", "B", "2", "West"));
  }

  {
    VoltaPTElement inductor( "L1", [mLibrary defaultModelForType:VMT_L] );
    inductor.properties.push_back(VoltaPTProperty("inductance", "1.0u"));
    schematicData->elements.insert(inductor);
    schematicData->connectors.insert(VoltaPTConnector("L1", "A", "2", "East"));
    schematicData->connectors.insert(VoltaPTConnector("L1", "B", "3", "West"));
  }

  {
    VoltaPTElement capacitor( "C1", [mLibrary defaultModelForType:VMT_C] );
    capacitor.properties.push_back(VoltaPTProperty("capacitance", "4.7u"));
    schematicData->elements.insert(capacitor);
    schematicData->connectors.insert(VoltaPTConnector("C1", "A", "3", "South"));
    schematicData->connectors.insert(VoltaPTConnector("C1", "B", "GND2", "Ground"));
  }

  {
    VoltaPTElement battery( "V1", [mLibrary defaultModelForType:VMT_V] );
    battery.modelName = "ACVoltage";
    battery.properties.push_back(VoltaPTProperty("magnitude", "100"));
    schematicData->elements.insert(battery);
    schematicData->connectors.insert(VoltaPTConnector("V1", "Anode", "1", "South"));
    schematicData->connectors.insert(VoltaPTConnector("V1", "Cathode", "GND1", "Ground"));
  }

  {
    VoltaPTElement meter1( "MT1", [mLibrary defaultModelForType:VMT_METER] );
    meter1.modelName = "VoltmeterAC";
    meter1.properties.push_back(VoltaPTProperty("# points", "1000"));
    meter1.properties.push_back(VoltaPTProperty("start frequency", "10"));
    meter1.properties.push_back(VoltaPTProperty("stop frequency", "10000"));
    schematicData->elements.insert(meter1);
    schematicData->connectors.insert(VoltaPTConnector("MT1", "Anode", "2", "North"));
  }

  {
    VoltaPTElement meter2( "MT2", [mLibrary defaultModelForType:VMT_METER] );
    meter2.modelName = "VoltmeterAC";
    meter2.properties.push_back(VoltaPTProperty("# points", "500"));
    meter2.properties.push_back(VoltaPTProperty("start frequency", "1"));
    meter2.properties.push_back(VoltaPTProperty("stop frequency", "10000"));
    schematicData->elements.insert(meter2);
    schematicData->connectors.insert(VoltaPTConnector("MT2", "Anode", "3", "East"));
  }

  return schematicData;
}



@end
