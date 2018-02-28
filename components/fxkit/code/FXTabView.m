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

#import "FXTabView.h"
#import <FXKit/FXKit-Swift.h>

static const CGFloat skTabMinWidth          = 100.0;
static const CGFloat skTabRowHeight         = 24.0;
static const CGFloat skTitleTextSize        = 12.0;
static const CGFloat skTextColor[]          = {0.5, 0.5, 0.5, 1.0};
static const CGFloat skSelectedTextColor[]  = {0.95, 1.0, 0.95, 1.0};


#pragma mark - FXTabHeaderView -


@interface FXTabHeaderView : NSView
@property SEL action;
@property (unsafe_unretained) id target;
- (void) addTitle:(NSString*)title;
- (void) removeAllTitles;
- (NSInteger) selectedTitle;
- (void) selectTitleAtIndex:(NSInteger)index;
@end


@implementation FXTabHeaderView
{
@private
  NSInteger mMouseDownTabIndex;
  NSInteger mSelectedTabIndex;
  CGColorSpaceRef mColorSpace;
  CGGradientRef mGradient;
  CGGradientRef mSelectedGradient;
  NSMutableArray* mTabTitles;
  CGContextRef mContext;
}

@synthesize action;
@synthesize target;

- (id) initWithFrame:(NSRect)frameRect
{
  if ( (self = [super initWithFrame:frameRect]) != nil )
  {
    mSelectedTabIndex = -1;
    mTabTitles = [[NSMutableArray alloc] init];
    [self resetMouseEventHandling];
    mColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    mGradient = NULL;
    mSelectedGradient = NULL;
    [self setWantsLayer:YES]; // to get rid of artifacts from focus ring layers of neighboring views
  }
  return self;
}


- (void) dealloc
{
  CGColorSpaceRelease(mColorSpace);
  if ( mGradient != NULL )
  {
    CGGradientRelease(mGradient);
  }
  if ( mSelectedGradient != NULL )
  {
    CGGradientRelease(mSelectedGradient);
  }
  FXRelease(mTabTitles)
  FXDeallocSuper
}


#pragma mark Public


- (void) addTitle:(NSString*)title
{
  [mTabTitles addObject:title];
  mSelectedTabIndex = [mTabTitles count] - 1;
  [self setNeedsDisplay:YES];
}


- (void) removeAllTitles
{
  [mTabTitles removeAllObjects];
  mSelectedTabIndex = - 1;
  [self setNeedsDisplay:YES];
}


- (NSInteger) selectedTitle
{
  return mSelectedTabIndex;
}


- (void) selectTitleAtIndex:(NSInteger)index
{
  if ( (index >= 0) && (index < [mTabTitles count]) )
  {
    if (mSelectedTabIndex != index)
    {
      mSelectedTabIndex = index;
      [self setNeedsDisplay:YES];
    }
  }
}


#pragma mark NSResponder overrides


- (void) mouseDown:(NSEvent*)mouseEvent
{
  NSPoint mouseDownLocation = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
  NSSize const viewSize = [self frame].size;
  mMouseDownTabIndex = -1;
  if ( (viewSize.width > 0) && NSPointInRect(mouseDownLocation, NSMakeRect(0, viewSize.height - skTabRowHeight, viewSize.width, skTabRowHeight)) )
  {
    NSInteger numTabs = [mTabTitles count];
    mMouseDownTabIndex = (NSInteger) floor( mouseDownLocation.x / viewSize.width * numTabs );
  }
}


- (void) mouseUp:(NSEvent*)mouseEvent
{
  if ( mMouseDownTabIndex != -1 )
  {
    NSPoint mouseUpLocation = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
    NSSize viewSize = [self frame].size;
    if ( (viewSize.width > 0) && NSPointInRect(mouseUpLocation, NSMakeRect(0, viewSize.height - skTabRowHeight, viewSize.width, skTabRowHeight)) )
    {
      NSInteger numTabs = [mTabTitles count];
      NSInteger mouseUpTabIndex = (NSInteger) floor( mouseUpLocation.x / viewSize.width * numTabs );
      if ( mMouseDownTabIndex == mouseUpTabIndex )
      {
        [self selectTitleAtIndex:mMouseDownTabIndex];
      #pragma clang diagnostic push
      #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.action withObject:self];
      #pragma clang diagnostic pop
      }
    }
  }
  [self resetMouseEventHandling];
}


#pragma mark NSView overrides


- (BOOL) acceptsFirstMouse:(NSEvent*)mouseEvent
{
  return YES;
}


