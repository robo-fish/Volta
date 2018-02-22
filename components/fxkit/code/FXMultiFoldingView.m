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

#import "FXMultiFoldingView.h"
#import "FXClipView.h"
#import "FXViewUtils.h"


#pragma mark - FXMultiFoldingSubview -


@interface FXMultiFoldingSubview : FXClipView
{
@private
  NSButton* mTriangleButton;
  NSTextField* mTitleField;
  NSSize mMinSize;
  FXClipView* mContainerView;
  id<NSObject> __weak mTarget;
}
@property SEL action;
@property (weak) id<NSObject> target;
@property (readonly) BOOL isFolded;
@property (copy) NSString* title;

- (id) initWithTitle:(NSString*)title;
- (void) setContentView:(NSView*)view;
- (void) handleDisclosureAction:(id)sender;
@end

static const CGFloat skFoldingSubviewHeaderHeight = 18.0;


@implementation FXMultiFoldingSubview

@synthesize target = mTarget;

- (id) initWithTitle:(NSString*)title
{
  static const NSRect dummyFrame = {0,0,200,200};
  if ( (self = [super initWithFrame:dummyFrame]) != nil )
  {
    mMinSize = NSZeroSize;

    NSView* view = [[NSView alloc] initWithFrame:dummyFrame];

    mTitleField = [[NSTextField alloc] initWithFrame:dummyFrame];
    mTitleField.stringValue = title;
    mTitleField.bordered = NO;
    mTitleField.backgroundColor = [NSColor colorWithDeviceRed:0.4 green:0.42 blue:0.4 alpha:1];
    mTitleField.drawsBackground = YES;
    mTitleField.textColor = [NSColor colorWithDeviceWhite:0.9 alpha:1.0];
    mTitleField.font = [NSFont fontWithName:@"Lucida Grande" size:12.0];
    mTitleField.selectable = NO;
    mTitleField.editable = NO;
    mTitleField.focusRingType = NSFocusRingTypeNone;
    mTitleField.alignment = NSTextAlignmentCenter;

    mContainerView = [[FXClipView alloc] initWithFrame:dummyFrame];

    view.subviews = @[mTitleField, mContainerView];
    FXRelease(mTitleField)
    FXRelease(mContainerView)

    NSDictionary* views = @{ @"container" : mContainerView, @"title" : mTitleField };
    NSDictionary* metrics = @{ @"titleHeight" : @(skFoldingSubviewHeaderHeight) };
    [FXViewUtils layoutInView:view
                visualFormats:@[@"H:|[title]|", @"H:|[container]|", @"V:|[title(titleHeight)][container(>=32)]|"]
                  metricsInfo:metrics
                    viewsInfo:views];

    self.documentView = view;
    self.minDocumentViewHeight = skFoldingSubviewHeaderHeight;
    FXRelease(view)
  }
  return self;
}

- (void) dealloc
{
  FXDeallocSuper
}

- (void) setTitle:(NSString*)title
{
  [mTitleField setStringValue:title];
}

- (NSString*) title
{
  return [mTitleField stringValue];
}

- (BOOL) isFolded
{
  return ([mTriangleButton state] == NSOffState);
}

- (void) setContentView:(NSView*)view
{
  mContainerView.documentView = view;
  NSDictionary* views = NSDictionaryOfVariableBindings(view);
  [mContainerView removeConstraints:[mContainerView constraints]];
  [FXViewUtils layoutInView:mContainerView visualFormats:@[@"H:|[view]|", @"V:|[view]|"] metricsInfo:nil viewsInfo:views];
  self.minDocumentViewHeight = skFoldingSubviewHeaderHeight + view.fittingSize.height;
}

- (void) handleDisclosureAction:(id)sender
{
  NSAssert(sender == mTriangleButton, @"Action sent from unknown control.");
  if ( (self.target != nil) && (self.action != 0) )
  {
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.target performSelector:self.action];
  #pragma clang diagnostic pop
  }
}

- (void) encodeRestorableStateWithCoder:(NSCoder*)coder
{
  [super encodeRestorableStateWithCoder:coder];
  [mContainerView encodeRestorableStateWithCoder:coder];
}

- (void) restoreStateWithCoder:(NSCoder*)coder
{
  [super restoreStateWithCoder:coder];
  [mContainerView restoreStateWithCoder:coder];
}

@end


#pragma mark - FXMultiFoldingView -


@interface FXMultiFoldingView () <NSSplitViewDelegate>
@end


@implementation FXMultiFoldingView
{
@private
  NSSplitView* mSplitter;
  NSMutableArray* mFoldingSubviews;
}

