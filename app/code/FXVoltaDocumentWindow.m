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

#import "FXVoltaDocumentWindow.h"


@implementation FXVoltaDocumentWindow


#if 0
- (void) close
{
  [super close];
}
#endif


#if 0
- (void) dealloc
{
  FXDeallocSuper
}
#endif


#if 0
- (void) sendEvent:(NSEvent*)event
{
    NSString* eventInformation = nil;
    NSEventType const kEventType = [event type];
    switch ( kEventType )
    {
        case NSLeftMouseDown: eventInformation = @"NSLeftMouseDown"; break;
        case NSLeftMouseUp: eventInformation = @"NSLeftMouseUp"; break;
        case NSRightMouseDown: eventInformation = @"NSRightMouseDown"; break;
        case NSRightMouseUp: eventInformation = @"NSRightMouseUp"; break;
        case NSMouseMoved: eventInformation = @"NSMouseMoved"; break;
        case NSLeftMouseDragged: eventInformation = @"NSLeftMouseDragged"; break;
        case NSRightMouseDragged: eventInformation = @"NSRightMouseDragged"; break;
        case NSMouseEntered: eventInformation = @"NSMouseEntered"; break;
        case NSMouseExited: eventInformation = @"NSMouseExited"; break;
        case NSKeyDown: eventInformation = @"NSKeyDown"; break;
        case NSKeyUp: eventInformation = @"NSKeyUp"; break;
        case NSFlagsChanged: eventInformation = @"NSFlagsChanged"; break;
        case NSAppKitDefined: eventInformation = @"NSAppKitDefined"; break;
        case NSSystemDefined: eventInformation = @"NSSystemDefined"; break;
        case NSApplicationDefined: eventInformation = @"NSApplicationDefined"; break;
        case NSPeriodic: eventInformation = @"NSPeriodic"; break;
        case NSCursorUpdate: eventInformation = @"NSCursorUpdate"; break;
        case NSScrollWheel: eventInformation = @"NSScrollWheel"; break;
        case NSTabletPoint: eventInformation = @"NSTabletPoint"; break;
        case NSTabletProximity: eventInformation = @"NSTabletProximity"; break;
        case NSOtherMouseDown: eventInformation = @"NSOtherMouseDown"; break;
        case NSOtherMouseUp: eventInformation = @"NSOtherMouseUp"; break;
        case NSOtherMouseDragged: eventInformation = @"NSOtherMouseDragged"; break;
        case NSEventTypeGesture: eventInformation = @"NSEventTypeGesture"; break;
        case NSEventTypeMagnify: eventInformation = @"NSEventTypeMagnify"; break;
        case NSEventTypeSwipe: eventInformation = @"NSEventTypeSwipe"; break;
        case NSEventTypeRotate: eventInformation = @"NSEventTypeRotate"; break;
        case NSEventTypeBeginGesture: eventInformation = @"NSEventTypeBeginGesture"; break;
        case NSEventTypeEndGesture: eventInformation = @"NSEventTypeEndGesture"; break;
        default: eventInformation = @"Unknown Event Type";
    }
    if ( kEventType == NSKeyDown )
    {
        eventInformation = [eventInformation stringByAppendingFormat:@" %@", [event characters]];
    }
    NSLog(@"Document window event: %@", eventInformation);
    [super sendEvent:event];
}
#endif


#if 0
- (void) setFrame:(NSRect)frame display:(BOOL)flag
{
  [super setFrame:frame display:flag];
}
#endif


@end
