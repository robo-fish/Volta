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

#import "FXSchematicUndoManager.h"
#import "VoltaSchematicElement.h"
#import "VoltaPersistentTypes.h"
#import "FXSchematicCapture.h"


NSString* FXSchematicCreateUndoPointNotification      = @"FXSchematicCreateUndoPointNotification";
NSString* FXSchematicDidCreateUndoPointNotification   = @"FXSchematicDidCreateUndoPointNotification";
NSString* FXSchematicInsideUndoNotification           = @"FXSchematicInsideUndoNotification";
NSString* FXSchematicInsideRedoNotification           = @"FXSchematicInsideRedoNotification";

@interface FX(FXSchematicUndoManager) ()
{
@private
  id<VoltaSchematic> mSchematic;
  NSUndoManager* __weak mUndoManager;
}

@end


#pragma mark -


@implementation FX(FXSchematicUndoManager)

@synthesize undoManager = mUndoManager;

- (id) init
{
  self = [super init];
  if ( self != nil )
  {
    mSchematic = nil;
  }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  FXRelease(mSchematic)
  FXDeallocSuper
}


#pragma mark Public


- (void) setSchematic:(NSObject <VoltaSchematic> *)newSchematic
{
  if ( newSchematic != mSchematic )
  {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];

    if ( mSchematic != nil )
    {
      [notificationCenter removeObserver:self name:FXSchematicCreateUndoPointNotification object:mSchematic];
      FXRelease(mSchematic)
      mSchematic = nil;
    }

    mSchematic = newSchematic;
    if ( mSchematic != nil )
    {
      FXRetain(mSchematic)
      [notificationCenter addObserver:self selector:@selector(createUndoPoint:) name:FXSchematicCreateUndoPointNotification object:mSchematic];
    }
  }
}


- (NSObject <VoltaSchematic> *) schematic
{
  return mSchematic;
}


#pragma mark Private


/// Replaces the contents of the current schematic with data restored from given capture.
- (void) restoreCapturedSchematic:(FXSchematicCapture*)inCapturedSchematic
{
  if ( inCapturedSchematic != nil )
  {
    CGFloat const scaleFactor = mSchematic.scaleFactor; // the scale factor should be preserved

    // The undo of the undo is the current state of the schematic.
    FXSchematicCapture* newCapture = [[FXSchematicCapture alloc] initWithSchematic:mSchematic];
    [self.undoManager registerUndoWithTarget:self selector:@selector(restoreCapturedSchematic:) object:newCapture];
    FXRelease(newCapture)

    // Applying the previous state
    [inCapturedSchematic restoreSchematic:mSchematic];
    mSchematic.scaleFactor = scaleFactor;
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter postNotificationName:VoltaSchematicElementUpdateNotification object:mSchematic];
    [notificationCenter postNotificationName:VoltaSchematicBoundingBoxNeedsUpdateNotification object:mSchematic]; FXIssue(112)

    if ( self.undoManager != nil )
    {
      if ( [self.undoManager isUndoing] )
      {
        [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicInsideUndoNotification object:self];
      }
      else if ( [self.undoManager isRedoing] )
      {
        [notificationCenter postNotificationName:FXSchematicInsideRedoNotification object:self];
      }
    }
  }
}


- (void) createUndoPoint:(NSNotification*)notification
{
  if ( self.undoManager != nil )
  {
    NSString* undoActionName = [[notification userInfo] valueForKey:@"ActionName"];
    FX(FXSchematicCapture)* capturedSchematic = [[notification userInfo] valueForKey:@"CapturedSchematic"];
    if ( capturedSchematic == nil )
    {
      capturedSchematic = [[FX(FXSchematicCapture) alloc] initWithSchematic:mSchematic];
      FXAutorelease(capturedSchematic)
    }
    if ( capturedSchematic != nil )
    {
      [self.undoManager registerUndoWithTarget:self selector:@selector(restoreCapturedSchematic:) object:capturedSchematic];
      [self.undoManager setActionName:undoActionName];
      [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicDidCreateUndoPointNotification object:self];
    }
  }
}


@end
