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

#import "FXVoltaLibraryData.h"
#import "FXVoltaCircuitDomainAgent.h"
#import <algorithm>
#import <tuple>

typedef std::lock_guard<std::recursive_mutex> FXLOCK;


void FXVoltaLibraryData::clearAll()
{
  clearElementGroups();
  clearSubcircuits();
  clearModelGroups();
}


void FXVoltaLibraryData::clearSubcircuits()
{
  FXLOCK a(mSubcircuitsLock);
  mSubcircuits.clear();
}


void FXVoltaLibraryData::clearElementGroups()
{
  FXLOCK a(mElementsLock);
  mElementGroups.clear();
}


void FXVoltaLibraryData::clearModelGroups()
{
  FXLOCK a(mModelsLock);
  mModelGroups.clear();
}


#pragma mark --- Locks


void FXVoltaLibraryData::lockModels()        { mModelsLock.lock(); }
void FXVoltaLibraryData::unlockModels()      { mModelsLock.unlock(); }
void FXVoltaLibraryData::lockElements()      { mElementsLock.lock(); }
void FXVoltaLibraryData::unlockElements()    { mElementsLock.unlock(); }
void FXVoltaLibraryData::lockSubcircuits()   { mSubcircuitsLock.lock(); }
void FXVoltaLibraryData::unlockSubcircuits() { mSubcircuitsLock.unlock(); }


#pragma mark --- Model Groups


bool FXVoltaLibraryData::addModelGroup(VoltaPTModelGroupPtr group)
{
  bool result = false;
  FXLOCK l(mModelsLock);
  if ( (group.get() != nullptr) && (group->modelType != VMT_Unknown) )
  {
    bool groupWithSameTypeExists = false;
    for ( auto existingGroup : mModelGroups )
    {
      if ( existingGroup->modelType == group->modelType )
      {
        groupWithSameTypeExists = true;
        break;
      }
    }
    if ( !groupWithSameTypeExists )
    {
      mModelGroups.push_back(group);
      result = true;
    }
  }
  return result;
}


size_t FXVoltaLibraryData::numModelGroups()
{
  return mModelGroups.size();
}


void FXVoltaLibraryData::iterateModelGroups( void(^block)(VoltaPTModelGroupPtr group, BOOL* stop) )
{
  BOOL stop = NO;
  FXLOCK a(mModelsLock);
  for ( VoltaPTModelGroupPtr group : mModelGroups )
  {
    block( group, &stop );
    if ( stop )
      break;
  }
}


#pragma mark --- Models


bool FXVoltaLibraryData::addModel(VoltaPTModelPtr model, FXVoltaLibraryItemAddingPolicy policy)
{
  bool result = false;
  FXLOCK a(mModelsLock);
  if ( model.get() != nullptr )
  {
    for (VoltaPTModelGroupPtr group : mModelGroups)
    {
      if ( group->modelType == model->type )
      {
        bool modelAlreadyExists = false;
        VoltaPTModelPtrVector::iterator const itEnd = group->models.end();
        for ( auto it = group->models.begin(); it != itEnd; it++ )
        {
          VoltaPTModelPtr groupModel = *it;
          if ( *groupModel == *model )
          {
            modelAlreadyExists = true;
            if ( (policy == FXVoltaLibraryItemAddingPolicy::ReplaceOlderVersion)
              && (groupModel->revision < model->revision) )
            {
              it = group->models.insert(it, model);
              group->models.erase(++it);
              result = true;
            }
            else if ( policy == FXVoltaLibraryItemAddingPolicy::RenameNewItem )
            {
              model->name = generateUniqueModelName( model->type, model->name);
              if ( model->name != groupModel->name )
              {
                group->models.push_back( model );
                result = true;
              }
            }
            break;
          }
        }
        if ( !modelAlreadyExists )
        {
          group->models.push_back(model);
          result = true;
        }
        break;
      }
    }
  }
  return result;
}


void FXVoltaLibraryData::addLibraryModels(VoltaPTLibraryPtr library, FXString const & source, bool isMutable)
{
  if ( library.get() != nullptr )
  {
    library->modelGroup->isMutable = isMutable;
    for( VoltaPTModelPtr model : library->modelGroup->models )
    {
      model->isMutable = isMutable;
      model->source = source;
      addModel(model, FXVoltaLibraryItemAddingPolicy::ReplaceOlderVersion);
    }    
  }
}


