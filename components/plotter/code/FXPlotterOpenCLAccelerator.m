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

#import "FXPlotterOpenCLAccelerator.h"


NSString* getPlatformInfo( cl_platform_id platform, cl_platform_info infoType )
{
  static char nameBuffer[256];
  size_t nameLength = 0;

  if ( clGetPlatformInfo( platform, infoType, 256, nameBuffer, &nameLength) != CL_SUCCESS )
  {
    return @"";
  }

  nameBuffer[255] = 0;
  return @(nameBuffer);
}


NSString* getDeviceInfo( cl_device_id device, cl_device_info infoType )
{
  static char nameBuffer[256];
  size_t nameLength = 0;

  if ( clGetDeviceInfo( device, infoType, 256, nameBuffer, &nameLength ) != CL_SUCCESS )
  {
    return @"";
  }

  nameBuffer[255] = 0;
  return @(nameBuffer);
}


#pragma mark -


@implementation FX(FXPlotterOpenCLAccelerator)

@synthesize context  = mContext;
@synthesize device   = mDevice;
@synthesize platform = mPlatform;

- (id) init
{
  self = [super init];

  BOOL success = NO;
  mContext = clCreateContextFromType(NULL, CL_DEVICE_TYPE_GPU, NULL, NULL, NULL);
  if ( mContext != NULL )
  {
    cl_uint numberOfPlatforms;
    if ( (clGetPlatformIDs(1, &mPlatform, &numberOfPlatforms) == CL_SUCCESS) && (numberOfPlatforms == 1) )
    {
      cl_uint numberOfDevices;
      if ( (clGetDeviceIDs( mPlatform, CL_DEVICE_TYPE_GPU, 1, &mDevice, &numberOfDevices ) == CL_SUCCESS) && (numberOfDevices == 1) )
      {
        success = YES;
      }
    }
  }
  if ( !success )
  {
    FXRelease(self)
    return nil;
  }

  return self;
}


- (void) dealloc
{
  clReleaseContext( mContext );
  FXDeallocSuper
}


- (NSString*) description
{
  return [NSString stringWithFormat:@"%@ %@ %@ %@, %@ %@ %@ %@", 
    getPlatformInfo( mPlatform, CL_PLATFORM_VENDOR ),
    getPlatformInfo( mPlatform, CL_PLATFORM_NAME ),
    getPlatformInfo( mPlatform, CL_PLATFORM_VERSION ),
    getPlatformInfo( mPlatform, CL_PLATFORM_PROFILE ),
    getDeviceInfo( mDevice, CL_DEVICE_VENDOR ),
    getDeviceInfo( mDevice, CL_DEVICE_NAME ),
    getDeviceInfo( mDevice, CL_DEVICE_VERSION ),
    getDeviceInfo( mDevice, CL_DEVICE_PROFILE )
  ];
}

@end
