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
#pragma once

/// AppKit/UIKit abstraction
/// Note: On 64-Bit architecture NSPoint equals CGPoint, NSRect equals CGRect, NSSize equals CGSize

#define FXGraphicsContext ((CGContextRef)[[NSGraphicsContext currentContext] graphicsPort])
#define FXView            NSView
#define FXEvent           NSEvent

#if __LP64__

#define FXSize            CGSize
#define FXSizeMake        CGSizeMake
#define FXSizeZero        CGSizeZero
#define FXPoint           CGPoint
#define FXPointMake       CGPointMake
#define FXPointZero       CGPointZero
#define FXRect            CGRect
#define FXRectMake        CGRectMake
#define FXRectZero        CGRectZero

#else

#define FXSize            NSSize
#define FXSizeMake        NSMakeSize
#define FXSizeZero        NSZeroSize
#define FXPoint           NSPoint
#define FXPointMake       NSMakePoint
#define FXPointZero       NSZeroPoint
#define FXRect            NSRect
#define FXRectMake        NSMakeRect
#define FXRectZero        NSZeroRect

#endif