bool FXVoltaLibraryData::removeModel(VoltaPTModelPtr model)
{
  bool result = false;
  if ( model.get() != nullptr )
  {
    FXLOCK a(mModelsLock);
    for ( VoltaPTModelGroupPtr group : mModelGroups )
    {
      if ( group->modelType == model->type )
      {
        for ( auto it = group->models.begin(); it != group->models.end(); )
        {
          if ( *(*it) == *model )
          {
            it = group->models.erase(it);
            result = true;
          }
          else
          {
            it++;
          }
        }
        break;
      }
    }
  }
  return result;
}


VoltaPTModelPtrVector FXVoltaLibraryData::removeNonBuiltInModels()
{
  FXLOCK a(mModelsLock);
  VoltaPTModelPtrVector result;
  for ( VoltaPTModelGroupPtr group : mModelGroups )
  {
    for ( auto it = group->models.begin(); it != group->models.end(); )
    {
      if ( !(*it)->source.empty() )
      {
        result.push_back(*it);
        it = group->models.erase(it);
      }
      else
      {
        it++;
      }
    }
  }
  return result;
}


bool FXVoltaLibraryData::renameModel( VoltaPTModelPtr model, FXString const & newName )
{
  bool result = false;
  if ( model.get() != nullptr )
  {
    FXLOCK m(mModelsLock);
    for ( VoltaPTModelGroupPtr modelGroup : mModelGroups )
    {
      if ( modelGroup->modelType == model->type )
      {
        bool foundModelWithSameNewName = false;
        VoltaPTModelPtr matchingModel;
        for ( VoltaPTModelPtr groupModel : modelGroup->models )
        {
          if ( groupModel->vendor == model->vendor )
          {
            if ( (matchingModel.get() == nullptr) && (groupModel->name == model->name) )
            {
              matchingModel = groupModel;
            }
            else if ( groupModel->name == newName )
            {
              foundModelWithSameNewName = true;
            }
          }
        }
        if ( (matchingModel.get() != nullptr) && !foundModelWithSameNewName )
        {
          if ( matchingModel->isMutable )
          {
            matchingModel->name = newName;
            result = true;
          }
        }
        break;
      }
    }
  }
  return result;
}


bool FXVoltaLibraryData::setVendorString( VoltaPTModelPtrVector const & givenModels, FXString const & newVendorString )
{
  bool result = false;
  FXLOCK m(mModelsLock);

  // Checking if the given models will conflict with existing models when their vendor strings are changed.
  bool conflictDetected = false;
  for ( VoltaPTModelPtr const & givenModel : givenModels )
  {
    if ( givenModel->vendor == newVendorString )
      continue;

    for ( auto & group : mModelGroups )
    {
      if ( group->modelType == givenModel->type )
      {
        for ( auto groupModel : group->models )
        {
          if ( (groupModel != givenModel)
              && (groupModel->name == givenModel->name)
              && (groupModel->vendor == newVendorString) )
          {
            conflictDetected = true;
            break;
          }
        }
        break;
      }
    }

    if ( conflictDetected )
      break;
  }

  if ( !conflictDetected )
  {
    for ( auto & givenModel : givenModels )
    {
      for ( auto & group : mModelGroups )
      {
        if ( group->modelType == givenModel->type )
        {
          for ( auto & existingModel : group->models )
          {
            if ( (existingModel.get() == givenModel.get())
              || (*existingModel == *givenModel) )
            {
              if ( existingModel->isMutable )
              {
                existingModel->vendor = newVendorString;
                result = true;
              }
              break;
            }
          }
          break;
        }
      }
    }
  }

  return result;
}


size_t FXVoltaLibraryData::numModels(VoltaModelType type)
{
  size_t result = 0;
  FXLOCK a(mModelsLock);
  for ( VoltaPTModelGroupPtr group : mModelGroups )
  {
    if ( (group->modelType == type) || (type == VMT_Unknown) )
    {
      result += group->models.size();
    }
  }
  return result;
}


