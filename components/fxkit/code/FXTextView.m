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

#import "FXTextView.h"
#import "FXSyntaxHighlighter.h"


#pragma mark - FXGutterView -


static float const skInitialGutterWidth = 25.0f;


@interface FXGutterView : NSView <NSCoding>
{
@private
  NSMutableDictionary* mStringAttributes;
  NSTextView* __unsafe_unretained mTextView;
  NSFont* mFont;
  NSColor* mTextColor;
}
@property (assign) NSTextView* textView;
@property (copy) NSFont* font;
@property NSColor* backgroundColor;
@property NSColor* separatorColor;
@property (nonatomic) NSColor* textColor;
@end


@implementation FXGutterView

@synthesize textView = mTextView;
@synthesize font = mFont;
@synthesize textColor = mTextColor;

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if ( self != nil )
	{
    self.font = [NSFont systemFontOfSize:12.0f];
    self.textColor = [NSColor colorWithDeviceWhite:0.0f alpha:1.0f];
    self.backgroundColor = [NSColor colorWithDeviceWhite:0.95f alpha:1.0f];
    self.separatorColor = [NSColor colorWithDeviceWhite:0.30f alpha:1.0f];

    mStringAttributes = [[NSMutableDictionary alloc] initWithCapacity:2];
    mStringAttributes[NSFontAttributeName] = [self font];
    mStringAttributes[NSForegroundColorAttributeName] = [self textColor];

    {
      // using a right-aligned paragraph style
      NSMutableParagraphStyle* mps = [NSMutableParagraphStyle new];
      mps.alignment = NSTextAlignmentRight;
      mStringAttributes[NSParagraphStyleAttributeName] = mps;
      FXRelease(mps)
    }

  }
  return self;
}


- (void) dealloc
{
  FXRelease(mStringAttributes)
  mTextView = nil;
  FXDeallocSuper
}


#pragma mark Public


- (void) setFont:(NSFont*)font
{
  mFont = font;
  mStringAttributes[NSFontAttributeName] = mFont;
}


- (NSFont*) font
{
  return mFont;
}


- (void) setTextColor:(NSColor*)textColor
{
  if ( mTextColor != textColor )
  {
    FXRelease(mTextColor)
    mTextColor = textColor;
    FXRetain(mTextColor)

    mStringAttributes[NSForegroundColorAttributeName] = textColor;
    [self setNeedsDisplay:YES];
  }
}


#pragma mark NSCoding


static NSString* const GUTTER_STRING_ATTRIBUTES_ARCHIVING_KEY = @"string attributes";
static NSString* const GUTTER_FONT_ARCHIVING_KEY = @"font";
static NSString* const GUTTER_BACKGROUND_COLOR_ARCHIVING_KEY = @"background color";
static NSString* const GUTTER_SEPARATOR_COLOR_ARCHIVING_KEY = @"separator color";
static NSString* const GUTTER_TEXT_COLOR_ARCHIVING_KEY = @"text color";


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [super encodeWithCoder:encoder];
  [encoder encodeObject:mStringAttributes forKey:GUTTER_STRING_ATTRIBUTES_ARCHIVING_KEY];
  [encoder encodeObject:mFont forKey:GUTTER_FONT_ARCHIVING_KEY];
  [encoder encodeObject:self.backgroundColor forKey:GUTTER_BACKGROUND_COLOR_ARCHIVING_KEY];
  [encoder encodeObject:self.separatorColor forKey:GUTTER_SEPARATOR_COLOR_ARCHIVING_KEY];
  [encoder encodeObject:self.textColor forKey:GUTTER_TEXT_COLOR_ARCHIVING_KEY];
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super initWithCoder:decoder];
  mStringAttributes = [decoder decodeObjectForKey:GUTTER_STRING_ATTRIBUTES_ARCHIVING_KEY];
  FXRetain(mStringAttributes)
  mFont = [decoder decodeObjectForKey:GUTTER_FONT_ARCHIVING_KEY];
  FXRetain(mFont)
  self.backgroundColor = [decoder decodeObjectForKey:GUTTER_BACKGROUND_COLOR_ARCHIVING_KEY];
  self.separatorColor = [decoder decodeObjectForKey:GUTTER_SEPARATOR_COLOR_ARCHIVING_KEY];
  self.textColor = [decoder decodeObjectForKey:GUTTER_TEXT_COLOR_ARCHIVING_KEY];
  return self;
}


