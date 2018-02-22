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
#import "FXVoltaLibraryData.h"


@interface test_library_data : SenTestCase
@end


@implementation test_library_data
{
@private
  FXVoltaLibraryData mData;
  VoltaPTModelPtr mZenerDiodeModel;
  VoltaPTModelPtr mInvalidModel;
  VoltaPTModelGroupPtr mResistorGroup;
  VoltaPTModelGroupPtr mDiodeGroup;
  VoltaPTModelGroupPtr mMOSFETGroup;
  VoltaPTModelGroupPtr mInvalidGroup;
  VoltaPTElementGroup mBasicElementsGroup;
  VoltaPTElementGroup mTransistorElementsGroup;
  VoltaPTElementGroup mMeterElementsGroup;
  VoltaPTModelPtr mOperationalAmp;
  VoltaPTModelPtr mDifferentialAmp;
  VoltaPTModelPtr mFlipFlop;
}


- (id) initWithInvocation:(NSInvocation*)anInvocation
{
  self = [super initWithInvocation:anInvocation];
  [self createTestModelGroups];
  [self createTestModels];
  [self createTestElementGroups];
  [self createTestSubcircuits];
  return self;
}


#pragma mark --- Clearing


- (void) test_clearAll
{
  [self addTestModelGroups];
  [self addTestElementGroups];
  FXUTAssert(mData.numModels() > 0);
  FXUTAssert(mData.numElementGroups() > 0);
  mData.clearAll();
  FXUTAssertEqual(mData.numModels(), (size_t)0);
  FXUTAssertEqual(mData.numElementGroups(), (size_t)0);
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)0);
}


- (void) test_clearSubcircuits
{
  VoltaPTModelPtr someSubcircuit( new VoltaPTModel(VMT_SUBCKT, "Bla") );
  mData.addSubcircuit(someSubcircuit);
  __block size_t numSubcircuits = 0;
  mData.iterateSubcircuits(^(VoltaPTModelPtr, BOOL*) { numSubcircuits++; });
  FXUTAssert(numSubcircuits > 0);
  numSubcircuits = 0;
  mData.clearSubcircuits();
  mData.iterateSubcircuits(^(VoltaPTModelPtr, BOOL*) { numSubcircuits++; });
  FXUTAssertEqual(numSubcircuits, (size_t)0);
}


#pragma mark --- Model Groups


- (void) test_addModelGroup
{
  mData.clearAll();
  FXUTAssertEqual(mData.numModelGroups(), (size_t)0);
  FXUTAssertEqual(mDiodeGroup->models.size(), (size_t)3);
  mData.addModelGroup(mDiodeGroup);
  FXUTAssertEqual(mData.numModelGroups(), (size_t)1);
  mData.addModelGroup(mMOSFETGroup);
  FXUTAssertEqual(mData.numModelGroups(), (size_t)2);
}


- (void) test_addModelGroup_invalid_group
{
  mData.clearAll();
  FXUTAssertEqual( mData.numModelGroups(), (size_t)0 );
  mData.addModelGroup(mInvalidGroup);
  FXUTAssertEqual( mData.numModelGroups(), (size_t)0 );
}


- (void) test_addModelGroups_groups_with_same_type
{
  mData.clearAll();
  [self addTestModelGroups];
  size_t const before = mData.numModelGroups();
  VoltaPTModelGroupPtr otherDiodeGroup = VoltaPTModelGroupPtr( new VoltaPTModelGroup("More Diodes", VMT_D) );
  mData.addModelGroup(otherDiodeGroup);
  size_t const after = mData.numModelGroups();
  FXUTAssertEqual(before, after);
}


- (void) test_iterateModelGroups
{
  mData.clearAll();
  [self addTestModelGroups];
  __block unsigned index = 0;
  mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
    switch (index)
    {
      case 0: FXUTAssert(group.get() == mResistorGroup.get()); break;
      case 1: FXUTAssert(group.get() == mDiodeGroup.get()); break;
      case 2: FXUTAssert(group.get() == mMOSFETGroup.get()); break;
      default: FXUTAssert(!"There should be no other model groups");
    }
    index++;
  });
  FXUTAssertEqual(index, (unsigned)3);
}


#pragma mark --- Models


- (void) test_addModel
{
  mData.addModelGroup(mDiodeGroup);
  size_t const modelCountBefore = mData.numModels();
  FXUTAssert(mData.addModel(mZenerDiodeModel));
  size_t const modelCountAfter = mData.numModels();
  FXUTAssertEqual(modelCountAfter - modelCountBefore, (size_t)1);
}


- (void) test_addModel_invalid_model
{
  size_t modelCountBefore = mData.numModels();
  mData.addModel(mInvalidModel);
  size_t modelCountAfter = mData.numModels();
  FXUTAssertEqual(modelCountAfter, modelCountBefore);
}


- (void) test_addModel_same_model_twice
{
  mData.clearAll();
  [self addTestModelGroups];
  mData.addModel(mZenerDiodeModel);
  size_t const before = mData.numModels();
  mData.addModel(mZenerDiodeModel);
  size_t const after = mData.numModels();
  FXUTAssertEqual(before, after);
}


