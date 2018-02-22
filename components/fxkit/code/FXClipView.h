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

@interface FXClipView : NSClipView

/// For enabling or disabling constrainment of the document view to a minimum size.
/// You should turn constraining off if you use constraints based AppKit layout.
@property (nonatomic) BOOL constrainsDocumentSize;

@property (nonatomic) CGFloat minDocumentViewHeight;
@property (nonatomic) CGFloat minDocumentViewWidth;

// This offset is needed when the clip view is used inside of an NSScrollView.
// It helps make the vertical scrollbar disappear.
// If no offset is used then the height of the document view becomes stuck
// at a few pixels (determined by NSScrollView and NSClipView) larger than
// the content view, thus the scrollbar does not disappear.
@property (nonatomic) CGFloat verticalClipOffset;

- (id) initWithFrame:(NSRect)frameRect flipped:(BOOL)isFlipped;

@end