#pragma mark NSView overrides


- (void) drawRect:(NSRect)rect
{
  NSRect myBounds = [self bounds];
  NSRect myFrame = [self frame];
  [[self backgroundColor] set]; 
  [NSBezierPath fillRect:myFrame];

	// For each line in the text view...
	//   Determine the rectangle in which the glyphs are laid out.
	//   Place the line number at the vertical center of the rectangle
  NSLayoutManager* layoutManager = self.textView.layoutManager;
  NSTextContainer* textContainer = self.textView.textContainer;
  const float GutterMargin = 3.0f;
  float yOffset = [self.textView bounds].origin.y;

  NSTextStorage* textStorage = [self.textView textStorage];
  NSString* textString = [textStorage string];
  NSUInteger textLength = [textString length];
  BOOL numberRectCalculated = NO;
  NSRect numberRect; // the rectangle into which draw the right-aligned number
  if ( textLength > 0 )
  {
    NSUInteger lineNumber = 1;
    NSRange searchRange = NSMakeRange(0, textLength);
    NSRange newlineRange = [textString rangeOfString:@"\n" options:NSCaseInsensitiveSearch range:searchRange];
    BOOL done = NO;
    while ( !done )
    {
      // Handle last line (with or without newline at end)
      if ( newlineRange.location == NSNotFound )
      {
        done = YES;
      }
      
      NSRange glyphRange;
      if ( done && (textLength >= searchRange.location) )
      {
        glyphRange = NSMakeRange(searchRange.location, textLength - searchRange.location);
      }
      else
      {
        glyphRange = NSMakeRange(searchRange.location, newlineRange.location - searchRange.location);
      }

      NSRect textViewLineRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
      textViewLineRect = [self convertRect:textViewLineRect fromView:self.textView];

      NSString* numberString = [NSString stringWithFormat:@"%ld", lineNumber];
      NSSize numberSize = [numberString sizeWithAttributes:mStringAttributes];
        
        // Prepare for drawing next line
      if (!done)
      {
        searchRange.location = newlineRange.location + 1;
        searchRange.length = textLength - searchRange.location;
        newlineRange = [textString rangeOfString:@"\n" options:NSCaseInsensitiveSearch range:searchRange];
        lineNumber++;
      }

      // Check whether the gutter needs to widen to accomodate the string
      float gutterTargetWidth = numberSize.width + (2 * GutterMargin);
      if ( gutterTargetWidth > myFrame.size.width )
      {
        float diff = gutterTargetWidth - myFrame.size.width;
        myFrame.size.width = gutterTargetWidth;
        [self setFrame:myFrame];

        NSScrollView* enclosingView = [self.textView enclosingScrollView];
        if ( enclosingView != nil )
        {
          NSRect textViewFrame = [enclosingView frame];
          textViewFrame.size.width -= diff;
          textViewFrame.origin.x += diff;
          [enclosingView setFrame:textViewFrame];
        }
        else
        {
          NSRect textViewFrame = [self.textView frame];
          textViewFrame.size.width -= diff;
          textViewFrame.origin.x += diff;
          [self.textView setFrame:textViewFrame];
        }

        [self setNeedsDisplay:YES];
        [self.textView setNeedsDisplay:YES];
        return;
      }            
          
      // Optimization: Assume all number rectangles are of the same height and width.
      if ( numberRectCalculated )
      {
        numberRect.origin.y = textViewLineRect.origin.y + yOffset;
      }
      else
      {
        numberRect = NSMakeRect( GutterMargin, textViewLineRect.origin.y + yOffset, myFrame.size.width - (2 * GutterMargin), numberSize.height );
        numberRectCalculated = YES;
      }

      // Optimization: If numberRect is above the bounds rectangle do not draw.
      if ( numberRect.origin.y > (myBounds.origin.y + myBounds.size.height) )
      {
        continue;
      }

      // Optimization: If numberRect is below the bounds rectangle stop altogether (because we draw from top to bottom).
      if ( (numberRect.origin.y + numberRect.size.height) < myBounds.origin.y )
      {
        break; // because the text continues below bounds rectangle
      }

      // Finally, draw the number string.
      [numberString drawInRect:numberRect withAttributes:mStringAttributes];

    } // while

  } // if
  
  // Draw the separation line between the gutter and the text view
  [self.separatorColor set];
  [NSBezierPath strokeLineFromPoint:NSMakePoint(myBounds.size.width, 0.0f) toPoint:NSMakePoint(myBounds.size.width, myBounds.size.height)];
}

