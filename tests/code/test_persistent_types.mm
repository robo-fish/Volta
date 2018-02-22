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
#import "VoltaPersistentTypes.h"


@interface test_persistent_types : SenTestCase
@end


@implementation test_persistent_types


- (void) test_model_equality
{
  VoltaPTModelPtr model1( new VoltaPTModel(VMT_L, "H", "fish.robo.test") );

  VoltaPTModelPtr model2 = model1;
  FXUTAssert( model1 == model2 );

  VoltaPTModelPtr model3( new VoltaPTModel(VMT_L, "H", "fish.robo.test") );

  STAssertFalse(model1 == model3, @"The models are equal only if they point to the same object.");
}


static bool lessThanModel(VoltaPTModelPtr const & a, VoltaPTModelPtr const & b)
{
  return *a < *b;
}


- (void) test_model_sorting
{
  VoltaPTModelPtrVector models;
  models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_D, "#4", "fish.robo" ) ) );
  models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_D, "#4","fish.robo.test" ) ) );
  models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_BJT, "#77", "com.semiconductor") ) );
  models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_R, "#5", "com.somecompany" ) ) );
  models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_L, "#3", "fish.robo" ) ) );
  models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_C, "#2", "com.othercompany" ) ) );
  models.push_back( VoltaPTModelPtr( new VoltaPTModel(VMT_D, "#4", "com.bigcompany" ) ) );
  std::sort(models.begin(), models.end(), lessThanModel);
  FXUTAssert(models.at(0)->name == "#5");
  FXUTAssert(models.at(1)->name == "#2");
  FXUTAssert(models.at(2)->name == "#3");
  FXUTAssert((models.at(3)->name == "#4") && (models.at(3)->vendor == "com.bigcompany"));
  FXUTAssert((models.at(4)->name == "#4") && (models.at(4)->vendor == "fish.robo"));
  FXUTAssert((models.at(5)->name == "#4") && (models.at(5)->vendor == "fish.robo.test"));
  FXUTAssert(models.at(6)->name == "#77");
}


- (void) test_model_comparison
{
  VoltaPTModelPtr model1( new VoltaPTModel(VMT_BJT, "aModel", "fish.robo.test") );
  VoltaPTModelPtr model2 = model1;
  VoltaPTModelPtr model3( new VoltaPTModel(VMT_BJT, "aModel", "fish.robo.test") );
  FXUTAssert(model1 == model2);
  FXUTAssert(model1 != model3);
}


- (void) test_thread_safety_of_VoltaPTModelPtrVector
{
  __block VoltaPTModelPtrVector models;
  VoltaPTModelPtr testModel1( new VoltaPTModel(VMT_R, "Test Model 1") );
  VoltaPTModelPtr testModel2( new VoltaPTModel(VMT_R, "Test Model 2") );

  dispatch_queue_t globalQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_group_t asyncGroup = dispatch_group_create();

  size_t const numInsertions = 200;
  size_t const repeats = 10;
  size_t const threadCount = 4;
  bool const withLocking = true;

  void(^block)(void) = ^{
    for ( size_t k = 0; k < repeats; k++ )
    {
      if ( withLocking )
      {
        while ( !models.lock() ) ;
      }

      size_t const originalSize = models.size();

      for ( size_t j = 0; j < numInsertions; j++ )
      {
        models.push_back(testModel1);
      }
      FXUTAssert(models.size() == (originalSize + numInsertions));

      for ( size_t j = 0; j < numInsertions; j+=2 )
      {
        models.erase(models.begin(), models.begin() + 1);
      }
      FXUTAssert(models.size() == (originalSize + numInsertions/2));

      if ( withLocking )
      {
        models.unlock();
      }
    }
  };
  
  for ( size_t t = 0; t < threadCount; t++ )
  {
    dispatch_group_async( asyncGroup, globalQ, block );
  }

  dispatch_group_wait(asyncGroup, DISPATCH_TIME_FOREVER);
  dispatch_release(asyncGroup);

  STAssertEquals(models.size(), threadCount * numInsertions * repeats / 2, @"Unexpected container size.");
}


@end
