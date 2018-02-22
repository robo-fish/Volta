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

#import "FXSchematicPaletteElementsView.h"
#import "FXSchematicElement.h"
#import "FXSchematicElementGroup.h"
#import "FXSchematicElementView.h"
#import "VoltaSchematicElementGroup.h"
#import "FXShape.h"

static const CGFloat skPaletteElementSpacing          = 4.0;
static const CGFloat skPaletteElementWidth            = 42.0;
static const CGFloat skPaletteVerticalMarginTop       = 2.0;
static const CGFloat skPaletteVerticalMarginScrollBar = 8.0;


@implementation FXSchematicPaletteElementsView
{
@private
  id<VoltaSchematicElementGroup> mElements;
  BOOL mRefreshing; // whether the elements are currently refreshed
  NSMenu* mContextMenu;
}

@synthesize contextMenu = mContextMenu;

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    mElements = nil;
    mRefreshing = NO;
    mContextMenu = nil;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScrollerStyleChanged:) name:NSPreferredScrollerStyleDidChangeNotification object:nil];
  }
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  FXRelease(mContextMenu)
  FXRelease(mElements)
  FXDeallocSuper
}


#pragma mark NSView overrides


- (BOOL) isOpaque
{
  return NO;
}


- (NSMenu*) menuForEvent:(NSEvent*)mouseDownEvent
{
  if ( mContextMenu != nil )
  {
    return mContextMenu;
  }
  return [[self class] defaultMenu];
}


#pragma mark Public


- (void) refresh
{
  @synchronized(self)
  {
    [self setSubviews:@[]];
    if ( mElements != nil )
    {
      NSArray* paletteElements = [mElements elements];
      if ( [paletteElements count] > 0 )
      {
        NSMutableArray* subviewsArray = [[NSMutableArray alloc] initWithCapacity:[paletteElements count]];
        NSRect frame = [self frame];
        CGFloat const marginBottom = ([[[self enclosingScrollView] horizontalScroller] scrollerStyle] == NSScrollerStyleOverlay) ? skPaletteVerticalMarginScrollBar : 0;
        CGFloat elementHeight = frame.size.height - skPaletteVerticalMarginTop - marginBottom;

        for ( id<VoltaSchematicElement> element in paletteElements )
        {
          // Placing the new element at the end of the row.
          CGFloat const posX = skPaletteElementSpacing + [subviewsArray count] * (skPaletteElementWidth + skPaletteElementSpacing);
          // Create the subview and add it to the elements viewer
          FXSchematicElementView* newSubview = [[FXSchematicElementView alloc] initWithFrame:FXRectMake( posX, marginBottom, skPaletteElementWidth, elementHeight)];
          id<VoltaSchematicElement> elementCopy = [element copyWithZone:nil]; // Making a copy prevents modifications made by the view to affect the original group element.
          newSubview.schematicElement = elementCopy;
          FXRelease(elementCopy)
          newSubview.showSinglePropertyValue = YES;
          newSubview.showName = YES;
          [newSubview setToolTip:[self toolTipForElement:element]];
          [newSubview setNextResponder:self];
          [subviewsArray addObject:newSubview];
          FXRelease(newSubview)
        }
        [self setSubviews:subviewsArray];

        frame.size.width = ceil(skPaletteElementSpacing + ([subviewsArray count] * (skPaletteElementWidth + skPaletteElementSpacing)));
        [self setFrame:frame];

        FXRelease(subviewsArray)
      }
    }
  }
}


- (void) setElements:(id<VoltaSchematicElementGroup>)elements animate:(BOOL)withAnimation
{
  if ( mElements != elements )
  {
    FXRelease(mElements)
    mElements = elements;
    FXRetain(mElements)
  #if 1
    FXIssue(159)
    if ( withAnimation )
    {
      [self startRefreshingWithAnimation];
    }
    else
  #endif
    {
      [self refresh];
    }
  }
}


- (id<VoltaSchematicElementGroup>) elements
{
  FXRetain(mElements)
  FXAutorelease(mElements)
  return mElements;
}



#pragma mark NSAnimationDelegate


- (void) animationDidEnd:(NSAnimation*)animation
{
  if ( mRefreshing )
  {
    [self endRefreshingWithAnimation];
  }
  FXRelease(animation)
}


#pragma mark Private


- (void) fadeIn
{
  NSDictionary* fadeInEffect = @{ NSViewAnimationTargetKey : self, NSViewAnimationEffectKey : NSViewAnimationFadeInEffect };
  NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:@[fadeInEffect]];
  [animation setAnimationBlockingMode:NSAnimationNonblocking];
  [animation setAnimationCurve:NSAnimationLinear];
  [animation setDuration:0.08];
  [animation setFrameRate:0.0];
  [animation setDelegate:self];
  [animation startAnimation];
}


- (void) fadeOut
{
  NSDictionary* fadeOutEffect = @{ NSViewAnimationTargetKey : self, NSViewAnimationEffectKey : NSViewAnimationFadeOutEffect };
  NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:@[fadeOutEffect]];
  [animation setAnimationBlockingMode:NSAnimationNonblocking];
  [animation setAnimationCurve:NSAnimationLinear];
  [animation setDuration:0.06];
  [animation setFrameRate:0.0];
  [animation setDelegate:self];
  [animation startAnimation];
}


- (void) endRefreshingWithAnimation
{
  [self refresh];
  mRefreshing = NO;
  [self fadeIn];
}


- (void) startRefreshingWithAnimation
{
  mRefreshing = YES;
  [self fadeOut];
}


- (NSString*) toolTipForElement:(id<VoltaSchematicElement>)element
{
  NSString* vendorName = [element modelVendor];
  if ( (vendorName != nil) && ([vendorName length] > 0) )
  {
    return [NSString stringWithFormat:@"%@ (%@)", [element name], vendorName];
  }
  else
  {
    return [element name];
  }
}


- (void) handleScrollerStyleChanged:(NSNotification*)notification
{
  NSScroller* scroller = [[self enclosingScrollView] horizontalScroller];
  CGFloat const scrollerWidth = [NSScroller scrollerWidthForControlSize:NSControlSizeRegular scrollerStyle:NSScrollerStyleLegacy];
  NSRect frame = self.frame;
  frame.size.height += (([scroller scrollerStyle] == NSScrollerStyleOverlay) ? 1 : -1) * scrollerWidth;
  self.frame = frame;
  [self refresh];
}


@end
