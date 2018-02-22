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

@protocol VoltaSchematicConnector;
@protocol VoltaSchematicElement;
@class FXShapeConnectionPoint;

/// Information about the schematic element and its connection point at some location in the schematic.
/// This structure is used to store information about the connector that is
/// closest to a certain location.
struct FXConnectionInformation
{

  // The element which the point is inside. Nil if not inside an element.
  id<VoltaSchematicElement> element;
  
  // The connection point which the point is inside.
  // Nil if not inside a connection point or not inside an element.
  FXShapeConnectionPoint* connectionPoint;
  
  // The center location (in schematic coordinates) of the connection point
  // which the point is inside. Valid only if connectionPoint is not nil.
  CGPoint connectionPointLocation;

  
  
  // Nil if no connector passes close to the location.
  // Invalid if element is not nil.
  id<VoltaSchematicConnector> connector;
  
  // These two indices are valid only if connector is not nil.
  //
  // If jointIndex2 == jointIndex1 then this indicates that the tested
  // location is on top of the referenced joint.
  //
  // If jointIndex2 == jointIndex1 + 1 then this means the tested location
  // is close to the line segment between the referenced joints.
  // The joint with index jointIndex1 is the one that is reached first
  // when traveling from the start element to the end element.
  //
  // The start point on the start element and the end point on the end element
  // are also counted as joints. So don't forget to always convert between
  // the joint index used here and the index into the 'joints' array of a
  // VoltaSchematicConnector.
  NSUInteger jointIndex1;
  NSUInteger jointIndex2;



  FXConnectionInformation() :
    element(nil),
    connectionPoint(nil),
    connector(nil),
    jointIndex1(0),
    jointIndex2(0)
  {}

};
