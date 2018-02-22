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

#import "FXVoltaErrors.h"

NSString* const FXVoltaErrorDomain = @"FXVoltaErrorDomain";


@implementation FXVoltaError


- (id) initWithErrorCode:(FXVoltaErrorCode)errorCode
{
  self = [super initWithDomain:FXVoltaErrorDomain code:(NSInteger)errorCode userInfo:nil];
  if ( self != nil )
  {
    
  }
  return self;
}


- (id) init
{
  return [self initWithErrorCode:FXVoltaError_Generic];
}


+ (FXVoltaError*) errorWithCode:(FXVoltaErrorCode)code
{
  FXVoltaError* error = [[FXVoltaError alloc] initWithErrorCode:code];
  FXAutorelease(error)
  return error;
}


+ (NSString*) stringForCode:(FXVoltaErrorCode)errorCode
{
  switch ( errorCode )
  {
    case FXVoltaError_PluginLoading :        return @"E_PluginLoading";
    case FXVoltaError_NoSimulator :          return @"E_NoSimulator";
    case FXVoltaError_NoSimulatorInput :     return @"E_NoSimulatorInput";
    default: return @"E_Generic";
  }
}


- (NSString*) localizedDescription
{
  NSString* errorDescription = [[NSBundle mainBundle] localizedStringForKey:[FXVoltaError stringForCode:(FXVoltaErrorCode)[self code]] value:@"!translate!" table:@"VoltaErrors"];
  NSAssert(errorDescription != nil, @"Problem creating an error description.");
  return errorDescription;
}


@end
