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

#import <XCTest/XCTest.h>
#import "FXVoltaArchiveValidator.h"

@interface test_archive_validator : XCTestCase
@end


@implementation test_archive_validator


FXString archivedLibraryWithOldButSupportedVersionNumber =
  "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta xmlns=\"http://kulfx.com/volta\" version=\"1\">"
    "<library name=\"Test\">"
      "<model type=\"D\" name=\"TestResistor\" labelPosition=\"north\">"
        "<shape width=\"42\" height=\"12\">"
          "<path d=\"M -21 0 h 8 m 26 0 h 8\"/>"
        "</shape>"
        "<pin name=\"A\" x=\"-21\" y=\"0\"/>"
        "<pin name=\"B\" x=\"21\" y=\"0\"/>"
      "</model>"
    "</library>"
  "</volta>";

FXString archivedLibraryWithFutureVersionNumber =
  "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"
  "<volta xmlns=\"http://kulfx.com/volta\" version=\"9999\">"
    "<library name=\"Test\">"
      "<model type=\"D\" name=\"TestResistor\" labelPosition=\"north\">"
        "<shape width=\"42\" height=\"12\">"
          "<path d=\"M -21 0 h 8 m 26 0 h 8\"/>"
        "</shape>"
        "<pin name=\"A\" x=\"-21\" y=\"0\"/>"
        "<pin name=\"B\" x=\"21\" y=\"0\"/>"
      "</model>"
    "</library>"
  "</volta>";


- (void) test_tolerance_against_incorrect_archive_format_version_numbers
{
  NSError* validationError = nil;
  FXXMLDocumentPtr upgradedLibrary = [FXVoltaArchiveValidator parseAndValidate:archivedLibraryWithOldButSupportedVersionNumber upgradedWhileParsing:nil error:&validationError];
  FXUTAssert( upgradedLibrary.get() != nullptr );
  FXUTAssert( validationError == nil );

  FXXMLDocumentPtr futureFormatLibrary = [FXVoltaArchiveValidator parseAndValidate:archivedLibraryWithFutureVersionNumber upgradedWhileParsing:nil error:&validationError];
  FXUTAssert( futureFormatLibrary.get() == nullptr );
  FXUTAssert( validationError != nil );
}

@end