VoltaPTModelPtr FXVoltaLibraryData::findModel(VoltaModelType targetType, FXString const & targetModelName, FXString const & targetVendor, FXVoltaLibrarySearchStrategy strategy)
{
  VoltaPTModelPtr result;
  FXLOCK a(mModelsLock);

  for (VoltaPTModelGroupPtr modelGroup : mModelGroups)
  {
    if ( modelGroup->modelType == targetType )
    {
      for (VoltaPTModelPtr currentModel : modelGroup->models)
      {
        if ( strategy == FXVoltaLibrarySearchStrategy::Undefined )
        {
          result = currentModel;
        }
        else if ( strategy == FXVoltaLibrarySearchStrategy::DefaultModelForType )
        {
          if ( !(currentModel->isMutable) && currentModel->vendor.empty() )
          {
            result = currentModel;
          }
        }
        else if ( currentModel->name == targetModelName )
        {
          if ( strategy == FXVoltaLibrarySearchStrategy::IgnoreVendor )
          {
            result = currentModel;
          }
          else if ( (strategy == FXVoltaLibrarySearchStrategy::MatchAll) && (currentModel->vendor == targetVendor) )
          {
            result = currentModel;
          }
        }
        if ( result.get() != nullptr )
          break;
      }
      break;
    }
  }

  return result;
}


VoltaPTModelPtr FXVoltaLibraryData::defaultModelForType(VoltaModelType type)
{
  return findModel(type);
}


#pragma mark --- Element Groups


FXString FXVoltaLibraryData::createElementGroup( FXString const & proposedGroupName )
{
  FXLOCK a(mElementsLock);
  FXString groupName = generateUniqueElementGroupName(proposedGroupName);
  mElementGroups.push_back( VoltaPTElementGroup(groupName) );
  return groupName;
}


FXString FXVoltaLibraryData::copyElementGroup( FXString const & existingGroupName )
{
  FXLOCK a(mElementsLock);
  FXString groupName = generateUniqueElementGroupName(existingGroupName);
  VoltaPTElementGroup copiedGroup(groupName);

  for ( VoltaPTElementGroup const & sourceGroup : mElementGroups )
  {
    if ( sourceGroup.name == existingGroupName )
    {
      copiedGroup.elements.resize(sourceGroup.elements.size());
      std::copy(sourceGroup.elements.begin(), sourceGroup.elements.end(), copiedGroup.elements.begin());
      break;
    }
  }

  mElementGroups.push_back( copiedGroup );
  return groupName;
}


bool FXVoltaLibraryData::removeElementGroup( FXString const & groupName )
{
  bool result = false;
  FXLOCK a(mElementsLock);
  for ( auto it = mElementGroups.begin(); it != mElementGroups.end(); it++ )
  {
    if ( it->name == groupName )
    {
      mElementGroups.erase(it);
      result = true;
      break;
    }
  }
  return result;
}


bool FXVoltaLibraryData::renameElementGroup( FXString const & groupName, FXString const & newName )
{
  bool result = false;
  FXLOCK m(mElementsLock);
  bool nameCollision = false;
  VoltaPTElementGroup* targetGroup = NULL;
  for ( VoltaPTElementGroup & group : mElementGroups )
  {
    if ( group.name == newName )
    {
      nameCollision = true;
    }
    if ( group.name == groupName )
    {
      targetGroup = &group;
    }
  }
  if ( (targetGroup != NULL) && !nameCollision )
  {
    targetGroup->name = newName;
    result = true;
  }
  return result;
}


bool FXVoltaLibraryData::moveElementGroups( std::set<unsigned> const & groupIndexes, unsigned insertionIndex )
{
  bool result = false;
  FXLOCK m(mElementsLock);
  std::vector<VoltaPTElementGroup> movedGroups;
  unsigned insertionOffset = 0;
  // Sets are sorted in increasing order. So we need to iterate in reverse order to erase items.
  auto const itEnd = groupIndexes.rend();
  for ( auto it = groupIndexes.rbegin(); it != itEnd; it++ )
  {
    unsigned groupIndex = *it;
    if ( groupIndex < mElementGroups.size() )
    {
      movedGroups.push_back(mElementGroups.at(groupIndex));
      mElementGroups.erase(mElementGroups.begin() + groupIndex);
      if ( groupIndex < insertionIndex )
      {
        insertionOffset++;
      }
    }
  }
  if ( !movedGroups.empty() )
  {
    std::vector<VoltaPTElementGroup>::iterator insertionIt;
    if ( insertionIndex >= mElementGroups.size() )
    {
      insertionIt = mElementGroups.end();
    }
    else if ( insertionIndex > insertionOffset )
    {
      insertionIt = mElementGroups.begin() + insertionIndex - insertionOffset;
    }
    else
    {
      insertionIt = mElementGroups.begin();
    }
    mElementGroups.insert(insertionIt, movedGroups.rbegin(), movedGroups.rend());
    result = true;
  }
  return result;
}


