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
#pragma once

#import <VoltaCore/VoltaPersistentTypes.h>
#import "FXShape.h"
#import "FXString.h"
#include <utility>

@protocol VoltaLibraryObserver;


/// Represents a library of device models and subcircuits.
@protocol VoltaLibrary <NSObject>

#pragma mark Thread-safe Editing

/// Changes are noted and notifications are sent later, when editing ends.
- (void) beginEditingPalette;

/// Notifies any listeners if elements or element groups have changed.
- (void) endEditingPalette;

- (void) beginEditingModels;

- (void) endEditingModels;

#pragma mark Iterating Over Items

- (void) iterateOverModelGroupsByApplyingBlock:(void(^)(VoltaPTModelGroupPtr, BOOL*))block;

- (void) iterateOverElementGroupsByApplyingBlock:(void(^)(VoltaPTElementGroup const &, BOOL*))block;

- (void) iterateOverSubcircuitsByApplyingBlock:(void(^)(VoltaPTModelPtr, BOOL*))block;

#pragma mark Model Shapes

/// Creates the shape for the given model and add it to the internal registry.
/// @param isDefaultShape If YES the created shape will be the default shape for all models of the same type.
- (void) createAndStoreShapeForModel:(VoltaPTModelPtr)model
                  makeDefaultForType:(BOOL)isDefaultShape;

/// @return The shape for the model with given name and type.
/// If no model with matching name is found it will return the default shape for the given type.
- (id<FXShape>) shapeForModelType:(VoltaModelType)type
                             name:(NSString*)modelName
                           vendor:(NSString*)modelVendor;

#pragma mark Notifications

- (void) addObserver:(id<VoltaLibraryObserver>)observer;

- (void) removeObserver:(id<VoltaLibraryObserver>)observer;

#pragma mark Elements and Element Groups

/// Creates an element group and adds it to the library.
/// @return a new group with a unique name
- (FXString) createElementGroup;

/// Creates a copy of the given element group with the given name.
/// @pre an element group with the given name must exist in the library
/// @return the name of the new element group
- (FXString) copyElementGroup:(FXString const &)groupName;

/// Reorders element groups by first removing the items at the given indexes,
/// then inserting before the item at the given index position.
/// @return YES if the groups were inserted successfully, NO if there was a problem.
/// @param insertionIndex index that is valid for the state of the list before items are removed
- (BOOL) moveElementGroupsAtIndexes:(NSIndexSet*)itemIndexes
       inFrontOfElementGroupAtIndex:(NSUInteger)insertionIndex;

/// Removes the element groups with the given names.
/// @return YES if all groups could be removed, NO otherwise.
- (BOOL) removeElementGroups:(FXStringVector const &)elementGroupsToRemove;

/// @return YES if the group could be renamed, NO otherwise.
/// Since group names need to be unique the actual assigned name may not be the proposed name.
/// You should therefore read the group's name after the method returns with YES.
- (BOOL) renameElementGroup:(FXString const &)groupName
               proposedName:(FXString const &)newName;

/// Appends the given elements to the group with the given name
/// @return true if the elements were added successfully, false otherwise
/// @post names of the elements may have been altered because of uniquing
- (BOOL) addElements:(VoltaPTElementVector const &)elements
             toGroup:(FXString const &)groupName;

/// The models will be added to the end of the group if the given index is either
/// less than zero or greater than the group's size.
/// @return YES if the models were inserted successfully, NO if there was a problem.
/// @param reordering Should be YES if the given models are already in the group and should be moved to the given index
- (BOOL) insertElements:(VoltaPTElementVector const &)elements
              intoGroup:(FXString const &)groupName
                atIndex:(NSInteger)index
        dueToReordering:(BOOL)reordering;

/// Removes the elements with the given names from the groups with the given names.
/// Note, that, elements have unique names within their element group.
/// @return YES if all the elements were removed, NO otherwise
/// @param elementsAndGroups an vector of a pair of names, where the first name is the element name and the second name is the name of the containing group
- (BOOL) removeElements:(std::vector< std::pair<FXString,FXString> > const &)elementsAndGroups;

/// @return YES if the element with the given name was renamed successfully
- (BOOL) renameElement:(FXString const &)elementName
               inGroup:(FXString const &)groupName
                toName:(FXString const &)newName;

/// @return YES if the properties of the element with the given name were successfully updated.
- (BOOL) updateProperties:(NSDictionary*)properties
                ofElement:(FXString const &)elementName
                  inGroup:(FXString const &)groupName;

#pragma mark Models

/// Removes the given models from the library.
/// @return the models that were successfully removed
- (VoltaPTModelPtrSet) removeModels:(VoltaPTModelPtrSet const &)modelsToRemove;

/// @param templateModel The model of which a copy shall be created
/// @return the created model
/// @post adds a new model to the model group of the same type
- (VoltaPTModelPtr) createModelFromTemplate:(VoltaPTModelPtr)templateModel;

/// @return YES if the model could be renamed successfully
- (BOOL) renameModel:(VoltaPTModelPtr)model
              toName:(FXString const &)newName;

- (void) setPropertyValueOfModel:(VoltaPTModelPtr)model
                    propertyName:(FXString const &)name
                   propertyValue:(FXString const &)newValue;

/// @return YES if the vendor strings of all given models could be changed
- (BOOL) setVendor:(FXString const &)vendorString
         forModels:(VoltaPTModelPtrVector const &)models;

/// @return the model for the given element, or empty pointer if not found.
- (VoltaPTModelPtr) modelForElement:(VoltaPTElement const &)element;

/// @return the system model (not subcircuit) that is the default for the given type.
- (VoltaPTModelPtr) defaultModelForType:(VoltaModelType)type;

/// @return the model with matching type, name, and vendor string. Returns empty pointer if no matching model was found.
- (VoltaPTModelPtr) modelForType:(VoltaModelType)type name:(FXString const &)modelName vendor:(FXString const &)vendorString;

#pragma mark Other

/// Requests the library editor (if there is one) to be opened.
- (void) openEditor;

/// @return The root location where subcircuits are stored.
- (NSURL*) subcircuitsLocation;

/// @return The location where all palette groups are stored.
- (NSURL*) paletteLocation;

/// @return The location where all user-defined (custom) models are stored.
- (NSURL*) modelsLocation;

@end


#pragma mark - VoltaLibraryObserver -


@protocol VoltaLibraryObserver <NSObject>

@optional

/// Received when there is a change in the elements palette
- (void) handleVoltaLibraryPaletteChanged:(id<VoltaLibrary>)library;

/// Received when new models are added.
- (void) handleVoltaLibraryModelsChanged:(id<VoltaLibrary>)library;

/// Received when there is some change in the subcircuits of the library.
- (void) handleVoltaLibraryChangedSubcircuits:(id<VoltaLibrary>)library;

/// Request to show the editor UI for the given library.
- (void) handleVoltaLibraryOpenEditor:(id<VoltaLibrary>)library;

/// Received when the library is about to close itself.
- (void) handleVoltaLibraryWillShutDown:(id<VoltaLibrary>)library;

@end
