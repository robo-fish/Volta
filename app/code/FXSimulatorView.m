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

#import "FXSimulatorView.h"
#import "FXOverlayTextLineView.h"


@interface FXSimulatorView ()
@property BOOL hasSimulationResults;
@end


@implementation FXSimulatorView
{
@private
  NSTextView* mResultsTextView;
  NSScrollView* mResultsScrollView;
  FXOverlayTextLineView* mOverlayInfoView;
}

- (id) initWithFrame:(NSRect)frame
{
  if ( (self = [super initWithFrame:frame]) != nil )
  {
    [self buildUI];
    self.hasSimulationResults = NO;
    self.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    [self showPlaceholderText];
  }
  return self;
}


#pragma mark Public


- (void) showOutput:(NSString*)output
{
  if ( (output == nil) || ([output length] == 0) )
  {
    [self clearOutput];
  }
  else
  {
    [self hidePlaceholderText];
    [mResultsTextView setString:output];
    self.hasSimulationResults = YES;
  }
}


- (void) clearOutput
{
  self.hasSimulationResults = NO;
  [mResultsTextView setString:@""];
  [self showPlaceholderText];
}


- (CGSize) minSize
{
  return CGSizeMake(50, 50);
}


#pragma mark Private


- (void) buildUI
{
  NSRect const frame = self.frame;

  mResultsTextView = [[NSTextView alloc] initWithFrame:frame];
  mResultsTextView.editable = NO;
  mResultsTextView.selectable = YES;
  mResultsTextView.usesFindBar = YES;
  mResultsTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  mResultsTextView.backgroundColor = [NSColor whiteColor];
  mResultsTextView.font = [NSFont fontWithName:@"Menlo" size:11.0]; // using a monospaced font
  mResultsTextView.drawsBackground = YES;

  // Preventing line wrapping
  mResultsTextView.textContainer.widthTracksTextView = NO;
  mResultsTextView.textContainer.heightTracksTextView = NO;
  mResultsTextView.textContainer.containerSize = NSMakeSize(20000, 100000000);
  mResultsTextView.horizontallyResizable = YES;
  mResultsTextView.verticallyResizable = YES;
  mResultsTextView.minSize = NSMakeSize(20, 10);
  // Important: the max vertical height must be huge so that, e.g., a million lines can fit in.
  mResultsTextView.maxSize = NSMakeSize(100000, 10000000);

  // Embedding in a scroll view
  mResultsScrollView = [[NSScrollView alloc] initWithFrame:frame];
  mResultsScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  mResultsScrollView.documentView = mResultsTextView;
  mResultsScrollView.hasVerticalScroller = YES;
  mResultsScrollView.autohidesScrollers = YES;

  [self addSubview:mResultsScrollView];
  FXRelease(mResultsScrollView)
  FXRelease(mResultsTextView)
}


- (void) showPlaceholderText
{
  if ( mOverlayInfoView == nil )
  {
    NSRect frame = self.frame;
    frame.origin = NSZeroPoint;
    mOverlayInfoView = [[FXOverlayTextLineView alloc] initWithFrame:frame];
    mOverlayInfoView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    mOverlayInfoView.text = FXLocalizedString(@"NoSimulatorOutput");
    [self addSubview:mOverlayInfoView];
    FXRelease(mOverlayInfoView)
  }
}


- (void) hidePlaceholderText
{
  [mOverlayInfoView removeFromSuperview];
  mOverlayInfoView = nil;
}


@end
