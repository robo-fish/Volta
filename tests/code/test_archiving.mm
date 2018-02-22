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
#import "FXVoltaArchiver.h"
#import "FXVoltaLibraryData.h"
#include <iostream>

@interface test_archiving : SenTestCase
@end


@implementation test_archiving
{
@private
  FXVoltaLibraryData mLibrary;
}


- (void) test_converting_special_characters
{
  VoltaPTModelPtr dummyModel( new VoltaPTModel );
  dummyModel->name = "Have a \"great\" day!";
  dummyModel->vendor = "My \n Company";
  dummyModel->type = VMT_R;

  VoltaPTLibraryPtr dummyLibrary( new VoltaPTLibrary );
  dummyLibrary->title = "Dummy";
  dummyLibrary->modelGroup = VoltaPTModelGroupPtr( new VoltaPTModelGroup );
  dummyLibrary->modelGroup->models.push_back(dummyModel);

  NSString* archivedLibrary = [FXVoltaArchiver archiveLibrary:dummyLibrary];
  NSUInteger const archivedLibraryLength = [archivedLibrary length];

  NSRange const firstQuoteRange = [archivedLibrary rangeOfString:@"{FX_quote}"];
  FXUTAssert( firstQuoteRange.location != NSNotFound );
  
  NSUInteger nextSearchStartLocation = firstQuoteRange.location + firstQuoteRange.length + 1;
  NSRange const secondQuoteRange = [archivedLibrary rangeOfString:@"{FX_quote}" options:0 range:NSMakeRange(nextSearchStartLocation, archivedLibraryLength - nextSearchStartLocation)];
  FXUTAssert( secondQuoteRange.location != NSNotFound );

  nextSearchStartLocation = secondQuoteRange.location + secondQuoteRange.length + 1;
  NSRange const otherQuoteRange = [archivedLibrary rangeOfString:@"{FX_quote}" options:0 range:NSMakeRange(nextSearchStartLocation, archivedLibraryLength - nextSearchStartLocation)];
  FXUTAssert( otherQuoteRange.location == NSNotFound );

  NSRange const newlineRange = [archivedLibrary rangeOfString:@"{FX_newline}"];
  FXUTAssert( newlineRange.location != NSNotFound );
  nextSearchStartLocation = newlineRange.location + newlineRange.length + 1;
  FXUTAssert( [archivedLibrary rangeOfString:@"{FX_newline}" options:0 range:NSMakeRange(nextSearchStartLocation, archivedLibraryLength - nextSearchStartLocation)].location == NSNotFound );
  
  VoltaPTLibraryPtr unarchivedLibrary = [FXVoltaArchiver unarchiveLibraryFromString:archivedLibrary formatUpgradedWhileUnarchiving:nil error:nil];
  FXUTAssert( unarchivedLibrary.get() != nullptr );
  FXUTAssert( unarchivedLibrary->modelGroup->models.size() == 1 );
  VoltaPTModelPtr model = unarchivedLibrary->modelGroup->models.front();
  FXUTAssert( model->name == "Have a \"great\" day!" );
  FXUTAssert( model->vendor == "My \n Company" );
}


static NSString* libraryString1 = 
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"    
    "<volta version=\"2\" xmlns=\"http://kulfx.com/volta\">"
      "<library title=\"TestLib\">"
        "<model type=\"R\" name=\"Resistor (IEC)\" >"
          "<shape width=\"42\" height=\"12\">"
              "<path d=\"M -21 0 h 8 m 26 0 h 8\"/>"
              "<path d=\"M -13 -6 h 26 v 12 h -26 v -12 z\"/>"
          "</shape>"
          "<pin name=\"A\" x=\"-21\" y=\"-5\"/>"
          "<pin name=\"B\" x=\"21\" y=\"0\"/>"
          "<p n=\"resistance\" v=\"1k\" />"
        "</model>"
      "</library>"
    "</volta>";