- (void) drawRect:(NSRect)dirtyRect
{
  mContext = FXGraphicsContext;
  CGContextClipToRect(mContext, dirtyRect);
  CGContextSaveGState(mContext);
  CGContextSetFillColorSpace(mContext, mColorSpace);
  CGContextSetStrokeColorSpace(mContext, mColorSpace);
  
  [self drawTabsInFrame:dirtyRect];

  CGContextRestoreGState(mContext);
}


#pragma mark Private


- (void) resetMouseEventHandling
{
  mMouseDownTabIndex = -1;
}


- (void) drawTabsInFrame:(NSRect)rect
{
  if ( mGradient == NULL )
  {
    static const CGFloat skGradientStopColors[8] = {
      0.80, 0.82, 0.80, 1.0,
      0.72, 0.76, 0.72, 1.0,
    };
    static const CGFloat skSelectedGradientStopColors[8] = {
      0.35, 0.45, 0.35, 1.0,
      0.30, 0.40, 0.30, 1.0
    };
    static const CGFloat skGradientStopPositions[2] = { 0.0, 1.0 };

    mGradient = CGGradientCreateWithColorComponents(mColorSpace, skGradientStopColors, skGradientStopPositions, 2);
    mSelectedGradient = CGGradientCreateWithColorComponents(mColorSpace, skSelectedGradientStopColors, skGradientStopPositions, 2);
  }

  CGRect const bounds = self.bounds;
  CGPoint const top = CGPointMake(0, bounds.size.height);
  CGPoint const bottom = CGPointMake(0,0);

  CGContextSaveGState(mContext);
  CGContextDrawLinearGradient (mContext, mGradient, top, bottom, 0);
  CGContextSetTextMatrix(mContext, CGAffineTransformIdentity);

  // Clearing the background.
  CGContextBeginPath(mContext);
  CGContextAddRect(mContext, CGRectMake(0, 0, bounds.size.width, bounds.size.height));
  CGContextDrawLinearGradient(mContext, mGradient, top, bottom, 0);

  if ( bounds.size.width >= skTabMinWidth )
  {
    NSUInteger tabIndex = 0;
    NSUInteger const numTabs = [mTabTitles count];
    CGFloat const tabWidth = bounds.size.width / numTabs;
    for ( NSString* __attribute__((unused)) tabTitle in mTabTitles )
    {
      NSRect const currentTabRect = CGRectMake(tabIndex * tabWidth, 0, tabWidth, bounds.size.height);
      CGContextSaveGState(mContext);
      CGGradientRef tabGradient = mGradient;
      if ( tabIndex == mSelectedTabIndex )
      {
        tabGradient = mSelectedGradient;
      }
      CGContextBeginPath(mContext);
      CGContextAddRect(mContext, currentTabRect);
      CGContextClip(mContext);
      CGContextDrawLinearGradient (mContext, tabGradient, top, bottom, 0);
      CGContextRestoreGState(mContext);

    #if 0
      static const CGFloat skFrameColor[] = {0.7, 0.7, 0.7, 1.0};
      CGContextSetStrokeColor(mContext, skFrameColor);
      CGContextBeginPath(mContext);
      CGContextAddRect(mContext, currentTabRect);
      CGContextStrokePath(mContext);
    #endif

      CGContextSaveGState(mContext);
      [self drawTitle:mTabTitles[tabIndex] inRect:currentTabRect withHighlight:(tabIndex == mSelectedTabIndex)];
      CGContextRestoreGState(mContext);

      tabIndex++;
    }
  }

  CGContextRestoreGState(mContext);
}


- (void) drawTitle:(NSString*)title inRect:(NSRect)rect withHighlight:(BOOL)hilite
{
  CGContextClipToRect(mContext, (CGRect)rect);
  static NSDictionary* sTitleAttributes = nil;
  static NSDictionary* sHighlightedTitleAttributes = nil;
  if ( sTitleAttributes == nil )
  {
    NSFont* titleFont = [NSFont fontWithName:@"Lucida Grande" size:skTitleTextSize];
    sTitleAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
                        titleFont, NSFontAttributeName,
                        [NSColor colorWithDeviceRed:skTextColor[0] green:skTextColor[1] blue:skTextColor[2] alpha:skTextColor[3]], NSForegroundColorAttributeName,
                        nil];
    sHighlightedTitleAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   titleFont, NSFontAttributeName,
                                   [NSColor colorWithDeviceRed:skSelectedTextColor[0] green:skSelectedTextColor[1] blue:skSelectedTextColor[2] alpha:skSelectedTextColor[3]], NSForegroundColorAttributeName,
                                   nil];
  }

  NSDictionary* titleAttributes = (hilite ? sHighlightedTitleAttributes : sTitleAttributes);
  NSSize titleSize = [title sizeWithAttributes:titleAttributes];
  [title drawAtPoint:NSMakePoint(rect.origin.x + (rect.size.width - titleSize.width)/2.0, rect.origin.y + (rect.size.height - titleSize.height)/2.0) withAttributes:titleAttributes];
}



