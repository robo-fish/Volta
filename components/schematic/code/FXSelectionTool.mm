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

#import "FXSelectionTool.h"
#import "FXSchematicView.h"
#import "FXSchematic.h"
#import "FXSchematicElement.h"
#import "FXSchematicUtilities.h"
#import "FXSchematicCapture.h"
#import "FXSchematicUndoManager.h"
#import "FXAlignmentLine.h"

static CGFloat const skSpeedThresholdForSnapping = 3.0;
static CGFloat const skAlignmentThreshold = 4.0;

// A single static snapping table should be sufficient since the user can not simultaneously drag elements in different circuit documents.
static FXSchematicSnappingTable sSnappingTable;


@implementation FXSelectionTool
{
@private
  id<VoltaSchematic> __weak        mSchematic;
  __weak id<VoltaSchematicElement> mMouseDownElement; ///< the element on which a mouse-down event occurred

  NSPoint  mLastDragLocation;
  BOOL     mElementsAreDragged;     /// a group of elements is being dragged
  BOOL     mElementsAreCopyDragged; /// dragging with the Option key pressed
  BOOL     mStartedDraggingJoint;   /// a connector joint is being dragged

  NSMutableSet* mDraggedElements;    /// moved by dragging
  NSMutableSet* mDraggedConnectors;  /// moved by dragging
  NSMutableSet* mMovedElements;      /// moved via arrow keys
  NSMutableSet* mMovedConnectors;    /// moved via arrow keys
  CGRect mDraggedItemsBoundingBox;
  CGPoint mDraggedItemsGrabLocation; /// relative to the origin of mDraggedItemsBoundingBox
  CGPoint mMouseDownElementGrabLocation; /// relative to the origin of mDraggedItemsBoundingBox

  NSPoint  mLocationWithoutSnapping; // new location of the dragged element if it had not snapped to to some position
  BOOL     mSnappedVertically;
  BOOL     mSnappedHorizontally;

  NSPoint  mSelectionBoxStart; ///< The first corner of the box. Located at the point dragging started.
  NSPoint  mSelectionBoxEnd; ///< The second corner of the box. Located at the current mouse position.
  BOOL     mSelectionBoxIsActive; ///< YES if the selection box is currently active

  /// This flag is raised when the user presses the 'Shift' key
  /// while starting to span the selection box. The elements in the box
  /// are then added to the previous selection instead of replacing them.
  BOOL     mSelectionBoxAddsToExistingSelection;

  /// Whether the mouse down event was received since the last reset
  BOOL     mMouseWasDownSinceLastReset;

  /// Elements selected before spanning the selection box.
  /// Used with mSelectionBoxAddsToExistingSelection.
  NSMutableSet* mExistingSelectionBeforeSpanningTheBox;

  FX(FXSchematicCapture)* mCapturedSchematic; /// for undoing element move actions

  /// For handling mouse events on connector lines.
  FXConnectionInformation mMouseDownConnectorInfo;
}


- (id) init
{
  self = [super init];

  @synchronized(self)
  {
    mSchematic = nil;
    mCapturedSchematic = nil;
    mExistingSelectionBeforeSpanningTheBox = [[NSMutableSet alloc] init];
    mDraggedElements = [[NSMutableSet alloc] init];
    mDraggedConnectors = [[NSMutableSet alloc] init];
    mMovedElements = [[NSMutableSet alloc] init];
    mMovedConnectors = [[NSMutableSet alloc] init];
    mDraggedItemsBoundingBox = CGRectZero;
    [self reset];
  }

  return self;
}


- (void) dealloc
{
  FXRelease(mDraggedElements)
  FXRelease(mDraggedConnectors)
  FXRelease(mMovedElements)
  FXRelease(mMovedConnectors)
  FXRelease(mExistingSelectionBeforeSpanningTheBox)
  FXDeallocSuper
}


#pragma mark VoltaSchematicTool


@synthesize schematic = mSchematic;

- (NSString*) name
{
  return @"Selection";
}

- (NSCursor*) cursor
{
  return [NSCursor arrowCursor];
}

- (void) activate
{
}