#ifdef MOUSE_TRACKING_IN_GUTTER

- (void) viewDidMoveToWindow
{
	int trackingOptions = NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect;
	NSTrackingArea* ta = [[NSTrackingArea alloc]
  initWithRect:NSZeroRect
  options:trackingOptions
  owner:self
  userInfo:nil];
	[self addTrackingArea:ta];
	FXRelease(ta)
}


#pragma mark NSResponder overrides


- (void) mouseEntered:(NSEvent*)mouseEvent
{
	[self setBackgroundColor:[NSColor redColor]];
	[self setNeedsDisplay:YES];
}

- (void) mouseExited:(NSEvent*)mouseEvent
{
	[self setBackgroundColor:[NSColor yellowColor]];
	[self setNeedsDisplay:YES];
}

#endif // MOUSE_TRACKING_IN_GUTTER

@end


#pragma mark - FXInternalTextViewScrollView -


@interface FXInternalTextViewScrollView : NSScrollView
@property (weak) id<NSTextFinderBarContainer> effectiveFindBarContainer;
@end


@implementation FXInternalTextViewScrollView
{
@private
  id<NSTextFinderBarContainer> __weak mEffectiveFindBarContainer;
}

@synthesize effectiveFindBarContainer = mEffectiveFindBarContainer;

#pragma mark NSTextFinderBarContainer overrides


- (void) setFindBarView:(NSView*)findBarView
{
  [self.effectiveFindBarContainer setFindBarView:findBarView];
}


- (NSView*) findBarView
{
  return [self.effectiveFindBarContainer findBarView];
}


- (BOOL) isFindBarVisible
{
  return [self.effectiveFindBarContainer isFindBarVisible];
}


- (void) setFindBarVisible:(BOOL)findBarVisible
{
  [self.effectiveFindBarContainer setFindBarVisible:findBarVisible];
}


- (void) findBarViewDidChangeHeight
{
  [self.effectiveFindBarContainer findBarViewDidChangeHeight];
}


@end


#pragma mark - FXTextView -


#define FIND_BAR_WITH_ANIMATION (1)

@interface FXTextView () <
#if FIND_BAR_WITH_ANIMATION
  NSAnimationDelegate,
#endif
  NSTextFinderBarContainer>
@end


@implementation FXTextView
{
@private
  FXInternalTextViewScrollView* mTextScrollView;
  NSTextView* mInternalTextView;
  FXGutterView* mGutterView;

  float mGutterWidth;
  id<FXSyntaxHighlighter> mSyntaxHighlighter;
  id<FXTextViewDelegate> __weak mDelegate;

  NSView* mFindBarView;
  NSView* mFindBarContainerView;
  BOOL mFindBarIsVisible;
#if FIND_BAR_WITH_ANIMATION
  NSViewAnimation* mFindBarAnimation;
#endif

  BOOL mIsPrintVersion;
}

@synthesize delegate = mDelegate;
@synthesize syntaxHighlighter = mSyntaxHighlighter;


- (id) initWithFrame:(NSRect)rect
{
  return [self initWithFrame:rect forPrinting:NO];
}