- (void) test_addModel_same_model_with_other_revision
{
  mData.clearAll();
  [self addTestModelGroups];

  VoltaPTModelPtr zenerDiodeModel2( new VoltaPTModel() );
  *zenerDiodeModel2 = *mZenerDiodeModel;
  zenerDiodeModel2->revision += 1;

  __block bool foundZenerDiode = false;
  __block bool foundZenerDiode2 = false;

  FXUTAssert(mData.addModel(mZenerDiodeModel));
  mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
    if ( group->modelType == mZenerDiodeModel->type )
    {
      for ( VoltaPTModelPtr groupModel : group->models )
      {
        if ( *groupModel == *mZenerDiodeModel )
        {
          foundZenerDiode = true;
          break;
        }
      }
      *stop = YES;
    }
  });
  FXUTAssert(foundZenerDiode);

  FXUTAssert( !mData.addModel(zenerDiodeModel2) );
  foundZenerDiode = false;
  mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
    if ( group->modelType == mZenerDiodeModel->type )
    {
      for ( VoltaPTModelPtr groupModel : group->models )
      {
        if ( *groupModel == *mZenerDiodeModel )
        {
          foundZenerDiode = (groupModel->revision == mZenerDiodeModel->revision);
        }
      }
      *stop = YES;
    }
  });
  FXUTAssert(foundZenerDiode);
  FXUTAssert(!foundZenerDiode2);

  FXUTAssert( mData.addModel(zenerDiodeModel2, FXVoltaLibraryItemAddingPolicy::ReplaceOlderVersion) );
  foundZenerDiode = false;
  foundZenerDiode2 = false;
  mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
    if ( group->modelType == mZenerDiodeModel->type )
    {
      for ( VoltaPTModelPtr groupModel : group->models )
      {
        if ( *groupModel == *mZenerDiodeModel )
        {
          if (groupModel->revision == mZenerDiodeModel->revision)
          {
            foundZenerDiode = true;
          }
          else if (groupModel->revision == zenerDiodeModel2->revision)
          {
            foundZenerDiode2 = true;
          }
        }
      }
      *stop = YES;
    }
  });
  FXUTAssert(!foundZenerDiode);
  FXUTAssert(foundZenerDiode2);
}


- (void) test_addLibraryModels
{
  mData.clearAll();
  mData.addModelGroup(VoltaPTModelGroupPtr(new VoltaPTModelGroup("Diodes", VMT_D)));
  VoltaPTLibraryPtr library( new VoltaPTLibrary );
  library->title = "Diode Library";
  library->modelGroup = mDiodeGroup;
  mData.addLibraryModels(library, "test", true);
  FXUTAssertEqual(mData.numModelGroups(), (size_t)1);
  FXUTAssertEqual(mData.numModels(), mDiodeGroup->models.size());
}


- (void) test_removeModel
{
  mData.clearAll();
  [self addTestModelGroups];
  FXUTAssert( mData.addModel(mZenerDiodeModel) );
  size_t const modelCountBefore = mData.numModels();
  FXUTAssert( mData.removeModel(mZenerDiodeModel) );
  size_t const modelCountAfter = mData.numModels();
  FXUTAssertEqual(modelCountBefore - modelCountAfter, (size_t)1);
}


- (void) test_removeNonBuiltInModels
{
  mData.clearAll();
  [self addTestModelGroups];
  __block size_t numMutableModels = 0;
  mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
    for ( VoltaPTModelPtr model : group->models )
    {
      if ( model->isMutable )
      {
        numMutableModels++;
      }
    }
  });
  FXUTAssertEqual(numMutableModels, (size_t)7);
  VoltaPTModelPtrVector const removedModels = mData.removeNonBuiltInModels();
  FXUTAssertEqual(removedModels.size(), numMutableModels);
  __block size_t numRemainingModels = 0;
  __block BOOL allRemainingModelsAreImmutable = YES;
  mData.iterateModelGroups(^(VoltaPTModelGroupPtr group, BOOL *stop) {
    for ( VoltaPTModelPtr model : group->models )
    {
      numRemainingModels++;
      if ( model->isMutable )
      {
        allRemainingModelsAreImmutable = NO;
      }
    }
  });
  FXUTAssertEqual(numRemainingModels, (size_t)2);
  FXUTAssert(allRemainingModelsAreImmutable);
}


- (void) test_renameModel
{
  mData.clearAll();
  FXUTAssert(mData.addModelGroup(VoltaPTModelGroupPtr(new VoltaPTModelGroup("Capacitors", VMT_C))));
  VoltaPTModelPtr aModel( new VoltaPTModel(VMT_C, "MyCapacitor", "fish.robo", true) );
  FXUTAssert(mData.addModel(aModel));
  FXUTAssert(mData.renameModel(aModel, "YourCapacitor"));
  FXUTAssert(aModel->name == "YourCapacitor");

  aModel->isMutable = false;
  FXUTAssert(!mData.renameModel(aModel, "HerCapacitor"));
  FXUTAssert(aModel->name == "YourCapacitor");
}


