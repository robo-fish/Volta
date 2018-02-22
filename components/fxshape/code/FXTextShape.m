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

#import "FXTextShape.h"


static NSDictionary* __strong sDefaultStringAttributes = nil;
NSString* const FXTextShapeAttribute_Text = @"text";
NSString* const FXTextShapeAttribute_TextColor = @"transient-text-color";
NSString* const FXTextShapeAttribute_TextFont = @"text-font";


@implementation FXTextShape
{
@private
  CGSize mSize;
  NSDictionary* mAttributes;
}


+ (void) initialize
{
  sDefaultStringAttributes = @{
    NSFontAttributeName : [NSFont fontWithName:@"Lucida Grande" size:18],
    NSForegroundColorAttributeName : [NSColor blackColor]
  };
}


- (id) init
{
  if ( (self = [super init]) != nil )
  {
    mSize = CGSizeZero;
  }
  return self;
}


- (void) dealloc
{
  self.attributes = nil;
  FXDeallocSuper
}


#pragma mark FXShape


@synthesize size = mSize;
@synthesize attributes = mAttributes;


- (BOOL) doesOwnDrawing
{
  return YES;
}


- (BOOL) isReusable
{
  return NO;
}


- (void) drawWithContext:(FXShapeRenderContext)context
{
  CGContextSaveGState(context.graphicsContext);
  if ( !context.flipped )
  {
    CGContextSetTextMatrix(context.graphicsContext, CGAffineTransformMakeScale(1, -1));
  }
  [self drawTextWithGraphicsContext:context.graphicsContext];
  CGContextRestoreGState(context.graphicsContext);
}


- (NSArray*) paths
{
  return nil;
}


- (NSArray*) circles
{
  return nil;
}


- (NSArray*) connectionPoints
{
  return nil;
}


- (void) setAttributes:(NSDictionary *)attributes
{
  if ( attributes != mAttributes )
  {
    FXRelease(mAttributes)
    mAttributes = attributes;
    FXRetain(mAttributes)
  }
  [self updateSize];
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  if ( self.attributes != nil )
  {
    [encoder encodeObject:self.attributes forKey:@"Attributes"];
  }
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  self.attributes = [decoder decodeObjectForKey:@"Attributes"];
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FXTextShape* newCopy = [[[self class] allocWithZone:zone] init];
  NSDictionary* copiedAttributes = [[NSDictionary alloc] initWithDictionary:self.attributes copyItems:YES];
  newCopy.attributes = copiedAttributes;
  FXRelease(copiedAttributes)
  return newCopy;
}


#pragma mark Private


- (NSDictionary*) effectiveStringAttributes
{
  NSMutableDictionary* stringAttributes = [NSMutableDictionary dictionaryWithDictionary:sDefaultStringAttributes];
  if ( self.attributes[FXTextShapeAttribute_TextColor] != nil )
  {
    stringAttributes[NSForegroundColorAttributeName] = self.attributes[FXTextShapeAttribute_TextColor];
  }
  if ( self.attributes[FXTextShapeAttribute_TextFont] != nil )
  {
    stringAttributes[NSFontAttributeName] = self.attributes[FXTextShapeAttribute_TextFont];
  }
  return stringAttributes;
}


- (void) drawTextWithGraphicsContext:(CGContextRef)context
{
  NSString* text = self.attributes[FXTextShapeAttribute_Text];
  if ( text != nil )
  {
    NSDictionary* stringAttributes = [self effectiveStringAttributes];
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithString:text attributes:stringAttributes];
    CTLineRef textLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributedString);
    CGSize const textSize = CTLineGetImageBounds(textLine, context).size;
    CGContextSetTextMatrix(context, CGAffineTransformMakeTranslation(floor(-textSize.width/2), floor(-textSize.height/2)));
    CTLineDraw(textLine, context);
    CFRelease(textLine);
  }
}


- (void) updateSize
{
  mSize = CGSizeZero;
  if ( self.attributes[FXTextShapeAttribute_Text] != nil )
  {
    NSString* text = self.attributes[FXTextShapeAttribute_Text];
    NSDictionary* stringAttributes = [self effectiveStringAttributes];
    mSize = [text sizeWithAttributes:stringAttributes];
    mSize.width = ceil(mSize.width);
    mSize.height = ceil(mSize.height);
  }
}


@end
