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

#import <XCTest/XCTest.h>
#import <VoltaCore/VoltaPersistentTypes.h>
#import "FXXMLDocument.h"
#import "FXVoltaArchiveConverterV1To2.h"

/// Tests whether data, that was stored by older versions of the app, can still be read.
@interface test_archive_converter_v1_to_v2 : XCTestCase
@end


@implementation test_archive_converter_v1_to_v2

static FXString input_1 =
  "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
    "<volta xmlns=\"http://kulfx.com/volta\" version=\"1\">"
      "<library name=\"Test\">"
        "<model type=\"D\" name=\"TestResistor\" labelPosition=\"north\">"
          "<shape width=\"42\" height=\"12\" flipped=\"true\">"
          "<path d=\"M -21 0 h 8 m 26 0 h 8\"/>"
          "</shape>"
          "<pin name=\"A\" x=\"-21\" y=\"0\"/>"
          "<pin name=\"B\" x=\"21\" y=\"0\"/>"
        "</model>"
      "</library>"
    "</volta>";

- (void) test_convert_shape_element_flipped_attribute
{
  FXXMLDocumentPtr doc = FXXMLDocument::fromString(input_1);
  FXUTAssert(doc.get() != nullptr);
  std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> conversionResult = [FXVoltaArchiveConverterV1To2 convertRootElement:doc->getRootElement()];
  FXXMLElementPtr convertedRoot = std::get<0>(conversionResult);
  FXUTAssert(convertedRoot.get() != nullptr);
  FXXMLElementPtrVector shapeElements;
  convertedRoot->collectChildrenWithName("shape", shapeElements, true);
  for ( FXXMLElementPtr shapeElement : shapeElements )
  {
    FXUTAssert( !shapeElement->hasAttribute("flipped") );
  }
}

- (void) test_convert_name_attribute
{
  FXXMLDocumentPtr doc = FXXMLDocument::fromString(input_1);
  FXUTAssert(doc.get() != nullptr);
  FXUTAssert(doc->getRootElement()->getChildren().at(0)->getName() == "library");
  FXUTAssert(doc->getRootElement()->getChildren().at(0)->hasAttribute("name"));
  FXUTAssert(!doc->getRootElement()->getChildren().at(0)->hasAttribute("title"));
  std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> conversionResult = [FXVoltaArchiveConverterV1To2 convertRootElement:doc->getRootElement()];
  FXXMLElementPtr convertedRoot = std::get<0>(conversionResult);
  FXUTAssert(convertedRoot.get() != nullptr);
  FXUTAssert(convertedRoot->getChildren().at(0)->getName() == "library");
  FXUTAssert(convertedRoot->getChildren().at(0)->hasAttribute("title"));
  FXUTAssert(!convertedRoot->getChildren().at(0)->hasAttribute("name"));
}


static FXString labelPosition_conversion_input1 =
  "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta xmlns=\"http://kulfx.com/volta\" version=\"1\">"
    "<circuit name=\"Test\">"
      "<schematic>"
        "<element type=\"NMOS\" name=\"M1\" x=\"100\" y=\"230\" labelPosition=\"north\"/>"
        "<element type=\"NJF\" name=\"J1\" x=\"130\" y=\"330\" labelPosition=\"east\"/>"
        "<element type=\"NPN\" name=\"Q1\" x=\"140\" y=\"430\" labelPosition=\"west\"/>"
        "<element type=\"R\" name=\"R1\" x=\"150\" y=\"470\" labelPosition=\"south\"/>"
      "</schematic>"
    "</circuit>"
  "</volta>";


