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

#import "FXSchematic.h"
#import "FXSchematicElement.h"
#import "FXSchematicConnector.h"
#import "FXAlignmentLine.h"
#import "VoltaLibrary.h"
#import "FXVector.h"

NSString* VoltaSchematicSelectionHasChangedNotification          = @"VoltaSchematicSelectionHasChangedNotification";
NSString* VoltaSchematicElementAddedToSchematicNotification      = @"VoltaSchematicElementAddedToSchematicNotification";
NSString* VoltaSchematicElementRemovedFromSchematicNotification  = @"VoltaSchematicElementRemovedFromSchematicNotification";
NSString* VoltaSchematicConnectionMadeNotification               = @"VoltaSchematicConnectionMadeNotification";
NSString* VoltaSchematicConnectionCutNotification                = @"VoltaSchematicConnectionCutNotification";
NSString* VoltaSchematicElementModelsWillChangeNotification      = @"VoltaSchematicElementModelsWillChangeNotification";
NSString* VoltaSchematicElementModelsDidChangeNotification       = @"VoltaSchematicElementModelsDidChangeNotification";
NSString* VoltaSchematicBoundingBoxNeedsUpdateNotification       = @"VoltaSchematicBoundingBoxNeedsUpdateNotification";


@implementation FX(FXSchematic)
{
@private
  NSString*            mTitle;
  id<VoltaLibrary>     mLibrary;
  NSMutableSet*        mElements;
  NSMutableSet*        mConnectors;
  NSMutableSet*        mSelectedElements;
  NSMutableSet*        mHighlightedConnectors;
  NSSet*               mAlignmentLines;
  NSMutableDictionary* mProperties;
  
  CGFloat           mScaleFactor;
  CGRect            mSelectionBox;
  CGPoint           mHighlightedConnectionPoint;
  BOOL              mHasHighlightedConnectionPoint;
  CGPoint           mHighlightedConnectorJoint;
  BOOL              mHasHighlightedConnectorJoint;

  NSDictionary*     mElementLabelAttributes;
}

@synthesize schematicTitle = mTitle;
@synthesize selectionBox = mSelectionBox;
@synthesize hasHighlightedConnectionPoint = mHasHighlightedConnectionPoint;
@synthesize highlightedConnectionPoint = mHighlightedConnectionPoint;
@synthesize hasHighlightedConnectorJoint = mHasHighlightedConnectorJoint;
@synthesize highlightedConnectorJoint = mHighlightedConnectorJoint;
@synthesize alignmentLines = mAlignmentLines;
@synthesize scaleFactor = mScaleFactor;
@synthesize library = mLibrary;
@synthesize properties = mProperties;

- (id) init
{
  self = [super init];
  mLibrary = nil;
  mTitle = @"";
  mElements = [[NSMutableSet alloc] init];
  mConnectors = [[NSMutableSet alloc] init];
  mSelectedElements = [[NSMutableSet alloc] init];
  mHighlightedConnectors = [[NSMutableSet alloc] init];
  mProperties = [[NSMutableDictionary alloc] init];
  mAlignmentLines = nil;
  mScaleFactor = 1.0;
  mSelectionBox = CGRectZero;
  mHasHighlightedConnectionPoint = NO;
  mHasHighlightedConnectorJoint = NO;
  mHighlightedConnectionPoint = CGPointMake(-1, -1);
  mHighlightedConnectorJoint = mHighlightedConnectionPoint;
  return self;
}

- (void) dealloc
{
  FXRelease(mProperties)
  FXRelease(mAlignmentLines)
  FXRelease(mTitle)
  FXRelease(mHighlightedConnectors)
  FXRelease(mSelectedElements)
  FXRelease(mElements)
  FXRelease(mConnectors)
  FXRelease(mLibrary)
  FXDeallocSuper
}


#pragma mark VoltaSchematic


- (void) setProperties:(NSMutableDictionary*)properties
{
  if ( properties != mProperties )
  {
    [mProperties removeAllObjects];
    [mProperties addEntriesFromDictionary:properties];
  }
}


