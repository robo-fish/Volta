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

#import "FXSchematicUtilities.h"
#import "FXSchematicConnector.h"
#import "FXShapeConnectionPoint.h"
#import "FXVector.h"
#import "FXAlignmentLine.h"
#import "FXShape.h"
#include <algorithm>
#include <assert.h>
#include <stack>
#if VOLTA_DEBUG
#include <iostream>
#endif

#warning TODO: FXSchematicUtilities needs testing!!!!

const CGFloat FXSchematicProximityThreshold = 5.0;
const CGFloat FXSchematicProximityThresholdSquared = FXSchematicProximityThreshold * FXSchematicProximityThreshold;

#if SCHEMATIC_VIEW_IS_FLIPPED
const int FXSchematicVerticalOrientationFactor = -1;
#else
const int FXSchematicVerticalOrientationFactor = 1;
#endif


#pragma mark -


CGPoint FXSchematicUtilities::convertToSchematicSpace( CGPoint pointInViewSpace, id<VoltaSchematic> schematic)
{
  return CGPointMake( pointInViewSpace.x/[schematic scaleFactor], pointInViewSpace.y/[schematic scaleFactor] );
}


static bool testProximityToLine( FXVector const & point, FXVector const & linePoint1, FXVector const & linePoint2 )
{
  // First of all, the point has to lie somewhere between the two line points.
  if( (point - linePoint1).dot(point - linePoint2) < 0 )
  {
    // Calculate the distance.
    // The distance between a point P(x1,y1) and a line y = m*x + b is given by
    //   d = abs(y1 - m*x1 - b)/sqrt(m*m + 1)
    CGFloat const kDistX = abs(linePoint2.x - linePoint1.x);
    CGFloat const kDistY = abs(linePoint2.y - linePoint1.y);
    if ( (kDistX <= FXSchematicProximityThreshold) && (kDistY <= FXSchematicProximityThreshold) )
    {
      return true;
    }
    else if ( kDistX < FXSchematicProximityThreshold )
    {
      return (abs( point.x - (linePoint2.x + linePoint1.x)/2.0 ) <= FXSchematicProximityThreshold);
    }
    else if ( kDistY < FXSchematicProximityThreshold )
    {
      return (abs( point.y - (linePoint2.y + linePoint1.y)/2.0 ) <= FXSchematicProximityThreshold);
    }
    else
    {
      CGFloat m = (linePoint2.y - linePoint1.y)/(linePoint2.x - linePoint1.x);
      CGFloat b = linePoint1.y - (m * linePoint1.x);
      CGFloat d = abs(point.y - m* point.x - b)/sqrt(m*m + 1);
      return ( d <= FXSchematicProximityThreshold );
    }
  }
  return false;
}