- (void) test_convert_element_labelPosition
{
  FXXMLDocumentPtr doc = FXXMLDocument::fromString(labelPosition_conversion_input1);
  FXUTAssert(doc.get() != nullptr);
  std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> conversionResult = [FXVoltaArchiveConverterV1To2 convertRootElement:doc->getRootElement()];
  FXXMLElementPtr convertedRoot = std::get<0>(conversionResult);
  FXUTAssert(convertedRoot.get() != nullptr);
  FXUTAssertEqual(convertedRoot->getChildren().size(), (size_t)1);
  FXXMLElementPtr circuit = convertedRoot->getChildren().at(0);
  FXUTAssert(circuit->getName() == "circuit");
  FXUTAssertEqual(circuit->getChildren().size(), (size_t)1);
  FXXMLElementPtr schematic = circuit->getChildren().at(0);
  FXUTAssert(schematic->getName() == "schematic");
  FXXMLElementPtrVector schematicElements = schematic->getChildren();
  FXUTAssertEqual(schematicElements.size(), (size_t)4);
  FXUTAssert(schematicElements.at(0)->hasAttribute("name"));
  FXUTAssert(schematicElements.at(0)->valueOfAttribute("name") == "M1");
  FXUTAssert(schematicElements.at(0)->hasAttribute("labelPosition"));
  FXUTAssert(schematicElements.at(0)->valueOfAttribute("labelPosition") == "top");
  FXUTAssert(schematicElements.at(1)->hasAttribute("name"));
  FXUTAssert(schematicElements.at(1)->valueOfAttribute("name") == "J1");
  FXUTAssert(schematicElements.at(1)->hasAttribute("labelPosition"));
  FXUTAssert(schematicElements.at(1)->valueOfAttribute("labelPosition") == "right");
  FXUTAssert(schematicElements.at(2)->hasAttribute("name"));
  FXUTAssert(schematicElements.at(2)->valueOfAttribute("name") == "Q1");
  FXUTAssert(schematicElements.at(2)->hasAttribute("labelPosition"));
  FXUTAssert(schematicElements.at(2)->valueOfAttribute("labelPosition") == "left");
  FXUTAssert(schematicElements.at(3)->hasAttribute("name"));
  FXUTAssert(schematicElements.at(3)->valueOfAttribute("name") == "R1");
  FXUTAssert(schematicElements.at(3)->hasAttribute("labelPosition"));
  FXUTAssert(schematicElements.at(3)->valueOfAttribute("labelPosition") == "bottom");
}


static FXString labelPosition_conversion_input2 =
  "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta xmlns=\"http://kulfx.com/volta\" version=\"1\">"
    "<library name=\"Test Models\">"
      "<model type=\"D\" name=\"MyDiode1\" labelPosition=\"north\" />"
      "<model type=\"NMOS\" name=\"MyMOSFET\" labelPosition=\"east\" />"
      "<model type=\"BJT\" name=\"MyBJT\" labelPosition=\"south\" />"
      "<model type=\"D\" name=\"MyDiode2\" labelPosition=\"west\" />"
    "</library>"
  "</volta>";


- (void) test_convert_model_labelPosition
{
  FXXMLDocumentPtr doc = FXXMLDocument::fromString(labelPosition_conversion_input2);
  FXUTAssert(doc.get() != nullptr);
  std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> conversionResult = [FXVoltaArchiveConverterV1To2 convertRootElement:doc->getRootElement()];
  FXXMLElementPtr convertedRoot = std::get<0>(conversionResult);
  FXUTAssert(convertedRoot.get() != nullptr);
  FXUTAssertEqual(convertedRoot->getChildren().size(), (size_t)1);
  FXXMLElementPtr library = convertedRoot->getChildren().at(0);
  FXUTAssert(library->getName() == "library");
  FXXMLElementPtrVector models = library->getChildren();
  FXUTAssertEqual(models.size(), (size_t)4);
  FXUTAssert(models.at(0)->hasAttribute("name"));
  FXUTAssert(models.at(0)->valueOfAttribute("name") == "MyDiode1");
  FXUTAssert(models.at(0)->hasAttribute("labelPosition"));
  FXUTAssert(models.at(0)->valueOfAttribute("labelPosition") == "top");
  FXUTAssert(models.at(1)->hasAttribute("name"));
  FXUTAssert(models.at(1)->valueOfAttribute("name") == "MyMOSFET");
  FXUTAssert(models.at(1)->hasAttribute("labelPosition"));
  FXUTAssert(models.at(1)->valueOfAttribute("labelPosition") == "right");
  FXUTAssert(models.at(2)->hasAttribute("name"));
  FXUTAssert(models.at(2)->valueOfAttribute("name") == "MyBJT");
  FXUTAssert(models.at(2)->hasAttribute("labelPosition"));
  FXUTAssert(models.at(2)->valueOfAttribute("labelPosition") == "bottom");
  FXUTAssert(models.at(3)->hasAttribute("name"));
  FXUTAssert(models.at(3)->valueOfAttribute("name") == "MyDiode2");
  FXUTAssert(models.at(3)->hasAttribute("labelPosition"));
  FXUTAssert(models.at(3)->valueOfAttribute("labelPosition") == "left");
}


