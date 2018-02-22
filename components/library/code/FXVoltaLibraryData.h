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

#import "VoltaPersistentTypes.h"
#import <vector>
#import <set>
#import <mutex>

enum class FXVoltaLibrarySearchStrategy
{
  Undefined = -1,         // Search result is undefined.
  MatchAll,               // All given attributes must be matched exactly
  DefaultModelForType,    // The default model for the given type, ignoring other attributes. Must be a built-in model.
  IgnoreVendor,           // The first model matching all attributes except the vendor ID
};


enum class FXVoltaLibraryItemAddingPolicy
{
  Undefined = -1,
  ReplaceOlderVersion,  // If an older version of the item already exists in the library, replace it. Otherwise don't add.
  RenameNewItem,        // If the item already exists then add the new item after giving it a unique name.
};


class FXVoltaLibraryData
{
public:
  void clearAll();
  void clearSubcircuits();
  void clearElementGroups();
  void clearModelGroups();

  void lockModels();
  void unlockModels();

  void lockElements();
  void unlockElements();

  void lockSubcircuits();
  void unlockSubcircuits();

  /// Adds the given model to the model groups if no model with the same type exists.
  /// A group with type VMT_Unknown is not added.
  /// @return true if a new group was created, false if there was an existing group with the same type.
  bool addModelGroup(VoltaPTModelGroupPtr group);

  size_t numModelGroups();

  void iterateModelGroups( void(^)(VoltaPTModelGroupPtr group, BOOL* stop) );

  /// Adds a model to the group with matching type.
  /// @return true if the model could be added to a group, otherwise false.
  /// @post A group may contain only one model with a certain signature (i.e., type + name + vendor)
  bool addModel(VoltaPTModelPtr model, FXVoltaLibraryItemAddingPolicy policy = FXVoltaLibraryItemAddingPolicy::Undefined);

  void addLibraryModels(VoltaPTLibraryPtr library, FXString const & source, bool isMutable);

  /// @return true if the model could be found and removed, otherwise false.
  bool removeModel(VoltaPTModelPtr model);

  /// @return the models that were removed
  VoltaPTModelPtrVector removeNonBuiltInModels();

  /// @return true if the model could be renamed, false if it couldn't because of a name collision.
  bool renameModel( VoltaPTModelPtr model, FXString const & newName );

  /// Sets the vendor string of the given models to the given string
  /// @return true if the vendor string of at least one model was changed, false otherwise (for example, if changing the vendor would cause a collision with existing models).
  bool setVendorString( VoltaPTModelPtrVector const & models, FXString const & newVendorString );

  VoltaPTModelPtr findModel(VoltaModelType type, FXString const & name = "", FXString const & vendor = "", FXVoltaLibrarySearchStrategy strategy = FXVoltaLibrarySearchStrategy::DefaultModelForType);

  /// Convenience method, which finds the default model for the given type
  VoltaPTModelPtr defaultModelForType(VoltaModelType type);

  /// @return the number of models in the model group with the given type.
  /// If the given type is VMT_Unknown then all models in all groups are counted.
  size_t numModels(VoltaModelType type = VMT_Unknown);

  /// @return the (unique) name of the created group.
  /// @param proposedGroupName the proposed group name
  FXString createElementGroup( FXString const & proposedGroupName );

  /// Creates a deep copy of the element group with the given name.
  /// If no group with the given name exists this will behave like createElementGroup.
  /// @return the (unique) name of the created group.
  /// @param existingGroupName the name of the element group of which a copy will be created
  FXString copyElementGroup( FXString const & existingGroupName );

  /// @return true if the element group with the given name could be found and removed, otherwise false.
  bool removeElementGroup( FXString const & groupName );

  /// @return true if the group with the given name could be found and renamed, false if it could not be found or the new name collides with another group name.
  bool renameElementGroup( FXString const & groupName, FXString const & newName );

  /// Reorders the list of element groups by moving the groups at the given indexes to the given index position.
  /// @return true if the groups were moved successfully, false if there was a problem.
  /// @param groupIndexes the indexes of the groups to be moved
  /// @param insertionIndex index that is valid for the state of the list before groups are moved
  bool moveElementGroups( std::set<unsigned> const & groupIndexes, unsigned insertionIndex );

  /// @return true if an element group with the given name exists, false otherwise.
  bool hasElementGroup( FXString const & groupName );

  size_t numElementGroups();

  /// Iterates over all element groups and calls the given block for each group.
  /// Group contents can not be changed while iterating. Use the other methods for editing.
  void iterateElementGroups( void(^)(VoltaPTElementGroup const & group, BOOL* stop) );