FXConnectionInformation FXSchematicUtilities::connectionAtPoint( CGPoint location, id<VoltaSchematic> schematic )
{
  FXConnectionInformation result;

  // First check if the location is on top of an element's connection point
  for ( id<VoltaSchematicElement> element in [schematic elements] )
  {
    FXPoint const elementLocation = [element location];
    CGSize elementSize = [element size];
    CGRect elementBoundingBox = CGRectMake(elementLocation.x - elementSize.width/2.0f - FXSchematicProximityThreshold, elementLocation.y - elementSize.height/2.0f - FXSchematicProximityThreshold, elementSize.width + (2*FXSchematicProximityThreshold), elementSize.height + (2*FXSchematicProximityThreshold));
    if ( CGRectContainsPoint( elementBoundingBox, location ) )
    {
      result.element = element;
      id<FXShape> elementShape = [element shape];
      if ( elementShape != nil )
      {
        for ( FXShapeConnectionPoint* connectionPoint in [elementShape connectionPoints] )
        {
          FXVector connectionPointLocation( [connectionPoint location] );
          if ( [element flipped] )
          {
            connectionPointLocation.scale(-1, 1);
          }
          connectionPointLocation.rotate( [element rotation] );
          connectionPointLocation.x += elementLocation.x;
          connectionPointLocation.y = elementLocation.y + (FXSchematicVerticalOrientationFactor * connectionPointLocation.y);
          CGFloat distanceX = location.x - connectionPointLocation.x;
          CGFloat distanceY = location.y - connectionPointLocation.y;
          static const CGFloat skProximityThreshold = FXSchematicProximityThreshold * FXSchematicProximityThreshold;
          if ( (distanceX * distanceX + distanceY * distanceY) <= skProximityThreshold )
          {
            result.connectionPoint = connectionPoint;
            result.connectionPointLocation.x = connectionPointLocation.x;
            result.connectionPointLocation.y = connectionPointLocation.y;
            break;
          }
        }
      }
      break;
    }
  }

  if ( result.element != nil )
  {
    return result;
  }

  // Go on, check if the given location is on top of a connector joint.
  FXVector const locationVec( location );
  for ( id<VoltaSchematicConnector> connector in [schematic connectors] )
  {
    FXVector lineStartPoint, lineEndPoint;
    NSUInteger const numRouteJoints = 2 + ( [connector joints] ? [[connector joints] count] : 0 );
    for ( NSUInteger headJointIndex = 0; headJointIndex < (numRouteJoints - 1); headJointIndex++ )
    {
      if ( headJointIndex == 0 )
      {
        id<VoltaSchematicElement> startElement = [connector startElement];
        FXVector startElementLocation( [startElement location] );
        id<FXShape> startShape = [startElement shape];
        for ( FXShapeConnectionPoint* pin in [startShape connectionPoints] )
        {
          if ([[pin name] isEqualToString:[connector startPin]])
          {
            lineStartPoint = FXVector( [pin location] );
            break;
          }
        }
        if ( [startElement flipped] )
        {
          lineStartPoint.scale(-1, 1);
        }
        lineStartPoint.rotate( [startElement rotation] );
        lineStartPoint.y *= FXSchematicVerticalOrientationFactor;
        lineStartPoint = lineStartPoint + startElementLocation;
      }
      else
      {
        NSValue* headPointValue = connector.joints[headJointIndex - 1];
        CGPoint headCGPoint;
        [headPointValue getValue:&headCGPoint];
        lineStartPoint = FXVector( headCGPoint );
      }

      // Test if the given location is very close to the head joint
      if ( (locationVec - lineStartPoint).squaredMagnitude() < FXSchematicProximityThresholdSquared )
      {
        result.connector = connector;
        result.jointIndex1 = result.jointIndex2 = headJointIndex;
        return result;
      }
      
      NSUInteger const endJointIndex = headJointIndex + 1;
      if ( endJointIndex == (numRouteJoints - 1) )
      {
        id<VoltaSchematicElement> endElement = [connector endElement];
        FXVector endElementLocation( [endElement location] );
        id<FXShape> endShape = [endElement shape];
        for ( FXShapeConnectionPoint* pin in [endShape connectionPoints] )
        {
          if ([[pin name] isEqualToString:[connector endPin]])
          {
            lineEndPoint = FXVector( [pin location] );
            break;
          }
        }
        if ( [endElement flipped] )
        {
          lineEndPoint.scale(-1, 1);
        }
        lineEndPoint.rotate( [endElement rotation] );
        lineEndPoint.y *= FXSchematicVerticalOrientationFactor;
        lineEndPoint = lineEndPoint + endElementLocation;
      }
      else
      {
        NSValue* endPointValue = connector.joints[endJointIndex - 1];
        CGPoint endCGPoint;
        [endPointValue getValue:&endCGPoint];
        lineEndPoint = FXVector( endCGPoint );
      }

      // Test if the given location is very close to the end joint
      if ( (locationVec - lineEndPoint).squaredMagnitude() < FXSchematicProximityThresholdSquared )
      {
        result.connector = connector;
        result.jointIndex1 = result.jointIndex2 = endJointIndex;
        return result;
      }

      if ( testProximityToLine( locationVec, lineStartPoint, lineEndPoint ) )
      {
        // found a connector
        result.connector = connector;
        result.jointIndex1 = headJointIndex;
        result.jointIndex2 = endJointIndex;
        return result;
      }
    }
  }
  return result;
}


id<VoltaSchematicConnector> FXSchematicUtilities::connectorAtConnectionPoint( FXConnectionInformation connectionInformation, id<VoltaSchematic> schematic )
{
  id<VoltaSchematicConnector> result = nil;
  for ( id<VoltaSchematicConnector> connector in [schematic connectors] )
  {
    // Note: the start and end pins and the connection points are not the same objects,
    // they are copies of each other. Therefore we compare the names instead of the pointers.
    if ( ( ([connector startElement] == connectionInformation.element) && ([[connector startPin] isEqualToString:[connectionInformation.connectionPoint name]]) )
        || ( ([connector endElement] == connectionInformation.element) && ([[connector endPin] isEqualToString:[connectionInformation.connectionPoint name]]) ) )
    {
      result = connector;
      break;
    }
  }
  return result;
}


