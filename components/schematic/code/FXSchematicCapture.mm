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

#import "FXSchematicCapture.h"
#import "VoltaSchematicElement.h"
#import "FXSchematicConnector.h"
#import "FXSchematicElement.h"
#import "FXShape.h"

NSString* FXSchematicCaptureWillRestoreSchematicNotification = @"FXSchematicCaptureWillRestoreSchematicNotification";
NSString* FXSchematicCaptureDidRestoreSchematicNotification  = @"FXSchematicCaptureDidRestoreSchematicNotification";


@interface FX(FXSchematicCapture) ()

+ (void) restoreElementsOfSchematic:(id <VoltaSchematic>)schematic fromCapture:(VoltaPTSchematicPtr)schematicPT;
+ (void) restoreConnectorsOfSchematic:(id <VoltaSchematic>)schematic fromCapture:(VoltaPTSchematicPtr)schematicPT;
+ (void) restorePropertiesOfSchematic:(id <VoltaSchematic>)schematic fromCapture:(VoltaPTSchematicPtr)schematicPT;
+ (void) restoreMetaDataOfSchematic:(id <VoltaSchematic>)schematic fromCapture:(VoltaPTSchematicPtr)schematicPT;

+ (void) captureElementsOfSchematic:(id <VoltaSchematic>)schematic inPersistentSchematic:(VoltaPTSchematicPtr)schematicPT;
+ (void) captureConnectorsOfSchematic:(id <VoltaSchematic>)schematic inPersistentSchematic:(VoltaPTSchematicPtr)schematicPT;
+ (void) captureMetaDataOfSchematic:(id <VoltaSchematic>)schematic inPersistentSchematic:(VoltaPTSchematicPtr)schematicPT;
+ (void) capturePropertiesOfSchematic:(id <VoltaSchematic>)schematic inPersistentSchematic:(VoltaPTSchematicPtr)schematicPT;

@end


@implementation FX(FXSchematicCapture)
{
@private
  VoltaPTSchematicPtr mSchematicData;
}


- (id) init
{
  NSAssert( NO, @"This initializer should never be called." );
  FXRelease(self)
  return nil;
}


- (id) initWithSchematic:(id <VoltaSchematic>)schematic
{
  self = [super init];
  if ( schematic != nil )
  {
    mSchematicData = [FX(FXSchematicCapture) capture:schematic];
  }
  return self;
}


- (void) dealloc
{
  FXDeallocSuper
}


- (id) copyWithZone:(NSZone *)zone
{
  FX(FXSchematicCapture)* newCopy = [[[self class] allocWithZone:zone] init];
  newCopy->mSchematicData = mSchematicData;
  return newCopy;
}


#pragma mark Public


- (BOOL) restoreSchematic:(id <VoltaSchematic>)schematic
{
  return [FX(FXSchematicCapture) restoreSchematic:schematic fromCapture:mSchematicData];
}


+ (VoltaPTSchematicPtr) capture:(id <VoltaSchematic>)schematic
{
  VoltaPTSchematicPtr result( new VoltaPTSchematic );
  if ( [schematic schematicTitle] != nil )
  {
    result->title = (__bridge CFStringRef)[schematic schematicTitle];
  }
  [self captureMetaDataOfSchematic:schematic inPersistentSchematic:result];
  [self captureElementsOfSchematic:schematic inPersistentSchematic:result];
  [self captureConnectorsOfSchematic:schematic inPersistentSchematic:result];
  [self capturePropertiesOfSchematic:schematic inPersistentSchematic:result];
  return result;
}


+ (BOOL) restoreSchematic:(id <VoltaSchematic>)schematic
              fromCapture:(VoltaPTSchematicPtr)schematicPT
{
  BOOL result = NO;
  if ( (schematic != nil) && (schematicPT.get() != nullptr) )
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCaptureWillRestoreSchematicNotification object:schematic];
    [schematic removeAll];
    [schematic setSchematicTitle:[NSString stringWithString:(__bridge NSString*)schematicPT->title.cfString()]];
    [self restoreElementsOfSchematic:schematic fromCapture:schematicPT];
    [self restoreConnectorsOfSchematic:schematic fromCapture:schematicPT];
    [self restorePropertiesOfSchematic:schematic fromCapture:schematicPT];
    [self restoreMetaDataOfSchematic:schematic fromCapture:schematicPT];
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCaptureDidRestoreSchematicNotification object:schematic];
    result = YES;
  }
  return result;
}


#pragma mark Private