static FXString element_type_conversion_input =
  "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta xmlns=\"http://kulfx.com/volta\" version=\"1\">"
    "<circuit name=\"Test\">"
      "<schematic>"
        "<element type=\"NPN\" name=\"Q1\" x=\"100\" y=\"230\" />"
        "<element type=\"PNP\" name=\"Q2\" x=\"130\" y=\"330\" />"
        "<element type=\"NJF\" name=\"J1\" x=\"140\" y=\"430\" />"
        "<element type=\"PJF\" name=\"J2\" x=\"150\" y=\"470\" />"
        "<element type=\"NMOS\" name=\"M1\" x=\"100\" y=\"230\" />"
        "<element type=\"PMOS\" name=\"M2\" x=\"130\" y=\"330\" />"
        "<element type=\"NMF\" name=\"Z1\" x=\"140\" y=\"430\" />"
        "<element type=\"PMF\" name=\"Z2\" x=\"150\" y=\"470\" />"
        "<element type=\"MTVDC\" name=\"MT1\" x=\"100\" y=\"230\" />"
        "<element type=\"MTVAC\" name=\"MT2\" x=\"130\" y=\"330\" />"
        "<element type=\"MTVTRAN\" name=\"MT3\" x=\"140\" y=\"430\" />"
        "<element type=\"MTAAC\" name=\"MT4\" x=\"150\" y=\"470\" />"
        "<element type=\"MTADC\" name=\"MT5\" x=\"100\" y=\"230\" />"
        "<element type=\"VSDC\" name=\"V1\" x=\"130\" y=\"330\" />"
        "<element type=\"VSAC\" name=\"V2\" x=\"140\" y=\"430\" />"
        "<element type=\"VSSIN\" name=\"V3\" x=\"150\" y=\"470\" />"
        "<element type=\"VSPLS\" name=\"V4\" x=\"100\" y=\"230\" />"
        "<element type=\"VSVC\" name=\"V5\" x=\"100\" y=\"230\" />"
        "<element type=\"VSCC\" name=\"V6\" x=\"100\" y=\"230\" />"
        "<element type=\"CSDC\" name=\"I1\" x=\"130\" y=\"330\" />"
        "<element type=\"CSAC\" name=\"I2\" x=\"140\" y=\"430\" />"
        "<element type=\"CSSIN\" name=\"I3\" x=\"150\" y=\"470\" />"
        "<element type=\"CSPLS\" name=\"I4\" x=\"100\" y=\"230\" />"
        "<element type=\"CSVC\" name=\"I5\" x=\"100\" y=\"230\" />"
        "<element type=\"CSCC\" name=\"I6\" x=\"100\" y=\"230\" />"
        "<element type=\"SWVC\" name=\"S1\" x=\"130\" y=\"330\" />"
        "<element type=\"SWCC\" name=\"W1\" x=\"140\" y=\"430\" />"
        "<element type=\"RSEM\" name=\"R1\" x=\"130\" y=\"330\" />"
        "<element type=\"CSEM\" name=\"C1\" x=\"140\" y=\"430\" />"
        "<element type=\"PSNLIN\" name=\"B1\" x=\"400\" y=\"4\" >"
          "<p n=\"expression\" v=\"v=v(2)+v(4)\"/>"
        "</element>"
        "<element type=\"PSNLIN\" name=\"B2\" x=\"400\" y=\"40\" >"
          "<p n=\"expression\" v=\"i=cos(v(2))+sin(v(4))\"/>"
        "</element>"
      "</schematic>"
    "</circuit>"
  "</volta>";


