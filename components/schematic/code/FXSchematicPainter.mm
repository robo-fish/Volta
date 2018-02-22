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

#import "FXSchematicPainter.h"
#import "VoltaSchematicElement.h"
#import "VoltaSchematicConnector.h"
#import "FXShapeConnectionPoint.h"
#import "FXShapeRenderer.h"
#import "FXVector.h"
#import "FXSchematicUtilities.h"
#import "VoltaAlignmentLine.h"

// The following header file resides in $(DERIVED_SOURCES_DIR) and is used for instrumenting the code.
// Xcode creates it automatically, using dtrace, from the file "SchematicRenderingProbes.d"
#import "SchematicRenderingProbes.h"

static const CGFloat skElementColor[4] = { 0.0f, 0.0f, 0.0f, 1.0f }; // black
static const CGFloat skSelectionColor[4] = { 0.6f, 0.0f, 0.0f, 1.0f }; // dark red
static const CGFloat skConnectorColor[4] = { 0.3f, 0.3f, 0.3f, 1.0f }; // dark gray
static const CGFloat skConnectionPointHighlightColor[4] = { 0.8f, 0.0f, 0.0f, 0.4f }; // translucent red
static const CGFloat skConnectorJointHighlightColor[4] = { 0.0f, 0.8f, 0.0f, 0.4f }; // translucent green
static const CGFloat skAlignmentLineColor[4] = { 0.7f, 1.0f, 0.7f, 1.0f }; // light green
static const CGFloat skSelectionBoxColor[4] = { 1.0, 0.1, 0.0, 0.40 }; // translucent red



@implementation FX(FXSchematicPainter)
{
@private
  CGContextRef mContext;         // current used graphics context
  id<VoltaSchematic> mSchematic; // currently drawn schematic
  CGRect mRect;
  
  CGColorSpaceRef mColorSpace;
  CFMutableAttributedStringRef mElementLabelString;
}

- (id) init
{
  self = [super init];
  mColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  mElementLabelString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
  return self;
}

- (void) dealloc
{
  CFRelease(mElementLabelString);
  CGColorSpaceRelease( mColorSpace );
  FXDeallocSuper
}


#pragma mark Singleton methods


static FX(FXSchematicPainter)* sSchematicPainter = nil;

+ (FX(FXSchematicPainter)*) sharedPainter
{
  @synchronized( self )
  {
    if ( sSchematicPainter == nil )
    {
      sSchematicPainter = [[FX(FXSchematicPainter) alloc] init];
    }
  }
  return sSchematicPainter;
}

+ (id) allocWithZone:(NSZone*)zone
{
  @synchronized(self)
  {
    if ( sSchematicPainter == nil )
    {
      sSchematicPainter = [super allocWithZone:zone];
      return sSchematicPainter;  // assignment and return on first allocation
    }
  }
  return nil; //on subsequent allocation attempts return nil
}

- (id) copyWithZone:(NSZone *)zone
{
  return self;
}


#pragma mark Private


- (void) drawAlignmentLines
{
  if ( [[mSchematic alignmentLines] count] > 0 )
  {
    // The translation of the schematic is taken into account by the offsets.
    // TODO: The scale factor also needs to be taken in to account.
    CGContextSetStrokeColor( mContext, skAlignmentLineColor );
    CGContextBeginPath( mContext );
    for ( id<VoltaAlignmentLine> line in [mSchematic alignmentLines] )
    {
      if ( [line vertical] )
      {
        CGContextMoveToPoint( mContext, [line position], 0.0 ); FXIssue(108)
        CGContextAddLineToPoint( mContext, [line position], mRect.size.height );
      }
      else
      {
        CGContextMoveToPoint( mContext, 0.0, [line position] ); FXIssue(108)
        CGContextAddLineToPoint( mContext, mRect.size.width, [line position] );
      }
    }
    CGContextStrokePath( mContext );
  }
}