- (id)initWithFrame:(NSRect)frame
{
  if ( (self = [super initWithFrame:frame]) != nil )
  {
    mSplitter = [[NSSplitView alloc] initWithFrame:frame];
    mSplitter.dividerStyle = NSSplitViewDividerStylePaneSplitter;
    mSplitter.delegate = self;
    mSplitter.vertical = NO;
    [super addSubview:mSplitter];
    FXRelease(mSplitter)

    [FXViewUtils layoutInView:self visualFormats:@[@"H:|[mSplitter]|", @"V:|[mSplitter]|"] metricsInfo:nil viewsInfo:NSDictionaryOfVariableBindings(mSplitter)];

    mFoldingSubviews = [NSMutableArray new];
  }
  return self;
}


- (void)dealloc
{
  FXRelease(mFoldingSubviews)
  FXDeallocSuper
}


#pragma mark Public


- (void) addSubview:(NSView*)view withTitle:(NSString*)title
{
  FXMultiFoldingSubview* foldingSubview = [self newFoldingSubviewWithTitle:title];
  foldingSubview.contentView = view;
  [mSplitter addSubview:foldingSubview];
  [FXViewUtils layoutInView:mSplitter
              visualFormats:@[@"V:[foldingSubview(>=minHeight)]"]
                metricsInfo:@{@"minHeight":@(foldingSubview.minDocumentViewHeight)}
                  viewsInfo:NSDictionaryOfVariableBindings(foldingSubview)];
  [mFoldingSubviews addObject:foldingSubview];
  FXRelease(foldingSubview)
}


- (void) addSubview:(NSView*)view
{
  [self addSubview:view withTitle:@""];
}


#pragma mark NSSplitViewDelegate methods


- (BOOL) splitView:(NSSplitView*)splitView canCollapseSubview:(NSView*)subview
{
  return YES;
}


- (BOOL) splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView*)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
  return YES;
}


FXIssue(247)
#if 0
- (BOOL) splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView*)targetSubview
{
  CGFloat const totalDividerThickness = MAX([mFoldingSubviews count] - 1, 0) * [mSplitter dividerThickness];
  CGFloat const totalHeight = self.frame.size.height;
  CGFloat const subviewHeight = targetSubview.frame.size.height;
  BOOL const allOtherSubviewsAreCollapsed = ( ( totalHeight - subviewHeight - totalDividerThickness) < 1 );
  return allOtherSubviewsAreCollapsed;
}
#endif


#pragma mark NSResponder overrides


NSString* FXResume_SplitterPositions = @"FXResume_SplitterPositions";

- (void) encodeRestorableStateWithCoder:(NSCoder*)coder
{
  [super encodeRestorableStateWithCoder:coder];
  NSArray* splitterSubviews = [mSplitter subviews];
  __block NSMutableArray* subviewHeights = [[NSMutableArray alloc] initWithCapacity:[splitterSubviews count]];
  [splitterSubviews enumerateObjectsUsingBlock:^(id subview, NSUInteger index, BOOL *stop) {
    FXMultiFoldingSubview* foldingSubview = subview;
    [foldingSubview encodeRestorableStateWithCoder:coder];
    NSNumber* heightNumber = @([foldingSubview frame].size.height);
    [subviewHeights addObject:heightNumber];
  }];
  [coder encodeObject:subviewHeights forKey:FXResume_SplitterPositions];
  FXRelease(subviewHeights)
  subviewHeights = nil;
}


- (void) restoreStateWithCoder:(NSCoder*)coder
{
  [super restoreStateWithCoder:coder];
  NSArray* subviewHeights = [coder decodeObjectForKey:FXResume_SplitterPositions];
  for ( FXMultiFoldingSubview* subview in [mSplitter subviews] )
  {
    [subview restoreStateWithCoder:coder];
  }
  [mSplitter adjustSubviews];
  __block CGFloat currentPos = 0.0;
  [subviewHeights enumerateObjectsUsingBlock:^(id heightNumber, NSUInteger index, BOOL *stop) {
    if ( index < ([[mSplitter subviews] count] - 1) )
    {
      currentPos += [(NSNumber*)heightNumber doubleValue] + (index * [mSplitter dividerThickness]);
      [mSplitter setPosition:currentPos ofDividerAtIndex:index];
    }
  }];
  [self setNeedsDisplay:YES];
}


#pragma mark Private


- (void) handleFoldingAction:(id)sender
{

}


- (FXMultiFoldingSubview*) newFoldingSubviewWithTitle:(NSString*)title
{
  FXMultiFoldingSubview* foldingBox = [[FXMultiFoldingSubview alloc] initWithTitle:title];
  foldingBox.action = @selector(handleFoldingAction:);
  foldingBox.target = self;
  return foldingBox;
}


@end
