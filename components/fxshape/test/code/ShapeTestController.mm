#import "ShapeTestController.h"
#import "FXBasicShape.h"
#import "FXPath.h"
#import "FXCircle.h"


NSString* ShapeDescriptionKey = @"ShapeDescription";


@interface ShapeTestController () <NSTextViewDelegate>
@end


@implementation ShapeTestController

@synthesize window = _window;
@synthesize shapeView;
@synthesize shapeDescriptionView;


+ (void) initialize
{
  [[NSUserDefaults standardUserDefaults] registerDefaults:@{ ShapeDescriptionKey : @"" }];
}


- (void)dealloc
{
  FXDeallocSuper
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Insert code here to initialize your application
}


- (void) awakeFromNib
{
  NSAssert( self.shapeView != nil, @"" );
  NSAssert( self.shapeDescriptionView != nil, @"" );
  self.shapeView.isBordered = NO;
  self.shapeView.isDraggable = YES;
  self.shapeDescriptionView.delegate = self;
  self.shapeDescriptionView.string = [[NSUserDefaults standardUserDefaults] objectForKey:ShapeDescriptionKey];
  [self processShapeDescription];
}


#pragma mark NSTextViewDelegate


- (void) textDidChange:(NSNotification *)notification
{
  if ( [notification object] == self.shapeDescriptionView )
  {
    [self processShapeDescription];
    [NSUserDefaults standardUserDefaults][ShapeDescriptionKey] = self.shapeDescriptionView.string;
  }
}


#pragma mark Private


- (void) processShapeDescription
{
  NSString* shapeDescription = self.shapeDescriptionView.string;
  id<FXShape> shape = [self newShapeFromDescription:[shapeDescription stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
  if ( shape != nil )
  {
    self.shapeView.shape = shape;
    FXRelease(shape)
  }
}


- (id<FXShape>) newShapeFromDescription:(NSString*)shapeDescription
{
  id<FXShape> result = nil;
  NSUInteger const shapeDescriptionLength = [shapeDescription length];
  if ( shapeDescriptionLength > 3 )
  {
    NSMutableArray* paths = [[NSMutableArray alloc] initWithCapacity:3];
    NSMutableArray* circles = [[NSMutableArray alloc] initWithCapacity:1];
    NSUInteger lineEndIndex = 0, contentsEndIndex = 0;
    while ( lineEndIndex < (shapeDescriptionLength - 1) )
    {
      NSUInteger lineStartIndex = lineEndIndex;
      [shapeDescription getLineStart:NULL end:&lineEndIndex contentsEnd:&contentsEndIndex forRange:NSMakeRange(lineEndIndex, 1)];
      NSString* line = [shapeDescription substringWithRange:NSMakeRange(lineStartIndex, lineEndIndex - lineStartIndex)];
      //NSLog(@"extracted line: %@", line);
      FXPath* path = [FXPath pathWithData:line];
      if ( (path != nil) && ([[path segments] count] > 0) )
      {
        [paths addObject:path];
      }
      else
      {
        FXCircle* circle = [self circleFromString:line];
        if ( circle != nil )
        {
          [circles addObject:circle];
        }
      }
    }
    if ( ([paths count] > 0) || ([circles count] > 0) )
    {
      result = [[FXBasicShape alloc] initWithPaths:paths circles:circles connectionPoints:[NSArray array] size:CGSizeMake(64,64)];
    }
    FXRelease(paths)
    FXRelease(circles)
  }
  return result;
}


- (FXCircle*) circleFromString:(NSString*)circleDescription
{
  FXCircle* result = nil;
  NSString* CircleCommandPrefix = @"circle ";
  if ( [[circleDescription lowercaseString] hasPrefix:CircleCommandPrefix] )
  {
    CGPoint center = {0, 0};
    CGFloat radius = 0.0;
    NSString* argumentsString = [circleDescription substringFromIndex:[CircleCommandPrefix length]];
    NSArray* components = [argumentsString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( [components count] > 2 )
    {
      center.x = [components[0] floatValue];
      center.y = [components[1] floatValue];
      radius = [components[2] floatValue];
      if ( radius > 0 )
      {
        result = [FXCircle circleWithCenter:center radius:radius];
      }
    }
  }
  return result;
}


@end
