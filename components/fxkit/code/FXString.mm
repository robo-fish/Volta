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

#import "FXString.h"
#import "FXDebug.h"
#import <iostream>

FXString::FXString()
{
  mString = CFStringCreateMutable(NULL, 0);
  mMutex = new pthread_mutex_t;
  pthread_mutex_init(mMutex, NULL);
}


FXString::FXString(const char* cString) : FXString()
{
  if ( cString != NULL )
  {
    CFStringAppendCString(mString, cString, kCFStringEncodingUTF8);
  }
}


FXString::FXString(const std::string& stdString) : FXString()
{
  CFStringAppendCString(mString, stdString.c_str(), kCFStringEncodingUTF8);
}


FXString::FXString(CFStringRef cfString) : FXString()
{
  if ( cfString != NULL )
  {
    CFStringReplaceAll(mString, cfString);
  }
}


FXString::FXString(const FXString& rhs) : FXString()
{
  if ( rhs.mString != NULL )
  {
    CFStringReplaceAll(mString, rhs.mString);
  }
}


FXString::FXString(FXString &&rhs) noexcept
  : mString(rhs.mString), mMutex(rhs.mMutex)
{
  rhs.mString = NULL;
  rhs.mMutex = NULL;
}


FXString::FXString(UniChar c) : FXString()
{
  CFStringAppendCharacters(mString, &c, 1);
}


FXString::FXString(CFNumberRef number) : FXString()
{
  CFLocaleRef locale = CFLocaleCopyCurrent();
  CFNumberFormatterRef numberFormatter = CFNumberFormatterCreate(kCFAllocatorDefault, locale, kCFNumberFormatterDecimalStyle);
  CFStringRef numberString = CFNumberFormatterCreateStringWithNumber(kCFAllocatorDefault, numberFormatter, number);
  CFRelease(numberFormatter);
  CFRelease(locale);
  if ( numberString != NULL )
  {
    CFStringAppend(mString, numberString);
    CFRelease(numberString);
  }
}


FXString::~FXString()
{
#if VOLTA_DEBUG
  if ( mString != NULL )
  {
    CFIndex const retainCount = CFGetRetainCount(mString);
    if ( retainCount != 1 )
    {
      std::cerr << "FXString internal retain count on destruction: " << retainCount << std::endl;
      FXDebug::printStackTrace();
      assert( !"Something is fishy here." );
    }
  }
#endif
  if ( mString != NULL )
  {
    CFRelease(mString);
  }
  if ( mMutex != NULL )
  {
    pthread_mutex_destroy(mMutex);
    delete mMutex;
  }
}


FXString FXString::localize(NSString* stringsTable) const
{
  NSString* localizedString = [[NSBundle mainBundle] localizedStringForKey:(__bridge NSString*)mString value:@"!translate!" table:stringsTable];
  FXString result((__bridge CFStringRef)localizedString);
  return result;
}


FXString FXString::localize(NSBundle* bundle, NSString* stringsTable) const
{
  if ( bundle == nil )
  {
    bundle = [NSBundle mainBundle];
  }
  NSString* localizedString = [bundle localizedStringForKey:(__bridge NSString*)mString value:@"!translate!" table:stringsTable];
  FXString result((__bridge CFStringRef)localizedString);
  return result;
}


FXString FXString::localize(NSBundle* bundle, NSString* stringsTable, va_list arguments) const
{
  if ( bundle == nil )
  {
    bundle = [NSBundle mainBundle];
  }
  NSString* localizedString = [bundle localizedStringForKey:(__bridge NSString*)mString value:@"!translate!" table:stringsTable];
  NSString* formattedString = [[NSString alloc] initWithFormat:localizedString arguments:arguments];
  FXString result((__bridge CFStringRef)formattedString);
  FXRelease(formattedString)
  return result;
}


long FXString::extractLong() const throw (std::runtime_error)
{
  char buffer[128];
  assert( mString != NULL );
  NSScanner* scanner = [NSScanner localizedScannerWithString:(__bridge NSString*)mString];
  NSInteger intValue;
  if ( [scanner scanInteger:&intValue] )
  {
    return intValue;
  }
  throw std::runtime_error("string to long conversion error");

  char* p = NULL;
  long result = strtol(buffer, &p, 10);
  if ( (*p) != '\0' )
  {
    throw std::runtime_error("string to long conversion error");
  }
  return result;
}


float FXString::extractFloat() const throw (std::runtime_error)
{
  char buffer[128];
  assert( mString != NULL );
  CFStringGetCString(mString, buffer, 127, kCFStringEncodingUTF8);

  char* p = NULL;
  float result = strtof(buffer, &p);
  if ( (*p) != '\0' )
  {
    throw std::runtime_error("string to float conversion error");
  }
  return result;
}