/// @param printing whether the text view is for printing, in which case it shows no gutter and no scroll bars
- (id) initWithFrame:(NSRect)rect forPrinting:(BOOL)printing
{
  if ((self = [super initWithFrame:rect]) != nil)
  {
    mIsPrintVersion = printing;
    mFindBarIsVisible = NO;
    mGutterWidth = mIsPrintVersion ? 0 : skInitialGutterWidth;

    mInternalTextView = [[NSTextView alloc] initWithFrame:rect];

    if ( mIsPrintVersion )
    {
      NSMutableParagraphStyle* paragraphStyle = [mInternalTextView.defaultParagraphStyle mutableCopy];
      paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
      mInternalTextView.defaultParagraphStyle = paragraphStyle;
      FXRelease(paragraphStyle)
    }
    else
    {
      mTextScrollView = [[FXInternalTextViewScrollView alloc] initWithFrame:rect];
      NSRect const dummyRect = NSMakeRect(0, -100, 200, 50);
      mFindBarContainerView = [[NSView alloc] initWithFrame:dummyRect];
      mGutterView = [[FXGutterView alloc] initWithFrame:rect];
    }

    [self setUpComponents];
    [self resizeComponents];
    [self initNotificationHandling];
  }
  return self;
}


- (void) dealloc
{
  [[mTextScrollView contentView] setPostsBoundsChangedNotifications:NO];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  FXRelease(mTextScrollView)
  FXRelease(mGutterView)
  FXRelease(mSyntaxHighlighter)
  FXRelease(mFindBarContainerView)
  FXDeallocSuper
}


#pragma mark Message forwarding to NSTextView


- (void) forwardInvocation:(NSInvocation*)invocation
{
  SEL aSelector = [invocation selector];

  if ([mInternalTextView respondsToSelector:aSelector])
  {
    [invocation invokeWithTarget:mInternalTextView];
  }
  else
  {
    [self doesNotRecognizeSelector:aSelector];
  }
}


- (NSMethodSignature*) methodSignatureForSelector:(SEL)aSelector
{
  if ([[self class] instancesRespondToSelector:aSelector])
  {
    return [[self class] instanceMethodSignatureForSelector:aSelector];
  }
  else
  {
    return [[mInternalTextView class] instanceMethodSignatureForSelector:aSelector];
  }
}


#pragma mark Public


+ (FXTextView*) newPrintableInstance
{
  return [[FXTextView alloc] initWithFrame:NSMakeRect(0, 0, 200, 300) forPrinting:YES];
}


- (void) setString:(NSString*)newText
{
  mInternalTextView.string = newText;
  [self highlight];
  [mGutterView setNeedsDisplay:YES];
}


- (NSString*) string
{
  return [mInternalTextView string];
}


- (void) setFont:(NSFont*)newFont
{
  mInternalTextView.font = newFont;
  mGutterView.font = newFont;
  mSyntaxHighlighter.font = newFont;
}


- (NSFont*) font
{
  return [mInternalTextView font];
}


- (void) setSyntaxHighlighter:(id<FXSyntaxHighlighter>)syntaxHighlighter
{
  if ( mSyntaxHighlighter != syntaxHighlighter )
  {
    FXRelease(mSyntaxHighlighter)
    mSyntaxHighlighter = syntaxHighlighter;
    FXRetain(mSyntaxHighlighter)
    mSyntaxHighlighter.font = self.font;
  }
}


- (void) textViewBoundsDidChange:(NSNotification*)notif
{
  [mGutterView setNeedsDisplay:YES];
}


- (NSColor*) gutterBackgroundColor
{
  return mGutterView.backgroundColor;
}


- (void) setGutterBackgroundColor:(NSColor*)newColor
{
  mGutterView.backgroundColor = newColor;
}


- (NSColor*) gutterSeparatorColor
{
  return mGutterView.separatorColor;
}


- (void) setGutterSeparatorColor:(NSColor*)newColor
{
  mGutterView.separatorColor = newColor;
}


- (NSColor*) gutterTextColor
{
  return mGutterView.textColor;
}


