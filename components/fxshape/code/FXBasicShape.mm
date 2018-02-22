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

#import "FXBasicShape.h"
#import "FXPath.h"
#import "FXCircle.h"
#import "FXShapeConnectionPoint.h"

@interface FXBasicShape ()
@property (readwrite, copy) NSArray* paths;
@property (readwrite, copy) NSArray* circles;
@property (readwrite, copy) NSArray* connectionPoints;
@property (readwrite) CGSize size;
@end


@implementation FXBasicShape

@synthesize attributes = mAttributes;
@synthesize paths = mPaths;
@synthesize connectionPoints = mConnectionPoints;
@synthesize circles = mCircles;
@synthesize size;


- (id) init
{
  return [self initWithPaths:nil circles:nil connectionPoints:nil size:CGSizeMake(0,0)];
}


- (id) initWithPersistentShape:(VoltaPTShape const &)shape persistentPins:(std::vector<VoltaPTPin> const &)pins
{
  // Create an FXShape from the given data and add it to the registry.
  NSMutableArray* paths = [NSMutableArray arrayWithCapacity:(NSUInteger)shape.paths.size()];
  for( VoltaPTPath const & path : shape.paths )
  {
    FXPath* currentPath = [FXPath pathWithData:(__bridge NSString*)path.pathData.cfString()];
    [currentPath setFilled:path.filled];
    [paths addObject:currentPath];
  }
  
  NSMutableArray* circles = [NSMutableArray arrayWithCapacity:(NSUInteger)shape.circles.size()];
  for( VoltaPTCircle const & circle : shape.circles )
  {
    FXCircle* currentCircle = [FXCircle circleWithCenter:CGPointMake(circle.centerX, circle.centerY) radius:circle.radius];
    [currentCircle setFilled:circle.filled];
    [circles addObject:currentCircle];
  }
  
  CGSize shapeSize = CGSizeMake(shape.width, shape.height);
  NSMutableArray* connectionPoints = nil;
  if ( !pins.empty() )
  {
    connectionPoints = [NSMutableArray arrayWithCapacity:(NSUInteger)pins.size()];
    for( VoltaPTPin const & pin : pins )
    {
      FXShapeConnectionPoint* cPoint = [[FXShapeConnectionPoint alloc] init];
      [cPoint setLocation:CGPointMake( pin.posX, pin.posY )];
      [cPoint setName:(__bridge NSString*) pin.name.cfString()];
      [connectionPoints addObject:cPoint];
      FXRelease(cPoint)
    }
  }
  return [self initWithPaths:paths circles:circles connectionPoints:connectionPoints size:shapeSize];
}


- (id) initWithPaths:(NSArray*)paths circles:(NSArray*)circles connectionPoints:(NSArray*)connectionPoints size:(CGSize)shapeSize
{
  self = [super init];
  mPaths = [[NSArray alloc] initWithArray:paths];
  mCircles = [[NSArray alloc] initWithArray:circles];
  mConnectionPoints = [[NSArray alloc] initWithArray:connectionPoints];
  self.size = shapeSize;
  return self;
}


- (void) dealloc
{
  self.attributes = nil;
  self.paths = nil;
  self.circles = nil;
  self.connectionPoints = nil;
  FXDeallocSuper
}



#pragma mark FXShape


- (BOOL) doesOwnDrawing
{
  return NO;
}


- (BOOL) isReusable
{
  return YES;
}


- (void) drawWithContext:(FXShapeRenderContext)context
{
  // ignored
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:self.paths            forKey:@"Paths"];
  [encoder encodeObject:self.circles          forKey:@"Circles"];
  [encoder encodeObject:self.connectionPoints forKey:@"Connection Points"];
  [encoder encodeObject:self.attributes       forKey:@"Attributes"];
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  self.paths = [decoder decodeObjectForKey:@"Paths"];
  self.circles = [decoder decodeObjectForKey:@"Circles"];
  self.connectionPoints = [decoder decodeObjectForKey:@"Connection Points"];
  self.attributes = [decoder decodeObjectForKey:@"Attributes"];
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXBasicShape* newCopy = [[[self class] allocWithZone:zone] init];
  NSArray* copiedPaths = [[NSArray alloc] initWithArray:mPaths copyItems:YES];
  newCopy.paths = copiedPaths;
  FXRelease(copiedPaths)

  NSArray* copiedCircles = [[NSArray alloc] initWithArray:mCircles copyItems:YES];
  newCopy.circles = copiedCircles;
  FXRelease(copiedCircles)

  NSArray* copiedConnectionPoints = [[NSArray alloc] initWithArray:mConnectionPoints copyItems:YES];
  newCopy.connectionPoints = copiedConnectionPoints;
  FXRelease(copiedConnectionPoints)

  NSDictionary* copiedAttributes = [[NSDictionary alloc] initWithDictionary:self.attributes copyItems:YES];
  newCopy.attributes = copiedAttributes;
  FXRelease(copiedAttributes)

  return newCopy;
}

@end
