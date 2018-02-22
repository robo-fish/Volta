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

#import "FXSchematicInspectorController.h"
#import "FXSchematicInspectorView.h"


@implementation FX(FXSchematicInspectorController)
{
@private
  BOOL                               mInspectorViewIsVisible;
  id<VoltaSchematic>                 mSchematic;
  FX(FXSchematicElementInspector)*   mElementInspector;
  FX(FXSchematicSchematicInspector)* mSchematicInspector;
}


@synthesize elementInspector = mElementInspector;
@synthesize schematicInspector = mSchematicInspector;


- (id) init
{
  self = [super initWithNibName:nil bundle:nil];
  if ( self != nil )
  {
    mElementInspector = [[FX(FXSchematicElementInspector) alloc] init];
    mSchematicInspector = [[FX(FXSchematicSchematicInspector) alloc] init];
    mInspectorViewIsVisible = YES;
  }
  return self;
}


- (void) dealloc
{
  [(FXSchematicInspectorView*)[self view] setInspectionView:nil];
  FXRelease(mElementInspector)
  FXRelease(mSchematicInspector)
  FXDeallocSuper
}


#pragma mark NSViewController overrides


- (void) loadView
{
  NSRect const dummyRect = NSMakeRect(0,0,200,200);
  FXSchematicInspectorView* inspectorView = [[FXSchematicInspectorView alloc] initWithFrame:dummyRect];
  [self setView:inspectorView];
  FXRelease(inspectorView)
}


#pragma mark NSResponder overrides


- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  [super encodeRestorableStateWithCoder:state];
  [[self view] encodeRestorableStateWithCoder:state];
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  [super restoreStateWithCoder:state];
  [[self view] restoreStateWithCoder:state];
}


#pragma mark Public


- (BOOL) visible
{
  return mInspectorViewIsVisible;
}


- (void) setVisible:(BOOL)visible
{
  if ( mInspectorViewIsVisible != visible )
  {
    if ( mInspectorViewIsVisible )
    {
      [(FX(FXSchematicInspectorView)*)[self view] hide];
    }
    else
    {
      [(FX(FXSchematicInspectorView)*)[self view] show];
    }
  }
  mInspectorViewIsVisible = visible;
}


- (void) setSchematic:(id<VoltaSchematic>)newSchematic
{
  if ( mSchematic != newSchematic )
  {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:VoltaSchematicSelectionHasChangedNotification object:mSchematic];
    [notificationCenter removeObserver:self name:VoltaSchematicElementRemovedFromSchematicNotification object:mSchematic];
    FXRelease(mSchematic)
    mSchematic = newSchematic;
    FXRetain(mSchematic)
    [notificationCenter addObserver:self selector:@selector(handleSchematicSelectionChange:) name:VoltaSchematicSelectionHasChangedNotification object:mSchematic];
    [notificationCenter addObserver:self selector:@selector(handleElementRemoval:) name:VoltaSchematicElementRemovedFromSchematicNotification object:mSchematic];
  }
  [self update];
}


- (id<VoltaSchematic>) schematic
{
  FXRetain(mSchematic)
  FXAutorelease(mSchematic)
  return mSchematic;
}


- (void) update
{
  if ( [mSchematic numberOfSelectedElements] > 0 )
  {
    [self inspectSelectedElements];
  }
  else
  {
    [self inspectSchematic];
  }
}


#pragma mark Private


- (void) handleSchematicSelectionChange:(NSNotification*)notification
{
  [self update];
}


- (void) handleElementRemoval:(id)sender
{
  [self update];
}


- (void) inspectSelectedElements
{
  [(FXSchematicInspectorView*)[self view] setInspectionView:[mElementInspector view]];
  [mElementInspector inspect:[mSchematic selectedElements]];
  [[self view] setNeedsDisplay:YES];
}


- (void) inspectSchematic
{
  [mElementInspector inspect:nil];
  [mSchematicInspector inspect:mSchematic];
  [(FXSchematicInspectorView*)[self view] setInspectionView:[mSchematicInspector view]];
  [[self view] setNeedsDisplay:YES];
}


@end
