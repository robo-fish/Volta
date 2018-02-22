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

#import "FXAutoTool.h"
#import "FXSelectionTool.h"
#import "FXConnectionTool.h"
#import "FXSchematicUtilities.h"
#import "FXSchematic.h"
#import "FXSchematicView.h"


@implementation FXAutoTool
{
@private
  FXSelectionTool*     mSelectionTool;
  FXConnectionTool*    mConnectionTool;
  id<VoltaSchematic>   mSchematic;
  id <FXSchematicTool> mCurrentTool;

  NSPoint   mMouseDownLocation;
  NSEvent*  mMouseDownEvent;
}


- (id) init
{
  self = [super init];
  mSelectionTool = [FXSelectionTool new];
  mConnectionTool = [FXConnectionTool new];
  [self switchToTool:mSelectionTool];
  return self;
}


- (void) dealloc
{
  [self reset];
  mCurrentTool = nil;
  FXRelease(mConnectionTool)
  FXRelease(mSelectionTool)
  FXDeallocSuper
}


#pragma mark VoltaSchematicTool


- (id<VoltaSchematic>) schematic
{
  return mSchematic;
}

- (void) setSchematic:(id<VoltaSchematic>)newSchematic
{
  if ( mSchematic != newSchematic )
  {
    mSchematic = newSchematic;
    [mCurrentTool setSchematic:mSchematic]; FXIssue(09)
  }
}

- (NSString*) name
{
  return [mCurrentTool name];
}


- (void) activate
{
}


- (void) reset
{
  FXRelease(mMouseDownEvent)
  mMouseDownEvent = nil;
  mMouseDownLocation = NSZeroPoint;
  [self switchToTool:mSelectionTool];
}


#pragma mark FXSchematicTool


- (NSCursor*) cursor
{
  return [mCurrentTool cursor];
}


- (BOOL) mouseDown:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  mMouseDownEvent = [mouseEvent copy];
  mMouseDownLocation = location;
  FXConnectionInformation connectionInfo = FXSchematicUtilities::connectionAtPoint(mMouseDownLocation, mSchematic);
  if ( connectionInfo.connectionPoint != nil )
  {
    [self switchToTool:mConnectionTool];
  }
  else
  {
    [self switchToTool:mSelectionTool];    
  }
  return [mCurrentTool mouseDown:mouseEvent schematicLocation:location];
}


- (BOOL) mouseUp:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  BOOL needsVisualRefresh = [mCurrentTool mouseUp:mouseEvent schematicLocation:location];
  [self reset];
  if ( mCurrentTool == mConnectionTool )
  {
    [self switchToTool:mSelectionTool];
  }
  return needsVisualRefresh;
}


- (BOOL) mouseDragged:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location
{
  return [mCurrentTool mouseDragged:mouseEvent schematicLocation:location];
}

- (BOOL) mouseMoved:(NSEvent*)mouseEvent schematicLocation:(NSPoint)location connectionInfo:(FXConnectionInformation*)dummy
{
  FXConnectionInformation connectionInfo = FXSchematicUtilities::connectionAtPoint(location, mSchematic);
  if ( connectionInfo.element && connectionInfo.connectionPoint )
  {
    [self switchToTool:mConnectionTool];
  }
  else if ( connectionInfo.connector && [[connectionInfo.connector joints] count] && (connectionInfo.jointIndex1 == connectionInfo.jointIndex2) )
  {
    FXIssue(59)
    [self switchToTool:mSelectionTool];
  }

  // Note: Observe that the tool is not switched back to the selection tool
  // if the current location is not near a connection point.

  return [mCurrentTool mouseMoved:mouseEvent schematicLocation:location connectionInfo:&connectionInfo];
}


- (BOOL) scrollWheel:(NSEvent*)scrollEvent schematicLocation:(NSPoint)location
{
  return [mCurrentTool scrollWheel:scrollEvent schematicLocation:location];
}


- (BOOL) toolExecuteEscapeKey
{
  return [mCurrentTool toolExecuteEscapeKey];
}


- (BOOL) toolExecuteDeleteKey
{
  return [mCurrentTool toolExecuteDeleteKey];
}


- (BOOL) toolHandleKeyPress:(UniChar)keyCode modifierFlags:(NSUInteger)flags
{
  return [mCurrentTool toolHandleKeyPress:keyCode modifierFlags:flags];
}


#pragma mark Private


- (void) switchToTool:(id<FXSchematicTool>)tool
{
  if ( tool != mCurrentTool )
  {
    if ( mCurrentTool != nil )
    {
      [mCurrentTool reset];
    }

    if ( tool != nil )
    {
      [tool setSchematic:mSchematic];
      [tool activate];
    }

    mCurrentTool = tool;
    
    if ( mCurrentTool != nil )
    {
      [[mCurrentTool cursor] set];
    }
  }
}

@end