double FXString::extractDouble() const throw (std::runtime_error)
{
  char buffer[128];
  assert( mString != NULL );
  CFStringGetCString(mString, buffer, 127, kCFStringEncodingUTF8);

  char* p = NULL;
  double result = strtod(buffer, &p);
  if ( (*p) != '\0' )
  {
    throw std::runtime_error("string to double conversion error");
  }
  return result;
}


bool FXString::extractBoolean() const throw (std::runtime_error)
{
  if ( CFStringCompare(mString, CFSTR("true"), 0) == kCFCompareEqualTo )
  {
    return true;
  }
  if ( CFStringCompare(mString, CFSTR("false"), 0) == kCFCompareEqualTo )
  {
    return false;
  }
  else
  {
    throw std::runtime_error("string to boolean conversion error");
  }
}


FXStringVector FXString::tokenize(const FXString& separator_, bool includeSeparators) const
{
  FXStringVector result;
  pthread_mutex_lock(mMutex);
  CFIndex const stringLength = CFStringGetLength(mString);
  CFStringRef const separator = separator_.mString;
  CFIndex numOccurrences = 0;
  CFArrayRef separatorOccurrences = NULL;
  if ( (separator != NULL) && (CFStringGetLength(separator) > 0) )
  {
    CFIndex const sepLength = CFStringGetLength(separator);
    if ( (sepLength <= 0) || (stringLength <= 0) )
    {
      throw std::runtime_error("invalid arguments to tokenize function");
    }
    separatorOccurrences = CFStringCreateArrayWithFindResults(NULL, mString, separator, CFRangeMake(0,stringLength), 0);
    if ( separatorOccurrences != NULL )
    {
      numOccurrences = CFArrayGetCount(separatorOccurrences);
    }
  }
  if ( numOccurrences > 0 )
  {
    CFIndex lastTokenStartIndex = 0;
    for ( CFIndex i = 0; i < numOccurrences; i++ )
    {
      CFRange* rangePtr = (CFRange*) CFArrayGetValueAtIndex(separatorOccurrences, i);
      if ( lastTokenStartIndex < rangePtr->location )
      {
        CFStringRef subString = CFStringCreateWithSubstring(NULL, mString, CFRangeMake(lastTokenStartIndex, rangePtr->location - lastTokenStartIndex));
        result.push_back( subString );
        CFRelease( subString );
      }
      lastTokenStartIndex = rangePtr->location + rangePtr->length;
    }
    // Handling the last token.
    if ( lastTokenStartIndex < stringLength )
    {
      CFStringRef subString = CFStringCreateWithSubstring(NULL, mString, CFRangeMake(lastTokenStartIndex, stringLength - lastTokenStartIndex));
      result.push_back( subString );
      CFRelease( subString );      
    }
  }
  else
  {
    result.push_back(mString);
  }
  if ( separatorOccurrences != NULL )
  {
    CFRelease(separatorOccurrences);
  }
  pthread_mutex_unlock(mMutex);
  return result;
}


FXStringVector FXString::getLines(bool ignoreEmptyLines) const
{
  FXStringVector result;
  pthread_mutex_lock(mMutex);
  CFCharacterSetRef newLineCharacterSet = CFCharacterSetCreateWithCharactersInString(NULL, CFSTR("\n\r\f"));
  CFIndex const stringLength = CFStringGetLength(mString);
  CFIndex currentPos = 0;
  CFRange newLineCharacterRange;
  while ( CFStringFindCharacterFromSet(mString, newLineCharacterSet, CFRangeMake(currentPos,stringLength-currentPos), 0, &newLineCharacterRange) )
  {
    if ( currentPos < newLineCharacterRange.location )
    {
      CFStringRef line = CFStringCreateWithSubstring(NULL, mString, CFRangeMake(currentPos, newLineCharacterRange.location - currentPos));
      result.push_back(line);
      CFRelease(line);
    }
    else if ( !ignoreEmptyLines )
    {
      result.push_back("");
    }
    currentPos = newLineCharacterRange.location + newLineCharacterRange.length;
  }
  // Handling last line
  if ( currentPos < stringLength )
  {
    CFStringRef line = CFStringCreateWithSubstring(NULL, mString, CFRangeMake(currentPos, stringLength - currentPos));
    result.push_back(line);
    CFRelease(line);
  }
  CFRelease( newLineCharacterSet );
  pthread_mutex_unlock(mMutex);
  return result;
}


