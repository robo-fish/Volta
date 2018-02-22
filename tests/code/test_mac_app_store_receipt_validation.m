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

#import <SenTestingKit/SenTestingKit.h>
#import "FXReceiptValidation_Internal.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>

@interface test_mac_app_store_receipt_validation : SenTestCase
@end


@implementation test_mac_app_store_receipt_validation


- (BOOL) keychainList:(NSArray*)keychains containsKeychainWithPath:(const char *)path
{
  BOOL result = NO;
  char keychainPathBuffer[1024];
  for ( id existingKeychain in keychains )
  {
    UInt32 pathLength = 1023;
    FXUTAssertEqual(SecKeychainGetPath((__bridge SecKeychainRef)existingKeychain, &pathLength, keychainPathBuffer), errSecSuccess);
    if (pathLength < 1023)
    {
      if ( strncmp(keychainPathBuffer, path, pathLength) == 0 )
      {
        result = YES;
        break;
      }
    }
  }
  return result;
}


- (NSData*) findAppleRootCertificate
{
  NSData* result = nil;

  SecKeychainRef rootCertificatesKeychain = NULL;
  const char* const kRootCertificateKeychainPath = "/System/Library/Keychains/SystemRootCertificates.keychain";
  CFArrayRef previousKeychainSearchList = NULL;
  FXUTAssertEqual(SecKeychainCopySearchList(&previousKeychainSearchList), errSecSuccess);
  if ( [self keychainList:(__bridge NSArray*)previousKeychainSearchList containsKeychainWithPath:kRootCertificateKeychainPath] )
  {
    CFRelease(previousKeychainSearchList);
    previousKeychainSearchList = NULL;
  }
  else
  {
    FXUTAssertEqual(SecKeychainOpen(kRootCertificateKeychainPath, &rootCertificatesKeychain), errSecSuccess);
    CFArrayRef searchList = (CFArrayRef)CFBridgingRetain(@[(__bridge id)rootCertificatesKeychain]);
    FXUTAssertEqual(SecKeychainSetSearchList(searchList), errSecSuccess);
    CFRelease(searchList);
  }

  NSDictionary* query = @{
    (id)kSecReturnData:       (id)kCFBooleanTrue,
  #if 0
    (id)kSecReturnAttributes: (id)kCFBooleanTrue,
  #endif
    (id)kSecClass:            (id)kSecClassCertificate,
    (id)kSecAttrLabel:        @"Apple Root CA",
    (id)kSecMatchLimit:       (id)kSecMatchLimitAll,
    (id)kSecMatchTrustedOnly: (id)kCFBooleanTrue
  };
  CFTypeRef queryResult = NULL;
  FXUTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)query, &queryResult), errSecSuccess);
  FXUTAssert(queryResult != NULL);
  CFArrayRef certificates = (CFArrayRef)queryResult;
  CFIndex const numberOfCertificates = CFArrayGetCount(certificates);
  FXUTAssertEqual(numberOfCertificates, (CFIndex)1);
  NSData* certificateData = (NSData*) CFArrayGetValueAtIndex(certificates, 0);
  FXUTAssert(certificateData != nil);
  result = [certificateData copy];
  FXAutorelease(result)

  CFRelease(certificates);
  if (previousKeychainSearchList != NULL)
  {
    FXUTAssertEqual(SecKeychainSetSearchList(previousKeychainSearchList), errSecSuccess);
    CFRelease(previousKeychainSearchList);
    previousKeychainSearchList = NULL;
  }
  if ( rootCertificatesKeychain != NULL )
  {
    CFRelease(rootCertificatesKeychain);
    rootCertificatesKeychain = NULL;
  }

  return result;
}


- (BOOL) data:(NSData*)data1 equalsData:(NSData*)data2
{
  if ( [data1 length] != [data2 length] )
  {
    return NO;
  }
  BOOL result = YES;
  char* bytes1 = (char*)[data1 bytes];
  char* bytes2 = (char*)[data2 bytes];
  NSUInteger const length = [data1 length];
  for ( NSUInteger i = 0; i < length; i++ )
  {
    if ( bytes1[i] != bytes2[i] )
    {
      result = NO;
      break;
    }
  }
  return result;
}


- (void) test_find_apple_root_certificate_data
{
  CFDataRef certificateData = createAppleRootCertificateData();
  FXUTAssert(certificateData != NULL);
  NSData* certificateData2 = [self findAppleRootCertificate];
  FXUTAssert(certificateData2 != nil);
  FXUTAssert([self data:(__bridge NSData*)certificateData equalsData:certificateData2]);
}


@end