static void fillSnappingTable( FXSchematicSnappingTable& table, id<VoltaSchematic> schematic, id<VoltaSchematicElement> draggedElement, FXConnectionInformation const & connectorInfo )
{
  // A collection of either the relative positions of the connection points of the dragged element
  // or the center position of the dragged joint
  std::set<CGFloat> draggedHorizontalPointPositions;
  std::set<CGFloat> draggedVerticalPointPositions;
  
  if ( draggedElement != nil )
  {
    if ( [[draggedElement modelName] isEqualToString:@"Node"] )
    {
      draggedHorizontalPointPositions.insert( 0 );
      draggedVerticalPointPositions.insert( 0 );    
    }
    else
    {
      id<FXShape> draggedElementShape = [draggedElement shape];
      if ( (draggedElementShape == nil) || ([[draggedElementShape connectionPoints] count] == 0) )
      {
        return; // the dragged element has no connection points
      }

      for ( FXShapeConnectionPoint* connectionPoint in [draggedElementShape connectionPoints] )
      {
        FXVector connectionPointLocation( [connectionPoint location] );
        if ( [draggedElement flipped] )
        {
          connectionPointLocation.scale(-1, 1);
        }
        connectionPointLocation.rotate( [draggedElement rotation] );
        connectionPointLocation.y *= FXSchematicVerticalOrientationFactor;
        draggedHorizontalPointPositions.insert( connectionPointLocation.y );
        draggedVerticalPointPositions.insert( connectionPointLocation.x );
      }
    }
  }
  else
  {
    // A connector joint is being dragged.
    draggedVerticalPointPositions.insert( 0 );
    draggedHorizontalPointPositions.insert( 0 );
  }

  // Set of positions with which the connection points of the dragged element can align.
  std::set<CGFloat> restingHorizontalPositions;
  std::set<CGFloat> restingVerticalPositions;
  
  // Collect the alignment positions for the connection points of all elements that are not being dragged (i.e., resting).
  NSMutableSet* restingElements = [[NSMutableSet alloc] initWithSet:[schematic elements]];
  if ( draggedElement != nil )
  {
    if ( [schematic isSelected:draggedElement] )
    {
      [restingElements minusSet:[schematic selectedElements]];
    }
    else
    {
      [restingElements removeObject:draggedElement];
    }
  }
  for ( id<VoltaSchematicElement> element in restingElements )
  {
    NSArray* connectionPoints = nil;
    
    if ( [[element modelName] isEqualToString:@"Node"] )
    {
      FX(FXShapeConnectionPoint)* virtualConnectionPoint = [[FX(FXShapeConnectionPoint) alloc] init];
      [virtualConnectionPoint setLocation:CGPointZero];
      connectionPoints = @[virtualConnectionPoint];
      FXRelease(virtualConnectionPoint)
    }
    else
    {
      id<FXShape> elementShape = [element shape];
      if ( elementShape != nil )
      {
        connectionPoints = [elementShape connectionPoints];
      }
    }
    if ( connectionPoints == nil )
    {
      continue;
    }
    
    for ( FXShapeConnectionPoint* elementConnectionPoint in connectionPoints )
    {
      FXVector restingConnectionPointLocation( [elementConnectionPoint location] );
      if ( [element flipped] )
      {
        restingConnectionPointLocation.scale(-1, 1);
      }
      restingConnectionPointLocation.rotate( [element rotation] );
      CGPoint const elementLocation = [element location];
      restingConnectionPointLocation.x += elementLocation.x;      
      restingConnectionPointLocation.y = elementLocation.y + (FXSchematicVerticalOrientationFactor * restingConnectionPointLocation.y);

      restingHorizontalPositions.insert( restingConnectionPointLocation.y );
      restingVerticalPositions.insert( restingConnectionPointLocation.x );
    } // for each connection point
  }
  
  FXIssue(59)
  if ( draggedElement != nil )
  {
    // Dragging an element.
    // Collect the alignment positions for the joints of the connectors that are not connected to dragged elements on both ends.
    for ( id<VoltaSchematicConnector> connector in [schematic connectors] )
    {
      if ( [restingElements containsObject:[connector startElement]] || [restingElements containsObject:[connector endElement]] )
      {
        for ( NSValue* jointValue in [connector joints] )
        {
          CGPoint jointPoint;
          [jointValue getValue:&jointPoint];
          restingHorizontalPositions.insert( jointPoint.y );
          restingVerticalPositions.insert( jointPoint.x );
        }
      }
    }
  }
  else
  {
    // Dragging a joint.
    // Collect the alignment positions for the joints of all connectors except, of course, the dragged joint.
    for ( id<VoltaSchematicConnector> connector in [schematic connectors]  )
    {
      NSUInteger jointIndex = 0;      
      for ( NSValue* jointValue in [connector joints] )
      {
        if ( (connector != connectorInfo.connector) || (jointIndex != (connectorInfo.jointIndex1 - 1) ) )
        {
          CGPoint jointPoint;
          [jointValue getValue:&jointPoint];
          restingHorizontalPositions.insert( jointPoint.y );
          restingVerticalPositions.insert( jointPoint.x );
        }
        jointIndex++;
      }
    }
  }

  // Create vertical snapping positions
  for( CGFloat restingVerticalPosition : restingVerticalPositions )
  {
    for( CGFloat draggedVerticalPointPos : draggedVerticalPointPositions )
    {
      CGFloat verticalSnappingPos = restingVerticalPosition - draggedVerticalPointPos;
      // Check if there is already an entry for this position
      bool foundExistingSnapping = false;
      for( FXSchematicSnapping & snapping : table.verticalSnappings )
      {
        if ( snapping.position == verticalSnappingPos )
        {
          foundExistingSnapping = true;
          // Add alignment line position to the existing snapping.
          snapping.alignmentLinePositions.insert( restingVerticalPosition );
          break;
        }
      }
      if ( !foundExistingSnapping )
      {
        FXSchematicSnapping verticalSnapping;
        verticalSnapping.position = verticalSnappingPos;
        verticalSnapping.alignmentLinePositions.insert( restingVerticalPosition );
        table.verticalSnappings.push_back(verticalSnapping);
      }
    }
  }
  
  // Create horizontal snapping positions
  for( CGFloat restingHorizontalPosition : restingHorizontalPositions  )
  {
    for( CGFloat draggedHorizontalPointPos : draggedHorizontalPointPositions )
    {
      CGFloat horizontalSnappingPos = restingHorizontalPosition - draggedHorizontalPointPos;
      // Check if there is already an entry for this position
      bool foundExistingSnapping = false;
      for( FXSchematicSnapping & snapping : table.horizontalSnappings )
      {
        if ( snapping.position == horizontalSnappingPos )
        {
          foundExistingSnapping = true;
          // Add alignment line position to the existing snapping.
          snapping.alignmentLinePositions.insert( restingHorizontalPosition );
          break;
        }
      }
      if ( !foundExistingSnapping )
      {
        FXSchematicSnapping horizontalSnapping;
        horizontalSnapping.position = horizontalSnappingPos;
        horizontalSnapping.alignmentLinePositions.insert( restingHorizontalPosition );
        table.horizontalSnappings.push_back(horizontalSnapping);
      }
    }
  }
  
  FXRelease(restingElements)

  // Sort the table entries
  std::sort( table.verticalSnappings.begin(), table.verticalSnappings.end() );
  std::sort( table.horizontalSnappings.begin(), table.horizontalSnappings.end() );
  
#if 0 && VOLTA_DEBUG
  std::cout << std::endl << "Vertical snapping positions" << std::endl;
  for( FXSchematicSnapping & snapping : table.verticalSnappings )
  {
    std::cout << snapping.position << std::endl;
  }
  std::cout << std::endl << "Horizontal snapping positions" << std::endl;
  for( FXSchematicSnapping & snapping : table.horizontalSnappings )
  {
    std::cout << snapping.position << std::endl;
  }
#endif
}