- (void) reset
{
  [mDraggedElements removeAllObjects];
  [mDraggedConnectors removeAllObjects];
  [mMovedElements removeAllObjects];
  [mMovedConnectors removeAllObjects];
  mDraggedItemsBoundingBox = CGRectZero;
  mDraggedItemsGrabLocation = CGPointZero;
  mMouseDownElementGrabLocation = CGPointZero;
  mLastDragLocation = NSZeroPoint;
  mMouseDownElement = nil;
  mMouseDownConnectorInfo.connector = nil;
  mElementsAreDragged = NO;
  mElementsAreCopyDragged = NO;
  mSnappedVertically = NO;
  mSnappedHorizontally = NO;
  mSelectionBoxIsActive = NO;
  mMouseWasDownSinceLastReset = NO;
  mStartedDraggingJoint = NO;
  [mExistingSelectionBeforeSpanningTheBox removeAllObjects];
  [mSchematic setSelectionBox:CGRectZero];
  [mSchematic setAlignmentLines:nil];
  if ( mCapturedSchematic != nil )
  {
    FXRelease(mCapturedSchematic)
    mCapturedSchematic = nil;
  }
}


#pragma mark FXSchematicTool


- (BOOL) mouseDown:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  @synchronized(self)
  {
    mMouseWasDownSinceLastReset = YES;
    mLastDragLocation = location;
    mMouseDownElement = [self elementAtLocation:location];

    if ( mMouseDownElement == nil )
    {
      mMouseDownConnectorInfo = FXSchematicUtilities::connectionAtPoint( location, mSchematic );
    }
  }
  return NO;
}


- (BOOL) mouseUp:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  BOOL refreshView = NO;
  @synchronized(self)
  {
    if ( mMouseWasDownSinceLastReset )
    {
      if ( mSelectionBoxIsActive )
      {
        refreshView = YES;
      }
      else if ( mMouseDownConnectorInfo.connector != nil )
      {
        refreshView = [self finishDraggingConnectorJoint]; FXIssue(59)
      }
      else if ( !mElementsAreDragged )
      {
        refreshView = [self finishSelectingElementsWithEvent:mouseEvent schematicLocation:location];
      }
      else
      {
        refreshView = [self finishDraggingElements];
      }
      [self reset];
    }
  }
  return refreshView;
}


- (BOOL) mouseDragged:(NSEvent*)mouseEvent schematicLocation:(NSPoint)draggingLocation
{  
  @synchronized(self)
  {
    if ( mMouseDownElement == nil )
    {
      if ( mMouseDownConnectorInfo.connector != nil )
      {
        [self dragConnectorJoint:draggingLocation]; FXIssue(59)
      }
      else if (  mMouseWasDownSinceLastReset )
      {
        [self dragSelectionBox:draggingLocation event:mouseEvent]; FXIssue(24)
      }
    }
    else
    {
      [self dragElementsWithEvent:mouseEvent schematicLocation:draggingLocation];
    }    
    mLastDragLocation = draggingLocation;
  }
  return YES;
}


- (BOOL) mouseMoved:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location connectionInfo:(FXConnectionInformation*)connectionInfo
{
  BOOL refreshView = NO;
  FXIssue(59)
  if ( connectionInfo->connector && [[connectionInfo->connector joints] count] && (connectionInfo->jointIndex1 == connectionInfo->jointIndex2) )
  {
    // A connector joint is being visited.
    CGPoint jointPoint;
    NSValue* jointPointValue = connectionInfo->connector.joints[connectionInfo->jointIndex1 - 1];
    [jointPointValue getValue:&jointPoint];
    [mSchematic setHasHighlightedConnectorJoint:YES];
    [mSchematic setHighlightedConnectorJoint:jointPoint];
    refreshView = YES;
  }
  else
  {
    if ( [mSchematic hasHighlightedConnectorJoint] )
    {
      [mSchematic setHasHighlightedConnectorJoint:NO];
      refreshView = YES;
    }
  }
  return refreshView;
}


- (BOOL) scrollWheel:(NSEvent*)theEvent schematicLocation:(NSPoint)location
{
  return NO;
}


- (BOOL) toolExecuteEscapeKey
{
  BOOL result = NO;
  if ( mSelectionBoxIsActive )
  {
    if ( mSelectionBoxAddsToExistingSelection )
    {
      [mSchematic selectElementsInSet:mExistingSelectionBeforeSpanningTheBox];
    }
    else
    {
      [mSchematic unselectAll];
    }
    [self reset];
    result = YES;
  }
  return result;
}