@end


#pragma mark - FXTabContentView -


@interface FXTabContentView : NSView <NSAnimationDelegate>
- (void) addContent:(NSView*)view;
- (void) showSubviewAtIndex:(NSInteger)index animate:(BOOL)withAnimation;
@end


@implementation FXTabContentView
{
@private
  NSMutableArray* _viewsSavedFromResizing;
  NSView* _lastSelectedView;
}

- (id) initWithFrame:(NSRect)frame
{
  if ( (self = [super initWithFrame:frame]) != nil )
  {
    _viewsSavedFromResizing = [[NSMutableArray alloc] init];
    _lastSelectedView = nil;
  }
  return self;
}


#pragma mark Public


- (void) showSubviewAtIndex:(NSInteger)index animate:(BOOL)withAnimation
{
  @synchronized(_viewsSavedFromResizing)
  {
    if ( [_viewsSavedFromResizing count] == 0 )
    {
      NSAssert( index < [[self subviews] count], @"The tab view does not contains a subview at the given index." );
      NSView* newSelectedView = self.subviews[index];

      NSView* currentSelectedView = nil;
      for ( NSView* currentSubview in [self subviews] )
      {
        if ( ![currentSubview isHidden] )
        {
          currentSelectedView = currentSubview;
          break;
        }
      }
      if ( newSelectedView != currentSelectedView )
      {
        if ( withAnimation )
        {
          [newSelectedView setHidden:NO];
          _lastSelectedView = currentSelectedView;
          [self animateSwitchingFromView:currentSelectedView toView:newSelectedView];
        }
        else
        {
          [currentSelectedView setHidden:YES];
          [newSelectedView setHidden:NO];
        }
      }
    }
  }
}


- (void) addContent:(NSView*)view
{
  if ( ![[self subviews] containsObject:view] )
  {
    for ( NSView* existingView in [self subviews] )
    {
      [existingView setHidden:YES];
    }
    [self addSubview:view];

    [FXViewUtils layoutIn:self visualFormats:@[@"H:|[view]|", @"V:|[view]|"] metricsInfo:nil viewsInfo:NSDictionaryOfVariableBindings(view)];
  }
}


#pragma mark NSAnimationDelegate


- (void) animationDidEnd:(NSAnimation*)animation
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [_lastSelectedView setHidden:YES];
  });
}


#pragma mark NSView overrides

- (void) setFrameSize:(NSSize)newSize
{
  @synchronized(_viewsSavedFromResizing)
  {
    if ( newSize.width < skTabMinWidth )
    {
      for ( NSView* view in [self subviews] )
      {
        [_viewsSavedFromResizing addObject:view];
      }
      [super setSubviews:@[]];
      [self removeConstraints:[self constraints]];
    }
    else
    {
      if ( [_viewsSavedFromResizing count] > 0 )
      {
        for ( NSView* view in _viewsSavedFromResizing )
        {
          [super addSubview:view];
          [FXViewUtils layoutIn:self visualFormats:@[@"H:|[view]|", @"V:|[view]|"] metricsInfo:nil viewsInfo:NSDictionaryOfVariableBindings(view)];
        }
        [_viewsSavedFromResizing removeAllObjects];
      }
    }
  }
  [super setFrameSize:newSize];
}


#pragma mark Private


- (void) animateSwitchingFromView:(NSView*)oldView toView:(NSView*)newView
{
  if ( (newView != nil) && (newView != oldView) )
  {
    NSDictionary* fadeInEffect = @{ NSViewAnimationTargetKey : newView, NSViewAnimationEffectKey : NSViewAnimationFadeInEffect };
    NSDictionary* fadeOutEffect = @{ NSViewAnimationTargetKey : oldView, NSViewAnimationEffectKey : NSViewAnimationFadeOutEffect };
    NSViewAnimation* switchAnimation = [[NSViewAnimation alloc] initWithViewAnimations:@[fadeInEffect, oldView ? fadeOutEffect : nil]];
    switchAnimation.animationBlockingMode = NSAnimationNonblockingThreaded;
    switchAnimation.duration = 0.12;
    switchAnimation.frameRate = 0.0;
    switchAnimation.animationCurve = NSAnimationLinear;
    switchAnimation.delegate = self;
    [switchAnimation startAnimation];
  }
}