- (NSMutableDictionary*) properties
{
  return mProperties;
}


- (NSSet*) elements
{
  return [NSSet setWithSet:mElements];
}


- (NSSet*) connectors
{
  return [NSSet setWithSet:mConnectors];
}


- (NSSet*) selectedElements
{
  return [NSSet setWithSet:mSelectedElements];
}


- (void) addElement:(id<VoltaSchematicElement>)element
{
  BOOL added = NO;
  @synchronized( self )
  {
    if ( ![mElements containsObject:element] )
    {
      [mElements addObject:element];
      added = YES;
    }
  }
  if ( added )
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementAddedToSchematicNotification object:self];
  }
}


- (BOOL) removeElement:(id<VoltaSchematicElement>)element andAttachedConnectors:(BOOL)removeConnectors
{
  BOOL removed = NO;
  @synchronized( self )
  {
    if ( [mElements containsObject:element] )
    {
      if ( removeConnectors )
      {
        NSMutableSet* obsoleteConnectors = [[NSMutableSet alloc] init];
        for ( id<VoltaSchematicConnector> connector in mConnectors )
        {
          if ( (connector.endElement == element) || (connector.startElement == element) )
          {
            [obsoleteConnectors addObject:connector];
          }
        }
        for ( id<VoltaSchematicConnector> obsoleteConnector in obsoleteConnectors )
        {
          [mConnectors removeObject:obsoleteConnector];
        }
        FXRelease(obsoleteConnectors)
      }

      // Now remove the element itself
      [mSelectedElements removeObject:element];
      [mElements removeObject:element];
      removed = YES;
    }
  }
  if ( removed )
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementRemovedFromSchematicNotification object:self];
  }
  return removed;
}


- (id<VoltaSchematicElement>) createCopyOfElement:(id<VoltaSchematicElement>)element
{
  id<VoltaSchematicElement> copiedElement = [element copyWithZone:nil];
  [self checkAndAssignUniqueName:copiedElement];
  [self addElement:copiedElement];
  FXRelease(copiedElement)
  return copiedElement;
}


- (void) addConnector:(id<VoltaSchematicConnector>)connector
{
  BOOL added = NO;
  @synchronized( self )
  {
    if ( ![mConnectors containsObject:connector] )
    {
      [mConnectors addObject:connector];
      added = YES;
    }
  }
  if ( added )
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicConnectionMadeNotification object:self];
  }
}


- (void) removeConnector:(id<VoltaSchematicConnector>)connector
{
  BOOL removed = NO;
  @synchronized( self )
  {
    if ( [mConnectors containsObject:connector] )
    {
      [mHighlightedConnectors removeObject:connector];
      [mConnectors removeObject:connector];
      removed = YES;
    }
  }
  if ( removed )
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicConnectionCutNotification object:self];
  }
}


- (void) removeAll
{
  @synchronized( self )
  {
    [mHighlightedConnectors removeAllObjects];
    [mSelectedElements removeAllObjects];
    [mElements removeAllObjects];
    [mConnectors removeAllObjects];
  }
}


- (void) select:(id<VoltaSchematicElement>)element
{
  if ( ![mSelectedElements containsObject:element] )
  {
    [mSelectedElements addObject:element];
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicSelectionHasChangedNotification object:self];
  }
}


- (void) selectElementsInSet:(NSSet*)newSelection
{
  if ( ![mSelectedElements isEqualToSet:newSelection] )
  {
    [mSelectedElements removeAllObjects];
    [mSelectedElements addObjectsFromArray:[newSelection allObjects]];
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicSelectionHasChangedNotification object:self];
  }
}


- (void) selectExclusively:(id<VoltaSchematicElement>)element
{
  if ( ![mSelectedElements containsObject:element] || ([mSelectedElements count] > 1) )
  {
    [mSelectedElements removeAllObjects];
    [mSelectedElements addObject:element];
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicSelectionHasChangedNotification object:self];
  }
}