bool FXVoltaLibraryData::hasElementGroup( FXString const & groupName )
{
  bool result = false;
  FXLOCK m(mElementsLock);
  for ( VoltaPTElementGroup const & elementGroup : mElementGroups )
  {
    if ( elementGroup.name == groupName )
    {
      result = true;
      break;
    }
  }
  return result;
}


size_t FXVoltaLibraryData::numElementGroups()
{
  return mElementGroups.size();
}


void FXVoltaLibraryData::iterateElementGroups( void(^block)(VoltaPTElementGroup const &, BOOL*) )
{
  BOOL stop = NO;
  FXLOCK a(mElementsLock);
  for ( VoltaPTElementGroup const & group : mElementGroups )
  {
    block( group, &stop );
    if ( stop )
      break;
  }
}


#pragma mark --- Elements


FXString FXVoltaLibraryData::addElement( VoltaPTElement const & element, FXString const & groupName )
{
  FXString result;
  FXLOCK a(mElementsLock);
  for ( VoltaPTElementGroup & group : mElementGroups )
  {
    if ( group.name == groupName )
    {
      result = generateUniqueElementName(element.name, group);
      if ( result == element.name )
      {
        group.elements.push_back(element);
      }
      else
      {
        VoltaPTElement copiedElement = element;
        copiedElement.name = result;
        group.elements.push_back(copiedElement);
      }
      break;
    }
  }
  return result;
}


bool FXVoltaLibraryData::insertElements( VoltaPTElementVector const & elements, FXString const & groupName, unsigned insertionIndex, bool dueToInternalReordering )
{
  bool result = false;
  FXLOCK m(mElementsLock);
  if ( getElementGroupWithName(groupName) != NULL )
  {
    if ( dueToInternalReordering )
    {
      result = moveElements(elements, groupName, insertionIndex, true);
    }
    else
    {
      result = insertNewElements(elements, groupName, insertionIndex);
    }
  }
  return result;
}


bool FXVoltaLibraryData::renameElement( FXString const & elementName, FXString const & groupName, FXString const & newElementName )
{
  bool result = false;
  FXLOCK m(mElementsLock);
  for ( auto & group : mElementGroups )
  {
    if ( group.name == groupName )
    {
      VoltaPTElement* targetElement = NULL;
      bool nameCollision = false;
      for ( auto & element : group.elements )
      {
        if ( element.name == elementName )
        {
          if (targetElement == NULL)
          {
            targetElement = &element;
          }
        }
        else if ( element.name == newElementName )
        {
          nameCollision = true;
          break;
        }
      }
      if ( (targetElement != NULL) && !nameCollision )
      {
        targetElement->name = newElementName;
        result = true;
      }
    }
  }
  return result;
}


bool FXVoltaLibraryData::removeElement( FXString const & elementName, FXString const & groupName )
{
  bool result = false;
  FXLOCK a(mElementsLock);
  for ( VoltaPTElementGroup & group : mElementGroups )
  {
    if ( group.name == groupName )
    {
      VoltaPTElementVector::iterator const itEnd = group.elements.end();
      for ( auto it = group.elements.begin(); it != itEnd; it++ )
      {
        if ( it->name == elementName )
        {
          group.elements.erase(it);
          result = true;
          break;
        }
      }
      break;
    }
  }
  return result;
}


size_t FXVoltaLibraryData::setElementProperties(FXString const & elementName, FXString const & groupName, VoltaPTPropertyVector const & properties)
{
  size_t result = 0;
  FXLOCK m(mElementsLock);
  for ( VoltaPTElementGroup & group : mElementGroups )
  {
    if ( group.name == groupName )
    {
      for ( VoltaPTElement & element : group.elements )
      {
        if ( element.name == elementName )
        {
          VoltaPTModelPtr model = findModel(element.type, element.modelName, element.modelVendor, FXVoltaLibrarySearchStrategy::MatchAll);
          if ( model.get() != nullptr )
          {
            VoltaPTPropertyVector const allowedProperties = FXVoltaCircuitDomainAgent::circuitElementParametersForModel(model);
            for ( VoltaPTProperty const & newProperty : properties )
            {
              if ( std::find(allowedProperties.begin(), allowedProperties.end(), newProperty) != allowedProperties.end() )
              {
                VoltaPTPropertyVector::iterator it = std::find(element.properties.begin(), element.properties.end(), newProperty);
                if ( it != element.properties.end() )
                {
                  it->value = newProperty.value;
                }
                else
                {
                  element.properties.push_back( newProperty );
                }
                result++;
              }
            }
          }
          break;
        }
      }
      break;
    }
  }
  return result;
}


