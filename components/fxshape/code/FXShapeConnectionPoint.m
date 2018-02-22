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

#import "FXShapeConnectionPoint.h"

@interface FX(FXShapeConnectionPoint) ()
{
  CGPoint   mLocation;
  NSString* mName;
}
@end


@implementation FX(FXShapeConnectionPoint)

@synthesize name = mName;
@synthesize location = mLocation;

- (id) init
{
  self = [super init];
  mLocation = CGPointZero;
  mName = nil;
  return self;
}


- (void) dealloc
{
  FXRelease(mName)
  FXDeallocSuper
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -

- (id) copyWithZone:(NSZone *)zone
{
  FX(FXShapeConnectionPoint)* newConnectionPoint = [[[self class] allocWithZone:zone] init];
  newConnectionPoint.location = self.location;
  newConnectionPoint.name = self.name;
  return newConnectionPoint;
}

@end