- (void) test_convert_element_type
{
  FXXMLDocumentPtr doc = FXXMLDocument::fromString(element_type_conversion_input);
  FXUTAssert(doc.get() != nullptr);
  std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> conversionResult = [FXVoltaArchiveConverterV1To2 convertRootElement:doc->getRootElement()];
  FXXMLElementPtr convertedRoot = std::get<0>(conversionResult);
  FXUTAssert(convertedRoot.get() != nullptr);
  FXUTAssertEqual(convertedRoot->getChildren().size(), (size_t)1);
  FXXMLElementPtr circuit = convertedRoot->getChildren().at(0);
  FXUTAssert(circuit->getName() == "circuit");
  FXUTAssertEqual(circuit->getChildren().size(), (size_t)1);
  FXXMLElementPtr schematic = circuit->getChildren().at(0);
  FXUTAssert(schematic->getName() == "schematic");
  FXXMLElementPtrVector schematicElements = schematic->getChildren();
  FXUTAssertEqual(schematicElements.size(), (size_t)31);
  FXUTAssert(schematicElements.at(0)->valueOfAttribute("type") == "BJT");
  FXUTAssert(schematicElements.at(1)->valueOfAttribute("type") == "BJT");
  FXUTAssert(schematicElements.at(2)->valueOfAttribute("type") == "JFET");
  FXUTAssert(schematicElements.at(3)->valueOfAttribute("type") == "JFET");
  FXUTAssert(schematicElements.at(4)->valueOfAttribute("type") == "MOSFET");
  FXUTAssert(schematicElements.at(5)->valueOfAttribute("type") == "MOSFET");
  FXUTAssert(schematicElements.at(6)->valueOfAttribute("type") == "MESFET");
  FXUTAssert(schematicElements.at(7)->valueOfAttribute("type") == "MESFET");
  FXUTAssert(schematicElements.at(8)->valueOfAttribute("type") == "METER");
  FXUTAssert(schematicElements.at(9)->valueOfAttribute("type") == "METER");
  FXUTAssert(schematicElements.at(10)->valueOfAttribute("type") == "METER");
  FXUTAssert(schematicElements.at(11)->valueOfAttribute("type") == "METER");
  FXUTAssert(schematicElements.at(12)->valueOfAttribute("type") == "METER");
  FXUTAssert(schematicElements.at(13)->valueOfAttribute("type") == "V");
  FXUTAssert(schematicElements.at(14)->valueOfAttribute("type") == "V");
  FXUTAssert(schematicElements.at(15)->valueOfAttribute("type") == "V");
  FXUTAssert(schematicElements.at(16)->valueOfAttribute("type") == "V");
  FXUTAssert(schematicElements.at(17)->valueOfAttribute("type") == "V");
  FXUTAssert(schematicElements.at(18)->valueOfAttribute("type") == "V");
  FXUTAssert(schematicElements.at(19)->valueOfAttribute("type") == "I");
  FXUTAssert(schematicElements.at(20)->valueOfAttribute("type") == "I");
  FXUTAssert(schematicElements.at(21)->valueOfAttribute("type") == "I");
  FXUTAssert(schematicElements.at(22)->valueOfAttribute("type") == "I");
  FXUTAssert(schematicElements.at(23)->valueOfAttribute("type") == "I");
  FXUTAssert(schematicElements.at(24)->valueOfAttribute("type") == "I");
  FXUTAssert(schematicElements.at(25)->valueOfAttribute("type") == "SW");
  FXUTAssert(schematicElements.at(26)->valueOfAttribute("type") == "SW");
  FXUTAssert(schematicElements.at(27)->valueOfAttribute("type") == "R");
  FXUTAssert(schematicElements.at(28)->valueOfAttribute("type") == "C");
  FXUTAssert(schematicElements.at(29)->valueOfAttribute("type") == "V");
  FXUTAssert(schematicElements.at(30)->valueOfAttribute("type") == "I");
  for ( FXXMLElementPtr const & schematicElement : schematicElements )
  {
    FXUTAssert(!schematicElement->hasAttribute("subtype"));
  }
}


static FXString model_type_conversion_input =
  "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta xmlns=\"http://kulfx.com/volta\" version=\"1\">"
    "<library name=\"Test Models\">"
      "<model type=\"NPN\" name=\"MyBJT1\" />"
      "<model type=\"PNP\" name=\"MyBJT2\" />"
      "<model type=\"NJF\" name=\"MyJFET1\" />"
      "<model type=\"PJF\" name=\"MyJFET2\" />"
      "<model type=\"NMOS\" name=\"MyMOSFET1\" />"
      "<model type=\"PMOS\" name=\"MyMOSFET2\" />"
      "<model type=\"NMF\" name=\"MyMESFET1\" />"
      "<model type=\"PMF\" name=\"MyMESFET2\" />"
      "<model type=\"MTVDC\" name=\"MyMeter1\" />"
      "<model type=\"MTVAC\" name=\"MyMeter2\" />"
      "<model type=\"MTVTRAN\" name=\"MyMeter3\" />"
      "<model type=\"MTAAC\" name=\"MyMeter4\" />"
      "<model type=\"MTADC\" name=\"MyMeter5\" />"
      "<model type=\"VSDC\" name=\"MySource1\" />"
      "<model type=\"VSAC\" name=\"MySource2\" />"
      "<model type=\"VSSIN\" name=\"MySource3\" />"
      "<model type=\"VSPLS\" name=\"MySource4\" />"
      "<model type=\"CSDC\" name=\"MySource5\" />"
      "<model type=\"CSAC\" name=\"MySource6\" />"
      "<model type=\"CSSIN\" name=\"MySource7\" />"
      "<model type=\"CSPLS\" name=\"MySource8\" />"
      "<model type=\"RSEM\" name=\"MyResistor\" />"
      "<model type=\"CSEM\" name=\"MyCapacitor\" />"
      "<model type=\"PSNLIN\" name=\"MyDependentPowerSource\" x=\"400\" y=\"4\" />"
    "</library>"
  "</volta>";