- (void) test_setVendorString
{
  mData.clearAll();

  FXUTAssert(mData.addModelGroup(VoltaPTModelGroupPtr(new VoltaPTModelGroup("Capacitors", VMT_C))));
  VoltaPTModelPtr aModel( new VoltaPTModel(VMT_C, "MyCapacitor", "fish.robo", true) );
  FXUTAssert(mData.addModel(aModel));
  VoltaPTModelPtrVector modelsToChange;
  modelsToChange.push_back(aModel);
  FXUTAssert(mData.setVendorString(modelsToChange, "fish.robo.test"));
  FXUTAssert(aModel->vendor == "fish.robo.test");

  VoltaPTModelPtr anotherModel( new VoltaPTModel(VMT_C, "MyCapacitor", "fish.robo", true) );
  FXUTAssert(mData.addModel(anotherModel));
  modelsToChange.clear();
  modelsToChange.push_back(anotherModel);
  FXUTAssert(!mData.setVendorString(modelsToChange, "fish.robo.test"));
  FXUTAssert(anotherModel->vendor == "fish.robo");

  [self addTestModelGroups];
  VoltaPTModelPtr NMOSModel( new VoltaPTModel(VMT_MOSFET, "N-Channel", "fish.robo.test") );
  modelsToChange.clear();
  modelsToChange.push_back(NMOSModel);
  FXUTAssert(mData.setVendorString(modelsToChange, "com.bogus"));
  NMOSModel->vendor = "com.bogus";
  FXUTAssert(!mData.setVendorString(modelsToChange, "fish.robo.test2"));
}


- (void) test_findModel
{
  mData.clearAll();
  [self addTestModelGroups];
  FXUTAssert(mData.findModel(VMT_MOSFET, "N-Channel", "fish.robo.test", FXVoltaLibrarySearchStrategy::MatchAll).get() != nullptr);
  FXUTAssert(mData.findModel(VMT_MOSFET, "N-Channel", "bla", FXVoltaLibrarySearchStrategy::MatchAll).get() == nullptr);
  FXUTAssert(mData.findModel(VMT_MOSFET, "N-Channel", "bla", FXVoltaLibrarySearchStrategy::IgnoreVendor).get() != nullptr);
  FXUTAssert(mData.findModel(VMT_R, "", "", FXVoltaLibrarySearchStrategy::DefaultModelForType).get() != nullptr);
  FXUTAssert(mData.findModel(VMT_D, "", "", FXVoltaLibrarySearchStrategy::DefaultModelForType).get() != nullptr);
  FXUTAssert(mData.findModel(VMT_L, "", "", FXVoltaLibrarySearchStrategy::DefaultModelForType).get() == nullptr);
}


- (void) test_defaultModelForType
{
  mData.clearAll();
  [self addTestModelGroups];

  FXUTAssert(mData.defaultModelForType(VMT_R).get() != nullptr);
  FXUTAssert(*mData.defaultModelForType(VMT_R) == *mData.findModel(VMT_R, "", "", FXVoltaLibrarySearchStrategy::DefaultModelForType));

  FXUTAssert(mData.defaultModelForType(VMT_D).get() != nullptr);
  FXUTAssert(*mData.defaultModelForType(VMT_D) == *mData.findModel(VMT_D, "", "", FXVoltaLibrarySearchStrategy::DefaultModelForType));

  FXUTAssert(mData.defaultModelForType(VMT_L).get() == nullptr);
}


- (void) test_ThreadSafety_model_add_remove
{
  mData.clearAll();
  [self addTestModelGroups];

  [self runThreadSafetyTestForBlock: ^{
    mData.lockModels();
    size_t const before = mData.numModels();
    FXUTAssert(mData.addModel(mZenerDiodeModel));
    size_t const later = mData.numModels();
    FXUTAssertEqual( later - before, (size_t)1 );
    FXUTAssert(mData.removeModel(mZenerDiodeModel));
    size_t const after = mData.numModels();
    FXUTAssertEqual( later - after, (size_t)1 );
    FXUTAssertEqual(before, after);
    mData.unlockModels();
  }];
}


- (void) test_ThreadSafety_model_editing
{
  mData.clearAll();
  [self addTestModelGroups];
  
  [self runThreadSafetyTestForBlock: ^{
    mData.lockModels();
    VoltaPTModelPtr NMOSModel1( new VoltaPTModel(VMT_MOSFET, "N-Channel", "fish.robo.test") );
    VoltaPTModelPtr NMOSModel2( new VoltaPTModel(VMT_MOSFET, "N-Channel") );
    VoltaPTModelPtrVector editedModels;
    editedModels.push_back(NMOSModel1);
    FXUTAssert(mData.setVendorString(editedModels, "com.bogus1"));
    FXUTAssert(NMOSModel1->vendor == "fish.robo.test");
    editedModels.clear();
    editedModels.push_back(NMOSModel2);
    FXUTAssert(!mData.setVendorString(editedModels, "com.bogus2"));
    editedModels.clear();
    NMOSModel1->vendor = "com.bogus1";
    editedModels.push_back(NMOSModel1);
    FXUTAssert(!mData.setVendorString(editedModels, "fish.robo.test2"));
    FXUTAssert(mData.setVendorString(editedModels, "fish.robo.test"));
    NMOSModel1->vendor = "fish.robo.test";
    mData.unlockModels();
  }];
}