- (void) drawConnectors
{
  for ( id<VoltaSchematicConnector> connector in [mSchematic connectors] )
  {
    NSMutableArray* pathPoints = [[NSMutableArray alloc] initWithCapacity:(2+[[connector joints] count])];
    if ( [connector startElement] != nil )
    {
      id<VoltaSchematicElement> startElement = [connector startElement];
      CGPoint startPoint = [startElement location];
      if ( ![[startElement modelName] isEqualToString:@"Node"] )
      {
        FXVector startPinOffset;
        id<FXShape> startShape = [startElement shape];
        NSArray* startPins = [startShape connectionPoints];
        for ( FXShapeConnectionPoint* connectionPoint in startPins )
        {
          if ( [[connectionPoint name] isEqualToString:[connector startPin]] )
          {
            startPinOffset = FXVector( [connectionPoint location] );
            break;
          }
        }
        if ( [startElement flipped] )
        {
          startPinOffset.scale( -1, 1 );
        }
        startPinOffset.rotate( [startElement rotation] );
        startPoint.x += startPinOffset.x;
        startPoint.y += FXSchematicVerticalOrientationFactor * startPinOffset.y;
      }
      [pathPoints addObject:[NSValue valueWithBytes:&startPoint objCType:@encode(CGPoint)]];
    }
    [pathPoints addObjectsFromArray:[connector joints]];
    if ( [connector endElement] != nil )
    {
      id<VoltaSchematicElement> endElement = [connector endElement];
      CGPoint endPoint = [endElement location];
      if ( ![[endElement modelName] isEqualToString:@"Node"] )
      {
        FXVector endPinOffset;
        id<FXShape> endShape = [endElement shape];
        NSArray* endPins = [endShape connectionPoints];
        for ( FXShapeConnectionPoint* connectionPoint in endPins )
        {
          if ( [[connectionPoint name] isEqualToString:[connector endPin]] )
          {
            endPinOffset = FXVector( [connectionPoint location] );
            break;
          }
        }
        if ( [endElement flipped] )
        {
          endPinOffset.scale( -1, 1 );
        }
        endPinOffset.rotate( [endElement rotation] );
        endPoint.x += endPinOffset.x;
        endPoint.y += FXSchematicVerticalOrientationFactor * endPinOffset.y;
      }
      [pathPoints addObject:[NSValue valueWithBytes:&endPoint objCType:@encode(CGPoint)]];
    }

    if ( [NSGraphicsContext currentContextDrawingToScreen] )
    {
      if ( [mSchematic isHighlighted:connector] )
      {
        CGContextSetStrokeColor( mContext, skSelectionColor );
      }
      else
      {
        CGContextSetStrokeColor( mContext, skConnectorColor );
      }
    }
    else
    {
      CGContextSetStrokeColor( mContext, skElementColor );
    }
    
    CGContextBeginPath( mContext );
    BOOL firstPoint = YES;
    for ( NSValue* linePointValue in pathPoints )
    {
      CGPoint linePoint;
      [linePointValue getValue:&linePoint];
      if ( firstPoint )
      {
        CGContextMoveToPoint(mContext, linePoint.x, linePoint.y);
        firstPoint = NO;
      }
      CGContextAddLineToPoint(mContext, linePoint.x, linePoint.y);
    }
    CGContextStrokePath(mContext);
    
    FXRelease(pathPoints)
  }
}


- (void) drawSelectionBox
{
  FXIssue(24)
  CGRect selectionBox = [mSchematic selectionBox];
  if ( (selectionBox.size.width * selectionBox.size.height) > 0 )
  {
    //static const CGFloat skLineDashPattern[2] = { 16.0, 16.0 };
    //CGContextSetLineDash(mContext, 0, skLineDashPattern, 2);
    CGContextSetLineWidth(mContext, 3.0);
    CGContextSetLineJoin(mContext, kCGLineJoinRound);
    CGContextSetStrokeColor(mContext, skSelectionBoxColor);
    CGContextBeginPath(mContext);
    CGContextAddRect(mContext, selectionBox);
    CGContextStrokePath(mContext);
  }
}


