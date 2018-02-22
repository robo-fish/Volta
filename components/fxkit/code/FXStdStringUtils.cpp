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

#include "FXStdStringUtils.h"
#include <algorithm>
#include <stdexcept>

std::string FXStdStringUtils::upperCase(std::string const & input)
{
	string the_copy = input;
	std::transform(input.begin(), input.end(), the_copy.begin(), toupper);
	return the_copy;
}


std::string FXStdStringUtils::lowerCase(std::string const & input)
{
	string the_copy = input;
	std::transform(input.begin(), input.end(), the_copy.begin(), tolower);
	return the_copy;
}


vector<string> FXStdStringUtils::tokenize( string const & input, string const & separator, bool includeSeparators )
{
  vector<string> result;
  if (separator.size() == 0 || input.size() == 0)
  {
    throw std::runtime_error("invalid arguments to tokenize function");
  }
  size_t const sepSize = separator.size();
  size_t pos1, pos2;
  pos1 = input.find(separator);
  if (pos1 != std::string::npos)
  {
    if (pos1 > 0)
    {
      result.push_back(input.substr(0, pos1));
    }
    if (includeSeparators)
    {
      result.push_back(separator);
    }
    pos2 = input.find(separator, pos1 + sepSize);
    while (pos2 != std::string::npos)
    {
      if (pos2 > (pos1 + sepSize))
      {
        result.push_back(input.substr(pos1 + sepSize, pos2 - pos1 - sepSize));
      }
      if (includeSeparators)
      {
        result.push_back(separator);
      }
      pos1 = pos2;
      pos2 = input.find(separator, pos2 + sepSize);
    }
    if ( (pos1 + sepSize) < input.size() )
    {
      result.push_back(input.substr(pos1 + sepSize, input.size() - pos1 - sepSize));
    }
    else if (includeSeparators)
    {
      result.push_back(separator);
    }
  }
  else
  {
    result.push_back(input);
  }
  return result;
}


vector<string> FXStdStringUtils::getLines( std::string const & input, bool ignoreEmptyLines )
{
  static const char skLineBreaks[] = {
    '\n', // new line
    '\r', // carriage return
    '\f'  // form feed
  };
  static const size_t skNumLineBreaks = sizeof(skLineBreaks)/sizeof(char);
  
  vector<string> result;
  if ( !input.empty() )
  {
    std::string::size_type currentLocation = 0;
    while ( currentLocation < input.size() )
    {
      std::string::size_type nextLineBreak = std::string::npos;
      std::string::size_type tmp = std::string::npos;
      for ( size_t i = 0; i < skNumLineBreaks; i++ )
      {
        tmp = input.find(skLineBreaks[i], currentLocation);
        if ( tmp != std::string::npos )
        {
          nextLineBreak = (nextLineBreak == std::string::npos) ? tmp : std::min(tmp, nextLineBreak);
        }
      }
      if ( nextLineBreak == std::string::npos )
      {
        break;
      }
      else
      {
        if (nextLineBreak <= currentLocation + 1)
        {
          if ( !ignoreEmptyLines )
          {
            result.push_back("");
          }
        }
        else
        {
          result.push_back(input.substr(currentLocation, nextLineBreak - currentLocation));
        }
        currentLocation = nextLineBreak + 1;
      }
    }
    if ( currentLocation < (input.size() - 1) )
    {
      result.push_back(input.substr(currentLocation));
    }
  }
  return result;
}


string FXStdStringUtils::trimWhitespace( string const & input )
{
  string result = input;
  if ( !result.empty() )
  {
    while ( (result.at(0) == ' ') || (result.at(0) == '\t') )
    {
      result = result.substr(1);
    }
    while ( (result.at(result.size() - 1) == ' ') || (result.at(result.size() - 1) == '\t') )
    {
      result = result.substr(0, result.size() - 1);
    }
  }
  return result;
}


void FXStdStringUtils::trim( string & input, char const charToRemove )
{
	if ( !input.empty() )
	{
		while ( input.at(0) == charToRemove )
		{
			input = input.substr(1);
		}
		while ( input.at(input.size() - 1) == charToRemove )
		{
			input = input.substr(0, input.size() - 1);
		}
	}
}


string FXStdStringUtils::extension( string const & input )
{
  size_t extensionSeparator = input.find_last_of(".");
  if ( (extensionSeparator == std::string::npos) || (extensionSeparator == ( input.size() - 1 ) ) )
  {
    return "";
  }
  return input.substr(extensionSeparator + 1);
}


string FXStdStringUtils::crop( string const & input, size_t startIndex, size_t cropLength )
{
  string result = input;
	if ( startIndex >= result.size() )
	{
		return "";
	}
	else
	{
		if ( (startIndex + cropLength) >= result.size() )
		{
			result = result.substr( startIndex );
		}
		else
		{
			result = result.substr( startIndex, cropLength );
		}
	}
  return result;
}


void FXStdStringUtils::replaceAll( string & input, string const & to_be_replaced, string const & replacement )
{
	const size_t size1 = to_be_replaced.size();
	const size_t size2 = replacement.size();
	size_t pos = input.find( to_be_replaced );
	while ( pos != std::string::npos )
	{
		input.replace( pos, size1, replacement, 0, size2 );
		pos = input.find( to_be_replaced, pos + size2 );
	}
}