+ (void) restoreElementsOfSchematic:(id <VoltaSchematic>)schematic fromCapture:(VoltaPTSchematicPtr)schematicPT
{
  for( VoltaPTElement const & schematicElement : schematicPT->elements )
  {
    FX(FXSchematicElement)* currentElement = [[FX(FXSchematicElement) alloc] init];
    [currentElement setName: (__bridge NSString*)schematicElement.name.cfString() ];
    [currentElement setType: schematicElement.type];
    [currentElement setModelName: (__bridge NSString*)schematicElement.modelName.cfString() ];
    [currentElement setModelVendor: (__bridge NSString*) schematicElement.modelVendor.cfString() ];
    [currentElement setLocation: FXPointMake( schematicElement.posX, schematicElement.posY ) ];
    [currentElement setRotation: schematicElement.rotation ];
    [currentElement setFlipped: (schematicElement.flipped ? YES : NO) ];
    switch ( schematicElement.labelPosition )
    {
      case VoltaPTLabelPosition::Top:    [currentElement setLabelPosition:SchematicRelativePosition_Top]; break;
      case VoltaPTLabelPosition::Bottom: [currentElement setLabelPosition:SchematicRelativePosition_Bottom]; break;
      case VoltaPTLabelPosition::Right:  [currentElement setLabelPosition:SchematicRelativePosition_Right];  break;
      case VoltaPTLabelPosition::Left:   [currentElement setLabelPosition:SchematicRelativePosition_Left];  break;
      default: [currentElement setLabelPosition:SchematicRelativePosition_None];
    }
    if ( !schematicElement.properties.empty() )
    {
      for( VoltaPTProperty const & property : schematicElement.properties )
      {
        NSString* propertyValue = [NSString stringWithString:(__bridge NSString*)property.value.cfString()];
        NSString* propertyName = [NSString stringWithString:(__bridge NSString*)property.name.cfString()];
        [currentElement setPropertyValue:propertyValue forKey:propertyName];
      }
    }
    [schematic addElement:currentElement];
    [currentElement setSchematic:schematic];
    FXRelease(currentElement)
  }
}


+ (void) restoreConnectorsOfSchematic:(id <VoltaSchematic>)schematic fromCapture:(VoltaPTSchematicPtr)schematicPT
{
  for( VoltaPTConnector const & schematicConnector : schematicPT->connectors )
  {
    FX(FXSchematicConnector)* currentConnector = [[FX(FXSchematicConnector) alloc] init];
    NSString* const startElementName = (__bridge NSString*) schematicConnector.startElementName.cfString();
    NSString* const endElementName = (__bridge NSString*) schematicConnector.endElementName.cfString();
    NSString* const startPinName = [NSString stringWithString:(__bridge NSString*) schematicConnector.startPinName.cfString()];
    NSString* const endPinName = [NSString stringWithString:(__bridge NSString*) schematicConnector.endPinName.cfString()];
    for ( id<VoltaSchematicElement> element in [schematic elements] )
    {
      if ( [[element name] isEqualToString:startElementName] )
      {
        [currentConnector setStartElement:element];
        [currentConnector setStartPin:startPinName];
      }
      else if ( [[element name] isEqualToString:endElementName] )
      {
        [currentConnector setEndElement:element];
        [currentConnector setEndPin:endPinName];
      }
    }
    if ( !schematicConnector.joints.empty() )
    {
      NSMutableArray* joints = [[NSMutableArray alloc] initWithCapacity:schematicConnector.joints.size()];
      for( VoltaSchematicConnectorJointData const & joint : schematicConnector.joints )
      {
        CGPoint jointPoint = { joint.first, joint.second };
        NSValue* jointValue = [NSValue valueWithBytes:&jointPoint objCType:@encode(CGPoint)];
        [joints addObject:jointValue];
      }
      [currentConnector setJoints:joints];
      FXRelease(joints)
    }
    [schematic addConnector:currentConnector];
    FXRelease(currentConnector)
  }
}


+ (void) restorePropertiesOfSchematic:(id <VoltaSchematic>)schematic fromCapture:(VoltaPTSchematicPtr)schematicPT
{
  [[schematic properties] removeAllObjects];
  for( VoltaPTProperty const & property : schematicPT->properties )
  {
    NSString* propertyName = [NSString stringWithString:(__bridge NSString*) property.name.cfString()];
    NSString* propertyValue = [NSString stringWithString:(__bridge NSString*)property.value.cfString()];
    schematic.properties[propertyName] = propertyValue;
  }
}