- (void) test_convert_model_type
{
  FXXMLDocumentPtr doc = FXXMLDocument::fromString(model_type_conversion_input);
  FXUTAssert(doc.get() != nullptr);
  std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> conversionResult = [FXVoltaArchiveConverterV1To2 convertRootElement:doc->getRootElement()];
  FXXMLElementPtr convertedRoot = std::get<0>(conversionResult);
  FXUTAssert(convertedRoot.get() != nullptr);
  FXUTAssertEqual(convertedRoot->getChildren().size(), (size_t)1);
  FXXMLElementPtr library = convertedRoot->getChildren().at(0);
  FXUTAssert(library->getName() == "library");
  FXXMLElementPtrVector models = library->getChildren();
  FXUTAssertEqual(models.size(), (size_t)24);
  FXUTAssert(models.at(0)->valueOfAttribute("type") == "BJT");
  FXUTAssert(models.at(0)->valueOfAttribute("subtype") == "NPN");
  FXUTAssert(models.at(1)->valueOfAttribute("type") == "BJT");
  FXUTAssert(models.at(1)->valueOfAttribute("subtype") == "PNP");
  FXUTAssert(models.at(2)->valueOfAttribute("type") == "JFET");
  FXUTAssert(models.at(2)->valueOfAttribute("subtype") == "NJF");
  FXUTAssert(models.at(3)->valueOfAttribute("type") == "JFET");
  FXUTAssert(models.at(3)->valueOfAttribute("subtype") == "PJF");
  FXUTAssert(models.at(4)->valueOfAttribute("type") == "MOSFET");
  FXUTAssert(models.at(4)->valueOfAttribute("subtype") == "NMOS");
  FXUTAssert(models.at(5)->valueOfAttribute("type") == "MOSFET");
  FXUTAssert(models.at(5)->valueOfAttribute("subtype") == "PMOS");
  FXUTAssert(models.at(6)->valueOfAttribute("type") == "MESFET");
  FXUTAssert(models.at(6)->valueOfAttribute("subtype") == "NMF");
  FXUTAssert(models.at(7)->valueOfAttribute("type") == "MESFET");
  FXUTAssert(models.at(7)->valueOfAttribute("subtype") == "PMF");
  FXUTAssert(models.at(8)->valueOfAttribute("type") == "METER");
  FXUTAssert(models.at(8)->valueOfAttribute("subtype") == "VDC");
  FXUTAssert(models.at(9)->valueOfAttribute("type") == "METER");
  FXUTAssert(models.at(9)->valueOfAttribute("subtype") == "VAC");
  FXUTAssert(models.at(10)->valueOfAttribute("type") == "METER");
  FXUTAssert(models.at(10)->valueOfAttribute("subtype") == "VTRAN");
  FXUTAssert(models.at(11)->valueOfAttribute("type") == "METER");
  FXUTAssert(models.at(11)->valueOfAttribute("subtype") == "AAC");
  FXUTAssert(models.at(12)->valueOfAttribute("type") == "METER");
  FXUTAssert(models.at(12)->valueOfAttribute("subtype") == "ADC");
  FXUTAssert(models.at(13)->valueOfAttribute("type") == "V");
  FXUTAssert(models.at(13)->valueOfAttribute("subtype") == "DC");
  FXUTAssert(models.at(14)->valueOfAttribute("type") == "V");
  FXUTAssert(models.at(14)->valueOfAttribute("subtype") == "AC");
  FXUTAssert(models.at(15)->valueOfAttribute("type") == "V");
  FXUTAssert(models.at(15)->valueOfAttribute("subtype") == "SIN");
  FXUTAssert(models.at(16)->valueOfAttribute("type") == "V");
  FXUTAssert(models.at(16)->valueOfAttribute("subtype") == "PULSE");
  FXUTAssert(models.at(17)->valueOfAttribute("type") == "I");
  FXUTAssert(models.at(17)->valueOfAttribute("subtype") == "DC");
  FXUTAssert(models.at(18)->valueOfAttribute("type") == "I");
  FXUTAssert(models.at(18)->valueOfAttribute("subtype") == "AC");
  FXUTAssert(models.at(19)->valueOfAttribute("type") == "I");
  FXUTAssert(models.at(19)->valueOfAttribute("subtype") == "SIN");
  FXUTAssert(models.at(20)->valueOfAttribute("type") == "I");
  FXUTAssert(models.at(20)->valueOfAttribute("subtype") == "PULSE");
  FXUTAssert(models.at(21)->valueOfAttribute("type") == "R");
  FXUTAssert(models.at(21)->valueOfAttribute("subtype") == "SEMI");
  FXUTAssert(models.at(22)->valueOfAttribute("type") == "C");
  FXUTAssert(models.at(22)->valueOfAttribute("subtype") == "SEMI");
  FXUTAssert(models.at(23)->valueOfAttribute("type") == "V");
  FXUTAssert(models.at(23)->valueOfAttribute("subtype") == "NONLIN");
}