- (BOOL) toolExecuteDeleteKey
{
  FXIssue(37)
  BOOL result = NO;
  @synchronized( self )
  {
    if ( !mElementsAreDragged )
    {
      NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_delete") };
      [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];

      result = [mSchematic removeSelectedElementsIncludingConnectors:YES];
      if ( result )
      {
        [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicBoundingBoxNeedsUpdateNotification object:mSchematic]; FXIssue(112)
        [self reset];
      }
    }
  }
  return result;
}


- (BOOL) toolHandleKeyPress:(UniChar)keyCode modifierFlags:(NSUInteger)flags
{
  if ( (keyCode == NSLeftArrowFunctionKey)
    || (keyCode == NSRightArrowFunctionKey)
    || (keyCode == NSUpArrowFunctionKey)
    || (keyCode == NSDownArrowFunctionKey) )
  {
    CGFloat const stepIncrement = (flags & NSEventModifierFlagShift) ? 6.0 : 1.0; // Note that the large step size is a multiple of both 2 and 3.
    CGPoint distance = CGPointZero;
    switch( keyCode )
    {
      case NSLeftArrowFunctionKey:
        distance.x -= stepIncrement;
        break;
      case NSRightArrowFunctionKey:
        distance.x += stepIncrement;
        break;
      case NSUpArrowFunctionKey:
        distance.y += stepIncrement;
        break;
      case NSDownArrowFunctionKey:
        distance.y -= stepIncrement;
        break;
    }
  #if SCHEMATIC_VIEW_IS_FLIPPED
    distance.y = -distance.y;
  #endif

    [self moveSelectedElements:distance]; FXIssue(90)

    return YES;
  }

  return NO;
}


#pragma mark Private


/// @return the topmost schematic element whose bounds contain the given point, nil if the given point is not inside the bounds of any element.
- (id<VoltaSchematicElement>) elementAtLocation:(NSPoint)location
{
  id<VoltaSchematicElement> result = nil;
  for ( id<VoltaSchematicElement> element in [mSchematic elements] )
  {
    NSPoint const elementLocation = [element location];
    CGSize const elementSize = [element size];
    NSRect const elementBoundingBox = NSMakeRect( elementLocation.x - elementSize.width/2.0f, elementLocation.y - elementSize.height/2.0f, elementSize.width, elementSize.height );
    if ( NSPointInRect( location, elementBoundingBox ) )
    {
      result = element;
      break;
    }
  }
  return result;
}


/// Collects positions to which the dragged element can be snapped.
/// Should run in a separate thread.
- (void) fillElementSnappingTable
{
  @autoreleasepool
  {
    // Does not require synchronizing on the schematic when accessing schematic elements
    // because dragging operates on the selected elements while snapping operates on the
    // remaining elements.
    if ( mElementsAreDragged && (mMouseDownElement != nil) )
    {
      FXSchematicUtilities::fillElementSnappingTable(sSnappingTable, mSchematic, mMouseDownElement);
      sSnappingTable.ready = true;
    }
  }
}


/// Collects positions to which the dragged joint can be snapped.
/// Should run in a separate thread.
- (void) fillJointSnappingTable
{
  @autoreleasepool
  {
    // Does not require synchronizing on the schematic when accessing schematic elements
    // because dragging operates on the selected elements while snapping operates on the
    // remaining elements.
    if ( mMouseDownConnectorInfo.connector != nil )
    {
      FXSchematicUtilities::fillJointSnappingTable(sSnappingTable, mSchematic, mMouseDownConnectorInfo);
      sSnappingTable.ready = true;
    }
  }
}