- (void) test_unarchiving_pure_library
{
  VoltaPTLibraryPtr library = [FXVoltaArchiver unarchiveLibraryFromString:libraryString1 formatUpgradedWhileUnarchiving:nil error:nil];
  FXUTAssert( library.get() != nullptr );
  FXUTAssert( library->modelGroup->models.size() == 1 );
  VoltaPTModelPtr model = library->modelGroup->models.front();
  FXUTAssert( model->name == "Resistor (IEC)" );
  FXUTAssert( model->type == VMT_R );
  FXUTAssert( model->shape.paths.size() == 2 );
  FXUTAssert( model->shape.paths.front().pathData == "M -21 0 h 8 m 26 0 h 8" );
  
  FXUTAssert( model->pins.size() == 2 );
  FXUTAssert( model->pins.front().name == "A" );
  FXUTAssert( model->pins.front().posX == -21.0f );
  FXUTAssert( model->pins.front().posY == -5.0f );
  FXUTAssert( model->pins.back().name == "B" );
  
  FXUTAssert( model->properties.size() == 1 );
  FXUTAssert( model->properties.front().name == "resistance" );
  FXUTAssert( model->properties.front().value == "1k" );
}


static NSString* circuitString1 =
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"    
    "<volta xmlns=\"http://kulfx.com/volta\" version=\"2\">"
      "<circuit title=\"test circuit 1\">"
        "<schematic>"
            "<element name=\"R1\" type=\"R\" x=\"100\" y=\"66\">"
              "<p n=\"model\" v=\"Resistor\" />"
              "<p n=\"resistance\" v=\"3\" />"
            "</element>"
            "<element name=\"R2\" type=\"R\" x=\"150\" y=\"100\" rotation=\"90\">"
              "<p n=\"model\" v=\"Resistor\" />"
              "<p n=\"resistance\" v=\"5\" />"
            "</element>"
            "<connector start=\"R1\" startPin=\"B\" end=\"R2\" endPin=\"A\">"
                "<joint x=\"125\" y=\"75\"/>"
            "</connector>"
        "</schematic>"
      "</circuit>"
    "</volta>";


- (void) test_unarchiving_pure_circuit
{
  VoltaPTCircuitPtr circuit = [FXVoltaArchiver unarchiveCircuitFromString:circuitString1 formatUpgradedWhileUnarchiving:nil error:nil];
  FXUTAssert( circuit.get() != nullptr );
  FXUTAssert( circuit->title == "test circuit 1" );
  FXUTAssert( circuit->schematicData->elements.size() == 2 );
  FXUTAssert( circuit->schematicData->connectors.size() == 1 );
    
  BOOL validatedR1 = NO;
  BOOL validatedR2 = NO;
  for( VoltaPTElement const & element : circuit->schematicData->elements )
  {
    if ( element.name == "R1" )
    {
      validatedR1 = YES;
      FXUTAssert( element.posX == 100 );
      FXUTAssert( element.posY == 66 );
    }
    else if ( element.name == "R2" )
    {
      validatedR2 = YES;
      FXUTAssert( element.posX == 150 );
      FXUTAssert( element.posY == 100 );
    }
  }
  FXUTAssert( validatedR1 );
  FXUTAssert( validatedR2 );

  BOOL validatedConnector = NO;
  for( VoltaPTConnector const & connector : circuit->schematicData->connectors )
  {
    if ( connector.startElementName == "R1" )
    {
      FXUTAssert( connector.endElementName == "R2" );
      FXUTAssert( connector.joints.size() == 1 );
      FXUTAssert( connector.joints.front().first == 125 );
      FXUTAssert( connector.joints.front().second == 75 );
      validatedConnector = YES;
    }
  }
  FXUTAssert( validatedConnector );
}


