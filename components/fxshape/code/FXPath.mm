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

#import "FXPath.h"
#import "FXSegment.h"
#import "FXString.h"

#include <cassert>
#include <stack>
#include <iostream>


@interface FX(FXPath) ()
{
  NSMutableArray*  mSegments;
  BOOL             mFilled;
  BOOL             mClosed;
}
@end


@implementation FX(FXPath)

@synthesize filled = mFilled;
@synthesize closed = mClosed;
@dynamic segments;


- (id) init
{
  self = [super init];
  mFilled = NO;
  mClosed = NO;
  mSegments = [[NSMutableArray alloc] init];
  return self;
}


- (void) dealloc
{
  FXRelease(mSegments)
  FXDeallocSuper
}


#pragma mark Public


- (NSArray*) segments
{
  return [NSArray arrayWithArray:mSegments];
}


- (void) setSegments:(NSArray*)segments
{
  [mSegments removeAllObjects];
  [mSegments setArray:segments];
}


- (CGRect) boundingBox
{
  return CGRectMake(0,0,0,0);
}


+ (FXPath*) pathWithData:(NSString*)SVG_path_data
{
  FXPath* result = [FXPath new];
  FXAutorelease(result)

  FXString d((__bridge CFStringRef)SVG_path_data);
  d.replaceAll( ",", " " );
  d.trimWhitespace();
  FXString const PathClosureSuffix("z");
  result.closed = d.endsWith( PathClosureSuffix ) ? YES : NO;
  if ( result.closed )
  {
    d.crop(0, d.length() - PathClosureSuffix.length());
    d.trim();
  }
  result.segments = [self extractSegmentsFromPathData:d];

  return result;
}


#pragma mark NSCoding


- (void) encodeWithCoder:(NSCoder*)encoder
{
  [encoder encodeObject:mSegments forKey:@"Segments"];
  [encoder encodeBool:mFilled forKey:@"Filled"];
  [encoder encodeBool:mClosed forKey:@"Closed"];
}

- (id) initWithCoder:(NSCoder*)decoder
{
  self = [super init];
  mSegments = [decoder decodeObjectForKey:@"Segments"];
  FXRetain(mSegments)
  mFilled = [decoder decodeBoolForKey:@"Filled"];
  mClosed = [decoder decodeBoolForKey:@"Closed"];
  return self;
}


#pragma mark NSCopying


- (id) copyWithZone:(NSZone*)zone
{
  FX(FXPath)* newCopy = [[[self class] allocWithZone:zone] init];
  NSArray* copiedSegments = [[NSArray alloc] initWithArray:mSegments copyItems:YES];
  FXAutorelease(copiedSegments)
  [newCopy setSegments:copiedSegments];
  [newCopy setFilled:mFilled];
  [newCopy setClosed:mClosed];
  return newCopy;
}


#pragma mark Private


////////////////////////////////////////////////////////////////////////////////
// SVG 1.1 PATH DATA FORMAT
// See implementation notes at http://www.w3.org/TR/SVG/implnote.html
////////////////////////////////////////////////////////////////////////////////
// All instructions are expressed as one character (e.g., a moveto is expressed
// as an M). Superfluous white space and separators such as commas can be
// eliminated (e.g., "M 100 100 L 200 200" contains unnecessary spaces and could
// be expressed more compactly as "M100 100L200 200").
// The command letter can be eliminated on subsequent commands if the same
// command is used multiple times in a row (e.g., you can drop the second "L" in
// "M 100 200 L 200 100 L -100 -200" and use "M 100 200 L 200 100 -100 -200"
// instead).
// Relative versions of all commands are available (uppercase means absolute
// coordinates, lowercase means relative coordinates).
// Alternate forms of lineto are available to optimize the special cases of
// horizontal and vertical lines (absolute and relative).
// Alternate forms of curve are available to optimize the special cases where
// some of the control points on the current segment can be determined
// automatically from the control points on the previous segment.
////////////////////////////////////////////////////////////////////////////////


//! \pre the result array must be be able to hold as many values as the stack size
//! \param[out] result contains the extracted float numbers upon return
//! \param[in] argumentStack stack of float numbers in string representation
//! \return \c true if successful, \c false if there was an exception
static std::vector<float> extractFloats( std::stack<FXString> & argumentStack ) throw (std::runtime_error)
{
  std::vector<float> result;
  size_t const numArguments = argumentStack.size();
  for( size_t currentIndex = 0; currentIndex < numArguments; ++currentIndex )
  {
    result.push_back( argumentStack.top().extractFloat() );
    argumentStack.pop();
  }
  return result;
}