- (void) copyElementsForDragging
{
  if ( [mSchematic isSelected:mMouseDownElement] )
  {
    // Copying elements
    NSDictionary* copiedElementsDictionary = [mSchematic createCopiesOfSelectedElements];
    mMouseDownElement = copiedElementsDictionary[[NSValue valueWithPointer:(const void*)mMouseDownElement]];
    NSAssert( mMouseDownElement != nil, @"A copy should have been made for the element under the mouse pointer." );
    [mDraggedElements addObjectsFromArray:[copiedElementsDictionary allValues]];
    
    // Also copying connectors that are connected to the original elements
    NSArray* originalElements = [copiedElementsDictionary allKeys];
    for ( id<VoltaSchematicConnector> connector in [mSchematic connectors] )
    {
      if ( [originalElements containsObject:[NSValue valueWithPointer:(const void*)[connector startElement]]]
          && [originalElements containsObject:[NSValue valueWithPointer:(const void*)[connector endElement]]] )
      {
        id<VoltaSchematicConnector> copiedConnector = [(NSObject*)connector copy];
        copiedConnector.startElement = copiedElementsDictionary[[NSValue valueWithPointer:(const void*)[connector startElement]]];
        copiedConnector.endElement = copiedElementsDictionary[[NSValue valueWithPointer:(const void*)[connector endElement]]];
        [mSchematic addConnector:copiedConnector];
        [mDraggedConnectors addObject:copiedConnector];
        FXRelease(copiedConnector)
      }
    }
  }
  else
  {
    mMouseDownElement = [mSchematic createCopyOfElement:mMouseDownElement];
  }
}


- (void) dragOtherElementsAndConnectorsForDistance:(CGPoint)distance
{
  if ( [mDraggedElements count] > 1 )
  {
    for ( id<VoltaSchematicElement> element in mDraggedElements )
    {
      if (element != mMouseDownElement)
      {
        CGPoint tmp = [element location];
        tmp.x += distance.x;
        tmp.y += distance.y;
        [element setLocation:tmp];
      }
    }
    
    // Also moving all the joints of the connectors that are connected to dragged elements on both ends.
    FXIssue(59)
    NSMutableArray* newJoints = [NSMutableArray new];
    for ( id<VoltaSchematicConnector> connector in mDraggedConnectors )
    {
      [newJoints removeAllObjects];
      for ( NSValue* jointCoordinateValue in [connector joints] )
      {
        CGPoint jointCoordinate;
        [jointCoordinateValue getValue:&jointCoordinate];
        jointCoordinate.x += distance.x;
        jointCoordinate.y += distance.y;
        NSValue* newJointCoordinateValue = [NSValue valueWithBytes:&jointCoordinate objCType:@encode(CGPoint)];
        [newJoints addObject:newJointCoordinateValue];
      }
      [[connector joints] removeAllObjects];
      [[connector joints] addObjectsFromArray:newJoints];
    }
    FXRelease(newJoints)
  }
}


/// Configures the event tracking state to process dragging of elements.
- (void) startDraggingElements:(NSPoint)draggingLocation
{
  if ( mCapturedSchematic == nil )
  {
    mCapturedSchematic = [[FX(FXSchematicCapture) alloc] initWithSchematic:mSchematic]; FXIssue(33) // Capture to create an undo point.
  }
  
  if ( mElementsAreCopyDragged )
  {
    [self copyElementsForDragging]; FXIssue(43)
  }
  else
  {
    // If the element is one of the selected elements then we move all selected elements and the connected connectors.
    if ( [mSchematic isSelected:mMouseDownElement] )
    {
      [mDraggedElements setSet:[mSchematic selectedElements]];
      
      for ( id<VoltaSchematicConnector> connector in [mSchematic connectors] )
      {
        if ( [mDraggedElements containsObject:[connector startElement]] && [mDraggedElements containsObject:[connector endElement]] )
        {
          [mDraggedConnectors addObject:connector];
        }
      }
    }
  }
  [mDraggedElements addObject:mMouseDownElement];
  
  // Filling the snapping table with positions to which the dragged element can be snapped.
  sSnappingTable.clear();
  [NSThread detachNewThreadSelector:@selector(fillElementSnappingTable) toTarget:self withObject:nil];
  
  FXIssue(112)
  mDraggedItemsBoundingBox = [mSchematic boundingBoxForElements:mDraggedElements connectors:mDraggedConnectors context:NULL];
  mDraggedItemsGrabLocation = CGPointMake( draggingLocation.x - mDraggedItemsBoundingBox.origin.x, draggingLocation.y - mDraggedItemsBoundingBox.origin.y );
  mMouseDownElementGrabLocation = [mMouseDownElement location];
  mMouseDownElementGrabLocation.x -= mDraggedItemsBoundingBox.origin.x;
  mMouseDownElementGrabLocation.y -= mDraggedItemsBoundingBox.origin.y;
}