- (void) test_archiving_and_unarchiving_subcircuit
{
  VoltaPTCircuitPtr circuit( new VoltaPTCircuit );
  circuit->title = "Some name";
  VoltaPTSubcircuitDataPtr subcircuit( new VoltaPTSubcircuitData );
  subcircuit->vendor = "KulFX";
  subcircuit->labelPosition = VoltaPTLabelPosition::Center;
  subcircuit->shape.width = 32.0f;
  subcircuit->shape.height = 24.0f;
  subcircuit->shape.paths.push_back(VoltaPTPath("M 5 -10 v 10 h -10 v -10 h 10 z"));
  subcircuit->shape.circles.push_back(VoltaPTCircle(-4, 2, 20));
  subcircuit->pins = { VoltaPTPin("Pin1", 4, 6), VoltaPTPin("Pin2", 7, 9) };
  subcircuit->externals["Pin1"] = "No\"de1";
  subcircuit->externals["Pin2"] = "blabla";
  VoltaPTSchematicPtr schematic( new VoltaPTSchematic );
  schematic->title = "Test Schematic";
  VoltaPTElement element1("R1", VMT_R, "Resistor", "");
  VoltaPTElement element2("C1", VMT_C, "Capacitor", "");
  VoltaPTElement element3("Node1", VMT_Node, "Node", "");
  VoltaPTElement element4("blabla", VMT_Node, "Node", "");
  schematic->elements.insert(element1);
  schematic->elements.insert(element2);
  schematic->elements.insert(element3);
  schematic->elements.insert(element4);
  VoltaPTConnector connector1("R1", "A", "Node1", "North");
  VoltaPTConnector connector2("C1", "A", "Node1", "South");
  VoltaPTConnector connector3("R1", "B", "blabla", "North");
  VoltaPTConnector connector4("C1", "B", "blabla", "South");
  schematic->connectors.insert(connector1);
  schematic->connectors.insert(connector2);
  schematic->connectors.insert(connector3);
  schematic->connectors.insert(connector4);
  circuit->schematicData = schematic;
  circuit->subcircuitData = subcircuit;
  circuit->metaData.push_back( { "Creator", "FX \"Unit\" Test" } );

  NSString* archivedCircuit = [FXVoltaArchiver archiveCircuit:circuit];
#if 0
  NSLog(@"%@", archivedCircuit);
#endif

  VoltaPTCircuitPtr unarchivedCircuit = [FXVoltaArchiver unarchiveCircuitFromString:archivedCircuit formatUpgradedWhileUnarchiving:nil error:nil];
  FXUTAssert( unarchivedCircuit.get() != nullptr );
  FXUTAssert( unarchivedCircuit->title == "Test Schematic" );
  FXUTAssert( unarchivedCircuit->subcircuitData.get() != nullptr );
  FXUTAssert( unarchivedCircuit->subcircuitData->vendor == "KulFX" );
  FXUTAssert( unarchivedCircuit->subcircuitData->labelPosition == VoltaPTLabelPosition::Center );
  FXUTAssertEqual( unarchivedCircuit->subcircuitData->shape.paths.size(), (size_t)1 );
  FXUTAssertEqual( unarchivedCircuit->subcircuitData->pins.size(), (size_t)2 );
  FXUTAssert( unarchivedCircuit->subcircuitData->pins.front().name == "Pin1" );
  FXUTAssert( unarchivedCircuit->subcircuitData->pins.back().name == "Pin2" );
  FXUTAssertEqual( unarchivedCircuit->subcircuitData->externals.size(), (size_t)2 );
  FXUTAssert( unarchivedCircuit->subcircuitData->externals.begin()->first == "Pin1" );
  FXUTAssert( unarchivedCircuit->subcircuitData->externals.begin()->second == "No\"de1" );
  FXUTAssert( unarchivedCircuit->subcircuitData->externals["Pin2"] == "blabla" );
  FXUTAssertEqual( unarchivedCircuit->schematicData->elements.size(), (size_t)4 );
  FXUTAssertEqual( unarchivedCircuit->schematicData->connectors.size(), (size_t)4 );
  FXUTAssert( unarchivedCircuit->metaData.front().first == "Creator" );
  FXUTAssert( unarchivedCircuit->metaData.front().second == "FX \"Unit\" Test" );
}


static NSString* libraryString_sameModelFromTwoVendors = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"    
  "<volta version=\"2\" xmlns=\"http://kulfx.com/volta\">"
    "<library title=\"TestLibOld\">"
      "<model type=\"R\" name=\"SuperResistor\" vendor=\"\" >"
      "<pin name=\"B\" x=\"21\" y=\"0\"/>"
      "</model>"
      "<model type=\"R\" name=\"SuperResistor\" vendor=\"fish.robo\" >"
      "<pin name=\"B\" x=\"21\" y=\"0\"/>"
      "</model>"
    "</library>"
  "</volta>";


- (void) test_same_name_different_vendors
{
  mLibrary.clearAll();
  mLibrary.addModelGroup( VoltaPTModelGroupPtr( new VoltaPTModelGroup("Resistors", VMT_R) ) );

  VoltaPTLibraryPtr unarchivedLibrary = [FXVoltaArchiver unarchiveLibraryFromString:libraryString_sameModelFromTwoVendors formatUpgradedWhileUnarchiving:nil error:nil];
  FXUTAssert( unarchivedLibrary.get() != nullptr );
  FXUTAssert( unarchivedLibrary->modelGroup->models.size() == 2 );

  __block VoltaPTModelGroupPtr resistorsModelGroup;
  mLibrary.iterateModelGroups( ^(VoltaPTModelGroupPtr group, BOOL* stop) {
    
    if ( group->modelType == VMT_R )
    {
      resistorsModelGroup = group;
      *stop = YES;
    }
  });
  FXUTAssert( resistorsModelGroup.get() != nullptr );
  size_t const kOriginalNumberOfResistorModels = resistorsModelGroup->models.size();

  mLibrary.addLibraryModels(unarchivedLibrary, "local", false);

  FXUTAssert( resistorsModelGroup->models.size() == (kOriginalNumberOfResistorModels + 2) );
}


