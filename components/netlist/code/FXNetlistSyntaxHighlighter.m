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

#import "FXNetlistSyntaxHighlighter.h"

// text attributes
static NSDictionary* sPrintAttributes = nil;
static NSDictionary* sCommentAttributes = nil;
static NSDictionary* sDefaultAttributes = nil;
static NSDictionary* sAnalysisCommandAttributes = nil;
static NSDictionary* sModelAttributes = nil;
static NSDictionary* sSubcircuitAttributes = nil;
static NSDictionary* sSystemMessageAttributes = nil;


@implementation FX(FXNetlistSyntaxHighlighter)
{
@private
  NSFont* mFont;
}

@synthesize font = mFont;


+ (void) initialize
{
  NSColor* analysisCommandColor = [NSColor colorWithDeviceRed:0.4 green:0.0 blue:0.0 alpha:1.0];
  NSColor* darkBlue = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.4 alpha:1.0];
  NSColor* lightGrey = [NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1.0];
  NSColor* darkYellow = [NSColor colorWithDeviceRed:0.5 green:0.4 blue:0.0 alpha:1.0];
  NSColor* orange = [NSColor colorWithDeviceRed:0.81 green:0.45 blue:0.14 alpha:1.0];
  NSColor* subcircuitColor = [NSColor colorWithDeviceRed:0.6 green:0.6 blue:1.0 alpha:1.0];

  sAnalysisCommandAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:analysisCommandColor, NSForegroundColorAttributeName, nil];
  sCommentAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:lightGrey, NSForegroundColorAttributeName, nil];
  sModelAttributes = [[NSDictionary alloc] initWithObjectsAndKeys: darkYellow, NSForegroundColorAttributeName, nil];
  sPrintAttributes = [[NSDictionary alloc] initWithObjectsAndKeys: orange, NSForegroundColorAttributeName, nil];
  sSubcircuitAttributes = [[NSDictionary alloc] initWithObjectsAndKeys: subcircuitColor, NSForegroundColorAttributeName, nil];
  sDefaultAttributes = [[NSDictionary alloc] initWithObjectsAndKeys: darkBlue, NSForegroundColorAttributeName, nil];
  sSystemMessageAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor redColor], NSForegroundColorAttributeName,nil];
}


- (id) init
{
  self = [super init];
  return self;
}


- (void) dealloc
{
  self.font = nil;
  FXDeallocSuper
}


- (NSAttributedString*) highlight:(NSString*)inputString
{
  NSMutableAttributedString* result = [[NSMutableAttributedString alloc] initWithString:inputString];
  FXAutorelease(result)
  if ( self.font != nil )
  {
    [result addAttribute:NSFontAttributeName value:self.font range:NSMakeRange(0, result.length)];
  }
  NSString* line; // a single line
  NSUInteger lineStart = 0;
  NSUInteger nextLineStart;
  NSUInteger lineEnd;
  NSDictionary* previousAttributes = nil;
  NSString* tmp = [inputString uppercaseString]; // upper case copy of input string
  NSRange tmpRange;

  BOOL reachedEndOfNetlist = NO; // whether the .END statement occurred
  BOOL inSubcircuit = NO;

  // Scan all lines
  while (lineStart < [tmp length])
  {
    tmpRange.location = lineStart;
    tmpRange.length = 1;
    [tmp getLineStart:&lineStart end:&nextLineStart contentsEnd:&lineEnd forRange:tmpRange];
    tmpRange.location = lineStart;
    tmpRange.length = lineEnd - lineStart;        
    line = [[tmp substringWithRange:tmpRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( [line hasPrefix:@"*>"] )
    {
      line = [line substringFromIndex:2];
    }
    
    tmpRange.location = lineStart;
    tmpRange.length = lineEnd - lineStart;
    if (lineStart == 0)
    {
      [result addAttributes:sCommentAttributes range:tmpRange];
    }
    else if ( reachedEndOfNetlist )
    {
      [result addAttributes:sSystemMessageAttributes range:tmpRange];
    }
    else if ( inSubcircuit )
    {
      [result addAttributes:sSubcircuitAttributes range:tmpRange];
      inSubcircuit = ![line hasPrefix:@".ENDS"];
    }
    else if (([line hasPrefix:@".TRAN "] || [line isEqualToString:@".TRAN"]) ||
             ([line hasPrefix:@".OP "] || [line isEqualToString:@".OP"]) ||
             ([line hasPrefix:@".AC "] || [line isEqualToString:@".AC"]) ||
             [line hasPrefix:@".NOISE "] ||
             [line hasPrefix:@".DISTO "] ||
             [line hasPrefix:@".FOUR "] ||
             [line hasPrefix:@".DC "]  ||
             [line hasPrefix:@".TF "] ||
             [line hasPrefix:@".NODESET "] ||
             [line hasPrefix:@".IC"] ||
             [line hasPrefix:@".OPTIONS "])
    {
      [result addAttributes:sAnalysisCommandAttributes range:tmpRange];
      previousAttributes = sAnalysisCommandAttributes;
    }
    else if ([line hasPrefix:@".MODEL"])
    {
      [result addAttributes:sModelAttributes range:tmpRange];
      previousAttributes = sModelAttributes;
    }
    else if ([line hasPrefix:@".ENDS"]) // end of subcircuit
    {
      
    }
    else if ([line hasPrefix:@".END"]) // end of netlist
    {
      [result addAttributes:sCommentAttributes range:tmpRange];
      reachedEndOfNetlist = YES;
    }
    else if ([line hasPrefix:@"*"])
    {
      [result addAttributes:sCommentAttributes range:tmpRange];
    }
    else if ([line hasPrefix:@".PRINT"])
    {
      [result addAttributes:sPrintAttributes range:tmpRange];
      previousAttributes = sPrintAttributes;
    }
    else if ([line hasPrefix:@".SUBCKT "])
    {
      [result addAttributes:sSubcircuitAttributes range:tmpRange];
      inSubcircuit = YES;
    }
    else if ([line hasPrefix:@"+"])
    {
      [result addAttributes:previousAttributes range:tmpRange];
    }
    else
    {
      [result addAttributes:sDefaultAttributes range:tmpRange];
      previousAttributes = sDefaultAttributes;
    }
    lineStart = nextLineStart;
  }

  return result;
}


@end