- (void) setGutterTextColor:(NSColor*)newColor
{
  mGutterView.textColor = newColor;
}


- (void) setGutterWidth:(float)width
{
  mGutterWidth = width;
  if ( !mIsPrintVersion )
  {
    if ( mGutterWidth < 1 )
    {
      mGutterView.hidden = YES;
    }
    else
    {
      mGutterView.hidden = NO;
    }
    NSRect gutterFrame = [mGutterView frame];
    float oldWidth = gutterFrame.size.width;
    gutterFrame.size.width = width;
    [mGutterView setFrame:gutterFrame];
    NSRect textViewFrame = [mTextScrollView frame];
    CGFloat const widthChange = width - oldWidth;
    textViewFrame.size.width -= widthChange;
    textViewFrame.origin.x += widthChange;
    [mTextScrollView setFrame:textViewFrame];
    [mGutterView setNeedsDisplay:YES];
  }
}


- (float) gutterWidth
{
  return mGutterWidth;
}


#pragma mark NSTextViewDelegate


- (BOOL) textShouldBeginEditing:(NSText *)aTextObject
{
  [self.delegate textWillChange:self];
  return YES;
}

- (void)textDidChange:(NSNotification *)aNotification
{
  [self highlight];
  [mGutterView setNeedsDisplay:YES];
  [self.delegate textDidChange:self];
}


#pragma mark NSTextFinderBarContainer


- (void) setFindBarView:(NSView*)findBarView
{
  mFindBarView = findBarView;
  if ( mFindBarView != nil )
  {
    mFindBarContainerView.frameSize = mFindBarView.frame.size;
    mFindBarContainerView.subviews = @[mFindBarView];
    [self setFindBarVisible:YES];
  }
  else
  {
    [mFindBarContainerView setSubviews:@[]];
    [self setFindBarVisible:NO];
  }
  [self resizeComponents];
}


- (NSView*) findBarView
{
  return mFindBarView;
}


- (BOOL) isFindBarVisible
{
  return mFindBarIsVisible;
}


- (void) setFindBarVisible:(BOOL)findBarVisible
{
  if ( mFindBarIsVisible != findBarVisible )
  {
    @synchronized(mFindBarContainerView)
    {
    #if FIND_BAR_WITH_ANIMATION
      if ( ![self animationIsRunning] )
    #endif
      {
        mFindBarIsVisible = findBarVisible;
        if ( mFindBarIsVisible )
        {
          [self showFindBar];
        }
        else
        {
          [self hideFindBar];
        }
      }
    }
  }
}


- (void) findBarViewDidChangeHeight
{
  mFindBarContainerView.frameSize = mFindBarView.frame.size;
  mFindBarView.frameOrigin = NSZeroPoint;
#if 0 && FIND_BAR_WITH_ANIMATION
  if ( mFindBarIsVisible )
  {
    [self animateFindBarToPosition:([self frame].size.height - [mFindBarContainerView frame].size.height)];
  }
#else
  [self resizeComponents];
#endif
}


#if 0
- (NSView*) contentView
{
  return [mTextScrollView contentView];
}
#endif


#pragma mark NSAnimationDelegate


#if FIND_BAR_WITH_ANIMATION
- (void) animationDidEnd:(NSAnimation*)animation
{
  NSAssert( [NSThread currentThread] == [NSThread mainThread], @"This needs to run in the main thread!" );
  @synchronized(mFindBarContainerView)
  {
    if ( animation == mFindBarAnimation )
    {
      FXRelease(mFindBarAnimation)
      mFindBarAnimation = nil;
      if ( !mFindBarIsVisible )
      {
        [self removeFindBarView];
      }
      [mGutterView setNeedsDisplay:YES];
      [self resizeComponents];
    }
  }
}
#endif

#if 0
- (float) animation:(NSAnimation*)animation valueForProgress:(NSAnimationProgress)progress
{
  [self performSelectorOnMainThread:@selector(resizeComponents) withObject:nil waitUntilDone:NO];
  return progress;
}
#endif