#pragma mark --- Element Groups


- (void) test_createElementGroup
{
  mData.clearAll();
  FXUTAssertEqual( mData.numElementGroups(), (size_t)0 );
  [self addTestElementGroups];
  FXUTAssertEqual( mData.numElementGroups(), (size_t)3 );

  __block unsigned elementIndex = 0;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *) {
    if ( elementIndex == 0 )
      FXUTAssert(group.name == mBasicElementsGroup.name);
    else if ( elementIndex == 1 )
      FXUTAssert(group.name == mTransistorElementsGroup.name);
    elementIndex++;
  });
}


- (void) test_copyElementGroup
{
  [self addTestElementGroups];
  FXUTAssert(mData.hasElementGroup(mMeterElementsGroup.name));
  FXString const newGroupName = mData.copyElementGroup(mMeterElementsGroup.name);
  FXUTAssert(newGroupName != mMeterElementsGroup.name);
  __block bool foundGroup = false;
  __block size_t numElementsInNewGroup = 0;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
    if ( group.name == newGroupName )
    {
      foundGroup = true;
      size_t index = 0;
      numElementsInNewGroup = group.elements.size();
      for ( auto element : group.elements )
      {
        FXUTAssert(element == mMeterElementsGroup.elements.at(index));
        index++;
      }
      *stop = YES;
    }
  });
  FXUTAssert(foundGroup);
  FXUTAssertEqual(numElementsInNewGroup, (size_t)mMeterElementsGroup.elements.size());
}


- (void) test_removeElementGroup
{
  mData.clearAll();
  [self addTestElementGroups];
  FXUTAssertEqual( mData.numElementGroups(), (size_t)3 );
  FXUTAssert( mData.removeElementGroup( mBasicElementsGroup.name ) );
  FXUTAssertEqual( mData.numElementGroups(), (size_t)2 );
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *) {
    FXUTAssert(group.name != mBasicElementsGroup.name );
  });
}


- (void) test_renameElementGroup
{
  mData.clearAll();
  [self addTestElementGroups];
  FXString const newGroupName = "My " + mBasicElementsGroup.name;
  FXUTAssert(mData.renameElementGroup(mBasicElementsGroup.name, newGroupName));
  __block bool foundGroupWithOldName = false;
  __block bool foundGroupWithNewName = false;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
    if ( group.name == mBasicElementsGroup.name )
    {
      foundGroupWithOldName = true;
    }
    else if ( group.name == newGroupName )
    {
      foundGroupWithNewName = true;
    }
  });
  FXUTAssert(foundGroupWithNewName);
  FXUTAssert(!foundGroupWithOldName);
}


- (void) test_moveElementGroups
{
  [self addTestElementGroups];
  FXUTAssert(mData.numElementGroups() > 2);
  std::set<unsigned int> indexesOfGroupsToBeMoved;
  indexesOfGroupsToBeMoved.insert(1);
  indexesOfGroupsToBeMoved.insert(2);
  __block FXString firstGroup;
  __block FXString secondGroup;
  __block FXString thirdGroup;
  __block size_t currentIndex = 0;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
    if ( currentIndex == 0 ) { firstGroup = group.name; }
    else if ( currentIndex == 1 ) { secondGroup = group.name; }
    else if ( currentIndex == 2 ) { thirdGroup = group.name; }
    else *stop = YES;
    currentIndex++;
  });
  FXUTAssert(mData.moveElementGroups(indexesOfGroupsToBeMoved, 0));
  currentIndex = 0;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
    if ( currentIndex == 0 ) FXUTAssert(group.name == secondGroup);
    else if ( currentIndex == 1) FXUTAssert(group.name == thirdGroup);
    else if ( currentIndex == 2 ) FXUTAssert(group.name == firstGroup);
    else *stop = YES;
    currentIndex++;
  });
}


- (void) test_hasElementGroup
{
  [self addTestElementGroups];
  FXUTAssert(mData.hasElementGroup(mBasicElementsGroup.name));
  __block bool foundGroup = false;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
    if ( group.name == mBasicElementsGroup.name )
    {
      foundGroup = true;
      *stop = YES;
    }
  });
  FXUTAssert(foundGroup);
}


- (void) test_iterateElementGroups
{
  mData.clearAll();
  [self addTestElementGroups];
  __block unsigned index = 0;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
    switch (index)
    {
      case 0: FXUTAssert(group == mBasicElementsGroup); break;
      case 1: FXUTAssert(group == mTransistorElementsGroup); break;
      case 2: FXUTAssert(group == mMeterElementsGroup); break;
      default: FXUTAssert(!"There should be no other element groups");
    }
    index++;
  });
  FXUTAssertEqual(index, (unsigned)3);
}


