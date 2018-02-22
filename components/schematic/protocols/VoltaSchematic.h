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

#import "VoltaSchematicElement.h"
#import "VoltaSchematicConnector.h"
#import "FXShapeConnectionPoint.h"

@protocol VoltaLibrary;


@protocol VoltaSchematic <NSObject>

@property (copy)                    NSString* schematicTitle;
@property (readonly, copy)             NSSet* elements;
@property (readonly, copy)             NSSet* connectors;
@property (readonly, copy)             NSSet* selectedElements;
@property                              NSSet* alignmentLines; ///< list of VoltaAlignmentLine objects which represent vertical or horizontal positions at which two or more connection points of different elements align.
@property                              CGRect selectionBox; ///< nonpositive width and height indicates the box is inactive.
@property                             CGPoint highlightedConnectionPoint;
@property                                BOOL hasHighlightedConnectionPoint;
@property                             CGPoint highlightedConnectorJoint;
@property                                BOOL hasHighlightedConnectorJoint;
@property                             CGFloat scaleFactor;
@property                    id<VoltaLibrary> library;
@property                NSMutableDictionary* properties; ///< schematic-wide properties
@property (nonatomic, readonly)    NSUInteger numberOfElements; ///< the number of elements in the schematic
@property (nonatomic, readonly)    NSUInteger numberOfSelectedElements; /// the number of currently selected elements
@property (nonatomic, readonly)    NSUInteger numberOfConnectors; ///< the number of connectors in the schematic
@property (nonatomic, readonly) NSDictionary* elementLabelAttributes; //< string attributes to use for element labels

- (void) addElement:(id<VoltaSchematicElement>)element;

/// @return whether the given element was actually removed
/// @param removeConnectors whether to remove all connectors attached to the removed element
- (BOOL) removeElement:(id<VoltaSchematicElement>)element andAttachedConnectors:(BOOL)removeConnectors;

/// Copies the given schematic element and adds the copy to the schematic.
/// @return The copy of the given element
- (id<VoltaSchematicElement>) createCopyOfElement:(id<VoltaSchematicElement>)element;

- (void) addConnector:(id<VoltaSchematicConnector>)connector;

- (void) removeConnector:(id<VoltaSchematicConnector>)connector;

/// Removes all content.
- (void) removeAll;

/// Adds the given element to the set of selected elements
- (void) select:(id<VoltaSchematicElement>)element;

/// Exclusively selects the elements in the given set
- (void) selectElementsInSet:(NSSet*)selection;

/// Adds the given element to the set of selected elements, removes all other selected elements.
- (void) selectExclusively:(id<VoltaSchematicElement>)element;

/// Removes the given element from the set of selected elements 
- (void) unselect:(id<VoltaSchematicElement>)element;

/// @return YES if the given schematic element is within the selected set
- (BOOL) isSelected:(id<VoltaSchematicElement>)element;

/// @return YES if the given schematic element is the only element selected
- (BOOL) isSelectedExclusively:(id<VoltaSchematicElement>)element;

/// Clears the set of selected elements
- (void) unselectAll;

/// Adds all elements to the set of selected elements
- (void) selectAll;

/// @return whether any elements were actually removed
/// @param removeConnectors whether to remove all connectors attached to the removed elements
- (BOOL) removeSelectedElementsIncludingConnectors:(BOOL)removeConnectors;

/// Creates copies of the current selected elements.
/// The copies are automatically added to the schematic.
/// @return A dictionary which maps the original elements to their copies.
/// The keys of the returned dictionary are NSValue objects containing pointers to id<VoltaSchematicElement>.
/// The element objects can not be used directly as keys because dictionaries only store copies of the keys.
- (NSDictionary*) createCopiesOfSelectedElements;


- (void) highlight:(id<VoltaSchematicConnector>)connector;

- (void) lowlight:(id<VoltaSchematicConnector>)connector;

- (void) lowlightAll;

- (BOOL) isHighlighted:(id<VoltaSchematicConnector>)connector;


/// Checks whether the name of the given element is unique within the schematic and has
/// a type-appropriate prefix. Creates and assigns a new name if it isn't.
- (void) checkAndAssignUniqueName:(id<VoltaSchematicElement>)element;


/// @return the set of elements inside the given rectangle
/// @param fullyInside Whether to add only those elements that are fully inside the rectangle.
///                    Otherwise the location of the center points of the elements is considered.
/// @param result For performance reasons the sender needs to provide the set that will contain the elements inside the rectangle.
- (void) getElementsInsideRect:(CGRect)rect fully:(BOOL)fullyInside outSet:(NSMutableSet*)result;

/// @return whether the given connection point of the given element is connected to a connector.
- (BOOL) isConnectionPointConnected:(FXShapeConnectionPoint*)connectionPoint forElement:(id<VoltaSchematicElement>)element;

/// @return the smallest rectangle enclosing all elements and all connectors of the schematic
/// Context is allowed to be NULL but calculation will be slower.
- (CGRect) boundingBoxWithContext:(CGContextRef)context;

/// @return the smallest rectangle enclosing the given elements and the given connectors (including their joints).
/// @param elements an array of VoltaSchematicElement instances
/// @param connectors an array of VoltaSchematicConnectors instances
/// Context is allowed to be NULL but calculation will be slower.
- (CGRect) boundingBoxForElements:(NSSet*)elements connectors:(NSSet*)connectors context:(CGContextRef)context;

/// @return the rectangle into which to draw the label of the given element, relative to the location of the element.
- (CGRect) relativeBoundingBoxForLabelOfElement:(id<VoltaSchematicElement>)element withContext:(CGContextRef)context;


@end


/// Posted when an element has been added to the schematic.
/// Notification object: The schematic which the element has been added to.
extern NSString* VoltaSchematicElementAddedToSchematicNotification;

/// Posted when an element has been added to the schematic.
/// Notification object: The schematic which the element has been added to.
extern NSString* VoltaSchematicElementRemovedFromSchematicNotification;

/// Posted when a connection between two elements has been created.
/// Notification object: The schematic which the element has been added to.
extern NSString* VoltaSchematicConnectionMadeNotification;

/// Posted when a connection between two elements has been cut.
/// Notification object: The schematic which the element has been added to.
extern NSString* VoltaSchematicConnectionCutNotification;

/// Posted when there is a change in selected elements.
/// Notification object: The schematic whose set of selected elements has changed.
extern NSString* VoltaSchematicSelectionHasChangedNotification;

/// Posted when the name of a model, that is assigned to some elements in a schematic, is about to change.
/// Notification object: the schematic containing the element.
extern NSString* VoltaSchematicElementModelsWillChangeNotification;

/// Posted when the name of a model, that is assigned to some elements in the schematic, has changed.
/// Notification object: the schematic containing the element.
extern NSString* VoltaSchematicElementModelsDidChangeNotification;

/// Should be posted whenever an operation, which may affect the bounding box, is performed.
/// Notification object: the schematic whose bounding box needs to be updated.
extern NSString* VoltaSchematicBoundingBoxNeedsUpdateNotification; FXIssue(112)