- (void) unselect:(id<VoltaSchematicElement>)element
{
  if ( [mSelectedElements containsObject:element] )
  {
    [mSelectedElements removeObject:element];
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicSelectionHasChangedNotification object:self];
  }
}


- (BOOL) isSelected:(id<VoltaSchematicElement>)element
{
  return [mSelectedElements containsObject:element];
}


- (BOOL) isSelectedExclusively:(id<VoltaSchematicElement>)element
{
  return [mSelectedElements containsObject:element] && ([mSelectedElements count] == 1);    
}


- (void) unselectAll
{
  BOOL postNotification = ([mSelectedElements count] > 0);
  [mSelectedElements removeAllObjects];
  if ( postNotification )
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicSelectionHasChangedNotification object:self];
  }
}


- (void) selectAll
{
  BOOL postNotification = ![mSelectedElements isEqualToSet:mElements];
  [mSelectedElements addObjectsFromArray:[mElements allObjects]];
  if ( postNotification )
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicSelectionHasChangedNotification object:self];
  }
}


- (NSUInteger) numberOfSelectedElements
{
  return [mSelectedElements count];
}


- (BOOL) removeSelectedElementsIncludingConnectors:(BOOL)removeConnectors
{
  BOOL removed = NO;
  @synchronized( self )
  {
    if ( removeConnectors && ([mSelectedElements count] > 0) )
    {
      NSMutableSet* obsoleteConnectors = [[NSMutableSet alloc] init];
      for ( id<VoltaSchematicElement> element in mSelectedElements )
      {
        for ( id<VoltaSchematicConnector> connector in mConnectors )
        {
          if ( (connector.endElement == element) || (connector.startElement == element) )
          {
            [obsoleteConnectors addObject:connector];
          }
        }
      }
      [mConnectors minusSet:obsoleteConnectors];
      FXRelease(obsoleteConnectors)
    }
    
    // Now remove the element itself
    while ( ([mSelectedElements count] > 0) && ([mElements count] > 0) )
    {
      for ( id<VoltaSchematicElement> element in mElements )
      {
        if ( [mSelectedElements containsObject:element] )
        {
          [mElements removeObject:element];
          [mSelectedElements removeObject:element];
          break;
        }
      }
    }

    removed = YES;
  }
  if ( removed )
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementRemovedFromSchematicNotification object:self];
  }
  return removed;
}


- (NSDictionary*) createCopiesOfSelectedElements
{
  NSMutableDictionary* copies = [NSMutableDictionary dictionaryWithCapacity:[mSelectedElements count]];
  for ( id<VoltaSchematicElement> element in mSelectedElements )
  {
    id<VoltaSchematicElement> copiedElement = [element copyWithZone:nil];
    [self checkAndAssignUniqueName:copiedElement];
    [self addElement:copiedElement];
    FXRelease(copiedElement)
    copies[[NSValue valueWithPointer:(const void*)element]] = copiedElement;
  }
  return copies;
}


- (void) highlight:(id<VoltaSchematicConnector>)connector
{
  if ( [mConnectors containsObject:connector] )
  {
    [mHighlightedConnectors addObject:connector];
  }
}


- (void) lowlight:(id<VoltaSchematicConnector>)connector
{
  [mHighlightedConnectors removeObject:connector];
}


- (void) lowlightAll
{
  [mHighlightedConnectors removeAllObjects];
}


- (BOOL) isHighlighted:(id<VoltaSchematicConnector>)connector
{
  return [mHighlightedConnectors containsObject:connector];
}