- (void) test_ThreadSafety_element_group_add_remove
{
  mData.clearAll();
  
  [self runThreadSafetyTestForBlock: ^{
    mData.lockElements();
    FXString const newGroupName("TestGroup");
    mData.createElementGroup(newGroupName);
    __block bool foundGroup = false;
    mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL* stop) {
      if ( group.name == newGroupName )
      {
        foundGroup = true;
        *stop = YES;
      }
    });
    FXUTAssert(foundGroup);
    FXUTAssert(mData.removeElementGroup(newGroupName));
    foundGroup = false;
    mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL* stop) {
      if ( group.name == newGroupName )
      {
        foundGroup = true;
        *stop = YES;
      }
    });
    FXUTAssert(!foundGroup);
    mData.unlockElements();
  }];
}


#pragma mark --- Elements


- (void) test_addElement
{
  mData.clearAll();
  [self addTestElementGroups];
  __block size_t oldNumElementsInBasicGroup = 0;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL* stop) {
    if ( group.name == mBasicElementsGroup.name )
    {
      oldNumElementsInBasicGroup = group.elements.size();
      *stop = YES;
    }
  });
  FXUTAssert(oldNumElementsInBasicGroup > 0);
  VoltaPTElement inductor( "TestInductor", VMT_L, "Inductor", "fish.robo.test" );
  inductor.name = mData.addElement(inductor, mBasicElementsGroup.name);
  __block size_t newNumElementsInBasicGroup = 0;
  __block bool groupContainsInductor = false;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL* stop) {
    if ( group.name == mBasicElementsGroup.name )
    {
      newNumElementsInBasicGroup = group.elements.size();
      for ( VoltaPTElement groupElement : group.elements )
      {
        if ( groupElement == inductor )
        {
          groupContainsInductor = true;
          break;
        }
      }
      *stop = YES;        
    }
  });
  FXUTAssertEqual( newNumElementsInBasicGroup - oldNumElementsInBasicGroup, (size_t)1 );
  FXUTAssert(groupContainsInductor);
}


- (void) test_insertElements
{
  mData.clearAll();
  [self addTestElementGroups];
  VoltaPTElementVector elementsToInsert;
  elementsToInsert.resize(mBasicElementsGroup.elements.size());
  std::copy( mBasicElementsGroup.elements.begin(), mBasicElementsGroup.elements.end(), elementsToInsert.begin() );
  FXUTAssert(mData.insertElements(elementsToInsert, mTransistorElementsGroup.name, 1, false));
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
    if ( group.name == mTransistorElementsGroup.name )
    {
      FXUTAssertEqual(group.elements.size(), mTransistorElementsGroup.elements.size() + mBasicElementsGroup.elements.size());
      size_t elementIndex = 0;
      for ( VoltaPTElement const & element : group.elements )
      {
        switch (elementIndex)
        {
          case 0: FXUTAssert( element == mTransistorElementsGroup.elements.at(0) ); break;
          case 1: FXUTAssert( element == mBasicElementsGroup.elements.at(0) ); break;
          case 2: FXUTAssert( element == mBasicElementsGroup.elements.at(1) ); break;
          case 3: FXUTAssert( element == mBasicElementsGroup.elements.at(2) ); break;
          case 4: FXUTAssert( element == mBasicElementsGroup.elements.at(3) ); break;
          case 5: FXUTAssert( element == mTransistorElementsGroup.elements.at(1) ); break;
          default: FXUTAssert(!"There should be no other element in this group.");
        }
        elementIndex++;
      }
    }
  });

  FXUTAssert(mData.insertElements(elementsToInsert, mTransistorElementsGroup.name, 0, true));
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
    if ( group.name == mTransistorElementsGroup.name )
    {
      FXUTAssertEqual(group.elements.size(), mTransistorElementsGroup.elements.size() + mBasicElementsGroup.elements.size());
      size_t elementIndex = 0;
      for ( VoltaPTElement const & element : group.elements )
      {
        switch (elementIndex)
        {
          case 0: FXUTAssert( element == mBasicElementsGroup.elements.at(0) ); break;
          case 1: FXUTAssert( element == mBasicElementsGroup.elements.at(1) ); break;
          case 2: FXUTAssert( element == mBasicElementsGroup.elements.at(2) ); break;
          case 3: FXUTAssert( element == mBasicElementsGroup.elements.at(3) ); break;
          case 4: FXUTAssert( element == mTransistorElementsGroup.elements.at(0) ); break;
          case 5: FXUTAssert( element == mTransistorElementsGroup.elements.at(1) ); break;
          default: FXUTAssert(!"There should be no other element in this group.");
        }
        elementIndex++;
      }
    }
  });
}


- (void) test_renameElement
{
  mData.clearAll();
  [self addTestElementGroups];
  __block bool foundJayZ = false;
  mData.iterateElementGroups(^(const VoltaPTElementGroup &group, BOOL *stop) {
    if ( group.name == mTransistorElementsGroup.name )
    {
      for ( auto & element : group.elements )
      {
        if ( element.name == "JayZ" )
        {
          foundJayZ = true;
          break;
        }
      }
      *stop = YES;
    }
  });
  FXUTAssert(!foundJayZ);
  FXUTAssert(mData.renameElement("JLo", mTransistorElementsGroup.name, "JayZ"));
  foundJayZ = false;
  mData.iterateElementGroups(^(const VoltaPTElementGroup &group, BOOL *stop) {
    if ( group.name == mTransistorElementsGroup.name )
    {
      for ( auto & element : group.elements )
      {
        if ( element.name == "JayZ" )
        {
          foundJayZ = true;
          break;
        }
      }
      *stop = YES;
    }
  });
  FXUTAssert(foundJayZ);

  FXUTAssert(!mData.renameElement("MOS1", mTransistorElementsGroup.name, "JayZ"));
  FXUTAssert(!mData.renameElement("Bogus", mTransistorElementsGroup.name, "NewName"));
  FXUTAssert(!mData.renameElement("MOS1", "Bogus", "Blabla"));
}