static FXString element_rotation_conversion_input =
  "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta xmlns=\"http://kulfx.com/volta\" version=\"1\">"
    "<circuit name=\"Test\">"
      "<schematic>"
        "<element type=\"R\" name=\"R1\" x=\"130\" y=\"330\" rotation=\"90\" flipped=\"true\" />"
        "<element type=\"C\" name=\"C1\" x=\"140\" y=\"430\" rotation=\"-180\" />"
        "<element type=\"L\" name=\"L1\" x=\"150\" y=\"470\" rotation=\"-90\" flipped=\"true\" />"
      "</schematic>"
    "</circuit>"
  "</volta>";

- (void) test_convert_element_rotation
{
  FXXMLDocumentPtr doc = FXXMLDocument::fromString(element_rotation_conversion_input);
  FXUTAssert(doc.get() != nullptr);
  FXXMLElementPtr originalSchematic = doc->getRootElement()->getChildren().at(0)->getChildren().at(0);
  for ( FXXMLElementPtr originalSchematicElement : originalSchematic->getChildren() )
  {
    if ( originalSchematicElement->valueOfAttribute("name") == "R1" )
    {
      FXUTAssert(originalSchematicElement->valueOfAttribute("rotation") == "90");
      FXUTAssert(originalSchematicElement->hasAttribute("flipped"));
    }
    else if ( originalSchematicElement->valueOfAttribute("name") == "C1" )
    {
      FXUTAssert(originalSchematicElement->valueOfAttribute("rotation") == "-180");
      FXUTAssert(!originalSchematicElement->hasAttribute("flipped"));
    }
    else if ( originalSchematicElement->valueOfAttribute("name") == "L1" )
    {
      FXUTAssert(originalSchematicElement->valueOfAttribute("rotation") == "-90");
      FXUTAssert(originalSchematicElement->hasAttribute("flipped"));
    }
  }
  std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> conversionResult = [FXVoltaArchiveConverterV1To2 convertRootElement:doc->getRootElement()];
  FXXMLElementPtr convertedRoot = std::get<0>(conversionResult);
  FXUTAssert(convertedRoot.get() != nullptr);
  FXUTAssertEqual(convertedRoot->getChildren().size(), (size_t)1);
  FXXMLElementPtr circuit = convertedRoot->getChildren().at(0);
  FXUTAssert(circuit->getName() == "circuit");
  FXUTAssertEqual(circuit->getChildren().size(), (size_t)1);
  FXXMLElementPtr schematic = circuit->getChildren().at(0);
  FXUTAssert(schematic->getName() == "schematic");
  FXXMLElementPtrVector schematicElements = schematic->getChildren();
  FXUTAssertEqual(schematicElements.size(), (size_t)3);
  for ( FXXMLElementPtr originalSchematicElement : schematic->getChildren() )
  {
    if ( originalSchematicElement->valueOfAttribute("name") == "R1" )
    {
      FXUTAssert(originalSchematicElement->valueOfAttribute("rotation") == "-90");
      FXUTAssert(originalSchematicElement->hasAttribute("flipped"));
    }
    else if ( originalSchematicElement->valueOfAttribute("name") == "C1" )
    {
      FXUTAssert(originalSchematicElement->valueOfAttribute("rotation") == "180");
      FXUTAssert(!originalSchematicElement->hasAttribute("flipped"));
    }
    else if ( originalSchematicElement->valueOfAttribute("name") == "L1" )
    {
      FXUTAssert(originalSchematicElement->valueOfAttribute("rotation") == "90");
      FXUTAssert(originalSchematicElement->hasAttribute("flipped"));
    }
  }
}

@end
