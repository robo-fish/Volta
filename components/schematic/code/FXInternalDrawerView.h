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

typedef NS_ENUM(short, FXInternalDrawerAttachment)
{
  FXDrawerAttachmentNone       = 0,
  FXDrawerAttachmentTop        = 1,
  FXDrawerAttachmentBottom     = 2,
};


typedef NS_ENUM(short, FXInternalDrawerResizing)
{
  FXDrawerResizingNone         = 0,
  FXDrawerResizingVerticalOnly = 1, // the drawer can only be resized along the direction vertical to its attached side
  FXDrawerResizingAuto         = 2, // the length of the drawer along its attached side is adjusted automatically
};


/// A subview which positions itself adjacent to one of the given sides of its parent view.
/// The view can be dragged vertical to in order to change its size. It remains attached
/// 3) The dragging region, which displays a drag handle and allows the user to drag the palette view vertically.
@interface FX(FXInternalDrawerView) : NSView <NSAnimationDelegate>

@property (readonly) CGFloat minHeight;
@property (readonly) CGFloat maxHeight;
@property (readonly) CGFloat initialHeight;
@property (readonly) CGFloat minWidth;
@property (readonly) CGFloat maxWidth;
@property (readonly) CGFloat initialWidth;
@property            BOOL lockHeight; // locking prevents vertical resizing

- (id) initWithAttachment:(FXInternalDrawerAttachment)attachment
           resizingPolicy:(FXInternalDrawerResizing)resizing;

// @return the view frame that would result from adjusting the view frame to the parent view dimensions.
- (NSRect) adjustedFrame;

/// Makes the receiver slide into the parent view's bounds
- (void) show;

/// Makes the view slide out of the parent view's bounds
- (void) hide;

@end
