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

@protocol VoltaPrintable <NSObject>

/// @return the view used for printing
- (FXView*) newPrintableView;

/// @return a list of NSString objects which represent print options
- (NSArray*) optionsForPrintableView:(FXView*)view;

/// the index of the current selected option, a negative number if no option is selected
- (NSInteger) selectedOptionForPrintableView:(FXView*)view;

- (void) selectOption:(NSInteger)optionIndex forPrintableView:(FXView*)view;

@end