+ (NSArray*) extractSegmentsFromPathData:(FXString &)d
{
  NSMutableArray* segmentsArray = [NSMutableArray arrayWithCapacity:10];

  // Extract tokens from the path command.
  // A token is either a command character or a command argument
  FXStringVector dTokens = d.tokenize();

  // Create segments from the token information
  if ( !dTokens.empty() )
  {
    try
    {
      std::stack<FXString> argumentTokens;
      FXStringVector::reverse_iterator it = dTokens.rbegin();
      FXStringVector::reverse_iterator itEnd = dTokens.rend();
      for ( ; it != itEnd; ++it )
      {
        FXStringVector::reverse_iterator nextIt = it;
        bool const isFirstCommandOfPath = (++nextIt == itEnd);
        FXString & token = *it;
        NSArray* segments = [self processJumpSegmentFromToken:token withArgumentTokens:argumentTokens isFirstCommand:isFirstCommandOfPath];
        if ( (segments != nil) && ([segments count] > 0) )
        {
          [segmentsArray insertObjects:segments atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [segments count])]];
        }
        else
        {
          segments = [self segmentsFromToken:token withArgumentTokens:argumentTokens];
          if ( (segments != nil) && ([segments count] > 0) )
          {
            [segmentsArray insertObjects:segments atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [segments count])]];
          }
          else
          {
            // The token must be a command argument.
            try
            {
              token.extractFloat();
              argumentTokens.push( token );
            }
            catch (std::runtime_error &)
            { // doing nothing skips the token
            }
          }
        }
      }
    }
    catch (std::runtime_error &)
    {
      [segmentsArray removeAllObjects];
    }
  }

  return segmentsArray;
}


+ (NSArray*) processJumpSegmentFromToken:(FXString const &)token withArgumentTokens:(std::stack<FXString> &)argumentTokens isFirstCommand:(BOOL)isFirstCommandOfPath
{
  NSMutableArray* segments = [NSMutableArray arrayWithCapacity:3];
  if ( (token == "M") || (token == "m") )
  {
    BOOL const isRelativeMove = !isFirstCommandOfPath && (token == "m");
    BOOL const isRelativeLine = isFirstCommandOfPath || (token == "m");
    std::vector<float> argumentValues = extractFloats( argumentTokens );
    size_t const numargs = argumentValues.size();
    // Expecting at least two arguments and the argument count to be a multiple of 2
    if ( (numargs >= 2) && ((numargs % 2) == 0 ) )
    {
      // According to the SVG specification, if a relative moveto (m) appears as the first element of the path, then it is treated as a pair of absolute coordinates.
      // Furthermore, in this case, subsequent pairs of coordinates are treated as relative even though the initial moveto is interpreted as an absolute moveto.
      // http://www.w3.org/TR/SVG/paths.html#PathDataMovetoCommands
      FXJumpSegment* jumpSegment = [[FXJumpSegment alloc] initWithDestination:FXVector(argumentValues[0], argumentValues[1]) relative:isRelativeMove];
      [segments addObject:jumpSegment];
      FXRelease(jumpSegment)
      jumpSegment = nil;
      // According to the standard, "if a moveto is followed by multiple pairs of coordinates, the subsequent pairs are treated as implicit lineto commands".
      if ( numargs > 2 )
      {
        for (size_t n = 2; n < numargs; n += 2 )
        {
          FXLineSegment* lineSegment = [[FXLineSegment alloc] initWithDestination:FXVector(argumentValues[n], argumentValues[n+1]) relative:isRelativeLine];
          [segments addObject:lineSegment];
          FXRelease(lineSegment)
        }
      }
    }
  }
  return segments;
}


+ (NSArray*) segmentsFromToken:(FXString const &)token withArgumentTokens:(std::stack<FXString> &)argumentTokens
{
  NSArray* result = [self arcSegmentsFromToken:token withArgumentTokens:argumentTokens];
  if ( result == nil ) result = [self lineSegmentsFromToken:token withArgumentTokens:argumentTokens];
  if ( result == nil ) result = [self verticalLineSegmentsFromToken:token withArgumentTokens:argumentTokens];
  if ( result == nil ) result = [self horizontalLineSegmentsFromToken:token withArgumentTokens:argumentTokens];
  if ( result == nil ) result = [self curveSegmentsFromToken:token withArgumentTokens:argumentTokens];
  return result;
}