/// Processes the current state to drag elements.
- (void) dragElementsWithEvent:(NSEvent*)mouseEvent schematicLocation:(NSPoint)draggingLocation;
{
  if ( !mElementsAreDragged )
  {
    mElementsAreDragged = YES;
    mElementsAreCopyDragged = ([mouseEvent modifierFlags] & NSEventModifierFlagOption) != 0;
    [self startDraggingElements:draggingLocation];
  }

  CGPoint const oldLocation = [mMouseDownElement location];
  CGPoint newLocation = CGPointZero;
  BOOL snapHorizontally = YES;
  BOOL snapVertically = YES;
  
  FXIssue(112)
  if ( draggingLocation.x < mDraggedItemsGrabLocation.x )
  {
    newLocation.x = mMouseDownElementGrabLocation.x;
    mDraggedItemsGrabLocation.x = std::max(0.0, newLocation.x);
    snapVertically = NO;
  }
  if ( draggingLocation.y < mDraggedItemsGrabLocation.y )
  {
    newLocation.y = mMouseDownElementGrabLocation.y;
    mDraggedItemsGrabLocation.y = std::max(0.0, newLocation.y);
    snapHorizontally = NO;
  }

  CGPoint snappingLocation = [self dragTo:draggingLocation snapVertically:snapVertically snapHorizontally:snapHorizontally]; FXIssue(60)
  newLocation.x = snapVertically ? snappingLocation.x : newLocation.x;
  newLocation.y = snapHorizontally ? snappingLocation.y : newLocation.y;
  
  CGPoint distance = CGPointMake(newLocation.x - oldLocation.x, newLocation.y - oldLocation.y);
  
  [mMouseDownElement setLocation:newLocation];
  
  [self dragOtherElementsAndConnectorsForDistance:distance];
  
  FXIssue(112)
  mDraggedItemsBoundingBox.origin.x = snapVertically ? (mDraggedItemsBoundingBox.origin.x + distance.x) : 0.0;
  mDraggedItemsBoundingBox.origin.y = snapHorizontally ? (mDraggedItemsBoundingBox.origin.y + distance.y) : 0.0;
  [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicBoundingBoxNeedsUpdateNotification object:mSchematic];
}


/// @return whether the view needs to be refreshed
- (BOOL) finishDraggingElements
{
  if ( mCapturedSchematic != nil )
  {
    FXIssue(33)
    NSString* actionName = mElementsAreCopyDragged ? FXLocalizedString(@"Action_copy") : FXLocalizedString(@"Action_move");
    NSDictionary* undoUserInfo = @{ @"ActionName" : actionName, @"CapturedSchematic" : mCapturedSchematic };
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];
  }

  return [[mSchematic alignmentLines] count] > 0;
}


/// Processes the current state to handle dragging of connector joints.
- (void) dragConnectorJoint:(NSPoint)draggingLocation
{
  if ( mMouseDownConnectorInfo.jointIndex1 == mMouseDownConnectorInfo.jointIndex2 )
  {
    [self dragExistingConnectorJoint:draggingLocation];
  }
  else if ( mMouseDownConnectorInfo.jointIndex2 == (mMouseDownConnectorInfo.jointIndex1 + 1) )
  {
    [self createAndDragNewConnectorJoint:draggingLocation];
  }        
}


/// @return whether the view needs to be refreshed
- (BOOL) finishDraggingConnectorJoint
{
  if ( mMouseDownConnectorInfo.jointIndex1 == mMouseDownConnectorInfo.jointIndex2 )
  {
    FXSchematicUtilities::simplifyConnectorRoute( mMouseDownConnectorInfo.connector );
    
    if ( mCapturedSchematic != nil )
    {
      NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_move_joint"), @"CapturedSchematic" : mCapturedSchematic };
      [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];
    }
    return YES;
  }
  return NO;
}