- (void) test_removeElement
{
  mData.clearAll();
  [self addTestElementGroups];
  VoltaPTElement inductor( "TestInductor", VMT_L, "Inductor", "fish.robo.test" );
  inductor.name = mData.addElement(inductor, mTransistorElementsGroup.name);
  __block bool foundInductorInGroup = false;
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL* stop) {
    if ( group.name == mTransistorElementsGroup.name )
    {
      for ( VoltaPTElement groupElement : group.elements )
      {
        if ( groupElement == inductor )
        {
          foundInductorInGroup = true;
          break;
        }
      }
      *stop = YES;
    }
  });
  FXUTAssert(foundInductorInGroup);
  foundInductorInGroup = false;
  FXUTAssert(mData.removeElement(inductor.name, mTransistorElementsGroup.name));
  mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL* stop) {
    if ( group.name == mTransistorElementsGroup.name )
    {
      for ( VoltaPTElement groupElement : group.elements )
      {
        if ( groupElement == inductor )
        {
          foundInductorInGroup = true;
          break;
        }
        break;
      }
      *stop = YES;
    }
  });
  FXUTAssert(!foundInductorInGroup);
}


- (void) test_setElementProperties
{
  mData.clearAll();
  [self addTestModelGroups];
  [self addTestElementGroups];
  VoltaPTPropertyVector properties = { VoltaPTProperty("bogus", "bla bla") };
  FXUTAssertEqual(mData.setElementProperties("MOS1", "Transistors", properties), (size_t)0);
  properties = { VoltaPTProperty("ad", "1"), VoltaPTProperty("as", "2"), VoltaPTProperty("pd","3") };
  FXUTAssertEqual(mData.setElementProperties("MOS1", "Transistors", properties), (size_t)3);
  properties = { VoltaPTProperty("m", "4"), VoltaPTProperty("imagined", "2") };
  FXUTAssertEqual(mData.setElementProperties("MOS1", "Transistors", properties), (size_t)1);
}


- (void) test_hasElementWithModel
{
  mData.clearAll();
  [self addTestElementGroups];
  VoltaPTModelPtr resistorModel( new VoltaPTModel(VMT_R, "Resistor IEC") );
  VoltaPTModelPtr capacitorModel( new VoltaPTModel(VMT_C, "Kondensator") );
  FXUTAssert(mData.hasElementWithModel(resistorModel));
  FXUTAssert(!mData.hasElementWithModel(capacitorModel));
}


- (void) test_ThreadSafety_element_add_remove
{
  mData.clearAll();
  [self addTestElementGroups];

  [self runThreadSafetyTestForBlock: ^{
    mData.lockElements();
    VoltaPTElement capacitor( "SomeCapacitor", VMT_C, "Capacitor", "fish.robo.test" );
    capacitor.name = mData.addElement(capacitor, mBasicElementsGroup.name);
    __block bool foundElementInGroup = false;
    mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL* stop) {
      if ( group.name == mBasicElementsGroup.name )
      {
        for ( VoltaPTElement e : group.elements )
        {
          if ( e == capacitor )
          {
            foundElementInGroup = true;
            break;
          }
        }
        *stop = YES;
      }
    });
    FXUTAssert(foundElementInGroup);
    FXUTAssert( mData.removeElement(capacitor.name, mBasicElementsGroup.name) );
    foundElementInGroup = false;
    mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL* stop) {
      if ( group.name == mBasicElementsGroup.name )
      {
        for ( VoltaPTElement e : group.elements )
        {
          if ( e == capacitor )
          {
            foundElementInGroup = true;
            break;
          }
        }
        *stop = YES;
      }
    });
    FXUTAssert(!foundElementInGroup);
    mData.unlockElements();
  }];
}


- (void) test_ThreadSafety_element_editing
{
  mData.clearAll();
  [self addTestElementGroups];

  [self runThreadSafetyTestForBlock:^{
    mData.lockElements();
    mData.renameElement("JFat", mTransistorElementsGroup.name, "JLo");
    [NSThread sleepForTimeInterval:0.00001];
    mData.renameElement("JLo", mTransistorElementsGroup.name, "JayZ");
    [NSThread sleepForTimeInterval:0.000017];
    mData.renameElement("JayZ", mTransistorElementsGroup.name, "JFat");
    [NSThread sleepForTimeInterval:0.000012];
    __block bool foundElement = false;
    mData.iterateElementGroups(^(VoltaPTElementGroup const & group, BOOL *stop) {
      if ( group.name == mTransistorElementsGroup.name )
      {
        for ( auto element : group.elements )
        {
          if ( element.name == "JFat" )
          {
            foundElement = true;
            break;
          }
        }
        *stop = YES;
      }
    });
    mData.unlockElements();
  }];
}


