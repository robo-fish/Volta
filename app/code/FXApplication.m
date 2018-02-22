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

#import "FXApplication.h"


@implementation FXApplication

#pragma mark Private methods

static void crashFXApplication()
{
  *((char*)0x08) = 1;
}

#pragma mark NSApplication overrides

//- (void) reportException:(NSException*)exception
//{
//  @try
//  {
//    @autoreleasepool
//    {
//      NSString *exceptionMessage = [NSString stringWithFormat:@"%@\n%@\n%@", [exception name], [exception reason], [exception userInfo]];
//      NSLog(@"Exception raised:\n%@", exceptionMessage);
//
//      NSAlert* alert = [[NSAlert alloc] init];
//      alert.messageText = FXLocalizedString(@"Exception");
//      alert.informativeText = FXLocalizedString(@"ExceptionOccurred");
//      [alert addButtonWithTitle:FXLocalizedString(@"ExceptionIgnore")];
//      [alert addButtonWithTitle:FXLocalizedString(@"ExceptionLetCrash")];
//      if ([alert runModal] == NSAlertSecondButtonReturn)
//      {
//        crashFXApplication();
//      }
//    }
//  }
//  @catch (NSException* e)
//  {
//    /* ignore */
//  }
//}


- (void) showHelp:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:FXLocalizedString(@"VoltaHelpURL")]];
}


#if 0 && VOLTA_SUPPORTS_RESUME
- (BOOL) restoreWindowWithIdentifier:(NSString*)identifier
                               state:(NSCoder *)state
                   completionHandler:(void (^)(NSWindow *, NSError *))handler
{
  return [super restoreWindowWithIdentifier:identifier state:state completionHandler:handler];
}
#endif


@end
