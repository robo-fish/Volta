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

#import "FXDocumentUpgradeDialogAccessoryView.h"
#import "FXSystemUtils.h"
#import <FXKit/FXKit-Swift.h>


@implementation FXDocumentUpgradeDialogAccessoryView


- (id) init
{
  self = [super initWithFrame:NSMakeRect(0, 0, 300, 30)];
  if ( self != nil )
  {
    NSButton* finderButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 30)];
    finderButton.buttonType = NSMomentaryLightButton;
    finderButton.bezelStyle = NSRoundedBezelStyle;
    finderButton.title = FXLocalizedString(@"ArchiveUpgradePrompt_Reveal");
    finderButton.target = self;
    finderButton.action = @selector(showLocationInFinder:);
    [self addSubview:finderButton];
    FXRelease(finderButton)
    
    [FXViewUtils layoutIn:self
            visualFormats:@[@"H:|-0-[button(>=50)]-|", @"V:|-[button(24)]-(>=0)-|"]
              metricsInfo:nil
                viewsInfo:@{ @"button" : finderButton }];
  }
  return self;
}


- (void) showLocationInFinder:(id)sender
{
  if ( self.filePath != nil )
  {
    [FXSystemUtils revealFileAtLocation:self.filePath];
  }
}


@end
