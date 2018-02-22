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

#import "FXConnectionTool.h"
#import "FXSchematicView.h"
#import "FXSchematic.h"
#import "FXSchematicElement.h"
#import "FXShapeConnectionPoint.h"
#import "FXSchematicConnector.h"
#import "FXSchematicUtilities.h"
#import "FXSchematicUndoManager.h"
#import "FXSchematicCapture.h"


@implementation FXConnectionTool
{
@private
  id<VoltaSchematic> __weak   mSchematic;
  id<VoltaSchematicElement>   mStartElement;
  id<VoltaSchematicElement>   mCurrentElement;
  id<VoltaSchematicConnector> mConnector;
  
  NSPoint mStartPinOffset;
  NSPoint mEndPinOffset;
  BOOL mDraggingNewConnection; ///< whether the user is extending a new connection
  
  FX(FXSchematicCapture)* mCapturedSchematic; ///< captured before the connection is made
}

@synthesize schematic = mSchematic;

- (id) init
{
  self = [super init];
  [self reset];
  return self;
}

- (void) dealloc
{
  [self reset];
  FXDeallocSuper
}


#pragma mark VoltaSchematicTool


- (NSString*) name
{
  return @"Connection";
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
  [mSchematic setHasHighlightedConnectionPoint:NO];
  if ( mCapturedSchematic != nil )
  {
    FXRelease(mCapturedSchematic)
    mCapturedSchematic = nil;
  }
  mConnector = nil;
  mStartElement = nil;
  mCurrentElement = nil;
  mStartPinOffset = NSZeroPoint;
  mEndPinOffset = NSZeroPoint;
  mDraggingNewConnection = NO;
}


#pragma mark FXSchematicTool


- (BOOL) mouseDown:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  [self activate];
  NSAssert( mConnector == nil, @"no temporary connector should exist here" );
  FXConnectionInformation connectionInformation = FXSchematicUtilities::connectionAtPoint(location, mSchematic);
  if ( connectionInformation.connectionPoint != nil )
  {
    mCapturedSchematic = [[FX(FXSchematicCapture) alloc] initWithSchematic:mSchematic];

    id<VoltaSchematicConnector> existingConnector = FXSchematicUtilities::connectorAtConnectionPoint(connectionInformation, mSchematic);
    if ( existingConnector != nil )
    {
      FXIssue(36)
      mConnector = existingConnector;
      if ( connectionInformation.element == [mConnector startElement] )
      {
        [mConnector setStartElement:nil];
        [mConnector setStartPin:nil];
      }
      else
      {
        [mConnector setEndElement:nil];
        [mConnector setEndPin:nil];
      }
    }
    else
    {
      // Create a new temporary connector
      mDraggingNewConnection = YES;
      FX(FXSchematicConnector)* newConnector = [FX(FXSchematicConnector) new];
      [newConnector setStartElement:connectionInformation.element];
      [newConnector setStartPin:[connectionInformation.connectionPoint name]];
      [newConnector setJoints:[NSMutableArray arrayWithObject:[NSValue valueWithBytes:&location objCType:@encode(CGPoint)]]];
      [mSchematic addConnector:newConnector];
      FXRelease(newConnector)
      mConnector = newConnector;
      return YES;
    }
  }
  return NO;
}

- (BOOL) mouseUp:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  BOOL result = NO;
  if ( mConnector != nil )
  {
    FXConnectionInformation connectionInformation = FXSchematicUtilities::connectionAtPoint(location, mSchematic);
    if ( (connectionInformation.connectionPoint != nil) &&
        !((connectionInformation.element == mConnector.startElement) && [[connectionInformation.connectionPoint name] isEqualToString:[mConnector startPin]]) )
    {
      // The free end of the connector is dropped on a connection point.

      // Create a connection only if the connection point is not occupied already.
      if ( [mSchematic isConnectionPointConnected:connectionInformation.connectionPoint forElement:connectionInformation.element] )
      {
        FXIssue(53)
        [mSchematic removeConnector:mConnector];
      }
      else
      {
        [mConnector setJoints:nil];
        if ( [mConnector endElement] == nil )
        {
          [mConnector setEndElement:connectionInformation.element];
          [mConnector setEndPin:[connectionInformation.connectionPoint name]];
        }
        else
        {
          [mConnector setStartElement:connectionInformation.element];
          [mConnector setStartPin:[connectionInformation.connectionPoint name]];
        }

        NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_connect"), @"CapturedSchematic" : mCapturedSchematic };
        [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];
      }
    }
    else
    {
      if ( !mDraggingNewConnection )
      {
        // Removing an existing connection
        NSDictionary* undoUserInfo = @{  @"ActionName" : FXLocalizedString(@"Action_disconnect"), @"CapturedSchematic" : mCapturedSchematic };
        [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];
      }
      [mSchematic removeConnector:mConnector];
    }
    result = YES;
  }
  [self reset];
  return result;
}

- (BOOL) mouseDragged:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  BOOL viewNeedsRefresh = NO;
  if ( mConnector != nil )
  {
    // Pull the other end of the connector
    CGPoint temporaryJointLocation = { location.x, location.y };
    [mConnector setJoints:[NSMutableArray arrayWithObject:[NSValue valueWithBytes:&temporaryJointLocation objCType:@encode(CGPoint)]]];
    
    // Highlight any connection point the mouse pointer may be hovering on
    FXConnectionInformation connectionInformation = FXSchematicUtilities::connectionAtPoint(location, mSchematic);
    if ( (connectionInformation.connectionPoint != nil)
        && ((connectionInformation.element != [mConnector startElement]) || ![[connectionInformation.connectionPoint name] isEqualToString:[mConnector startPin]])
        && ( ![mSchematic isConnectionPointConnected:connectionInformation.connectionPoint forElement:connectionInformation.element] ) )
    {
      [mSchematic setHasHighlightedConnectionPoint:YES];
      [mSchematic setHighlightedConnectionPoint:connectionInformation.connectionPointLocation];
    }
    else
    {
      [mSchematic setHasHighlightedConnectionPoint:NO];
    }

    viewNeedsRefresh = YES;
  }
  return viewNeedsRefresh;
}

- (BOOL) mouseMoved:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location connectionInfo:(FXConnectionInformation*)connectionInfo
{
  BOOL refreshView = NO;
  if ( connectionInfo != nullptr )
  {
    if ( connectionInfo->connectionPoint != nil )
    {
      [mSchematic setHasHighlightedConnectionPoint:YES];
      [mSchematic setHighlightedConnectionPoint:connectionInfo->connectionPointLocation];
      refreshView = YES;
    }
    else
    {
      if ( [mSchematic hasHighlightedConnectionPoint] )
      {
        [mSchematic setHasHighlightedConnectionPoint:NO];
        refreshView = YES;
      }
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
  return NO;
}

- (BOOL) toolExecuteDeleteKey
{
  return NO;
}

- (BOOL) toolHandleKeyPress:(UniChar)keyCode modifierFlags:(NSUInteger)flags
{
  return NO;
}


@end