bool FXVoltaLibraryData::hasElementWithModel(VoltaPTModelPtr model)
{
  bool result = false;
  if ( model.get() != nullptr )
  {
    FXLOCK m(mModelsLock);
    for ( VoltaPTElementGroup const & elementGroup : mElementGroups )
    {
      for ( VoltaPTElement const & element : elementGroup.elements )
      {
        if ( (element.modelName == model->name) && (element.modelVendor == model->vendor) )
        {
          result = true;
          break;
        }
      }
      if ( result )
        break;
    }
  }
  return result;
}


#pragma mark --- Subcircuits


bool FXVoltaLibraryData::addSubcircuit( VoltaPTModelPtr subcircuit, FXVoltaLibraryItemAddingPolicy policy )
{
  bool result = false;
  if ( (subcircuit.get() != nullptr) && (subcircuit->type == VMT_SUBCKT) )
  {
    FXLOCK a(mSubcircuitsLock);
    bool foundExistingSubcircuit = false;
    auto const itEnd = mSubcircuits.end();
    for ( auto it = mSubcircuits.begin(); it != itEnd; it++ )
    {
      VoltaPTModelPtr existingSubcircuit = *it;
      if ( (existingSubcircuit->name == subcircuit->name)
        && (existingSubcircuit->vendor == subcircuit->vendor) )
      {
        foundExistingSubcircuit = true;
        if ( (policy == FXVoltaLibraryItemAddingPolicy::ReplaceOlderVersion)
          && (existingSubcircuit->revision < subcircuit->revision) )
        {
          it = mSubcircuits.insert(it, subcircuit); // insert before existing item (with old revision)
          mSubcircuits.erase(++it); // erase item with old revision
          result = true;
        }
        break;
      }
    }
    if ( !foundExistingSubcircuit )
    {
      mSubcircuits.push_back(subcircuit);
      result = true;
    }
  }
  return result;
}


bool FXVoltaLibraryData::removeSubcircuit( VoltaPTModelPtr subcircuit )
{
  bool result = false;
  if ( (subcircuit.get() != nullptr) && (subcircuit->type == VMT_SUBCKT) )
  {
    FXLOCK a(mSubcircuitsLock);
    auto const itEnd = mSubcircuits.end();
    for ( auto it = mSubcircuits.begin(); it != itEnd; it++ )
    {
      if ( *(*it) == *subcircuit )
      {
        mSubcircuits.erase(it);
        result = true;
        break;
      }
    }
  }
  return result;
}


size_t FXVoltaLibraryData::numSubcircuits()
{
  return mSubcircuits.size();
}


void FXVoltaLibraryData::iterateSubcircuits( void(^block)(VoltaPTModelPtr, BOOL*) )
{
  BOOL stop = NO;
  FXLOCK a(mSubcircuitsLock);
  for ( VoltaPTModelPtr subcircuit : mSubcircuits )
  {
    block( subcircuit, &stop );
    if ( stop )
      break;
  }
}


#pragma mark Private
// No mutex locking needed for private methods.


bool FXVoltaLibraryData::hasModel( VoltaPTModelPtr model, bool mustBeSameInstance )
{
  bool result = false;
  for ( auto modelGroup : mModelGroups )
  {
    if ( modelGroup->modelType == model->type )
    {
      for ( auto existingModel : modelGroup->models )
      {
        if ( (mustBeSameInstance && (existingModel.get() == model.get()))
          || (!mustBeSameInstance && (*existingModel == *model)) )
        {
          result = true;
          break;
        }
      }
      break;
    }
  }
  return result;
}


VoltaPTElementGroup* FXVoltaLibraryData::getElementGroupWithName(const FXString &groupName)
{
  for ( VoltaPTElementGroup & group : mElementGroups )
  {
    if ( group.name == groupName )
    {
      return &group;
    }
  }
  return NULL;
}