+ (void) restoreMetaDataOfSchematic:(id <VoltaSchematic>)schematic fromCapture:(VoltaPTSchematicPtr)schematicPT
{
  for( VoltaPTMetaDataItem const & metaDataItem : schematicPT->metaData )
  {
    if ( metaDataItem.first == "FXVolta_SchematicScaleFactor" )
    {
      try
      {
        float scaleFactor = metaDataItem.second.extractFloat();
        [schematic setScaleFactor:scaleFactor];
      }
      catch (std::runtime_error & e) {}
    }
  }
}


+ (void) captureElementsOfSchematic:(id <VoltaSchematic>)schematic inPersistentSchematic:(VoltaPTSchematicPtr)schematicPT
{
  for ( id<VoltaSchematicElement> element in [schematic elements] )
  {
    __block VoltaPTElement newElement;
    newElement.name = (__bridge CFStringRef)[element name];
    newElement.type = (VoltaModelType)[element type];
    newElement.modelName = (__bridge CFStringRef)[element modelName];
    newElement.modelVendor = (__bridge CFStringRef)[element modelVendor];
    newElement.posX = [element location].x;
    newElement.posY = [element location].y;
    newElement.rotation = [element rotation];
    newElement.flipped = [element flipped] ? true : false;
    switch ( [element labelPosition] )
    {
      case SchematicRelativePosition_Top:    newElement.labelPosition = VoltaPTLabelPosition::Top; break;
      case SchematicRelativePosition_Bottom: newElement.labelPosition = VoltaPTLabelPosition::Bottom; break;
      case SchematicRelativePosition_Right:  newElement.labelPosition = VoltaPTLabelPosition::Right; break;
      case SchematicRelativePosition_Left:   newElement.labelPosition = VoltaPTLabelPosition::Left; break;
      default: newElement.labelPosition = VoltaPTLabelPosition::None;
    }

    FXString const emptyString("");
    [element enumeratePropertiesUsingBlock:^(NSString* propertyName, id propertyValue, BOOL *stop) {
      if ( [propertyValue isKindOfClass:[NSString class]] )
      {
        FXString pValue = propertyValue ? (__bridge CFStringRef)propertyValue : emptyString;
        newElement.properties.push_back( VoltaPTProperty( (__bridge CFStringRef)propertyName , pValue) );
      }
    }];

    schematicPT->elements.insert( newElement );
  }
}


+ (void) captureConnectorsOfSchematic:(id <VoltaSchematic>)schematic inPersistentSchematic:(VoltaPTSchematicPtr)schematicPT
{
  for ( id<VoltaSchematicConnector> connector in [schematic connectors] )
  {
    VoltaPTConnector newConnectorData;
    FXString emptyString("");
    newConnectorData.startElementName = [[connector startElement] name] ? (__bridge CFStringRef)[[connector startElement] name] : emptyString;
    newConnectorData.endElementName = [[connector endElement] name] ? (__bridge CFStringRef)[[connector endElement] name] : emptyString;
    newConnectorData.startPinName = [connector startPin] ? (__bridge CFStringRef)[connector startPin] : emptyString;
    newConnectorData.endPinName = [connector endPin] ? (__bridge CFStringRef)[connector endPin] : emptyString;
    for ( NSValue* value in [connector joints] )
    {
      CGPoint pointValue;
      [value getValue:&pointValue];
      VoltaSchematicConnectorJointData newJointData;
      newJointData.first = pointValue.x;
      newJointData.second = pointValue.y;
      newConnectorData.joints.push_back( newJointData );
    }
    schematicPT->connectors.insert( newConnectorData );
  }
}


+ (void) captureMetaDataOfSchematic:(id <VoltaSchematic>)schematic inPersistentSchematic:(VoltaPTSchematicPtr)schematicPT
{
  VoltaPTMetaDataItem scaleMetaDataItem;
  scaleMetaDataItem.first = "FXVolta_SchematicScaleFactor";
  scaleMetaDataItem.second = FXString( (__bridge CFStringRef)[NSString stringWithFormat:@"%g", [schematic scaleFactor]] );
  schematicPT->metaData.push_back(scaleMetaDataItem);
}


+ (void) capturePropertiesOfSchematic:(id <VoltaSchematic>)schematic inPersistentSchematic:(VoltaPTSchematicPtr)schematicPT
{
  [[schematic properties] enumerateKeysAndObjectsUsingBlock:^(id propertyKey, id propertyValue, BOOL *stop) {
    schematicPT->properties.push_back( VoltaPTProperty( (__bridge CFStringRef)propertyKey, (__bridge CFStringRef)propertyValue ) );
  }];
}


@end
