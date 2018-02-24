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

#import "FXVoltaArchiveValidator.h"
#import "FXVoltaArchiver.h"
#import "FXVoltaArchiveConverterV1To2.h"
#import <map>

NSString* FXVoltaArchiverErrorDomain = @"FXVoltaArchiverErrorDomain";
NSString* FXVoltaArchiverValidationSchemaFile = @"volta-v2.rng";

static long const skFormatVersion_MaxAllowed = 2;
static long const skFormatVersion_MinAllowed = 1;

typedef NS_ENUM(NSInteger, FXVoltaArchiveValidationError)
{
  FXVoltaArchiveValidationError_None,
  FXVoltaArchiveValidationError_InputFormatInvalid,        // Not a Volta document
  FXVoltaArchiveValidationError_InputFormatVersionTooLow,  // Volta document is too old
  FXVoltaArchiveValidationError_InputFormatVersionTooHigh, // Volta document created by newer software
};


@implementation FXVoltaArchiveValidator


+ (FXXMLDocumentPtr) parseAndValidate:(const FXString &)archive upgradedWhileParsing:(BOOL *)upgraded error:(NSError **)validationError
{
  FXIssue(216)
  FXXMLDocumentPtr result;
  if (upgraded != NULL)
  {
    *upgraded = NO;
  }

  FXXMLDocumentPtr unarchivedDocument = FXXMLDocument::fromString(archive);
  if ( unarchivedDocument.get() != nullptr )
  {
    FXVoltaArchiveValidationError errorCode = FXVoltaArchiveValidationError_InputFormatInvalid;
    unsigned const versionNumber = [self determineFormatVersionOfDocument:unarchivedDocument];
    FXXMLElementPtr rootElement = unarchivedDocument->getRootElement();
    if ( versionNumber > skFormatVersion_MaxAllowed )
    {
      errorCode = FXVoltaArchiveValidationError_InputFormatVersionTooHigh;
    }
    else if ( versionNumber < skFormatVersion_MinAllowed )
    {
      errorCode = FXVoltaArchiveValidationError_InputFormatVersionTooLow;
    }
    else if ( (versionNumber >= skFormatVersion_MinAllowed) && (versionNumber <= skFormatVersion_MaxAllowed) )
    {
      @try
      {
        if ( FXXMLDocument::validate( archive, [self getValidationSchemaForVersion:versionNumber] ) )
        {
          errorCode = FXVoltaArchiveValidationError_None;
          if ( versionNumber == skFormatVersion_MaxAllowed )
          {
            result = unarchivedDocument;
          }
          else
          {
            FXXMLElementPtr convertedDocumentRoot = [self convertDocumentRoot:rootElement fromVersion:versionNumber];
            NSAssert( convertedDocumentRoot.get() != nullptr, @"The document has already been validated. There should be no problem converting it." );
            if ( convertedDocumentRoot.get() == nullptr )
            {
              errorCode = FXVoltaArchiveValidationError_InputFormatInvalid;
            }
            else
            {
              result = FXXMLDocumentPtr( new FXXMLDocument(convertedDocumentRoot) );
              if (upgraded != NULL)
              {
                *upgraded = YES;
              }
            }
          }
        }
      }
      @catch (NSException *exception)
      {
      }
    }

    if ( (validationError != NULL) && (errorCode != FXVoltaArchiveValidationError_None) )
    {
      *validationError = [self errorForErrorCode:errorCode];
    }
  }

  return result;
}


#pragma mark Private


