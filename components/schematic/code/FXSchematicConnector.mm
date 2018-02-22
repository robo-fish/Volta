#import "FXSchematicConnector.h"
#import "FXSchematicElement.h"
#import "FXShapeConnectionPoint.h"

@implementation FX(FXSchematicConnector)
{
@private
  id<VoltaSchematicElement> mStartElement;
  id<VoltaSchematicElement> mEndElement;
  NSString* mStartPin;
  NSString* mEndPin;
  NSMutableArray* mJoints;
}

@synthesize startElement = mStartElement;
@synthesize endElement = mEndElement;
@synthesize startPin = mStartPin;
@synthesize endPin = mEndPin;
@synthesize joints = mJoints;

- (id) init
{
  self = [super init];
  mStartElement = nil;
  mEndElement = nil;
  mStartPin = nil;
  mEndPin = nil;
  mJoints = nil;
  return self;
}


- (void) dealloc
{
  self.startElement = nil;
  self.endElement = nil;
  self.startPin = nil;
  self.endPin = nil;
  self.joints = nil;
  FXDeallocSuper
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone *)zone
{
  FX(FXSchematicConnector)* newConnector = [[[self class] allocWithZone:zone] init];
  [newConnector setStartElement:[self startElement]];
  [newConnector setEndElement:[self endElement]];
  [newConnector setStartPin:[self startPin]];
  [newConnector setEndPin:[self endPin]];
  NSMutableArray* newJoints = [[NSMutableArray alloc] initWithArray:[self joints] copyItems:YES];
  [newConnector setJoints:newJoints];
  FXRelease(newJoints)
  return newConnector;
}


@end