/// Processes the dragging event and the current state to create a new connector joint which can immediately be dragged.
- (void) createAndDragNewConnectorJoint:(NSPoint)draggingLocation
{
  if ( mCapturedSchematic == nil )
  {
    mCapturedSchematic = [[FX(FXSchematicCapture) alloc] initWithSchematic:mSchematic];
  }
  NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_create_joint"), @"CapturedSchematic" : mCapturedSchematic };
  [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];

  CGPoint newJointPoint = draggingLocation;
  NSValue* newJointPointValue = [NSValue value:&newJointPoint withObjCType:@encode(CGPoint)];
  NSArray* joints = [mMouseDownConnectorInfo.connector joints];
  if ( joints == nil )
  {
    [mMouseDownConnectorInfo.connector setJoints:[NSMutableArray arrayWithObject:newJointPointValue]];
    mMouseDownConnectorInfo.jointIndex1 = mMouseDownConnectorInfo.jointIndex2 = 1;
  }
  else
  {
    [[mMouseDownConnectorInfo.connector joints] insertObject:newJointPointValue atIndex:(mMouseDownConnectorInfo.jointIndex2 - 1)];
    mMouseDownConnectorInfo.jointIndex1 = mMouseDownConnectorInfo.jointIndex2; // that is, from now on we continue by dragging this newly created joint
  }
}


/// Processes the dragging event and the current state to drag an existing connector joint.
- (void) dragExistingConnectorJoint:(NSPoint)draggingLocation
{
  if ( !mStartedDraggingJoint )
  {
    mStartedDraggingJoint = YES;
    
    if ( mCapturedSchematic == nil )
    {
      mCapturedSchematic = [[FX(FXSchematicCapture) alloc] initWithSchematic:mSchematic];
    }
    
    // Filling the snapping table with positions to which the dragged joint can be snapped.
    sSnappingTable.clear();
    [NSThread detachNewThreadSelector:@selector(fillJointSnappingTable) toTarget:self withObject:nil];
    
    [mSchematic setHasHighlightedConnectorJoint:NO];
  }
  
  CGPoint const newJointLocation = [self dragTo:draggingLocation snapVertically:YES snapHorizontally:YES];
  NSValue* newJointLocationValue = [NSValue valueWithBytes:&newJointLocation objCType:@encode(CGPoint)];
  mMouseDownConnectorInfo.connector.joints[mMouseDownConnectorInfo.jointIndex1 - 1] = newJointLocationValue;
  
  [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicBoundingBoxNeedsUpdateNotification object:mSchematic]; FXIssue(112)
}


/// @return a position that takes snapping into account using the static snapping table.
- (NSPoint) dragTo:(NSPoint)draggingLocation snapVertically:(BOOL)snapVertically snapHorizontally:(BOOL)snapHorizontally
{
  FXIssue(60)
  FXIssue(59)
  // Alignment and Snapping

  if ( !snapVertically && !snapHorizontally )
  {
    return draggingLocation;
  }
  
  NSMutableSet* alignmentLines = [[NSMutableSet alloc] init];
  BOOL snap;


  NSPoint loc = draggingLocation; // when a connector joint is dragged
  if ( mMouseDownElement != nil ) // when an element is dragged
  {
    loc = [mMouseDownElement location];
  }

  CGFloat distanceX = draggingLocation.x - mLastDragLocation.x;
  CGFloat distanceY = draggingLocation.y - mLastDragLocation.y;
  BOOL const snappingEnabled = ((distanceX*distanceX + distanceY*distanceY) < skSpeedThresholdForSnapping);

  if ( snapVertically )
  {
    if ( mSnappedVertically )
    {
      mLocationWithoutSnapping.x += distanceX;
    }
    loc.x = (mSnappedVertically ? mLocationWithoutSnapping.x : (loc.x + distanceX));
    snap = NO;
    if ( snappingEnabled && sSnappingTable.ready )
    {
      for( FXSchematicSnapping const & snapping : sSnappingTable.verticalSnappings )
      {
        if ( fabs(loc.x - snapping.position) < skAlignmentThreshold )
        {
          snap = YES;
          if ( !mSnappedVertically )
          {
            // now snaps to position
            mLocationWithoutSnapping.x = loc.x;
          }
          loc.x = snapping.position;
          // Add alignment lines for this snapping
          for( CGFloat linePos : snapping.alignmentLinePositions )
          {
            FXAlignmentLine* line = [FXAlignmentLine new];
            [line setVertical:YES];
            [line setPosition:linePos];
            [alignmentLines addObject:line];
            FXRelease(line)
          }
          break;
        }
      }
    }
    if ( !snap && mSnappedVertically )
    {
      // was snapped but now breaks free
      loc.x = mLocationWithoutSnapping.x;
    }
    mSnappedVertically = snap;    
  }

  if ( snapHorizontally )
  {
    if ( mSnappedHorizontally )
    {
      mLocationWithoutSnapping.y += distanceY;
    }
    loc.y = (mSnappedHorizontally ? mLocationWithoutSnapping.y : (loc.y + distanceY));  
    snap = NO;
    if ( snappingEnabled && sSnappingTable.ready )
    {
      for( FXSchematicSnapping const & snapping : sSnappingTable.horizontalSnappings )
      {
        if ( fabs(loc.y - snapping.position) < skAlignmentThreshold )
        {
          snap = YES;
          if ( !mSnappedHorizontally )
          {
            // now snaps to position
            mLocationWithoutSnapping.y = loc.y;
          }
          loc.y = snapping.position;
          // Add alignment lines for this snapping
          for( CGFloat linePos : snapping.alignmentLinePositions )
          {
            FXAlignmentLine* line = [FXAlignmentLine new];
            [line setVertical:NO];
            [line setPosition:linePos];
            [alignmentLines addObject:line];
            FXRelease(line)
          }
          break;
        }
      }
    }
    if ( !snap && mSnappedHorizontally )
    {
      // was snapped but now breaks free
      loc.y = mLocationWithoutSnapping.y;
    }
    mSnappedHorizontally = snap;
  }
  
  [mSchematic setAlignmentLines:alignmentLines];
  FXRelease(alignmentLines)

  return loc;
}