- (void) checkAndAssignUniqueName:(id<VoltaSchematicElement>)element
{
  FXIssue(28)
  // The unique name consists of the name prefix (specified by the model of the element) and a number.
  __block NSString* namePrefix = nil;
  VoltaModelType const elementType = [element type];
  FXString const elementModelName( (__bridge CFStringRef)[element modelName] );
  FXString const elementVendorName( (__bridge CFStringRef)[element modelVendor] );
  VoltaPTModelPtr model = [mLibrary modelForType:elementType name:elementModelName vendor:elementVendorName];
  BOOL const noNamePrefixNecessary = (model.get() != nullptr) && model->elementNamePrefix.empty();
  if ( !noNamePrefixNecessary )
  {
    if ( model.get() != nullptr )
    {
      namePrefix = (__bridge NSString*)model->elementNamePrefix.cfString();
    }
    else
    {
      [mLibrary iterateOverSubcircuitsByApplyingBlock:^(VoltaPTModelPtr model, BOOL* stop) {
        if ( (model->name == elementModelName) && (model->vendor == elementVendorName) )
        {
          namePrefix = (__bridge NSString*)model->elementNamePrefix.cfString();
          *stop = YES;
        }        
      }];
    }
    if ( namePrefix == nil )
    {
      VoltaPTModelPtr model = [mLibrary defaultModelForType:elementType];
      if ( model.get() != nullptr )
      {
        namePrefix = (__bridge NSString*)model->elementNamePrefix.cfString();
      }
    }
  }
  NSAssert( noNamePrefixNecessary || (namePrefix != nil), @"The element is missing a name prefix." );
  
  BOOL nameIsUsedByOtherElement = (noNamePrefixNecessary && ([[element name] length] == 0)) ? YES : NO;
  
  if ( ! nameIsUsedByOtherElement )
  {
    for ( id<VoltaSchematicElement> otherElement in mElements )
    {
      if ( (otherElement != element) && [[otherElement name] isEqualToString:[element name]] )
      {
        nameIsUsedByOtherElement = YES;
        break;
      }
    }
  }
  
  if ( ((noNamePrefixNecessary || (namePrefix != nil)) && nameIsUsedByOtherElement)
    || (!noNamePrefixNecessary && ([[element name] isEqualToString:namePrefix] || ![[element name] hasPrefix:namePrefix])) )
  {
    NSUInteger componentCounter = 1;
    NSString* newElementName = nil;
    do
    {
      newElementName = [NSString stringWithFormat:@"%@%ld", noNamePrefixNecessary ? @"" : namePrefix, componentCounter++];
      nameIsUsedByOtherElement = NO;
      for ( id<VoltaSchematicElement> otherElement in mElements )
      {
        if ( (otherElement != element) && [[otherElement name] isEqualToString:newElementName] )
        {
          nameIsUsedByOtherElement = YES;
          break;
        }
      }
    }
    while ( nameIsUsedByOtherElement );
    [element setName:newElementName];
  }
}


- (NSUInteger) numberOfElements
{
  return [mElements count];
}


- (NSUInteger) numberOfConnectors
{
  return [mConnectors count];
}


- (void) getElementsInsideRect:(CGRect)rect fully:(BOOL)fullyInside outSet:(NSMutableSet*)result
{
  // Note: This is a brute force approach. Performance can be optimized by
  // maintaining a data structure that subdivides the schematic's area.
  for ( id<VoltaSchematicElement> element in mElements )
  {
    BOOL inside = NO;
    if (fullyInside)
    {
      CGSize size = [element size];
      FXPoint location = [element location];
      CGRect elementRect = CGRectMake(location.x - size.width/2, location.y - size.height/2, size.width, size.height);
      inside = CGRectContainsRect(rect, elementRect);
    }
    else
    {
      inside = CGRectContainsPoint(rect, (CGPoint)[element location]);
    }
    if ( inside )
    {
      [result addObject:element];
    }
  }
}


- (BOOL) isConnectionPointConnected:(FXShapeConnectionPoint*)connectionPoint forElement:(id<VoltaSchematicElement>)element
{
  for ( id<VoltaSchematicConnector> connector in mConnectors )
  {
    if ((([connector startElement] == element) && [[connector startPin] isEqualToString:[connectionPoint name]]) ||
        (([connector endElement] == element) && [[connector endPin] isEqualToString:[connectionPoint name]]) )
    {
      return YES;
    }
  }
  return NO;
}


- (CGRect) boundingBoxWithContext:(CGContextRef)context
{
  FXIssue(112)
  return [self boundingBoxForElements:mElements connectors:mConnectors context:context];
}


