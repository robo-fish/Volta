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

#import "FXVoltaLibraryNotifier.h"


@implementation FXVoltaLibraryNotifier
{
@private
  NSMutableArray* mObservers;
  __weak id<VoltaLibrary> mLibrary;
}


- (id) initWithLibrary:(id<VoltaLibrary>)library
{
  if ( (self = [super init]) != nil )
  {
    mLibrary = library;
    mObservers = [NSMutableArray new];
  }
  return self;
}


- (void) dealloc
{
  mLibrary = nil;
  FXRelease(mObservers)
  FXDeallocSuper
}


#pragma mark Public methods


- (void) addObserver:(id<VoltaLibraryObserver>)observer
{
  if ( ![mObservers containsObject:observer] )
  {
    [mObservers addObject:observer];
  }
}


- (void) removeObserver:(id<VoltaLibraryObserver>)observer
{
  [mObservers removeObject:observer];  
}


- (void) notifyModelsChanged
{
  for ( id<VoltaLibraryObserver> observer in mObservers )
  {
    if ( [observer respondsToSelector:@selector(handleVoltaLibraryModelsChanged:)] )
    {
      [observer handleVoltaLibraryModelsChanged:mLibrary];
    }
  }
}


- (void) notifyPaletteChanged
{
  for ( id<VoltaLibraryObserver> observer in mObservers )
  {
    if ( [observer respondsToSelector:@selector(handleVoltaLibraryPaletteChanged:)] )
    {
      [observer handleVoltaLibraryPaletteChanged:mLibrary];
    }
  }
}


- (void) notifySubcircuitsChanged
{
  for ( id<VoltaLibraryObserver> observer in mObservers )
  {
    if ( [observer respondsToSelector:@selector(handleVoltaLibraryChangedSubcircuits:)] )
    {
      [observer handleVoltaLibraryChangedSubcircuits:mLibrary];
    }
  }
}


- (void) notifyOpenEditor
{
  for ( id<VoltaLibraryObserver> observer in mObservers )
  {
    if ( [observer respondsToSelector:@selector(handleVoltaLibraryOpenEditor:)] )
    {
      [observer handleVoltaLibraryOpenEditor:mLibrary];
    }
  }
}


- (void) notifyShutDown
{
  for ( id<VoltaLibraryObserver> observer in mObservers )
  {
    if ( [observer respondsToSelector:@selector(handleVoltaLibraryWillShutDown:)] )
    {
      [observer handleVoltaLibraryWillShutDown:mLibrary];
    }
  }
}



@end