/// Processes the dragging event and the current state to span a selection box.
- (void) dragSelectionBox:(NSPoint)draggingLocation event:(NSEvent*)mouseEvent
{
  if ( !mSelectionBoxIsActive )
  {
    mSelectionBoxStart = draggingLocation;
    mSelectionBoxIsActive = YES;
    mSelectionBoxAddsToExistingSelection = (([mouseEvent modifierFlags] & NSEventModifierFlagShift) != 0);
    if ( mSelectionBoxAddsToExistingSelection )
    {
      [mExistingSelectionBeforeSpanningTheBox setSet:[mSchematic selectedElements]];
    }
  }
  mSelectionBoxEnd = draggingLocation;

  CGRect selectionBox = CGRectMake(
    std::min(mSelectionBoxStart.x, mSelectionBoxEnd.x),
    std::min(mSelectionBoxStart.y, mSelectionBoxEnd.y),
    fabs(mSelectionBoxEnd.x - mSelectionBoxStart.x),
    fabs(mSelectionBoxEnd.y - mSelectionBoxStart.y)
    );
  [mSchematic setSelectionBox:selectionBox];

  NSMutableSet* allElements = [NSMutableSet setWithSet:mExistingSelectionBeforeSpanningTheBox];
  [mSchematic getElementsInsideRect:selectionBox fully:NO outSet:allElements];
  [mSchematic selectElementsInSet:allElements];
}


/// @return whether the view needs to be refreshed
- (BOOL) finishSelectingElementsWithEvent:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  BOOL refreshView = NO;
  BOOL isGroupSelection = ([mouseEvent modifierFlags] & NSEventModifierFlagCommand) != 0;
  id<VoltaSchematicElement> mouseUpElement = [self elementAtLocation:location];
  if ( mMouseDownElement == mouseUpElement )
  {
    if ( mMouseDownElement == nil )
    {
      if ( !isGroupSelection && ([mSchematic numberOfSelectedElements] > 0) )
      {
        [mSchematic unselectAll];
        refreshView = YES;
      }
    }
    else
    {
      // If the Command key is pressed the selection status of the element will be toggled.
      // Otherwise the element will be selected and all other elements will be unselected.
      if ( isGroupSelection )
      {
        if ( [mSchematic isSelected:mMouseDownElement] )
        {
          [mSchematic unselect:mMouseDownElement];
        }
        else
        {
          [mSchematic select:mMouseDownElement];
        }
        refreshView = YES;
      }
      else
      {
        if ( ![mSchematic isSelectedExclusively:mMouseDownElement] )
        {
          [mSchematic selectExclusively:mMouseDownElement];
          refreshView = YES;
        }
      }
    }
  }
  return refreshView;
}