- (CGRect) boundingBoxForElements:(NSSet*)elements connectors:(NSSet*)connectors context:(CGContextRef)context
{
  CGRect totalBoundingBox = CGRectZero;
  BOOL gotFirstBB = NO;
  if ( elements != nil )
  {
    for ( id<VoltaSchematicElement> element in elements )
    {
      CGRect elementBoundingBox = element.boundingBox;
      if (element.labelPosition != SchematicRelativePosition_None)
      {
        CGRect labelBoundingBox = [self relativeBoundingBoxForLabelOfElement:element withContext:context];
        labelBoundingBox.origin.x += element.location.x;
      #if SCHEMATIC_VIEW_IS_FLIPPED
        // This correction needs to be made here and not in relativeBoundingBoxForLabelOfElement:withContext:
        // because relativeBoundingBoxForLabelOfElement:withContext: is also used during rendering where the
        // flippedness of elements (and their labels) is accounted for by applying a transform on top of the
        // transform that generally acts on all shapes.
        labelBoundingBox.origin.y = element.location.y - labelBoundingBox.origin.y - labelBoundingBox.size.height;
      #else
        labelBoundingBox.origin.y += element.location.y;
      #endif
        elementBoundingBox = NSUnionRect(elementBoundingBox, labelBoundingBox);
      }
      if ( !gotFirstBB )
      {
        totalBoundingBox = elementBoundingBox;
        gotFirstBB = YES;
      }
      else
      {
        totalBoundingBox = NSUnionRect(totalBoundingBox, elementBoundingBox);
      }
    }
  }
  if ( connectors != nil )
  {
    for ( id<VoltaSchematicConnector> connector in connectors )
    {
      [self extendBoundingBox:&totalBoundingBox withJointsOfConnector:connector];
    }
  }

  static CGFloat skMargin = 6.0;
  if (totalBoundingBox.origin.x > skMargin)
  {
    totalBoundingBox.origin.x -= skMargin;
    totalBoundingBox.size.width += 2 * skMargin;
  }
  else if ( totalBoundingBox.origin.x > 0.0 )
  {
    totalBoundingBox.size.width += skMargin + totalBoundingBox.origin.x;
    totalBoundingBox.origin.x = 0.0;
  }
  else
  {
    totalBoundingBox.origin.x -= skMargin;
    totalBoundingBox.size.width += 2*skMargin;
  }

  if (totalBoundingBox.origin.y > skMargin)
  {
    totalBoundingBox.origin.y -= skMargin;
    totalBoundingBox.size.height += 2 * skMargin;
  }
  else if ( totalBoundingBox.origin.y > 0.0 )
  {
    totalBoundingBox.size.height += skMargin + totalBoundingBox.origin.y;
    totalBoundingBox.origin.y = 0.0;
  }
  else
  {
    totalBoundingBox.origin.y -= skMargin;
    totalBoundingBox.size.height += 2*skMargin;
  }

  return totalBoundingBox;
}


- (NSDictionary*) elementLabelAttributes
{
  if ( mElementLabelAttributes == nil )
  {
    mElementLabelAttributes = @{ NSFontAttributeName: [NSFont fontWithName:@"Lucida Grande" size:10] };
  }
  return mElementLabelAttributes;
}


