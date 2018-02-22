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

#import "FXVoltaPlugin.h"
#import "FXVoltaErrors.h"

@implementation FXVoltaPlugin
{
@private
  NSBundle*        mBundle;
  id<VoltaPlugin>  mPluginMainObject;
  NSString*        mBundlePath;
  NSString*        mName;
  NSString*        mVersion;
  NSString*        mIdentifier;
  NSString*        mVendor;
  VoltaPluginType  mType;
}

@synthesize bundlePath = mBundlePath;
@synthesize name = mName;
@synthesize vendor = mVendor;
@synthesize version = mVersion;
@synthesize type = mType;
@synthesize identifier = mIdentifier;


- (id) initWithBundlePath:(NSString*)bundlePath;
{
  self = [super init];

  mBundlePath = [bundlePath copy];
  mType = VoltaPluginType_Unknown;

  return self;
}


- (id) init
{
  return [self initWithBundlePath:nil];
}


- (void) dealloc
{
  //[self unload];
  FXRelease(mPluginMainObject)
  FXRelease(mBundlePath)
  FXRelease(mName)
  FXRelease(mVersion)
  FXRelease(mIdentifier)
  FXDeallocSuper
}


- (BOOL) loadWithError:(NSError**)error
{
  BOOL success = NO;

  @synchronized(self)
  {
    if ( mPluginMainObject && mBundle )
    {
      success = YES;
    }
    else
    {
      // Test whether it's a bundle
      mBundle = [[NSBundle alloc] initWithPath:mBundlePath];
      if ( (mBundle != nil) && [mBundle loadAndReturnError:error] )
      {
        Class principalClass = [mBundle principalClass];
        if ( principalClass != nil )
        {
          NSObject* instance = [[principalClass alloc] init];
          if ( instance && [instance conformsToProtocol:@protocol(VoltaPlugin)] )
          {
            if ( mPluginMainObject != nil )
            {
              FXRelease(mPluginMainObject)
            }
            mPluginMainObject = (id<VoltaPlugin>) instance;
            mName = [[mPluginMainObject pluginName] copy];
            mVendor = [[mPluginMainObject pluginVendor] copy];
            mVersion = [[mPluginMainObject pluginVersion] copy];
            mType = [mPluginMainObject pluginType];
            mIdentifier = [[mPluginMainObject pluginIdentifier] copy];
            success = YES;
          }
          else
          {
            FXRelease(instance)
          }
        }
      }            
    }
  }

  if ( !success && (error != nil) )
  {
    DebugLog(@"Error while loading plugin at path %@ : \"%@\"", mBundlePath, (*error != nil) ? [*error localizedDescription] : @"<missing system error message>");
    *error = [FXVoltaError errorWithCode:FXVoltaError_PluginLoading];
  }

  return success;
}

/*
- (void) unload
{
    @synchronized(self)
    {
        if ( mPluginMainObject && mBundle )
        {
            FXRelease(mPluginMainObject)
            mPluginMainObject = nil;
            
            if ( ![mBundle unload] )
            {
                DebugLog(@"Could not unload bundle 0x%x", mBundle);
            }
            else {
                DebugLog(@"Successfully unloaded bundle 0x%x", mBundle);
            }

            FXRelease(mBundle)
            mBundle = nil;
        }
    }
}
*/


- (NSObject*) newPluginImplementer
{
  return [mPluginMainObject newPluginImplementer];
}


- (NSArray*) mainMenuItems
{
  if ( mPluginMainObject != nil )
  {
    return [[mPluginMainObject class] mainMenuItems];
  }
  return @[];
}


#if 0
//Message forwarding to plugin's main object
- (void) forwardInvocation:(NSInvocation*)invocation
{
	[invocation invokeWithTarget:mPluginMainObject];
}

- (NSMethodSignature*) methodSignatureForSelector:(SEL)aSelector
{
	return [mPluginMainObject methodSignatureForSelector:aSelector];
}
#endif

@end