#pragma mark NSCoding


static NSString* TEXT_SCROLLVIEW = @"scroll view";
static NSString* TEXT_TEXT_VIEW = @"text view";
static NSString* TEXT_GUTTER_VIEW = @"gutter view";
static NSString* TEXT_GUTTER_WIDTH = @"gutter width";
static NSString* TEXT_IS_PRINT_VERSION = @"is print version";


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [super encodeWithCoder:encoder];
  [encoder encodeBool:mIsPrintVersion forKey:TEXT_IS_PRINT_VERSION];
  if ( mIsPrintVersion )
  {
    [encoder encodeObject:mInternalTextView forKey:TEXT_TEXT_VIEW];
  }
  else
  {
    [encoder encodeObject:mTextScrollView forKey:TEXT_SCROLLVIEW];
    [encoder encodeObject:mGutterView forKey:TEXT_GUTTER_VIEW];
    [encoder encodeFloat:mGutterWidth forKey:TEXT_GUTTER_WIDTH];
  }
}


- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super initWithCoder:decoder];
  mIsPrintVersion = [decoder decodeBoolForKey:TEXT_IS_PRINT_VERSION];
  if ( mIsPrintVersion )
  {
    mInternalTextView = [decoder decodeObjectForKey:TEXT_TEXT_VIEW];
    FXRetain(mInternalTextView)
    mGutterWidth = 0;
  }
  else
  {
    mTextScrollView = [decoder decodeObjectForKey:TEXT_SCROLLVIEW];
    FXRetain(mTextScrollView)
    mGutterView = [decoder decodeObjectForKey:TEXT_GUTTER_VIEW];
    FXRetain(mGutterView)
    mGutterWidth = [decoder decodeFloatForKey:TEXT_GUTTER_WIDTH];
    mInternalTextView = [mTextScrollView documentView];
    mGutterView.textView = mInternalTextView;
  }
  
  mInternalTextView.font = [NSFont systemFontOfSize:10.0f];

  [self setUpComponents];
  [self resizeComponents];
  [self initNotificationHandling];
  
  return self;
}


#pragma mark Private


- (void) setUpComponents
{
  [self setUpGutterAndInternalTextViewContainer];
  if (!mIsPrintVersion)
  {
    [self setUpFindBarContainer];
  }
  self.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
}


- (void) setUpGutterAndInternalTextViewContainer
{
  [self setUpInternalTextView];
  if ( !mIsPrintVersion )
  {
    [self setUpGutterView];
  }
}


- (void) setUpInternalTextView
{
  mInternalTextView.richText = NO;
  mInternalTextView.autoresizingMask = 0;
  mInternalTextView.delegate = self;
  mInternalTextView.allowsUndo = YES;
  mInternalTextView.richText = YES;
  mInternalTextView.usesFontPanel = NO;
  mInternalTextView.nextResponder = self;
  mInternalTextView.usesFindBar = YES;

  if (mIsPrintVersion)
  {
    mInternalTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:mInternalTextView];
  }
  else
  {
    mTextScrollView.hasVerticalScroller = YES;
    mTextScrollView.hasHorizontalScroller = YES;
    mTextScrollView.autohidesScrollers = YES;
    mTextScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    mTextScrollView.documentView = mInternalTextView;
    mTextScrollView.effectiveFindBarContainer = self;
    [self addSubview:mTextScrollView];

    [self disableLineWrapping];
  }
}


- (void) setUpGutterView
{
  mGutterView.autoresizingMask = NSViewHeightSizable;
  mGutterView.font = mInternalTextView.font;
  mGutterView.textView = mInternalTextView;
  [self addSubview:mGutterView];
}


- (void) setUpFindBarContainer
{
  mFindBarContainerView.autoresizingMask = NSViewWidthSizable;
  mFindBarContainerView.autoresizesSubviews = YES;
  mFindBarContainerView.wantsLayer = YES;
  mFindBarContainerView.layer.borderWidth = 1.0;
  CGColorRef borderColor = CGColorCreateGenericGray(0.6, 1.0);
  mFindBarContainerView.layer.borderColor = borderColor;
  CGColorRelease(borderColor);
  [self addSubview:mFindBarContainerView];
  mFindBarContainerView.hidden = YES;
}