- (void) drawHighlightPoints
{
  FXIssue(25)
  static CGRect sHiliteRect = CGRectMake(0, 0, 2*FXSchematicProximityThreshold, 2*FXSchematicProximityThreshold);
  // Connection point
  if ( [mSchematic hasHighlightedConnectionPoint] )
  {
    CGPoint highlightedPoint = [mSchematic highlightedConnectionPoint];
    sHiliteRect.origin.x = highlightedPoint.x - FXSchematicProximityThreshold;
    sHiliteRect.origin.y = highlightedPoint.y - FXSchematicProximityThreshold;
    CGContextSetFillColor(mContext, skConnectionPointHighlightColor);
    CGContextBeginPath(mContext);
    CGContextAddEllipseInRect(mContext, sHiliteRect);
    CGContextFillPath(mContext);
  }
  // Connector joint
  if ( [mSchematic hasHighlightedConnectorJoint] )
  {
    CGPoint highlightedPoint = [mSchematic highlightedConnectorJoint];
    sHiliteRect.origin.x = highlightedPoint.x - FXSchematicProximityThreshold;
    sHiliteRect.origin.y = highlightedPoint.y - FXSchematicProximityThreshold;
    CGContextSetFillColor(mContext, skConnectorJointHighlightColor);
    CGContextBeginPath(mContext);
    CGContextAddEllipseInRect(mContext, sHiliteRect);
    CGContextFillPath(mContext);
  }
}


- (void) drawLabelOfElement:(id<VoltaSchematicElement>)element
{
  if ( ([element name] != nil) && ([element labelPosition] != SchematicRelativePosition_None) )
  {
    CFAttributedStringReplaceString(mElementLabelString, CFRangeMake(0,CFAttributedStringGetLength(mElementLabelString)), (CFStringRef)[element name]);
    CFAttributedStringSetAttributes(mElementLabelString, CFRangeMake(0,CFAttributedStringGetLength(mElementLabelString)), (__bridge CFDictionaryRef)mSchematic.elementLabelAttributes, true);
    CTLineRef elementLabelLine = CTLineCreateWithAttributedString(mElementLabelString);

    CGRect labelFrame = [mSchematic relativeBoundingBoxForLabelOfElement:element withContext:mContext];
    labelFrame.origin.x = round(labelFrame.origin.x);
    labelFrame.origin.y = round(labelFrame.origin.y);

    CGContextSaveGState(mContext);
    CGAffineTransform textTransform = CGAffineTransformIdentity;
    textTransform = CGAffineTransformConcat(textTransform, CGAffineTransformMakeTranslation(labelFrame.origin.x, labelFrame.origin.y));
    textTransform = CGAffineTransformConcat(textTransform, CGAffineTransformMakeScale(1, FXSchematicVerticalOrientationFactor));
    CGContextSetTextMatrix(mContext, textTransform );
    CTLineDraw(elementLabelLine, mContext);
  #if 0 && VOLTA_DEBUG
    CGContextBeginPath(mContext);
    CGContextAddRect(mContext, labelFrame);
    CGContextStrokePath(mContext);
  #endif
    CGContextRestoreGState(mContext);

    CFRelease(elementLabelLine);
  }
}


