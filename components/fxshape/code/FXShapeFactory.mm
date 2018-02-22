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

#import "FXShapeFactory.h"
#import "FXDIPShape.h"
#import "FXBasicShape.h"
#import "FXTextShape.h"

FXString FXVolta_SubcircuitShapeType("FXVolta_SubcircuitShapeType");
FXString FXVolta_SubcircuitShapeLabel("FXVolta_SubcircuitShapeLabel");


@interface FXShapeFactory ()

+ (id<FXShape>) DIPShapeWithPinCount:(NSUInteger)pinCount;

@end




@implementation FX(FXShapeFactory)

#pragma mark Singleton methods

static FXShapeFactory* sShapeFactory = nil;

+ (FXShapeFactory*) sharedFactory
{
  @synchronized( self )
  {
    if ( sShapeFactory == nil )
    {
      sShapeFactory = [[FX(FXShapeFactory) alloc] init];
    }
  }
  return sShapeFactory;
}

+ (id) allocWithZone:(NSZone*)zone
{
  @synchronized(self)
  {
    if ( sShapeFactory == nil )
    {
      sShapeFactory = [super allocWithZone:zone];
      return sShapeFactory;  // assignment and return on first allocation
    }
  }
  return nil; //on subsequent allocation attempts return nil
}

- (id) copyWithZone:(NSZone *)zone
{
  return self;
}


#pragma mark Public


+ (id<FXShape>) DIPShapeWithPinCount:(NSUInteger)pinCount
{
  FXDIPShape* result = [[FXDIPShape alloc] initWithLeadCount:pinCount];
  FXAutorelease(result)
  return result;
}


+ (id<FXShape>) shapeFromMetaData:(std::vector<VoltaPTMetaDataItem> const &)metaData
{
  id<FXShape> shape = nil;
  FXString label;
  for( VoltaPTMetaDataItem const & metaDataItem : metaData )
  {
    if ( (shape == nil) && (metaDataItem.first == FXVolta_SubcircuitShapeType) )
    {
      FXString shapeTypeName = metaDataItem.second;
      static const FXString skDIPPrefix("DIP");
      if ( shapeTypeName.startsWith(skDIPPrefix) )
      {
        long numDIPLeads = shapeTypeName.substring(skDIPPrefix.length()).extractLong();
        shape = [self DIPShapeWithPinCount:numDIPLeads];
      }
    }
    else if ( label.empty() && (metaDataItem.first == FXVolta_SubcircuitShapeLabel) )
    {
      label = metaDataItem.second;
    }
    if ( (shape != nil) && !label.empty() )
    {
      break;
    }
  }
  if ( (shape != nil) && (!label.empty()) )
  {
    NSString* labelAttribute = [NSString stringWithString:(__bridge NSString*)label.cfString()];
    shape.attributes = @{@"label" : labelAttribute};
  }
  return shape;
}


+ (id<FXShape>) shapeWithPersistentShape:(VoltaPTShape const &)shape persistentPins:(std::vector<VoltaPTPin> const &)pins
{
  if ( shape.paths.empty() && shape.circles.empty() )
    return nil;

  FXBasicShape* basicShape = [[FXBasicShape alloc] initWithPersistentShape:shape persistentPins:pins];
  FXAutorelease(basicShape)
  return basicShape;
}


+ (id<FXShape>) shapeFromText:(NSString*)text
{
  FXTextShape* textShape = [[FXTextShape alloc] init];
  textShape.attributes = @{ @"text" : text };
  FXAutorelease(textShape)
  return textShape;
}



@end