static NSString* libraryString_oldModel = 
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"    
  "<volta version=\"2\" xmlns=\"http://kulfx.com/volta\">"
    "<library title=\"TestLibOld\">"
      "<model type=\"R\" name=\"VersionedResistor\" vendor=\"UnitTest\" >"
        "<pin name=\"B\" x=\"21\" y=\"0\"/>"
      "</model>"
    "</library>"
  "</volta>";

static NSString* libraryString_newModel = 
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"    
  "<volta version=\"2\" xmlns=\"http://kulfx.com/volta\">"
    "<library title=\"TestLibNew\">"
      "<model type=\"R\" name=\"VersionedResistor\" vendor=\"UnitTest\" revision=\"3\" >"
        "<pin name=\"B\" x=\"21\" y=\"0\"/>"
      "</model>"
    "</library>"
  "</volta>";

- (void) test_replacing_an_existing_model_with_a_newer_revision
{
  mLibrary.clearAll();
  mLibrary.addModelGroup( VoltaPTModelGroupPtr( new VoltaPTModelGroup("Resistors", VMT_R) ) );

  VoltaPTLibraryPtr oldLibrary = [FXVoltaArchiver unarchiveLibraryFromString:libraryString_oldModel formatUpgradedWhileUnarchiving:nil error:nil];
  FXUTAssert( oldLibrary.get() != nullptr );
  FXUTAssertEqual( oldLibrary->modelGroup->models.size(), (size_t)1 );
  VoltaPTModelPtr oldModel = *(oldLibrary->modelGroup->models.begin());
  FXUTAssertEqual( oldModel->type, VMT_R );
  FXUTAssertEqual( oldModel->revision, (uint64_t)1 );

  VoltaPTLibraryPtr newLibrary = [FXVoltaArchiver unarchiveLibraryFromString:libraryString_newModel formatUpgradedWhileUnarchiving:nil error:nil];
  FXUTAssert( newLibrary.get() != nullptr );
  FXUTAssertEqual( newLibrary->modelGroup->models.size(), (size_t)1 );
  VoltaPTModelPtr newModel = *(newLibrary->modelGroup->models.begin());
  FXUTAssertEqual( newModel->type, VMT_R );
  FXUTAssertEqual( newModel->revision, (uint64_t)3 );

  __block VoltaPTModelGroupPtr resistorsModelGroup;
  mLibrary.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL* stop) {
    if ( group->modelType == VMT_R )
    {
      resistorsModelGroup = group;
      *stop = YES;
    }
  });
  FXUTAssert( resistorsModelGroup.get() != nullptr );
  FXUTAssertEqual( resistorsModelGroup->models.size(), (size_t)0 );

  mLibrary.addLibraryModels(oldLibrary, "local", false);
  FXUTAssertEqual( resistorsModelGroup->models.size(), (size_t)1 );
  uint64_t revision = 0;
  for( VoltaPTModelPtr model : resistorsModelGroup->models )
  {
    if ( (model->name == "VersionedResistor") && (model->vendor == "UnitTest") )
    {
      revision = model->revision;
      break;
    }
  }
  FXUTAssertEqual(revision, (uint64_t)1);

  mLibrary.addLibraryModels(newLibrary, "local", false);
  FXUTAssertEqual( resistorsModelGroup->models.size(), (size_t)1 );
  for( VoltaPTModelPtr model : resistorsModelGroup->models )
  {
    if ( (model->name == "VersionedResistor") && (model->vendor == "UnitTest") )
    {
      revision = model->revision;
      break;
    }
  }
  FXUTAssertEqual(revision, (uint64_t)3);
}


static NSString* invalid_input =
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<blabla version=\"1\" xmlns=\"http://kulfx.com/volta\">"
  "</blabla>";

