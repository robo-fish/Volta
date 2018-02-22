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
#include "FXString.h"
#include <iostream>

@interface test_fxstring : SenTestCase
@end


@implementation test_fxstring

- (void) setUp
{
}

- (void) tearDown
{
}

- (void) test_basics
{
  FXString s;
  FXUTAssert(s.empty());
}

- (void) test_tokenize
{
  FXStringVector slist = FXString("m 11 12 L 21 22").tokenize();
  FXUTAssert( slist.size() == 6 );
  FXUTAssert( slist[0] == "m" );
  FXUTAssert( slist[1] == "11" );
  FXUTAssert( slist[2] == "12" );
  FXUTAssert( slist[3] == "L" );
  FXUTAssert( slist[4] == "21" );
  FXUTAssert( slist[5] == "22" );
  FXStringVector slist2 = FXString("aba\tdoing\tgar").tokenize("\t");
  FXUTAssert( slist2.size() == 3 );
}

- (void) test_upper_lower_case
{
  FXUTAssert( FXString("bNaRguuG").upperCase() == FXString("BNARGUUG") );
  FXUTAssert( FXString("HaRnnMuD").lowerCase() == FXString("harnnmud") );
}

- (void) test_suffix_prefix
{
  FXUTAssert( FXString("GingerBread").startsWith("Ginger") );
  FXUTAssert( FXString("SommerRain").endsWith("Rain") );
}

- (void) test_trim_and_crop
{
  FXUTAssert( FXString("  hello ").trim() == "hello" );
  FXUTAssert( FXString("@brr!").trim("@") == "brr!" );
  FXUTAssert( FXString("@brr!").trim("!") == "@brr" );
  FXUTAssert( FXString("	 tabAndSpace	  ").trimWhitespace() == "tabAndSpace" );
  FXUTAssert( FXString("tatalolotattr").crop(4,4) == "lolo" );
}

- (void) test_value_extraction
{
  FXUTAssert( FXString("1.35").extractFloat() == 1.35f );
  FXUTAssert( FXString("true").extractBoolean() );
  FXUTAssert( !FXString("false").extractBoolean() );
  FXUTAssert( FXString("12").extractLong() == 12 );
  FXUTAssert( FXString("-23.000006").extractDouble() == -23.000006 );
}

- (void) test_search
{
  FXString s("My name is Bond. What's your name?");
  FXUTAssert( s.find("name") == 3 );
  FXUTAssert( s.find("name", 10) == 29 );
  FXUTAssert( s.find("James") < 0 );
}

- (void) test_string_extraction
{
  FXString s("The length() function returns the number of elements in the current string");
  try
  {
    s.substring(s.length() + 5);
    FXUTAssert(NO);
  }
  catch (std::runtime_error& e)
  {
    FXUTAssert(YES);
  }

  FXUTAssert(s.substring(13, 4) == "func");
  FXUTAssert(s.substring(60) == "current string");
  FXUTAssert(s.substring(0,10) == "The length");
}

- (void) test_getlines
{
  const char * cstr ="\nbla bal\rhelp\n\nbingo\r\n\f\rjames\rbond\n\r";
  const char * cstr2 ="\nbla bal\rhelp\n\nbingo\r\n\f\rjames\rbond\n\rhallo";
  FXString str(cstr);
  FXString str2(cstr2);
  FXStringVector list = str.getLines(true);
  FXStringVector list2 = str2.getLines(true);
  FXStringVector listWithEmptyLines = str.getLines(false);
  FXUTAssert(list.size() == 5);
  FXUTAssert(list2.size() == 6);
  FXUTAssert(listWithEmptyLines.size() == 11);
  FXUTAssert(list.at(0) == "bla bal");
  FXUTAssert(list.at(1) == "help");
  FXUTAssert(list.at(2) == "bingo");
  FXUTAssert(list.at(3) == "james");
  FXUTAssert(list.at(4) == "bond");
  FXUTAssert(list2.at(5) == "hallo");
  FXUTAssert(listWithEmptyLines.at(0).empty());
  FXUTAssert(listWithEmptyLines.at(1) == "bla bal");
  FXUTAssert(listWithEmptyLines.at(2) == "help");
  FXUTAssert(listWithEmptyLines.at(3).empty());
  FXUTAssert(listWithEmptyLines.at(4) == "bingo");
  FXUTAssert(listWithEmptyLines.at(5).empty());
  FXUTAssert(listWithEmptyLines.at(6).empty());
  FXUTAssert(listWithEmptyLines.at(7).empty());
  FXUTAssert(listWithEmptyLines.at(8) == "james");
  FXUTAssert(listWithEmptyLines.at(9) == "bond");
  FXUTAssert(listWithEmptyLines.at(10).empty());
}

- (void) test_unicode
{
  FXString s1("künçe");
  std::unique_ptr<char[]> charArray = s1.cString();
  FXUTAssert( strlen(charArray.get()) == 7 );
  FXUTAssert( s1.substring(1,1) == FXString("ü") );
}

- (void) test_unique_ptr_with_arrays
{
  static int const kNumTestClassInstance = 3;
  static int FXStringTestClassACount = 0;
  struct FXStringTestClassA
  {
    FXStringTestClassA()  { FXStringTestClassACount++; }
    ~FXStringTestClassA() { FXStringTestClassACount--; }
  };

  {
    std::unique_ptr<FXStringTestClassA[]> arrayOfInstances( new FXStringTestClassA[kNumTestClassInstance] );
    FXUTAssertEqual( FXStringTestClassACount, kNumTestClassInstance );
  }
  FXUTAssertEqual( FXStringTestClassACount, 0 );
}

@end