- (CGRect) relativeBoundingBoxForLabelOfElement:(id<VoltaSchematicElement>)element withContext:(CGContextRef)context
{
  CGSize labelSize = CGSizeZero;
  CGPoint labelPos = CGPointZero;
  if ( element.name.length > 0 && (element.labelPosition != SchematicRelativePosition_None) )
  {
    CGSize const elementSize = element.size;

    labelSize = [self sizeForLabel:element.name withContext:context];

    static CGFloat const skElementLabelMargin = 5.0;
    SchematicRelativePosition const relativeLabelPos = element.labelPosition;
    if ( relativeLabelPos == SchematicRelativePosition_Right )
    {
      labelPos.x = elementSize.width/2.0 + skElementLabelMargin;
      labelPos.y = -labelSize.height/2.0;
    }
    else if ( relativeLabelPos == SchematicRelativePosition_Left )
    {
      labelPos.x = -elementSize.width/2.0 - labelSize.width - skElementLabelMargin;
      labelPos.y = -labelSize.height/2.0;
    }
    else if ( relativeLabelPos == SchematicRelativePosition_Top )
    {
      labelPos.x = -labelSize.width/2.0;
      labelPos.y = elementSize.height/2.0 + skElementLabelMargin;
    }
    else if ( relativeLabelPos == SchematicRelativePosition_Bottom )
    {
      labelPos.x = -labelSize.width/2.0;
      labelPos.y = -elementSize.height/2.0 -labelSize.height - skElementLabelMargin;
    }
    else if ( relativeLabelPos == SchematicRelativePosition_Center )
    {
      labelPos.x = -labelSize.width/2.0;
      labelPos.y = -labelSize.height/2.0;
    }
  }
  return CGRectMake(labelPos.x, labelPos.y, labelSize.width, labelSize.height);
}


#pragma mark Private


- (CGSize) sizeForLabel:(NSString*)label withContext:(CGContextRef)context
{
  if ( label == nil )
    return CGSizeZero;

  void* bitmapData = NULL;
  CGColorSpaceRef colorSpace = NULL;

  CGSize result = CGSizeZero;

  BOOL const createOwnContext = (context == NULL);

  if ( createOwnContext )
  {
    // Core Text based precise size calculation
    CGSize const labelSizeInPoints = [label sizeWithAttributes:self.elementLabelAttributes];
    int const bitmapWidthInPixels = ceil(2 * labelSizeInPoints.width);
    int const bitmapHeightInPixels = ceil(2 * labelSizeInPoints.height);

    static int const skNumColorComponents = 1;
    int const bitmapBytesPerRow = (bitmapWidthInPixels * skNumColorComponents);
    int const bitmapByteCount = (bitmapBytesPerRow * bitmapHeightInPixels);

    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    bitmapData = calloc( 1, bitmapByteCount );
    if (bitmapData == NULL)
    {
      DebugLog(@"Could not allocate memory for creating a bitmap ");
      result = CGSizeZero;
    }
    else
    {
      static size_t const skBitsPerColorComponent = 8;
      context = CGBitmapContextCreate(bitmapData, bitmapWidthInPixels, bitmapHeightInPixels, skBitsPerColorComponent, bitmapBytesPerRow, colorSpace, kCGImageAlphaNone);
    }
  }

  if ( context != NULL )
  {
    NSAttributedString* attributedLabel = [[NSAttributedString alloc] initWithString:label attributes:self.elementLabelAttributes];
    CTLineRef labelLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributedLabel);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    result = CTLineGetImageBounds(labelLine, context).size;
    CFRelease(labelLine);
    FXRelease(attributedLabel)
  }
  else
  {
    result = [label sizeWithAttributes:self.elementLabelAttributes]; // not precise enough
  }

  if ( createOwnContext )
  {
    CGContextRelease(context);
    free (bitmapData);
    CGColorSpaceRelease( colorSpace );
  }

  return result;
}


- (void) extendBoundingBox:(CGRect*)pBoundingBox withJointsOfConnector:(id<VoltaSchematicConnector>)connector
{
  if ( (pBoundingBox != NULL) && connector.joints.count > 0 )
  {
    for ( NSValue* jointPointValue in connector.joints )
    {
      CGPoint point;
      [jointPointValue getValue:&point];
      if (!NSPointInRect(point, *pBoundingBox))
      {
        CGRect const bbox = *pBoundingBox;
        pBoundingBox->origin.x = MIN( point.x, bbox.origin.x );
        pBoundingBox->origin.y = MIN( point.y, bbox.origin.y );
        pBoundingBox->size.width = MAX(point.x, NSMaxX(bbox)) - pBoundingBox->origin.x;
        pBoundingBox->size.height = MAX(point.y, NSMaxY(bbox)) - pBoundingBox->origin.y;
      }
    }
  }
}

@end

