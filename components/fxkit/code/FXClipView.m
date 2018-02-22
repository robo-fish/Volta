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

#import "FXClipView.h"


@implementation FXClipView
{
@private
  BOOL    mFlippedClipView;
}


- (id) initWithFrame:(NSRect)frameRect flipped:(BOOL)isFlipped
{
  if ((self = [super initWithFrame:frameRect]) != nil)
  {
    self.minDocumentViewHeight = 0;
    self.minDocumentViewWidth = 0;
    self.verticalClipOffset = 0;
    self.constrainsDocumentSize = YES;
    mFlippedClipView = isFlipped;
  }  
  return self;
}


#pragma mark NSClipView overrides


- (void) setDocumentView:(NSView*)documentView
{
  [documentView setAutoresizingMask:0];
  [super setDocumentView:documentView];
}


#pragma mark NSView overrides


- (id) initWithFrame:(NSRect)frameRect
{
  return [self initWithFrame:frameRect flipped:NO];
}


- (void) setFrameSize:(NSSize)newSize
{
  if ( self.constrainsDocumentSize )
  {
    NSSize newDocumentSize = newSize;
    newDocumentSize.width = ( newSize.width < self.minDocumentViewWidth ) ? self.minDocumentViewWidth : newSize.width;
    newDocumentSize.height = ( newSize.height < (self.minDocumentViewHeight + self.verticalClipOffset) ) ? self.minDocumentViewHeight : (newSize.height - self.verticalClipOffset);
    [[self documentView] setFrame:NSMakeRect(0,0,round(newDocumentSize.width),round(newDocumentSize.height))];
  }
  [super setFrameSize:newSize];
}


- (BOOL) isFlipped
{
  return mFlippedClipView;
}


#pragma mark NSResponder overrides


- (void) encodeRestorableStateWithCoder:(NSCoder*)coder
{
  [super encodeRestorableStateWithCoder:coder];
  [[self documentView] encodeRestorableStateWithCoder:coder];
}


- (void) restoreStateWithCoder:(NSCoder*)coder
{
  [super restoreStateWithCoder:coder];
  [[self documentView] restoreStateWithCoder:coder];
}


@end