+ (FXString const &) getValidationSchemaForVersion:(unsigned)versionNumber
{
  typedef std::map<long, FXString> FXVoltaArchiveValidatorSchemaMap;
  static  FXVoltaArchiveValidatorSchemaMap sValidationSchemaMap;

  FXVoltaArchiveValidatorSchemaMap::iterator it = sValidationSchemaMap.find(versionNumber);
  if ( it != sValidationSchemaMap.end() )
  {
    return it->second;
  }

  NSString* schemaFileName = [NSString stringWithFormat:@"volta-v%d.rng", versionNumber];
  NSString* schemaFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:schemaFileName ofType:nil];
  if ( schemaFilePath == nil )
  {
    @throw [NSException exceptionWithName:@"VoltaArchiveSchemaNotFound" reason:[NSString stringWithFormat:@"Could not find the Volta schema file for version %d.", versionNumber] userInfo:nil];
  }

  NSError* fileReadError = nil;
  NSString* schemaFileContents = [[NSString alloc] initWithContentsOfFile:schemaFilePath encoding:NSUTF8StringEncoding error:&fileReadError];
  if ( schemaFileContents == nil )
  {
    @throw [NSException exceptionWithName:@"VoltaArchiveSchemaReadError" reason:[NSString stringWithFormat:@"Could not read the contents of the Volta schema file for version %d.", versionNumber] userInfo:nil];
  }
  sValidationSchemaMap[versionNumber] = (__bridge CFStringRef)schemaFileContents;
  return sValidationSchemaMap[versionNumber];
}


+ (unsigned) determineFormatVersionOfDocument:(FXXMLDocumentPtr)document
{
  unsigned result = 0;
  FXXMLElementPtr rootElement = document->getRootElement();
  if ( rootElement->getName() == "volta" )
  {
    if ( rootElement->hasAttribute("version") )
    {
      FXString const versionString = rootElement->valueOfAttribute("version");
      if ( !versionString.empty() )
      {
        try
        {
          long versionNumber = versionString.extractLong();
          if ( (versionNumber >= 0) && (versionNumber < std::numeric_limits<unsigned>::max()) )
          {
            result = (unsigned)versionNumber;
          }
        }
        catch (std::runtime_error & e) {}
      }
    }
  }
  return result;
}


+ (NSError*) errorForErrorCode:(FXVoltaArchiveValidationError)errorCode
{
  NSMutableDictionary* errorInfo = [NSMutableDictionary dictionary];
  errorInfo[NSLocalizedDescriptionKey] = FXLocalizedString(@"UnarchivingError");
  errorInfo[NSLocalizedFailureReasonErrorKey] = [self localizedErrorDescriptionForConversionError:errorCode];
  if ( errorCode == FXVoltaArchiveValidationError_InputFormatVersionTooHigh )
  {
    errorInfo[NSLocalizedRecoverySuggestionErrorKey] = FXLocalizedString(@"UnarchivingError_RecoverByUpgrading");
  }
  return [NSError errorWithDomain:FXVoltaArchiverErrorDomain code:(NSInteger)errorCode userInfo:errorInfo];
}


+ (NSString*) localizedErrorDescriptionForConversionError:(FXVoltaArchiveValidationError)errorCode
{
  NSString* errorDescription = @"";
  switch ( errorCode )
  {
    case FXVoltaArchiveValidationError_InputFormatVersionTooLow:
      errorDescription = FXLocalizedString(@"UnarchivingError_FormatVersionTooLow");
      break;
    case FXVoltaArchiveValidationError_InputFormatVersionTooHigh:
      errorDescription = FXLocalizedString(@"UnarchivingError_FormatVersionTooHigh");
      break;
    case FXVoltaArchiveValidationError_InputFormatInvalid:
      errorDescription = FXLocalizedString(@"UnarchivingError_InvalidFormat");
      break;
    default:
      break;
  }
  return errorDescription;
}


+ (FXXMLElementPtr) convertDocumentRoot:(FXXMLElementPtr)rootElement fromVersion:(NSUInteger)sourceVersion
{
  FXXMLElementPtr result;
  if ( sourceVersion == 1 )
  {
    std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector> conversionArtifacts = [FXVoltaArchiveConverterV1To2 convertRootElement:rootElement];
    result = std::get<0>(conversionArtifacts);
  #if VOLTA_DEBUG
    for ( FXString const & warning : std::get<1>(conversionArtifacts) )
    {
      DebugLog(@"Conversion warning: %@", warning.cfString());
    }
    for ( FXString const & error : std::get<2>(conversionArtifacts) )
    {
      DebugLog(@"Conversion errors: %@", error.cfString());
    }
  #endif
  }
  else
  {
    result = rootElement;
  }
  return result;
}


@end

