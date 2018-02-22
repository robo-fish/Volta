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

#include <vector>
#include <string>

using namespace std;

class FXStdStringUtils
{
public:
  static string upperCase(string const & input);

  static string lowerCase(string const & input);

  static vector<string> tokenize( string const & input, string const & separator, bool includeSeparators );

  static vector<string> getLines( string const & input, bool ignoreEmptyLines );

  static string trimWhitespace( string const & input );

  static string extension( string const & input );

  static string crop( string const & input, size_t startIndex, size_t cropLength );

  static void trim( string & input, char const toBeRemoved );

  static void replaceAll( string & input, string const & to_be_replaced, string const & replacement );
};

