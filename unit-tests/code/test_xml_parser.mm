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
#import "FXXMLDocument.h"

#define TEST_WITH_UNICODE (1)


@interface test_xml_parser : XCTestCase
@end


@implementation test_xml_parser


static NSString* libraryString = 
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"    
    "<volta version=\"2\" xmlns=\"http://kulfx.com/volta\">"
      "<library title=\"test\">"
        "<model name=\"TheModel\" type=\"R\" >"
          "<shape width=\"42\" height=\"12\">"
              "<path d=\"M -21 0 h 8 m 26 0 h 8\"/>"
              "<path d=\"M -13 -6 h 26 v 12 h -26 v -12 z\"/>"
          "</shape>"
          "<pin name=\"A\" x=\"-21\" y=\"-5\"/>"
          "<pin name=\"B\" x=\"21\" y=\"0\"/>"
          "<p n=\"resistance\" v=\"1\" />"
        "</model>"
      "</library>"
    "</volta>";


#if TEST_WITH_UNICODE
static NSString* libraryStringWithUnicode = 
  @"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"    
    "<volta version=\"2\" xmlns=\"http://kulfx.com/volta\">"
      "<library title=\"test\">"
        "<model name=\"künçe\" type=\"R\" >"
          "<shape width=\"42\" height=\"12\">"
              "<path d=\"M -21 0 h 8 m 26 0 h 8\"/>"
              "<path d=\"M -13 -6 h 26 v 12 h -26 v -12 z\"/>"
          "</shape>"
          "<pin name=\"A\" x=\"-21\" y=\"-5\"/>"
          "<pin name=\"B\" x=\"21\" y=\"0\"/>"
          "<p n=\"resistance\" v=\"1\" />"
        "</model>"
      "</library>"
    "</volta>";
#endif


- (void) testVoltaValidation
{
  NSString* schemaFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"volta-v2" ofType:@"rng"];
  FXUTAssert( schemaFilePath != nil );
  if ( schemaFilePath != nil )
  {
    NSError* fileReadError = nil;
    NSString* schemaFileContents = [[NSString alloc] initWithContentsOfFile:schemaFilePath encoding:NSUTF8StringEncoding error:&fileReadError];
    FXUTAssert( schemaFileContents != nil );
    if ( schemaFileContents != nil )
    {
      FXUTAssert( FXXMLDocument::validate( FXString((__bridge CFStringRef) libraryString), FXString((__bridge CFStringRef) schemaFileContents) ) );
    }
  }
}


- (void) testVoltaParsing
{
  FXXMLDocumentPtr doc;

  try
  {
    doc = FXXMLDocument::fromString( FXString((__bridge CFStringRef)libraryString) );
    FXUTAssert( doc.get() != nullptr );
  }
  catch ( std::runtime_error & e )
  {
    std::cout << e.what() << std::endl;
    FXUTAssert( NO );
  }

#if TEST_WITH_UNICODE
  try
  {
    doc = FXXMLDocument::fromString( FXString((__bridge CFStringRef)libraryStringWithUnicode) );
    FXUTAssert( doc.get() != nullptr );
  }
  catch ( std::runtime_error & e )
  {
    std::cout << e.what() << std::endl;
    FXUTAssert( NO );
  }
#endif
}


@end
