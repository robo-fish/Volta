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

#import "FXPlotterUtils.h"


NSDictionary* sSuperscriptsDictionary = nil;


@implementation FXPlotterUtils


+ (void) initialize
{
  // UTF-8 codes for various superscript characters
  static uint8_t const skUTF_Mult[] = { 0xC2, 0xB7, 0 }; // Multiplication sign. A dot.
  static uint8_t const skUTF_Mult_US[] = { 0xC3, 0x97, 0 }; // Multiplication sign in the U.S. is a cross.
  static uint8_t const skUTF_Minus[] = { 0xE2, 0x81, 0xBB, 0 };
  static uint8_t const skUTF_0[] = { 0xE2, 0x81, 0xB0, 0 };
  static uint8_t const skUTF_1[] = { 0xC2, 0xB9, 0 };
  static uint8_t const skUTF_2[] = { 0xC2, 0xB2, 0 };
  static uint8_t const skUTF_3[] = { 0xC2, 0xB3, 0 };
  static uint8_t const skUTF_4[] = { 0xE2, 0x81, 0xB4, 0 };
  static uint8_t const skUTF_5[] = { 0xE2, 0x81, 0xB5, 0 };
  static uint8_t const skUTF_6[] = { 0xE2, 0x81, 0xB6, 0 };
  static uint8_t const skUTF_7[] = { 0xE2, 0x81, 0xB7, 0 };
  static uint8_t const skUTF_8[] = { 0xE2, 0x81, 0xB8, 0 };
  static uint8_t const skUTF_9[] = { 0xE2, 0x81, 0xB9, 0 };

  sSuperscriptsDictionary = @{
    @"*US" : @((const char *)skUTF_Mult_US),
    @"*"   : @((const char *)skUTF_Mult),
    @"-"   : @((const char *)skUTF_Minus),
    @"0"   : @((const char *)skUTF_0),
    @"1"   : @((const char *)skUTF_1),
    @"2"   : @((const char *)skUTF_2),
    @"3"   : @((const char *)skUTF_3),
    @"4"   : @((const char *)skUTF_4),
    @"5"   : @((const char *)skUTF_5),
    @"6"   : @((const char *)skUTF_6),
    @"7"   : @((const char *)skUTF_7),
    @"8"   : @((const char *)skUTF_8),
    @"9"   : @((const char *)skUTF_9)
  };
  FXRetain(sSuperscriptsDictionary)
}


+ (NSString*) stringForNumber:(FXPlotterNumber const &)number byReducingSignificand:(BOOL)reduce
{
  NSString* significand = nil;
  int exponent = 0;
  if ( reduce && (fabs(number.significand) >= 10) )
  {
    NSString* decimalSeparator = (NSString*)[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
    int powerOfSignificand = 0;
    int multiplierOfMostSignificantDigit = 1;
    int mostSignificantDigit = number.significand;
    while ( fabs(mostSignificantDigit) >= 10 )
    {
      mostSignificantDigit /= 10;
      multiplierOfMostSignificantDigit *= 10;
      powerOfSignificand++;
    };
    int remainingDigits = fabs(number.significand - (mostSignificantDigit * multiplierOfMostSignificantDigit));
    // Note: We can't use [NSNumberFormatter localizedStringFromNumber:numberStyle:] because we could loose some digits after the decimal separator.
    significand = [NSString stringWithFormat:@"%d%@%d", mostSignificantDigit, decimalSeparator, remainingDigits];
    exponent = number.exponent + powerOfSignificand;
  }
  else
  {
    significand = [NSString stringWithFormat:@"%d", number.significand];
    exponent = number.exponent;
  }
  return (exponent == 0) ? significand : [NSString stringWithFormat:@"%@*10^%d", significand, exponent];
}


+ (NSString*) processSuperscriptsInLabelString:(NSString*)labelString
{
  NSUInteger const exponentLocation = [labelString rangeOfString:@"10^"].location;
  if ( exponentLocation != NSNotFound )
  {
    NSMutableString* result = [NSMutableString stringWithFormat:@"%@%@",[labelString substringToIndex:(exponentLocation+2)], [labelString substringFromIndex:(exponentLocation+3)]];
    NSUInteger const multiplicationSignLocation = [labelString rangeOfString:@"*"].location;
    if ( (multiplicationSignLocation != NSNotFound) && (multiplicationSignLocation == (exponentLocation-1)) )
    {
      BOOL const localeIsUS = [[[NSLocale currentLocale] localeIdentifier] isEqualToString:@"en_US"];
      [result replaceCharactersInRange:NSMakeRange(multiplicationSignLocation, 1) withString:sSuperscriptsDictionary[localeIsUS ? @"*US" : @"*"]];
    }
    NSUInteger const labelLength = [result length];
    for ( NSUInteger currentCharLocation = exponentLocation + 2; currentCharLocation < labelLength; currentCharLocation++ )
    {
      NSString* exponentString = [result substringWithRange:NSMakeRange(currentCharLocation, 1)];
      NSString* superscriptCharacter = sSuperscriptsDictionary[exponentString];
      if ( superscriptCharacter != nil )
      {
        NSAssert( [superscriptCharacter length] == 1, @"Unexpected superscript character" );
        [result replaceCharactersInRange:NSMakeRange(currentCharLocation, 1) withString:superscriptCharacter];
      }
    }
    return result;
  }
  return labelString;
}


@end