#pragma mark --- Subcircuits


- (void) test_addSubcircuit
{
  mData.clearAll();
  VoltaPTModelPtr invalidSubcircuit( new VoltaPTModel(VMT_V, "InvalidSubcircuit", "fish.robo.test", "DC") );
  VoltaPTModelPtr someSubcircuit( new VoltaPTModel(VMT_SUBCKT, "Some Subcircuit", "fish.robo.test") );
  VoltaPTModelPtr emptySubcircuit;
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)0);
  FXUTAssert(mData.addSubcircuit(someSubcircuit));
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
  FXUTAssert(!mData.addSubcircuit(invalidSubcircuit));
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
  FXUTAssert(!mData.addSubcircuit(invalidSubcircuit));
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
}


- (void) test_addSubcircuit_replacing_older_revision
{
  mData.clearAll();
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)0);

  VoltaPTModelPtr opamp( new VoltaPTModel(VMT_SUBCKT, "OP-AMP", "fish.robo.test") );
  FXUTAssert(mData.addSubcircuit(opamp));
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
  VoltaPTModelPtr opamp2( new VoltaPTModel() );
  *opamp2 = *opamp;
  opamp2->revision = opamp->revision + 1;
  FXUTAssert(!mData.addSubcircuit(opamp2));
  FXUTAssert(mData.addSubcircuit(opamp2, FXVoltaLibraryItemAddingPolicy::ReplaceOlderVersion));
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
  __block bool foundOriginalSubcircuit = false;
  mData.iterateSubcircuits(^(VoltaPTModelPtr subcircuit, BOOL *stop) {
    if ( subcircuit.get() == opamp.get() )
    {
      foundOriginalSubcircuit = true;
      *stop = YES;
    }
  });
  FXUTAssert(!foundOriginalSubcircuit);
}


- (void) test_removeSubcircuit
{
  mData.clearAll();
  VoltaPTModelPtr someSubcircuit( new VoltaPTModel(VMT_SUBCKT, "Some Subcircuit", "fish.robo.test") );
  FXUTAssert(mData.addSubcircuit(someSubcircuit));
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
  FXUTAssert(!mData.removeSubcircuit( VoltaPTModelPtr() ));
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
  FXUTAssert(mData.removeSubcircuit(someSubcircuit));
  FXUTAssertEqual(mData.numSubcircuits(), (size_t)0);
}


- (void) test_iterateSubcircuits
{
  mData.clearAll();
  [self addTestSubcircuits];
  __block unsigned index = 0;
  mData.iterateSubcircuits(^(VoltaPTModelPtr subcircuit, BOOL *stop) {
    switch (index)
    {
      case 0: FXUTAssert(subcircuit.get() == mOperationalAmp.get()); break;
      case 1: FXUTAssert(subcircuit.get() == mDifferentialAmp.get()); break;
      case 2: FXUTAssert(subcircuit.get() == mFlipFlop.get()); break;
      default: FXUTAssert(!"There should be no other model groups");
    }
    index++;
  });
  FXUTAssertEqual(index, (unsigned)3);
}


- (void) test_ThreadSafety_add_remove_subcircuit
{
  mData.clearAll();

  [self runThreadSafetyTestForBlock: ^{
    mData.lockSubcircuits();
    VoltaPTModelPtr s1( new VoltaPTModel(VMT_SUBCKT, "Subcircuit1", "fish.robo.test") );
    VoltaPTModelPtr s2( new VoltaPTModel(VMT_SUBCKT, "Subcircuit2", "fish.robo.test") );
    FXUTAssert(mData.addSubcircuit(s1));
    FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
    FXUTAssert(mData.addSubcircuit(s2));
    FXUTAssertEqual(mData.numSubcircuits(), (size_t)2);
    FXUTAssert(mData.removeSubcircuit(s1));
    FXUTAssertEqual(mData.numSubcircuits(), (size_t)1);
    FXUTAssert(mData.removeSubcircuit(s2));
    FXUTAssertEqual(mData.numSubcircuits(), (size_t)0);
    mData.unlockSubcircuits();
  }];
}


#pragma mark Helper methods


- (void) createTestModels
{
  mZenerDiodeModel = VoltaPTModelPtr( new VoltaPTModel(VMT_D, "Zener Diode", "fish.robo.test") );
  mInvalidModel = VoltaPTModelPtr( new VoltaPTModel(VMT_Unknown) );
}


static VoltaPTModelPtr nonBuiltinModel( VoltaPTModelPtr model )
{
  model->source = "KulFX";
  return model;
}