- (void) disableLineWrapping
{
  mInternalTextView.textContainer.widthTracksTextView = NO;
  mInternalTextView.textContainer.heightTracksTextView = NO;
  mInternalTextView.textContainer.containerSize = NSMakeSize(20000, 10000000);
  mInternalTextView.horizontallyResizable = YES;
  mInternalTextView.verticallyResizable = YES;
  mInternalTextView.maxSize = NSMakeSize(100000, 100000);
  mInternalTextView.minSize = mTextScrollView.contentSize;
}


- (void) resizeComponents
{
  NSSize const newSize = [self frame].size;
  CGFloat const findBarHeight = mIsPrintVersion ? 0 : [self resizeFindBarContainer:newSize];
  [self resizeGutterAndTextView:NSMakeSize(newSize.width, newSize.height - findBarHeight)];
}


- (CGFloat) resizeFindBarContainer:(NSSize)parentSize
{
  CGFloat newHeight = 0.0;
#if FIND_BAR_WITH_ANIMATION
  if ( [self animationIsRunning] )
  {
    newHeight = [mFindBarContainerView frame].origin.y;
  }
  else
#endif
  {
    if ( mFindBarIsVisible )
    {
      NSSize const findBarSize = [mFindBarView frame].size;
      newHeight = findBarSize.height;
      NSRect const findBarContainerRect = NSMakeRect(0, parentSize.height - newHeight, parentSize.width, newHeight);
      [mFindBarContainerView setFrame:findBarContainerRect];
    }
    else
    {
      [mFindBarContainerView setFrameOrigin:NSMakePoint(0, parentSize.height)];
    }
  }
  return newHeight;
}


- (void) resizeGutterAndTextView:(NSSize)newSize
{
  mGutterView.frame = NSMakeRect(0.0f, 0.0f, mGutterWidth, newSize.height);
  [self resizeTextScrollView:NSMakeRect(mGutterWidth, 0, newSize.width - mGutterWidth, newSize.height)];
}


- (void) resizeTextScrollView:(NSRect)frame
{
  if (mIsPrintVersion)
  {
    mInternalTextView.frame = frame;
  }
  else
  {
    mTextScrollView.frame = frame;
    
    FXIssue(124)
    NSSize const scrollViewContentSize = mTextScrollView.contentSize;
    NSLayoutManager* layoutManager = mInternalTextView.layoutManager;
    NSRect const glyphBoundingRect = [layoutManager usedRectForTextContainer:mInternalTextView.textContainer];
    NSSize const textContentSize = NSMakeSize(NSMaxX(glyphBoundingRect), NSMaxY(glyphBoundingRect));
    NSSize const newTextViewSize = NSMakeSize(MAX(textContentSize.width, scrollViewContentSize.width), MAX(textContentSize.height, scrollViewContentSize.height));
    NSPoint const textViewOrigin = {0, 0}; // upside down (vertically flipped) coordinate system
    mInternalTextView.frame = NSMakeRect(textViewOrigin.x, textViewOrigin.y, newTextViewSize.width, newTextViewSize.height);
  }
}


- (void) initNotificationHandling
{
  [[mTextScrollView contentView] setPostsBoundsChangedNotifications:YES];
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(textViewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:[mTextScrollView contentView]];
}


- (void) highlight
{
  if ( mSyntaxHighlighter != nil )
  {
    // Get current cursor position
    NSRange currentSelectedRange = [[[mInternalTextView selectedRanges] objectAtIndex:0] rangeValue];
    // Get the unattributed content of the text view and create attributed text with highlighting from it
    NSAttributedString* highlightedText = [mSyntaxHighlighter highlight:[mInternalTextView string]];
    // Set the new attributed content of the text view
    NSTextStorage* internalTextStorage = [mInternalTextView textStorage];
    [internalTextStorage beginEditing];
    [internalTextStorage setAttributedString:highlightedText];
    [internalTextStorage endEditing];
    // Restore cursor position
    [mInternalTextView setSelectedRange:NSMakeRange(currentSelectedRange.location, 0)]; 
  }
}


