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

#import "VoltaSchematic.h"
#import "VoltaSchematicElement.h"
#import "FXShapeConnectionPoint.h"
#import "VoltaSchematicConnector.h"
#import "FXSchematicSnappingTable.h"
#import "FXConnectionInformation.h"


struct FXSchematicUtilities
{
  /// @return the point in schematic space corresponding to the given point in view space.
  static CGPoint convertToSchematicSpace( CGPoint pointInViewSpace, id<VoltaSchematic> schematic);

  /// @return connection information about the given location in the schematic
  /// @param location must be given in the schematic coordinate space.
  static FXConnectionInformation connectionAtPoint( CGPoint location, id<VoltaSchematic> schematic );

  /// @return the VoltaSchematicConnector which is connected to the given connection point.
  static id<VoltaSchematicConnector> connectorAtConnectionPoint( FXConnectionInformation connectionInformation, id<VoltaSchematic> schematic );

  /// Creates a table of snapping points which the dragged element can be snapped to
  /// in order to help the user to align it with
  ///   1) connection points of elements that are not dragged,
  ///   2) joints of connectors that are not dragged.
  /// @param element Should be the element that is dragged.
  /// Thread-safe.
  static void fillElementSnappingTable( FXSchematicSnappingTable& table, id<VoltaSchematic> schematic, id<VoltaSchematicElement> element );

  /// Creates a table of snapping points which the dragged joint can be snapped to
  /// in order to help the user to align it with
  ///   1) connection points of elements
  ///   2) other joints
  /// Thread-safe.
  static void fillJointSnappingTable( FXSchematicSnappingTable& table, id<VoltaSchematic> schematic, FXConnectionInformation const & connectorInfo );
  
  /// Eliminates unnecessary joints from the connector.
  /// @return true if any joint was removed from the connector, false otherwise.
  static bool simplifyConnectorRoute( id<VoltaSchematicConnector> connector );
};



/// The minimum distance to some schematic hotspot at which the mouse pointer
/// can be considered on top of it.
extern const CGFloat FXSchematicProximityThreshold;

/// 1 or -1, depending on the vertical orientation (a.k.a. flippedness) of the schematic canvas.
extern const int FXSchematicVerticalOrientationFactor;