+ (NSArray*) arcSegmentsFromToken:(FXString const &)token withArgumentTokens:(std::stack<FXString> &)argumentTokens
{
  NSMutableArray* result = nil;
  if ( (token == "A") || (token == "a") )
  {
    std::vector<float> const f = extractFloats( argumentTokens );
    size_t const numargs = f.size();
    if ( (numargs >= 7) && ((numargs % 7) == 0 ) )
    {
      result = [NSMutableArray arrayWithCapacity:numargs/7];
      for ( size_t n = 0; n < numargs; n += 7 )
      {
        FXArcSegment* arc = [[FXArcSegment alloc]
          initWithRadiusX:f[0]
          radiusY:f[1]
          rotation:f[2]
          largeArc:(f[3] > 0.5f)
          positiveSweep:(f[4] > 0.5f)
          endPoint:FXVector(f[5], f[6])
          relative:(token == "a")];
        [result addObject:arc];
        FXRelease(arc)
      }
    }
  }
  return result;
}


+ (NSArray*) lineSegmentsFromToken:(FXString const &)token withArgumentTokens:(std::stack<FXString> &)argumentTokens
{
  NSMutableArray* result = nil;
  if ( (token == "L") || (token == "l") )
  {
    std::vector<float> const f = extractFloats( argumentTokens );
    size_t const numargs = f.size();
    if ( (numargs >= 2) && ((numargs % 2) == 0 ) )
    {
      result = [NSMutableArray arrayWithCapacity:numargs/2];
      for ( size_t n = 0; n < numargs; n += 2 )
      {
        FXLineSegment* line = [[FXLineSegment alloc] initWithDestination:FXVector(f[n], f[n+1]) relative:(token == "l")];
        [result addObject:line];
        FXRelease(line)
      }
    }
  }
  return result;
}


+ (NSArray*) verticalLineSegmentsFromToken:(FXString const &)token withArgumentTokens:(std::stack<FXString> &)argumentTokens
{
  NSMutableArray* result = nil;
  if ( (token == "V") || (token == "v") )
  {
    // The SVG standard allows multiple arguments to 'V'/'v' although it makes no sense
    std::vector<float> const f = extractFloats( argumentTokens );
    size_t numargs = f.size();
    if ( numargs >= 1 )
    {
      result = [NSMutableArray arrayWithCapacity:numargs];
      float total = 0.0f;
      for ( size_t n = 0; n < numargs; n++ )
      {
        total += f[n];
      }
      FXVerticalLineSegment* line = [[FXVerticalLineSegment alloc] initWithDistance:total relative:(token == "v")];
      [result addObject:line];
      FXRelease(line)
    }
  }
  return result;
}


+ (NSArray*) horizontalLineSegmentsFromToken:(FXString const &)token withArgumentTokens:(std::stack<FXString> &)argumentTokens
{
  NSMutableArray* result = nil;
  if ( (token == "H") || (token == "h") )
  {
    // The SVG standard allows multiple arguments to 'H'/'h' although it makes no sense.
    std::vector<float> const f = extractFloats( argumentTokens );
    size_t numargs = f.size();
    if ( numargs >= 1 )
    {
      result = [NSMutableArray arrayWithCapacity:numargs];
      float total = 0.0f;
      for ( size_t n = 0; n < numargs; n++ )
      {
        total += f[n];
      }
      FXHorizontalLineSegment* line = [[FXHorizontalLineSegment alloc] initWithDistance:total relative:(token == "h")];
      [result addObject:line];
      FXRelease(line)
    }
  }
  return result;
}


+ (NSArray*) curveSegmentsFromToken:(FXString const &)token withArgumentTokens:(std::stack<FXString> &)argumentTokens
{
  NSMutableArray* result = nil;
  if ( (token == "C") || (token == "c") )
  {
    std::vector<float> const f = extractFloats( argumentTokens );
    size_t numargs = f.size();
    if ( (numargs >= 6) && ((numargs % 6) == 0) )
    {
      result = [NSMutableArray arrayWithCapacity:numargs/6];
      for ( size_t n = 0; n < numargs; n += 6 )
      {
        FXCurveSegment* curve = [[FXCurveSegment alloc]
          initWithControlPoint1:FXVector(f[n+0], f[n+1])
          controlPoint2:FXVector(f[n+2], f[n+3])
          endPoint:FXVector(f[n+4], f[n+5])
          relative:(token == "c")];
        [result addObject:curve];
        FXRelease(curve)
      }
    }
  }
  return result;
}


@end