bool FXVoltaLibraryData::insertNewElements( VoltaPTElementVector const & elements, FXString const & groupName, unsigned insertionIndex )
{
  BOOL result = false;
  if ( !elements.empty() )
  {
    for ( VoltaPTElementGroup & elementGroup : mElementGroups )
    {
      if ( elementGroup.name == groupName )
      {
        for ( auto it = elements.rbegin(); it != elements.rend(); it++ )
        {
          VoltaPTElement element = *it;
          element.name = generateUniqueElementName(element.name, elementGroup);
          if ( insertionIndex < elementGroup.elements.size() )
          {
            elementGroup.elements.insert(elementGroup.elements.begin() + insertionIndex, element);
          }
          else
          {
            elementGroup.elements.push_back(element);
          }
        }
        result = true;
        break;
      }
    }
  }
  return result;
}


static void removeDuplicateElements( VoltaPTElementVector & elements )
{
  size_t currentIndex = 0;
  while ( currentIndex < elements.size() )
  {
    VoltaPTElement & element = elements.at(currentIndex);
    auto it = std::find( elements.begin() + currentIndex + 1, elements.end(), element );
    while (it != elements.end())
    {
      elements.erase(it);
      it = std::find( elements.begin() + currentIndex + 1, elements.end(), element );
    }
    currentIndex++;
  }
}


bool FXVoltaLibraryData::moveElements( VoltaPTElementVector const & givenElements, FXString const & groupName, unsigned insertionIndex, bool keepPreviousOrder )
{
  bool result = false;

  if ( !givenElements.empty() )
  {
    VoltaPTElementGroup* targetGroup = getElementGroupWithName(groupName);
    if ( targetGroup != NULL )
    {
      VoltaPTElementVector elements = givenElements;
      removeDuplicateElements(elements);

      // Finding the offset by which to reduce the insertion index after models have been removed from the target group.
      NSUInteger numberOfElementsAtIndexesBeforeGivenIndex = 0;
      auto itToIndex = targetGroup->elements.begin() + insertionIndex;
      for ( VoltaPTElement const & elementToBeMoved : elements )
      {
        if ( std::find(targetGroup->elements.begin(), itToIndex, elementToBeMoved) != itToIndex )
        {
          numberOfElementsAtIndexesBeforeGivenIndex++;
        }
      }

      // Ordering the elements like they are in the group.
      if ( keepPreviousOrder )
      {
        VoltaPTElementVector unorderedElements = elements;
        elements.clear();
        for ( VoltaPTElement const & groupElement : targetGroup->elements )
        {
          for ( VoltaPTElement const & givenElement : unorderedElements )
          {
            if ( givenElement == groupElement )
            {
              elements.push_back(givenElement);
            }
          }
        }
      }

      // Removing the given elements from the target group
      for ( VoltaPTElement const & movedElement : elements )
      {
        auto it = std::find(targetGroup->elements.begin(), targetGroup->elements.end(), movedElement);
        if ( it != targetGroup->elements.end() )
        {
          targetGroup->elements.erase(it);
        }
        else
        {
          DebugLog(@"All of the given elements should exist in the given element group");
        }
      }

      // Inserting the moved elements at the position given by insertionIndex
      int effectiveIndex = (int)insertionIndex - (int)numberOfElementsAtIndexesBeforeGivenIndex;
      assert( effectiveIndex >= 0 && "Wrong index value" );
      targetGroup->elements.insert( targetGroup->elements.begin() + effectiveIndex, elements.begin(), elements.end() );

      result = true;
    }
  }

  return result;
}