- (void) createTestModelGroups
{
  mInvalidGroup = VoltaPTModelGroupPtr( new VoltaPTModelGroup("Invalid") );

  mResistorGroup = VoltaPTModelGroupPtr( new VoltaPTModelGroup("Resistors", VMT_R) );
  mResistorGroup->models.push_back( nonBuiltinModel( VoltaPTModelPtr( new VoltaPTModel(VMT_R, "Resistor IEC") ) ) );
  mResistorGroup->models.push_back( nonBuiltinModel( VoltaPTModelPtr( new VoltaPTModel(VMT_R, "Resistor US") ) ) );
  VoltaPTModelPtr defaultResistor( new VoltaPTModel(VMT_R, "Resistor") );
  defaultResistor->isMutable = false;
  mResistorGroup->models.push_back(defaultResistor);

  mDiodeGroup = VoltaPTModelGroupPtr( new VoltaPTModelGroup("Diodes", VMT_D) );
  mDiodeGroup->models.push_back( nonBuiltinModel( VoltaPTModelPtr(new VoltaPTModel(VMT_D, "Diode", "fish.robo.test") ) ) );
  mDiodeGroup->models.push_back( nonBuiltinModel( VoltaPTModelPtr(new VoltaPTModel(VMT_D, "LED", "fish.robo.test") ) ) );
  VoltaPTModelPtr defaultDiode( new VoltaPTModel(VMT_D, "Diode") );
  defaultDiode->isMutable = false;
  mDiodeGroup->models.push_back(defaultDiode);

  mMOSFETGroup = VoltaPTModelGroupPtr( new VoltaPTModelGroup("MOSFETs", VMT_MOSFET) );
  mMOSFETGroup->models.push_back( nonBuiltinModel( VoltaPTModelPtr(new VoltaPTModel(VMT_MOSFET, "N-Channel", "fish.robo.test", "NMOS") ) ) );
  mMOSFETGroup->models.push_back( nonBuiltinModel( VoltaPTModelPtr(new VoltaPTModel(VMT_MOSFET, "N-Channel", "fish.robo.test2", "NMOS") ) ) );
  mMOSFETGroup->models.push_back( nonBuiltinModel( VoltaPTModelPtr(new VoltaPTModel(VMT_MOSFET, "Enhancement", "fish.robo.test", "PMOS") ) ) );
}


- (void) createTestElementGroups
{
  mBasicElementsGroup.name = "Basic Elements";
  mBasicElementsGroup.elements = {
    VoltaPTElement("R120", VMT_R, "Resistor IEC", ""),
    VoltaPTElement("R1k", VMT_R, "Resistor IEC", ""),
    VoltaPTElement("Node", VMT_Node, "Node", ""),
    VoltaPTElement("Ground", VMT_Ground, "Ground", "") };

  mTransistorElementsGroup.name = "Transistors";
  mTransistorElementsGroup.elements = {
    VoltaPTElement("MOS1", VMT_MOSFET, "N-Channel", "fish.robo.test"),
    VoltaPTElement("JFat", VMT_JFET, "N-JFET", "fish.robo.test") };

  mMeterElementsGroup.name = "Power Meters";
  mMeterElementsGroup.elements = {
    VoltaPTElement("VM1", VMT_METER, "DC Voltmeter", "fish.robo.test"),
    VoltaPTElement("IM2", VMT_METER, "AC Voltmeter", "fish.robo.test") };
}


- (void) createTestSubcircuits
{
  mOperationalAmp = VoltaPTModelPtr( new VoltaPTModel( VMT_SUBCKT, "Operational Amplifier" ) );
  mDifferentialAmp = VoltaPTModelPtr( new VoltaPTModel( VMT_SUBCKT, "Differential Amplifier" ) );
  mFlipFlop = VoltaPTModelPtr( new VoltaPTModel( VMT_SUBCKT, "FlipFlop" ) );
}


- (void) addTestModelGroups
{
  mData.addModelGroup(mResistorGroup);
  mData.addModelGroup(mDiodeGroup);
  mData.addModelGroup(mMOSFETGroup);
}


- (void) addTestElementGroup:(VoltaPTElementGroup const &)group
{
  mData.createElementGroup(group.name);
  for ( VoltaPTElement const & element : group.elements )
  {
    mData.addElement(element, group.name);
  }
}


- (void) addTestElementGroups
{
  [self addTestElementGroup:mBasicElementsGroup];
  [self addTestElementGroup:mTransistorElementsGroup];
  [self addTestElementGroup:mMeterElementsGroup];
}


- (void) addTestSubcircuits
{
  mData.addSubcircuit(mOperationalAmp);
  mData.addSubcircuit(mDifferentialAmp);
  mData.addSubcircuit(mFlipFlop);
}


- (void) runThreadSafetyTestForBlock:(void(^)(void))block
{
  dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_group_t asyncGroup = dispatch_group_create();

  size_t const threadCount = 5;
  size_t const repeats = 1000;

  void(^testBlock)(void) = ^{
    for ( size_t i = 0; i < repeats; i++ )
    {
      block();
    }
  };

  for ( size_t t = 0; t < threadCount; t++ )
  {
    dispatch_group_async( asyncGroup, globalQueue, testBlock );
  }

#if 0
  static int64_t const oneSecondInNanoSeconds = 1000000000;
  dispatch_group_wait(asyncGroup, dispatch_time(0, oneSecondInNanoSeconds));
#else
  dispatch_group_wait(asyncGroup, DISPATCH_TIME_FOREVER);
#endif
  dispatch_release(asyncGroup);
}


@end