/// Processes the current state to move the set of selected elements by the given distance.
/// Use for handling keyboard events.
- (void) moveSelectedElements:(CGPoint)distance
{
  for ( id<VoltaSchematicConnector> connector in [mSchematic connectors] )
  {
    if ( [mSchematic isSelected:[connector startElement]] && [mSchematic isSelected:[connector endElement]] )
    {
      [mMovedConnectors addObject:connector];
    }
  }
  
  [mMovedElements setSet:[mSchematic selectedElements]];
  
  distance = [self moveWithConstraint:distance];
  
  [self checkAlignmentForMovedElement];
  
  NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_move") };
  [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];
  
  for ( id<VoltaSchematicElement> element in mMovedElements )
  {
    CGPoint const oldLocation = [element location];
    [element setLocation:CGPointMake(oldLocation.x + distance.x, oldLocation.y + distance.y)];
  }
  
  // Also moving all joints of connectors that are tied to moving elements on both ends.
  FXIssue(59)
  NSMutableArray* newJoints = [NSMutableArray new];
  for ( id<VoltaSchematicConnector> connector in mMovedConnectors )
  {
    for ( NSValue* jointCoordinateValue in [connector joints] )
    {
      CGPoint jointCoordinate;
      [jointCoordinateValue getValue:&jointCoordinate];
      jointCoordinate.x += distance.x;
      jointCoordinate.y += distance.y;
      NSValue* newJointCoordinateValue = [NSValue valueWithBytes:&jointCoordinate objCType:@encode(CGPoint)];
      [newJoints addObject:newJointCoordinateValue];
    }
    [[connector joints] removeAllObjects];
    [[connector joints] addObjectsFromArray:newJoints];
    [newJoints removeAllObjects];
  }
  FXRelease(newJoints)
  
  [mMovedConnectors removeAllObjects];
  [mMovedElements removeAllObjects];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicBoundingBoxNeedsUpdateNotification object:mSchematic]; FXIssue(112)
}


/// @return a differential distance to move while restricting the current bounding box to the first quadrant.
/// Use for handling keyboard events.
- (CGPoint) moveWithConstraint:(CGPoint)increment
{
  CGRect boundingBox = [mSchematic boundingBoxForElements:mMovedElements connectors:mMovedConnectors context:NULL];
  if ( (boundingBox.origin.x + increment.x) < 0.0 )
  {
    increment.x = -boundingBox.origin.x;
  }
  if ( (boundingBox.origin.y + increment.y) < 0.0 )
  {
    increment.y = -boundingBox.origin.y;
  }
  return increment;
}


/// Checks whether the element, which is moved using the arrow keys, aligns with connection points of connector joints.
- (void) checkAlignmentForMovedElement
{
#if 0
  // If only one element is moved it makes sense to show alignment lines.
  if ( [mSchematic numberOfSelectedElements] == 1 )
  {
    id<VoltaSchematicElement> movedElement = [[mSchematic selectedElements] anyObject];
    CGPoint elementLocation = [movedElement location];
    elementLocation.x += moveX;
    elementLocation.y += moveY;
    sSnappingTable.ready = false;
    FXSchematicUtilities::fillElementSnappingTable(sSnappingTable, mSchematic, movedElement);
    NSAssert( sSnappingTable.ready, @"Error while filling snapping table when moving elements with arrow keys." );
    
    NSMutableSet* alignmentLines = [[NSMutableSet alloc] initWithCapacity:(sSnappingTable.horizontalSnappings.size() + sSnappingTable.verticalSnappings.size())];
    for( FXSchematicSnapping const & snapping : sSnappingTable.horizontalSnappings )
    {
      if ( fabs(elementLocation.y - snapping.position) < skAlignmentThreshold )
      {
        for( CGFloat linePos : snapping.alignmentLinePositions )
        {
          FXAlignmentLine* line = [FXAlignmentLine new];
          [line setVertical:NO];
          [line setPosition:linePos];
          [alignmentLines addObject:line];
          FXRelease(line)
        }
        break;
      }
    }
    for( FXSchematicSnapping const & snapping : sSnappingTable.verticalSnappings )
    {
      if ( fabs(elementLocation.x - snapping.position) < skAlignmentThreshold )
      {
        for( CGFloat linePos : snapping.alignmentLinePositions )
        {
          FXAlignmentLine* line = [FXAlignmentLine new];
          [line setVertical:YES];
          [line setPosition:linePos];
          [alignmentLines addObject:line];
          FXRelease(line)
        }
        break;
      }
    }
    [mSchematic setAlignmentLines:alignmentLines];
  }
#endif
}


@end