#if FIND_BAR_WITH_ANIMATION
- (void) animateFindBarToPosition:(CGFloat)containerOriginEndPositionY
{
  NSRect const currentContainerFrame = [mFindBarContainerView frame];
  NSRect endContainerFrame = currentContainerFrame;
  endContainerFrame.origin.y = containerOriginEndPositionY;

  NSDictionary* findBarSlideAnimationDictionary = @{
    NSViewAnimationTargetKey     : mFindBarContainerView,
    NSViewAnimationStartFrameKey : [NSValue valueWithRect:currentContainerFrame],
    NSViewAnimationEndFrameKey   : [NSValue valueWithRect:endContainerFrame],
  };

  NSRect const currentTextFrame = [mTextScrollView frame];
  NSRect endTextFrame = currentTextFrame;
  endTextFrame.size.height = containerOriginEndPositionY;

  NSDictionary* textSlideAnimationDictionary = @{
    NSViewAnimationTargetKey     : mTextScrollView,
    NSViewAnimationStartFrameKey : [NSValue valueWithRect:currentTextFrame],
    NSViewAnimationEndFrameKey   : [NSValue valueWithRect:endTextFrame]
  };

  NSRect const currentGutterFrame = [mGutterView frame];
  NSRect endGutterFrame = currentGutterFrame;
  endGutterFrame.size.height = containerOriginEndPositionY;

  NSDictionary* gutterSlideAnimationDictionary = @{
    NSViewAnimationTargetKey     : mGutterView,
    NSViewAnimationStartFrameKey : [NSValue valueWithRect:currentGutterFrame],
    NSViewAnimationEndFrameKey   : [NSValue valueWithRect:endGutterFrame]
  };

  if ( mFindBarAnimation != nil )
  {
    FXRelease(mFindBarAnimation)
  }
  NSArray* animations = @[findBarSlideAnimationDictionary, textSlideAnimationDictionary, gutterSlideAnimationDictionary];
  mFindBarAnimation = [[NSViewAnimation alloc] initWithViewAnimations:animations];
  [mFindBarAnimation setAnimationBlockingMode:NSAnimationBlocking];
  [mFindBarAnimation setAnimationCurve:NSAnimationLinear];
  [mFindBarAnimation setDuration:0.08];
  [mFindBarAnimation setDelegate:self];
  [mFindBarAnimation startAnimation];
}

- (BOOL) animationIsRunning
{
  return mFindBarAnimation != nil;
}
#endif


- (void) hideFindBar
{
#if FIND_BAR_WITH_ANIMATION
  [self animateFindBarToPosition:[self frame].size.height];
#else
  [self removeFindBarView];
  [self resizeComponents];
  [self setNeedsDisplay:YES];
#endif
}


- (void) showFindBar
{
#if FIND_BAR_WITH_ANIMATION
  if ( mFindBarView != nil )
  {
    {
      NSRect newFindBarContainerFrame = [self frame];
      newFindBarContainerFrame.origin.y = newFindBarContainerFrame.size.height;
      newFindBarContainerFrame.size.height = [mFindBarView frame].size.height;
      [mFindBarContainerView setFrame:newFindBarContainerFrame];
      [mFindBarContainerView setHidden:NO];
    }
    [self animateFindBarToPosition:([self frame].size.height - [mFindBarContainerView frame].size.height)];
  }
#else
  [self resizeComponents];
  [self setNeedsDisplay:YES];
#endif
}


- (void) removeFindBarView
{
  // Due to a bug in AppKit (rdar://10926990) the finder bar view needs to be removed from its superview so that it can become visible again.
  [mFindBarContainerView setSubviews:@[]];
  mFindBarView = nil;
  [mFindBarContainerView setHidden:YES];
}


@end