@end


#pragma mark - FXTab -


@interface FXTab : NSObject
@property (copy) NSString* title;
@property NSView* content;
@end


@implementation FXTab

@synthesize title;
@synthesize content;

- (void) dealloc
{
  self.title = nil;
  self.content = nil;
  FXDeallocSuper
}

@end



#pragma mark - FXTabView -



@implementation FXTabView
{
@private
  NSMutableArray* mTabs;
  NSUInteger mSelectedTabIndex;
  FXTabHeaderView* mTabHeader;
  FXTabContentView* mTabContent;
}


- (id) initWithFrame:(NSRect)frameRect
{
  if ( (self = [super initWithFrame:frameRect]) != nil )
  {
    mTabs = [NSMutableArray new];
    mSelectedTabIndex = 0;

    mTabContent = [[FXTabContentView alloc] initWithFrame:frameRect];

    mTabHeader = [[FXTabHeaderView alloc] initWithFrame:frameRect];
    mTabHeader.action = @selector(handleTabSelection:);
    mTabHeader.target = self;

    self.subviews = @[mTabContent, mTabHeader];
    FXRelease(mTabContent)
    FXRelease(mTabHeader)

    [FXViewUtils layoutIn:self
            visualFormats:@[@"H:|[header]|",
                            @"V:|[header(headerHeight)]-(>=0)-|",
                            @"H:|[content]|",
                            @"V:|-(headerHeight)-[content]|"]
              metricsInfo:@{ @"headerHeight" : @(skTabRowHeight) }
                viewsInfo:@{ @"header" : mTabHeader, @"content" : mTabContent}];
  }
  return self;
}


- (void) dealloc
{
  [mTabHeader removeFromSuperview];
  [mTabContent removeFromSuperview];
  FXRelease(mTabs)
  FXDeallocSuper
}


#pragma mark Public


- (void) addTabView:(NSView*)view withTitle:(NSString*)title
{
  FXTab* newTab = [[FXTab alloc] init];
  [newTab setTitle:title];
  [newTab setContent:view];
  [mTabs addObject:newTab];

  [mTabContent addContent:[newTab content]];
  [mTabHeader addTitle:[newTab title]];

  [self selectTabAtIndex:([mTabs count] - 1) animate:NO];
}


- (void) selectTabAtIndex:(NSUInteger)tabIndex animate:(BOOL)withAnimation
{
  if ( tabIndex < [mTabs count] )
  {
    mSelectedTabIndex = tabIndex;
    [mTabContent showSubviewAtIndex:mSelectedTabIndex animate:withAnimation];
    [mTabHeader selectTitleAtIndex:mSelectedTabIndex];
  }
}


- (void) selectTabWithTitle:(NSString*)title animate:(BOOL)withAnimation
{
  NSInteger tabIndex = 0;
  for ( FXTab* tab in mTabs )
  {
    if ( [[tab title] isEqualToString:title] )
    {
      [self selectTabAtIndex:tabIndex animate:withAnimation];
      break;
    }
    tabIndex++;
  }
}


- (NSSize) minimumSize
{
  return NSMakeSize(80, skTabRowHeight);
}


- (CGFloat) headerHeight
{
  return skTabRowHeight;
}


#pragma mark NSResponder overrides


static NSString* FXResume_SelectedTabIndexKey = @"FXResume_SelectedTabIndex";

- (void) encodeRestorableStateWithCoder:(NSCoder*)coder
{
  [super encodeRestorableStateWithCoder:coder];
  [coder encodeInteger:(NSInteger)mSelectedTabIndex forKey:FXResume_SelectedTabIndexKey];
}

- (void) restoreStateWithCoder:(NSCoder*)coder
{
  [super restoreStateWithCoder:coder];
  NSInteger const selectedTab = [coder decodeIntegerForKey:FXResume_SelectedTabIndexKey];
  if ( selectedTab >= 0 )
  {
    [self selectTabAtIndex:(NSUInteger)selectedTab animate:NO];
    [self setNeedsDisplay:YES];
  }
}


#pragma mark Private


- (void) handleTabSelection:(id)sender
{  
  NSInteger selectedTabIndex = [mTabHeader selectedTitle];
  [self selectTabAtIndex:selectedTabIndex animate:YES];
  [[self window] invalidateRestorableState];
}


@end