- (void) drawElements
{
#if VOLTA_DEBUG
  BOOL const drawElementBoundingBoxes = [(NSNumber*)[[NSUserDefaults standardUserDefaults] objectForKey:@"FXVoltaDebug_ShowSchematicElementBoundingBoxes"] boolValue];
#endif
  for ( id<VoltaSchematicElement> element in [mSchematic elements] )
  {
    CGContextSaveGState(mContext);
    const CGFloat* colorComponents = NULL;
    if ( [mSchematic isSelected:element] && [NSGraphicsContext currentContextDrawingToScreen] )
    {
      CGContextSetStrokeColor( mContext, skSelectionColor );
      CGContextSetFillColor( mContext, skSelectionColor );
      colorComponents = skSelectionColor;
    }
    else
    {
      CGContextSetStrokeColor( mContext, skElementColor );
      CGContextSetFillColor( mContext, skElementColor );
      colorComponents = skElementColor;
    }
    if ( element.shape.doesOwnDrawing )
    {
      NSColor* textColor = [NSColor colorWithColorSpace:[NSColorSpace genericRGBColorSpace] components:colorComponents count:4];
      [element setPropertyValue:textColor forKey:@"transient-text-color"];
    }
    
    FXPoint elementLocation = [element location];

    CGContextTranslateCTM( mContext, elementLocation.x, elementLocation.y );

  #if VOLTA_DEBUG
    if (drawElementBoundingBoxes)
    {
      CGSize const elementSize = element.size;
      CGContextSaveGState(mContext);
      CGContextSetStrokeColor(mContext, skSelectionBoxColor);
      CGContextBeginPath(mContext);
      CGContextAddRect(mContext, CGRectMake(-elementSize.width/2, -elementSize.height/2, elementSize.width, elementSize.height));
      CGContextStrokePath(mContext);
      CGContextRestoreGState(mContext);
    }
  #endif

    CGFloat const kElementFlippednessFactor = element.flipped ? -1 : 1;
    CGContextSaveGState( mContext );
    CGContextScaleCTM( mContext, 1, FXSchematicVerticalOrientationFactor );
    CGContextRotateCTM( mContext, element.rotation );
    CGContextScaleCTM( mContext, kElementFlippednessFactor, 1 );
    FXShapeRenderContext renderContext;
    renderContext.graphicsContext = mContext;
    renderContext.flipped = NO;
    renderContext.strokeColor = NULL;
    renderContext.textColor = NULL;
    [element prepareShapeForDrawing];
    [[FXShapeRenderer sharedRenderer] renderShape:element.shape withContext:renderContext forHiDPI:NO scaleFactor:1.0];
    CGContextRestoreGState(mContext);

    [self drawLabelOfElement:element];

    CGContextRestoreGState(mContext);
  }
}


- (void) configureGraphicsContext
{
  CGContextSetFillColorSpace( mContext, mColorSpace );
  CGContextSetStrokeColorSpace( mContext, mColorSpace );
  CGContextSetLineJoin( mContext, kCGLineJoinRound );
  CGContextSetLineCap( mContext, kCGLineCapButt );
  CGContextSetTextMatrix(mContext, CGAffineTransformIdentity);
  CGFloat const scaleFactor = mSchematic.scaleFactor;
  CGAffineTransform s = CGAffineTransformMakeScale( scaleFactor, scaleFactor );
  CGContextConcatCTM( mContext, s );
}


#if VOLTA_DEBUG
- (void) drawDebugShapes
{
  if ( [(NSNumber*)[[NSUserDefaults standardUserDefaults] objectForKey:@"FXVoltaDebug_ShowSchematicBoundingBox"] boolValue] )
  {
    CGContextSetStrokeColor(mContext, skSelectionBoxColor);
    CGContextBeginPath(mContext);
    CGContextAddRect(mContext, [mSchematic boundingBoxWithContext:mContext]);
    CGContextStrokePath(mContext);
  }
}
#endif


#pragma mark Public methods


// Note: This can run in the main thread only.
- (void) drawSchematic:(id<VoltaSchematic>)schematic viewRect:(CGRect)rect
{
  mContext = FXGraphicsContext;
  mSchematic = schematic;
  mRect = rect;

  CGContextSaveGState( mContext );

  // Note: Connectors need to be drawn before elements because of node elements.
  // In node elements the connector lines are extended into the center of the node.

  [self configureGraphicsContext];

#if VOLTA_DEBUG
  [self drawDebugShapes];
#endif

  if ([NSGraphicsContext currentContextDrawingToScreen])
  {
    [self drawAlignmentLines];
  }

  [self drawConnectors];
  [self drawElements];

  if ([NSGraphicsContext currentContextDrawingToScreen])
  {
    [self drawSelectionBox];
    [self drawHighlightPoints];
  }

  CGContextRestoreGState( mContext );

  mContext = NULL;
  mSchematic = nil;
}


@end