int FXString::find( FXString const & s, unsigned int startIndex ) const
{
  CFRange range;
  if ( CFStringFindWithOptions(mString, s.cfString(), CFRangeMake(startIndex, length() - startIndex), 0, &range) )
  {
    if ( range.location != kCFNotFound )
    {
      return static_cast<int>(range.location);
    }
  }
  return -1;
}


FXString FXString::upperCase() const
{
  CFMutableStringRef mutableString = CFStringCreateMutableCopy(NULL, 0, mString);
  CFLocaleRef locale = CFLocaleCopyCurrent();
  CFStringUppercase(mutableString, locale);
  FXString result(mutableString);
  CFRelease(locale);
  CFRelease(mutableString);
  return result;
}


FXString FXString::lowerCase() const
{
  CFMutableStringRef mutableString = CFStringCreateMutableCopy(NULL, 0, mString);
  CFLocaleRef locale = CFLocaleCopyCurrent();
  CFStringLowercase(mutableString, locale);
  FXString result(mutableString);
  CFRelease(locale);
  CFRelease(mutableString);
  return result;
}


FXString& FXString::trim( FXString const & toBeRemoved )
{
  CFStringTrim( mString, toBeRemoved.mString );
	return *this;
}


FXString& FXString::trimWhitespace()
{
  assert( mString != NULL );
  CFStringTrimWhitespace(mString);
	return *this;
}


bool FXString::startsWith( FXString const & prefix ) const
{
  bool result = false;
  pthread_mutex_lock(mMutex);
  if ( (prefix.mString != NULL) && (CFStringGetLength(prefix.mString) > 0) )
  {
    result = CFStringHasPrefix(mString, prefix.mString);
  }
  pthread_mutex_unlock(mMutex);
  return result;
}


bool FXString::endsWith( FXString const & suffix ) const
{
  bool result = false;
  pthread_mutex_lock(mMutex);
  if ( (suffix.mString != NULL) && (CFStringGetLength(suffix.mString) > 0) )
  {
    result = CFStringHasSuffix(mString, suffix.mString);
  }
  pthread_mutex_unlock(mMutex);
  return result;
}


FXString FXString::extension() const
{
  FXString result;
  CFIndex pos = CFStringFind(mString, CFSTR("."), kCFCompareBackwards).location;
  if ( (pos != kCFNotFound) && (pos < (length() - 1)) )
  {
    CFStringRef extensionString = CFStringCreateWithSubstring(NULL, mString, CFRangeMake(pos+1, CFStringGetLength(mString) - pos - 1));
    result = FXString(extensionString);
    CFRelease( extensionString );
  }
  return result;
}


size_t FXString::length() const
{
  return CFStringGetLength(mString);
}


bool FXString::empty() const
{
	return length() == 0;
}


UniChar FXString::at(size_t index) const
{
  if ( index < CFStringGetLength(mString) )
  {
    return CFStringGetCharacterAtIndex(mString, index);
  }
  return 0;
}


FXString& FXString::crop( size_t startIndex, size_t cropLength )
{
  pthread_mutex_lock(mMutex);
  if ( startIndex > length() )
  {
    CFStringReplaceAll(mString, CFSTR(""));
  }
  else
  {
    CFStringReplace(mString, CFRangeMake(0, startIndex), CFSTR(""));
    if ( cropLength < CFStringGetLength(mString) )
    {
      CFStringReplace(mString, CFRangeMake(cropLength, CFStringGetLength(mString) - cropLength), CFSTR(""));
    }
  }
  pthread_mutex_unlock(mMutex);
  return *this;
}


FXString FXString::substring(size_t startIndex, int substringLength) const throw (std::runtime_error)
{
  if ( substringLength == 0 )
  {
    return FXString("");
  }
  if ( startIndex >= length() )
  {
    throw std::runtime_error("The given start index is out of bounds.");
  }

  pthread_mutex_lock(mMutex);
  CFStringRef substring = NULL;
  CFIndex stringSize = CFStringGetLength(mString);
  if ( substringLength < 0 )
  {
    substring = CFStringCreateWithSubstring( NULL, mString, CFRangeMake(startIndex, stringSize - startIndex) );
  }
  else if ( substringLength > 0 )
  {
    if ( (startIndex+substringLength) >= stringSize )
    {
      substringLength = static_cast<int>(stringSize - startIndex);
    }
    substring = CFStringCreateWithSubstring( NULL, mString, CFRangeMake(startIndex, substringLength) );
  }
  pthread_mutex_unlock(mMutex);
  assert( substring != NULL );
  FXString result( substring );    
  CFRelease( substring );
  return result;
}


