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
#import "FXSPICELibParser.h"

@interface test_spice_lib_parsing : SenTestCase
@end


@implementation test_spice_lib_parsing
{
@private
  FXString mSingleModelWithVendorFileContent;
  FXString mSingleModelWithoutVendorFileContent;
  FXString mMultiModelFileContent;
}


- (id) initWithInvocation:(NSInvocation*)anInvocation
{
  self = [super initWithInvocation:anInvocation];
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  NSString* singleModelLibFilePath = [bundle pathForResource:@"test_single_model" ofType:@"lib"];
  mSingleModelWithVendorFileContent = (__bridge CFStringRef)[NSString stringWithContentsOfFile:singleModelLibFilePath encoding:NSUTF8StringEncoding error:NULL];
  NSString* singleModelNoVendorLibFilePath = [bundle pathForResource:@"test_single_model_no_vendor" ofType:@"lib"];
  mSingleModelWithoutVendorFileContent = (__bridge CFStringRef)[NSString stringWithContentsOfFile:singleModelNoVendorLibFilePath encoding:NSUTF8StringEncoding error:NULL];
  NSString* multiModelLibFilePath = [bundle pathForResource:@"Models_OnSemi" ofType:@"lib"];
  mMultiModelFileContent = (__bridge CFStringRef)[NSString stringWithContentsOfFile:multiModelLibFilePath encoding:NSUTF8StringEncoding error:NULL];
  return self;
}


- (void) test_lib_file_contents_loaded
{
  FXUTAssert(!mSingleModelWithVendorFileContent.empty());
  FXUTAssert(!mSingleModelWithoutVendorFileContent.empty());
  FXUTAssert(!mMultiModelFileContent.empty());
}


- (void) runTestsOn1N4004RLModel:(VoltaPTModelPtr)model expectedVendor:(FXString const &)vendor
{
  FXUTAssert(model->name == "1N4004RL");
  FXUTAssert(model->vendor == vendor);
  FXUTAssertEqual(model->type, VMT_D);
  FXUTAssert(model->subtype == "");
  FXUTAssertEqual(model->properties.size(), (size_t)14);
  FXUTAssert(model->properties.at(1).name == "RS");
  FXUTAssert(model->properties.at(1).value == "0.0392384");
  FXUTAssert(model->properties.at(2).name == "N");
  FXUTAssert(model->properties.at(2).value == "2");
  FXUTAssert(model->properties.at(4).name == "XTI");
  FXUTAssert(model->properties.at(4).value == "0.05");
  FXUTAssert(model->properties.at(6).name == "IBV");
  FXUTAssert(model->properties.at(6).value == "5e-08");
  FXUTAssert(model->properties.at(7).name == "CJO");
  FXUTAssert(model->properties.at(7).value == "1e-11");
  FXUTAssert(model->properties.at(11).name == "TT");
  FXUTAssert(model->properties.at(11).value == "1e-09");
  FXUTAssert(model->elementNamePrefix == "D");
}


- (void) test_parse_single_model_with_vendor_file_contents
{
  VoltaPTModelGroupPtr modelGroup = FXSPICELibParser::parseLib(mSingleModelWithVendorFileContent);
  FXUTAssert(modelGroup.get() != nullptr);
  if (modelGroup.get() != nullptr)
  {
    FXUTAssertEqual(modelGroup->models.size(), (size_t)1);
    VoltaPTModelPtr model = modelGroup->models.at(0);
    [self runTestsOn1N4004RLModel:model expectedVendor:"ON Semiconductor"];
  }
}


- (void) test_parse_single_model_without_vendor_file_contents
{
  VoltaPTModelGroupPtr modelGroup = FXSPICELibParser::parseLib(mSingleModelWithoutVendorFileContent);
  FXUTAssert(modelGroup.get() != nullptr);
  if (modelGroup.get() != nullptr)
  {
    FXUTAssertEqual(modelGroup->models.size(), (size_t)1);
    VoltaPTModelPtr model = modelGroup->models.at(0);
    [self runTestsOn1N4004RLModel:model expectedVendor:""];
  }
}


- (void) assertName:(FXString const &)name modelType:(VoltaModelType)type numProperties:(size_t)size forModel:(VoltaPTModelPtr)model
{
  FXUTAssert(model->name == name);
  FXUTAssertEqual(model->properties.size(), size);
}


- (void) test_parse_multi_model_file_contents
{
  VoltaPTModelGroupPtr modelGroup = FXSPICELibParser::parseLib(mMultiModelFileContent);
  FXUTAssert(modelGroup.get() != nullptr);
  if (modelGroup.get() != nullptr)
  {
    for ( VoltaPTModelPtr model : modelGroup->models )
      FXUTAssert(model->vendor == "ON Semiconductor");

    FXUTAssertEqual(modelGroup->models.size(), (size_t)10);
    [self assertName:"1N4004RL" modelType:VMT_D   numProperties:14 forModel:modelGroup->models.at(0)];
    [self assertName:"1N5401RL" modelType:VMT_D   numProperties:14 forModel:modelGroup->models.at(1)];
    [self assertName:"1N5402RL" modelType:VMT_D   numProperties:14 forModel:modelGroup->models.at(2)];
    [self assertName:"1N5408RL" modelType:VMT_D   numProperties:14 forModel:modelGroup->models.at(3)];
    [self assertName:"2N3055"   modelType:VMT_BJT numProperties:40 forModel:modelGroup->models.at(4)];
    [self assertName:"2N3904"   modelType:VMT_BJT numProperties:40 forModel:modelGroup->models.at(5)];
    [self assertName:"BC547B"   modelType:VMT_BJT numProperties:40 forModel:modelGroup->models.at(6)];
    [self assertName:"BC557B"   modelType:VMT_BJT numProperties:40 forModel:modelGroup->models.at(7)];
    [self assertName:"BD139"    modelType:VMT_BJT numProperties:40 forModel:modelGroup->models.at(8)];
    [self assertName:"BD140"    modelType:VMT_BJT numProperties:40 forModel:modelGroup->models.at(9)];
  }
}


@end