void FXSchematicUtilities::fillElementSnappingTable( FXSchematicSnappingTable& table, id<VoltaSchematic> schematic, id<VoltaSchematicElement> draggedElement )
{
  FXConnectionInformation dummy;
  fillSnappingTable( table, schematic, draggedElement, dummy );
}


void FXSchematicUtilities::fillJointSnappingTable( FXSchematicSnappingTable& table, id<VoltaSchematic> schematic, FXConnectionInformation const & connectorInfo )
{
  fillSnappingTable( table, schematic, nil, connectorInfo );
}


bool FXSchematicUtilities::simplifyConnectorRoute( id<VoltaSchematicConnector> connector )
{
  if ( ([connector startElement] == nil)
    || ([connector endElement] == nil)
    || ([connector joints] == nil)
    || ([[connector joints] count] == 0) )
  {
    return false;
  }

  FXVector currentJointPoint, lastJointPoint, nextJointPoint;
  std::stack<NSUInteger> toBePurged; // indices of joints that can be removed
  NSUInteger const numJoints = 2 + [[connector joints] count]; // also counting connector start point and end point
  for ( NSUInteger currentJointIndex = 1; currentJointIndex < (numJoints - 1); currentJointIndex++ )
  {
    NSValue* currentJointPointValue = connector.joints[currentJointIndex - 1];
    CGPoint currentJointCGPoint;
    [currentJointPointValue getValue:&currentJointCGPoint];
    currentJointPoint = FXVector( currentJointCGPoint );

    if ( currentJointIndex == 1 )
    {
      // the last joint is the start point of the connector
      id<VoltaSchematicElement> startElement = [connector startElement];
      FXVector const startElementLocation( [startElement location] );
      id<FXShape> startShape = [startElement shape];
      for ( FXShapeConnectionPoint* pin in [startShape connectionPoints] )
      {
        if ( [[pin name] isEqualToString:[connector startPin]] )
        {
          lastJointPoint = FXVector( [pin location] );
          break;
        }
      }
      if ( [startElement flipped] )
      {
        lastJointPoint.scale(-1, 1);
      }
      lastJointPoint.rotate( [startElement rotation] );
      lastJointPoint.y *= FXSchematicVerticalOrientationFactor;
      lastJointPoint = lastJointPoint + startElementLocation;
    }
    else
    {
      NSValue* lastJointPointValue = connector.joints[currentJointIndex - 2];
      CGPoint lastJointCGPoint;
      [lastJointPointValue getValue:&lastJointCGPoint];
      lastJointPoint = FXVector( lastJointCGPoint );
    }

    if ( currentJointIndex == (numJoints - 2) )
    {
      id<VoltaSchematicElement> endElement = [connector endElement];
      FXVector endElementLocation( [endElement location] );
      id<FXShape> endShape = [endElement shape];
      for ( FXShapeConnectionPoint* pin in [endShape connectionPoints] )
      {
        if ( [[pin name] isEqualToString:[connector endPin]] )
        {
          nextJointPoint = FXVector( [pin location] );
        }
      }
      if ( [endElement flipped] )
      {
        nextJointPoint.scale(-1, 1);
      }
      nextJointPoint.rotate( [endElement rotation] );
      nextJointPoint.y *= FXSchematicVerticalOrientationFactor;
      nextJointPoint = nextJointPoint + endElementLocation;
    }
    else
    {
      NSValue* nextJointPointValue = connector.joints[currentJointIndex];
      CGPoint nextJointCGPoint;
      [nextJointPointValue getValue:&nextJointCGPoint];
      nextJointPoint = FXVector( nextJointCGPoint );
    }

    // Test if the three joint points are in line.
    CGFloat magnitudesOfTwoSegments = (currentJointPoint - lastJointPoint).magnitude() + (currentJointPoint - nextJointPoint).magnitude();
    CGFloat magnitudeOfDirectLine = (nextJointPoint - lastJointPoint).magnitude(); // imaginary line that goes directly from lastPoint to nextPoint
    if ( fabs( magnitudesOfTwoSegments - magnitudeOfDirectLine ) < FXSchematicProximityThreshold )
    {
      toBePurged.push( currentJointIndex - 1 );
    }
  }
  
  bool purgedJoints = !toBePurged.empty();

  while ( !toBePurged.empty() )
  {
    // Remove the objects starting from the end of the array, otherwise the
    // indices in the stack won't not match the array anymore.
    [[connector joints] removeObjectAtIndex:toBePurged.top()];
    toBePurged.pop();
  }

  return purgedJoints;
}