void FXString::replaceAll( FXString const & to_be_replaced, FXString const & replacement )
{
  pthread_mutex_lock(mMutex);
  CFIndex const size1 = CFStringGetLength(to_be_replaced.cfString());
  CFIndex pos = CFStringFind(mString, to_be_replaced.cfString(), 0).location;
  while ( pos != kCFNotFound )
  {
    CFStringReplace(mString, CFRangeMake(pos, size1), replacement.cfString());
    pos = CFStringFind(mString, to_be_replaced.cfString(), 0).location;
  }
  pthread_mutex_unlock(mMutex);
}


CFStringRef FXString::cfString() const
{
  return mString;
}


std::unique_ptr<char[]> FXString::cString() const
{
  CFIndex const bufferSize = sizeof(UniChar) * CFStringGetLength(mString);
  char * buffer = new char[bufferSize + 1];
  buffer[bufferSize] = 0;
  if ( CFStringGetCString(mString, buffer, bufferSize, kCFStringEncodingUTF8) )
  {
    return std::unique_ptr<char[]>(buffer);
  }
  else
  {
    std::unique_ptr<char[]> dummy;
    delete [] buffer;
    return dummy;
  }
}


std::string FXString::stdString() const
{
  pthread_mutex_lock(mMutex);
  CFIndex bufferSize = 2 * CFStringGetLength(mString);
  char* buffer = new char[bufferSize + 1];
  buffer[bufferSize] = 0;
  CFStringGetCString(mString, buffer, bufferSize, kCFStringEncodingUTF8);
  pthread_mutex_unlock(mMutex);
  std::string result(buffer);
  delete [] buffer;
  return result;
}


bool FXString::operator< ( FXString const & b ) const
{
  return (CFStringCompare(mString, b.mString, 0) == kCFCompareLessThan);
}


FXString FXString::operator+ ( FXString const & b ) const
{
  CFMutableStringRef copyString = CFStringCreateMutableCopy(NULL, 0, mString);
  CFStringAppend( copyString, b.mString );
  FXString result( copyString );
  CFRelease( copyString );
  return result;
}


FXString FXString::operator+ ( const char * b ) const
{
  CFMutableStringRef copyString = CFStringCreateMutableCopy(NULL, 0, mString);
  CFStringAppendCString( copyString, b, kCFStringEncodingUTF8 );
  FXString result( copyString );
  CFRelease( copyString );
  return result;
}


FXString& FXString::operator= (const FXString& rhs)
{
  if ( mString == NULL )
  {
    mString = CFStringCreateMutableCopy(NULL, 0, rhs.mString);
  }
  else
  {
    CFStringReplaceAll(mString, rhs.cfString());
  }
  return *this;
}


FXString& FXString::operator= (FXString&& rhs)
{
  if ( mString != NULL )
  {
    CFRelease(mString);
  }
  mString = rhs.mString;
  rhs.mString = NULL;

  if ( mMutex != NULL )
  {
    pthread_mutex_destroy(mMutex);
    delete mMutex;
  }
  mMutex = rhs.mMutex;
  rhs.mMutex = NULL;

  return *this;
}


FXString& FXString::operator= (const char* rhs)
{
  if ( mString == NULL )
  {
    mString = CFStringCreateMutable(NULL, 0);
  }
  else
  {
    CFStringReplaceAll(mString, CFSTR(""));
  }
  if ( rhs != NULL )
  {
    CFStringAppendCString(mString, rhs, kCFStringEncodingUTF8);
  }
  return *this;  
}
  

FXString& FXString::operator= (CFStringRef rhs)
{
  if ( mString != rhs )
  {
    if ( mString == NULL )
    {
      mString = CFStringCreateMutable(NULL, 0);
    }
    else
    {
      CFStringReplaceAll(mString, CFSTR(""));
    }
    if ( rhs != NULL )
    {
      CFStringAppend(mString, rhs);
    }
  }
  return *this;
}


bool FXString::operator== ( FXString const & b ) const
{
  if ( (mString == NULL) || (b.mString == NULL) )
    return false;
  return (CFStringCompare(mString, b.mString, 0) == kCFCompareEqualTo);
}


bool FXString::operator!= ( FXString const & b ) const
{
  return (CFStringCompare(mString, b.mString, 0) != kCFCompareEqualTo);
}


FXString operator+ (const char* a, FXString const & b )
{
  return FXString(a) + b;
}


std::ostream& operator<< ( std::ostream & stream, FXString const & str )
{
  if ( !str.empty() ) // This check is important. Otherwise the stream may get confused when confronted with a NULL array.
  {
    std::unique_ptr<char[]> stringChars = str.cString();
    stream << stringChars.get();
  }
  return stream;
}