  /// @return The unique name of the element that was added to the group with the given name, or empty string if the group does not exist.
  /// Note: Also return true if the element already exists in the group with the given name.
  FXString addElement( VoltaPTElement const & element, FXString const & groupName );

  /// @return true if successful, false otherwise.
  /// @param groupName the name of the elements group in which to insert the given elements
  /// @param insertionIndex the position at which the elements will be inserted
  /// @param dueToInternalReordering whether the inserted elements originate from the group they are inserted in.
  bool insertElements( VoltaPTElementVector const & elements, FXString const & groupName, unsigned insertionIndex, bool dueToInternalReordering );

  /// @param elementName the current name of the element
  /// @param groupName the name of the group that contains the element to be renamed
  /// @param newElementName the new name of the element
  /// @return false if the element could not be found or if another element in the same group already uses the same name
  bool renameElement( FXString const & elementName, FXString const & groupName, FXString const & newElementName );

  /// @return true if the element could be found and removed from the group with the given name
  /// Note, that, element names must be unique within an element group.
  bool removeElement( FXString const & elementName, FXString const & groupName );

  /// Sets the given properties of the given element in the given group.
  /// Ignores properties which are not supported by the given element type.
  /// @return the number of properties that successfully changed or set.
  size_t setElementProperties(FXString const & elementName, FXString const & groupName, VoltaPTPropertyVector const & properties);

  bool hasElementWithModel(VoltaPTModelPtr model);

  /// @return true if the given subcircuit was added, otherwise false.
  bool addSubcircuit( VoltaPTModelPtr subcircuit, FXVoltaLibraryItemAddingPolicy policy = FXVoltaLibraryItemAddingPolicy::Undefined );

  /// @return true if the given subcircuit was found and removed, otherwise false.
  bool removeSubcircuit( VoltaPTModelPtr subcircuit );

  size_t numSubcircuits();

  void iterateSubcircuits( void(^)(VoltaPTModelPtr subcircuit, BOOL* stop) );

private:
  /// Groups of built-in (bundled) and user-defined models, by type.
  VoltaPTModelGroupPtrVector mModelGroups;
  
  /// User-defined groups of schematic elements
  std::vector<VoltaPTElementGroup> mElementGroups;
  
  /// Subcircuits are interpreted as device models of type VMT_SUBCKT
  /// where some of the necessary data is stored in the meta data fields and the
  /// property fields of the model.
  ///
  ///   VoltaPTSubcircuitData.name       --->   VoltaPTModel.name
  ///   VoltaPTSubcircuitData.vendor     --->   VoltaPTModel.vendor
  ///   VoltaPTSubcircuitData.shape      --->   VoltaPTModel.shape
  ///   VoltaPTSubcircuitData.pins       --->   VoltaPTMode.pins
  ///   VoltaPTSubcircuitData.metaData   --->   VoltaPTModel.metaData
  ///   VoltaPTSubcircuitData.externals  --->   VoltaPTModel.properties
  ///   path to subcircuit file          --->   VoltaPTModel.source
  ///
  /// The pin-to-node mapping (externals) of the subcircuit is stored such that
  /// the pin name is assigned to the name field of the property, and the node
  /// name assigned to the value of the property, where the pin name must be
  /// correspond to the name of one the pins in VoltaPTSubcircuitData.pins.
  VoltaPTModelPtrVector mSubcircuits;

  std::recursive_mutex mModelsLock;
  std::recursive_mutex mElementsLock;
  std::recursive_mutex mSubcircuitsLock;

  /// @return whether the library contains the given model
  /// @param mustBeSameInstance whether to check if the library contains the given model instance or an equivalent model.
  bool hasModel( VoltaPTModelPtr model, bool mustBeSameInstance = false );

  /// @return NULL if a group with the given name could not be found
  VoltaPTElementGroup* getElementGroupWithName(FXString const & groupName);

  /// Reorders the elements within a given group
  /// @param elements the elements to be moved
  /// @param groupName the name of the group in which the elements are to be reordered
  /// @param index the position at which to re-insert the moved elements
  /// @return true if successful, false otherwise
  bool moveElements( VoltaPTElementVector const & elements, FXString const & groupName, unsigned index, bool keepPreviousOrder );

  /// @param elements the elements to be inserted
  /// @return false if there was an error, true otherwise
  bool insertNewElements( VoltaPTElementVector const & elements, FXString const & groupName, unsigned insertionIndex );

  FXString generateUniqueModelName( VoltaModelType type, FXString const & baseName );

  FXString generateUniqueElementGroupName( FXString const & baseName );

  FXString generateUniqueElementName( FXString const & baseName, VoltaPTElementGroup const & elementGroup );
};