/// @return a tuple with the following components:
///   1) the base component of the input string, without the suffix which (possibly) represents an integer number
///   2) the numeric value of a number string that was appended to the base component of the input string
/// If the returned suffix number is not a positive integer number then no suffix number could be extracted.
static std::tuple<FXString, unsigned> extractBaseString( FXString const & inputString )
{
  std::tuple<FXString, unsigned> result = std::make_tuple(inputString, 0);

  NSUInteger const baseComponentLength = inputString.length();

  if ( baseComponentLength > 0 )
  {
    // Decomposing the base name in a locale-aware manner.
    NSMutableString* lastComponent = [[NSMutableString alloc] initWithCapacity:baseComponentLength];
    NSString* tmpString = [NSString stringWithString:(__bridge NSString*)inputString.cfString()];

    [tmpString enumerateSubstringsInRange:NSMakeRange(0, baseComponentLength) options:NSStringEnumerationByWords usingBlock:
      ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
      {
        if ( (substringRange.location > 0) && (substringRange.location + substringRange.length >= baseComponentLength) )
        {
          [lastComponent appendString:substring];
          *stop = YES;
        }
      }
    ];

    try
    {
      unsigned numValue = (unsigned) FXString((__bridge CFStringRef)lastComponent).extractLong();
      if ( numValue > 0 )
      {
        std::get<1>(result) = numValue;
      }
      tmpString = [tmpString substringToIndex:[tmpString length] - [lastComponent length]];
      tmpString = [tmpString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    catch (std::exception & e) {}

    std::get<0>(result) = (__bridge CFStringRef)tmpString;
    FXRelease(lastComponent)
  }

  return result;
}


/// @return a unique name by appending a locale-aware number to the end of the given baseName
/// @param testBlock a function that returns YES if an item with the given name exists
static FXString generateUniqueName( FXString const & baseName, bool(^testNameExists)(FXString const &) )
{
  FXString baseComponent = baseName;
  baseComponent.trimWhitespace();

  FXString result = baseComponent;
  if ( testNameExists(result) )
  {
    std::tuple<FXString, unsigned> extractionResult = extractBaseString(baseComponent);
    FXString const baseString = std::get<0>(extractionResult);
    unsigned baseSuffixNumber = std::get<1>(extractionResult);
    NSUInteger counter = (baseSuffixNumber > 0) ? (baseSuffixNumber + 1) : 2;
    NSUInteger insanelyLargeNumberOfTries = 5000;
    do
    {
      CFNumberRef number = CFNumberCreate(NULL, kCFNumberNSIntegerType, &counter);
      FXString newSuffixString(number);
      CFRelease(number);
      result = baseString + " " + newSuffixString;
      counter++;
      insanelyLargeNumberOfTries--;

      if ( !testNameExists(result) )
        break;
    }
    while (insanelyLargeNumberOfTries > 0);

    if ( insanelyLargeNumberOfTries == 0 )
    {
      DebugLog( @"Ran out of number suffixes for creating a unique name. This is not normal. Creating UUID as last resort." );
      CFUUIDRef uniqueID = CFUUIDCreate(kCFAllocatorDefault);
      CFStringRef uniqueString = CFUUIDCreateString(kCFAllocatorDefault, uniqueID);
      result = FXString(uniqueString);
      CFRelease(uniqueString);
      CFRelease(uniqueID);
    }
  }

  return result;
}



FXString FXVoltaLibraryData::generateUniqueModelName( VoltaModelType type, FXString const & baseName )
{
  FXString result = baseName;

  for ( VoltaPTModelGroupPtr group : mModelGroups )
  {
    if ( group->modelType == type )
    {
      result = generateUniqueName( baseName, ^(FXString const & candidateName) {
        bool nameAlreadyExists = false;
        for (VoltaPTModelPtr existingModel : group->models)
        {
          if (existingModel->name == candidateName)
          {
            nameAlreadyExists = true;
            break;
          }
        }
        return nameAlreadyExists;
      });
    }
  }

  return result;
}


FXString FXVoltaLibraryData::generateUniqueElementGroupName( FXString const & baseName )
{
  FXString result = baseName;

  result = generateUniqueName( baseName, ^(FXString const & candidateName) {
    bool nameAlreadyExists = false;
    for (VoltaPTElementGroup const & existingGroup : mElementGroups)
    {
      if (existingGroup.name == candidateName)
      {
        nameAlreadyExists = true;
        break;
      }
    }
    return nameAlreadyExists;
  });

  return result;
}


FXString FXVoltaLibraryData::generateUniqueElementName( FXString const & baseName, VoltaPTElementGroup const & elementGroup )
{
  FXString result = baseName;

  result = generateUniqueName( baseName, ^bool(const FXString & candidateName) {
    bool nameAlreadyExists = false;
    for ( VoltaPTElement const & element : elementGroup.elements )
    {
      if ( element.name == candidateName )
      {
        nameAlreadyExists = true;
        break;
      }
    }
    return nameAlreadyExists;
  });

  return result;
}


