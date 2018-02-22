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

#import "FXAlignmentLine.h"

@implementation FXAlignmentLine

@synthesize vertical;
@synthesize position;


- (id)init
{
  if ((self = [super init]) != nil)
  {
    self.vertical = YES;
    self.position = 0.0;
  }  
  return self;
}


- (BOOL) isEqual:(id)anObject
{
  if (anObject == self)
  {
    return YES;
  }
  if ((anObject == nil) || ![anObject conformsToProtocol:@protocol(VoltaAlignmentLine)])
  {
    return NO;
  }
  id<VoltaAlignmentLine> line = anObject;
  return (self.vertical == line.vertical) && (self.position == line.position);
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXAlignmentLine* newCopy = [[[self class] allocWithZone:zone] init];
  newCopy.vertical = self.vertical;
  newCopy.position = self.position;
  return newCopy;
}


@end