- (void) test_errors_generated_when_archive_format_is_invalid
{
  NSError* unarchivingError = nil;
  VoltaPTLibraryPtr library = [FXVoltaArchiver unarchiveLibraryFromString:invalid_input formatUpgradedWhileUnarchiving:nil error:&unarchivingError];
  FXUTAssert( library.get() == nullptr );
  FXUTAssert( unarchivingError != nil );
}


#if 0 // Can not be tested yet because the version number must be a positive integer and version 1 is still supported
static NSString* volta_library_with_invalid_format__too_old =
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta version=\"0\" xmlns=\"http://kulfx.com/volta\">"
    "<library title=\"TestLibNew\">"
      "<invalid_element/>"
    "</library>"
  "</volta>";

- (void) test_errors_generated_when_archive_format_is_too_old
{
  NSError* unarchivingError = nil;
  VoltaPTLibraryPtr library = [FXVoltaArchiver unarchiveLibraryFromString:volta_library_with_invalid_format__too_old source:nil error:&unarchivingError];
  FXUTAssert( library.get() == nullptr );
  FXUTAssert( unarchivingError != nil );
}
#endif


static NSString* volta_library_with_invalid_format__too_new =
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta version=\"3\" xmlns=\"http://kulfx.com/volta\">"
    "<lib name=\"TestLibNew\">"
      "<model type=\"R\" name=\"VersionedResistor\" vendor=\"UnitTest\" revision=\"3\" >"
        "<pin name=\"B\" x=\"21\" y=\"0\"/>"
      "</model>"
    "</lib>"
  "</volta>";

- (void) test_errors_generated_when_archive_format_is_too_new
{
  NSError* unarchivingError = nil;
  VoltaPTLibraryPtr library = [FXVoltaArchiver unarchiveLibraryFromString:volta_library_with_invalid_format__too_new formatUpgradedWhileUnarchiving:nil error:&unarchivingError];
  FXUTAssert( library.get() == nullptr );
  FXUTAssert( unarchivingError != nil );
}


- (void) test_archiving_library_element_group
{
  VoltaPTLibraryPtr library( new VoltaPTLibrary() );
  library->elementGroup.elements.push_back( VoltaPTElement("MyCap", VMT_C, "Capacitor", "fish.robo.test") );
  NSString* archivedLibrary = [FXVoltaArchiver archiveLibrary:library];
  FXUTAssert([archivedLibrary rangeOfString:@"<element name=\"MyCap\""].location != NSNotFound);
}


NSString* archivedLibraryWithElementGroup =
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta version=\"2\" xmlns=\"http://kulfx.com/volta\">"
    "<library title=\"MyElementGroup\">"
      "<element name=\"BMos\" type=\"MOSFET\" modelName=\"N-Channel3\" modelVendor=\"fish.robo\"/>"
    "</library>"
  "</volta>";


- (void) test_unarchiving_library_element_group
{
  VoltaPTLibraryPtr library = [FXVoltaArchiver unarchiveLibraryFromString:archivedLibraryWithElementGroup formatUpgradedWhileUnarchiving:NULL error:NULL];
  FXUTAssert(library.get() != nullptr);
  FXUTAssertEqual(library->elementGroup.elements.size(), (size_t)1);
  FXUTAssert(library->elementGroup.elements.front().name == "BMos");
  FXUTAssert(library->elementGroup.elements.front().type == VMT_MOSFET);
  FXUTAssert(library->elementGroup.elements.front().modelName == "N-Channel3");
  FXUTAssert(library->elementGroup.elements.front().modelVendor == "fish.robo");
}


- (void) test_default_value_for_element_position_attributes
{
  FXUTAssertEqual([archivedLibraryWithElementGroup rangeOfString:@"x="].location, (NSUInteger)NSNotFound);
  FXUTAssertEqual([archivedLibraryWithElementGroup rangeOfString:@"y="].location, (NSUInteger)NSNotFound);
  VoltaPTLibraryPtr library = [FXVoltaArchiver unarchiveLibraryFromString:archivedLibraryWithElementGroup formatUpgradedWhileUnarchiving:NULL error:NULL];
  FXUTAssert(library.get() != nullptr);
  FXUTAssertEqual(library->elementGroup.elements.size(), (size_t)1);
  FXUTAssertEqual(library->elementGroup.elements.front().posX, 0.0f);
  FXUTAssertEqual(library->elementGroup.elements.front().posY, 0.0f);
}


@end
