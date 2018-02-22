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

#import <SenTestingKit/SenTestingKit.h>
#import "FXPlotterUtils.h"


@interface test_plotter_utils : SenTestCase
@end


@implementation test_plotter_utils


- (void) test_stringForNumberByReducingSignificand
{
  FXUTAssert([[FXPlotterUtils stringForNumber:FXPlotterNumber(2,45) byReducingSignificand:YES] isEqualToString:@"4.5*10^3"]);
  FXUTAssert([[FXPlotterUtils stringForNumber:FXPlotterNumber(4,3385) byReducingSignificand:YES] isEqualToString:@"3.385*10^7"]);
  FXUTAssert([[FXPlotterUtils stringForNumber:FXPlotterNumber(-1,45) byReducingSignificand:YES] isEqualToString:@"4.5"]);
}


- (void) test_processSuperscriptsInLabelString
{
  BOOL const US = [[[NSLocale currentLocale] localeIdentifier] isEqualToString:@"en_US"];
  FXUTAssert([[FXPlotterUtils processSuperscriptsInLabelString:@"10^-2"] isEqualToString:@"10⁻²"]);
  FXUTAssert([[FXPlotterUtils processSuperscriptsInLabelString:@"4.5*10^-3"] isEqualToString:(US ? @"4.5×10⁻³" : @"4.5·10⁻³")]);
  FXUTAssert([[FXPlotterUtils processSuperscriptsInLabelString:@"-2*10^5"] isEqualToString:(US ? @"-2×10⁵" : @"-2·10⁵")]);
  FXUTAssert([[FXPlotterUtils processSuperscriptsInLabelString:@"11*10^12"] isEqualToString:(US ? @"11×10¹²" : @"11·10¹²")]);
  FXUTAssert([[FXPlotterUtils processSuperscriptsInLabelString:@"3.9*10^-15"] isEqualToString:(US ? @"3.9×10⁻¹⁵" : @"3.9·10⁻¹⁵")]);
}


@end
