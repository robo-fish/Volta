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

#import "FXProperty.h"


@implementation FXProperty
{
@private
  NSString* mName;
  NSString* mValue;
}

@synthesize name = mName;
@synthesize value = mValue;

- (id) initWithPersistentProperty:(VoltaPTProperty)property
{
  self = [super init];
  mName = [(__bridge NSString*)property.name.cfString() copy];
  mValue = [(__bridge NSString*)property.value.cfString() copy];
  return self;
}

- (void) dealloc
{
  FXRelease(mValue)
  FXRelease(mName)
  FXDeallocSuper
}

- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:mName forKey:@"Name"];
  [encoder encodeObject:mValue forKey:@"Value"];
}

- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  mName = [decoder decodeObjectForKey:@"Name"];
  FXRetain(mName)
  mValue = [decoder decodeObjectForKey:@"Value"];
  FXRetain(mValue)
  return self;
}

@end
