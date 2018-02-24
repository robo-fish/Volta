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

#include <string>
#include <vector>
#include <stdexcept>
#include <memory>
#import <pthread.h>

class FXString;
typedef std::vector<FXString> FXStringVector;


//! used for special string operations
class FX_VISIBLE FXString
{
public:
  FXString();
  FXString(const char* cString);
  FXString(const std::string& stdString);
  FXString(CFStringRef cfString);
  FXString(const FXString& rhs);
  FXString(FXString &&rhs) noexcept;
  FXString(UniChar c);
  FXString(CFNumberRef number);

  ~FXString();

  /// @param stringsTable the name of the localization strings table.
  /// The strings table will be searched in the app main bundle.
  FXString localize(NSString* stringsTable) const;

  /// @param bundle the bundle which contains the localization strings table.
  /// @param stringsTable the name of the localization strings table.
  /// The main bundle of the app will be used if the given bundle is nil.
  FXString localize(NSBundle* bundle, NSString* stringsTable) const;

  /// @param bundle the bundle which contains the localization strings table.
  /// @param stringsTable the name of the localization strings table.
  /// @param arguments values that will be treated as arguments to format specifiers within the string, as in printf()
  FXString localize(NSBundle* bundle, NSString* stringsTable, va_list arguments) const;

  /// @return same string converted to upper case 
  FXString upperCase() const;

  /// @return same string converted to lower case
  FXString lowerCase() const;

  /// @short Remove heading and trailing substrings equal to the given string.
  FXString& trim( FXString const & toBeRemoved = " " );

  /// @short Remove heading and trailing space and tab characters.
  FXString& trimWhitespace();

  /// @return \c true if this string starts with the given string, \c false otherwise
  bool startsWith( FXString const & ) const;

  /// @return \c true if this string ends with the given string, \c false otherwise
  bool endsWith( FXString const & ) const;

  /// @return the number of characters (code points) in the string
  size_t length() const;

  /// @return whether there are no characters in the string
  bool empty() const;

  /// @return the character at the given index
  UniChar at(size_t index) const;

  /// Reduces this string to its substring at given start index and of given length.
  FXString& crop( size_t startIndex, size_t length );

  /// @return A Substring extending from the given start index by the given length.
  /// @param[in] length the length of the substring. If less than zero, all of the remaining string is taken
  /// @param[in] startIndex at which index the substring shall start
  /// @throw runtime error if the given startIndex is out of bounds.
  FXString substring(size_t startIndex, int length = -1 ) const throw (std::runtime_error);

  /// @short replaces all occurrences of a given substring with another given string
  /// @param[in] to_be_replaced the substring whose occurrences will be replaced
  /// @param[in] replacement the string to be used as replacement
  void replaceAll( FXString const & to_be_replaced, FXString const & replacement );

  /// Extracts file extension (without the dot)
  /// @return the remaining characters after the last dot (".") character
  /// @exception std::runtime_error if a dot does not exist or no characters come after the last dot
  FXString extension() const;

  /// @param[in] separator the string which acts as a separating block between tokens
  /// @param[in] includeSeparators whether the separator itself should be put in the token list
  /// @return An array of strings, which are tokens and, optionally, the separators between.
  /// Multiple consecutive separators will not be compacted to a single separator item. 
  FXStringVector tokenize( FXString const & separator = " ", bool includeSeparators = false ) const;

  /// @return the lines of text in the string. These are either separated by \n (new line), \r (carriage return), or \f (form feed).
  /// @param ignoreEmptyLines whether to omit line breaks.
  FXStringVector getLines(bool ignoreEmptyLines = false) const;

  /// Finds the first occurrence of the given substring starting from the given index.
  /// @param startIndex the index at which to begin the search.
  /// @return the index of the character where the given substring starts, or -1 if not found.
  int find( FXString const & s, unsigned int startIndex = 0 ) const;

  bool   extractBoolean() const throw (std::runtime_error);
  float  extractFloat()   const throw (std::runtime_error);
  double extractDouble()  const throw (std::runtime_error);
  long   extractLong()    const throw (std::runtime_error);

  CFStringRef cfString() const;

  std::string stdString() const;

  std::unique_ptr<char[]> cString() const;

  bool operator< ( FXString const & b ) const;

  FXString operator+ ( FXString const & b ) const;

  FXString operator+ ( const char * b ) const;

  FXString& operator= (FXString const & rhs);

  FXString& operator= (FXString&& rhs);

  FXString& operator= (const char* rhs);

  FXString& operator= (CFStringRef rhs);

  bool operator== ( FXString const & b ) const;

  bool operator!= ( FXString const & b ) const;

protected:
  CFMutableStringRef mString;
  pthread_mutex_t* mMutex; // protects access to mString
};

FXString operator+ (const char*, FXString const & );

std::ostream& operator<< ( std::ostream &, FXString const & );

