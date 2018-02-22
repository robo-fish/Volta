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

#import "FXVoltaDocumentController.h"
#import "FXVoltaNotifications.h"
#import "VoltaLibrary.h"
#import "FXVoltaDocument.h"

@interface FXVoltaDocumentController ()
- (void) closeAllVoltaDocuments:(NSNotification*)notification;
- (void) closeAndReopenAllVoltaDocuments:(NSNotification*)notification;
- (void) openAllPreviousVoltaDocuments:(NSNotification*)notification;
- (void) voltaDocumentController:(NSDocumentController*)docController didCloseAll:(BOOL)didCloseAll contextInfo:(void *)contextInfo;
@end


#pragma mark -


@implementation FXVoltaDocumentController
{
@private
  BOOL mAllDocumentsWereClosed;
  NSMutableArray* mAllPreviousDocumentURLs;  // contains NSURL instances
  id<VoltaLibrary> mLibrary;
}

@synthesize library = mLibrary;

- (id) init
{
  self = [super init];
  if ( self != nil )
  {
    mAllDocumentsWereClosed = NO;
    mAllPreviousDocumentURLs = [[NSMutableArray alloc] initWithCapacity:3];
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(closeAllVoltaDocuments:) name:FXVoltaAllDocumentsShouldCloseNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(closeAndReopenAllVoltaDocuments:) name:FXVoltaAllDocumentsShouldCloseAndReopenNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(openAllPreviousVoltaDocuments:) name:FXVoltaReopenAllPreviousDocumentsNotification object:nil];
  }
  return self;
}

- (void) dealloc
{
  FXRelease(mAllPreviousDocumentURLs)
  FXDeallocSuper
}


#pragma mark NSDocumentController overrides


- (id) makeDocumentForURL:(NSURL*)absoluteDocumentURL
        withContentsOfURL:(NSURL*)absoluteDocumentContentsURL
                   ofType:(NSString*)typeName
                    error:(NSError**)outError
{
  id result = [super makeDocumentForURL:absoluteDocumentURL withContentsOfURL:absoluteDocumentContentsURL ofType:typeName error:outError];
  if ( result != nil )
  {
    [(FXVoltaDocument*)result setLibrary:mLibrary];
  }
  return result;
}


- (id) makeDocumentWithContentsOfURL:(NSURL*)absoluteURL
                              ofType:(NSString*)typeName
                               error:(NSError **)outError
{
  id result = [super makeDocumentWithContentsOfURL:absoluteURL ofType:typeName error:outError];
  if ( result != nil )
  {
    [(FXVoltaDocument*)result setLibrary:mLibrary];
  }
  return result;
}


- (id) makeUntitledDocumentOfType:(NSString*)typeName error:(NSError**)outError
{
  id result = [super makeUntitledDocumentOfType:typeName error:outError];
  if ( result != nil )
  {
    [(FXVoltaDocument*)result setLibrary:mLibrary];
  }
  return result;
}


- (void) addDocument:(NSDocument*)document
{
  NSAssert( [document isKindOfClass:[FXVoltaDocument class]], @"Wrong document class. Should be FXVoltaDocument." );
  [(FXVoltaDocument*)document setLibrary:mLibrary];
  [super addDocument:document];
}


#pragma mark NSWindowRestoration


#if 0 && VOLTA_SUPPORTS_RESUME
+ (void) restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
  [super restoreWindowWithIdentifier:identifier state:state completionHandler:completionHandler];
}
#endif


#pragma mark Private methods


- (void) closeAllVoltaDocuments:(NSNotification*)notification
{
  [mAllPreviousDocumentURLs removeAllObjects];
  for ( NSDocument* doc in [self documents] )
  {
    [mAllPreviousDocumentURLs addObject:[doc fileURL]];
  }

  [self closeAllDocumentsWithDelegate:self didCloseAllSelector:@selector(documentController:didCloseAll:contextInfo:) contextInfo:NULL];
}


- (void) closeAndReopenAllVoltaDocuments:(NSNotification*)notification
{
  // First get all document URLs
  NSArray* allDocuments = [self documents];
  NSMutableArray* documentFileURLs = [NSMutableArray arrayWithCapacity:[allDocuments count]];
  for ( NSDocument* doc in allDocuments )
  {
    NSURL* url = [doc fileURL];
    if ( url != nil )
    {
      [documentFileURLs addObject:[doc fileURL]];
    }
  }
  
  [self closeAllDocumentsWithDelegate:self didCloseAllSelector:@selector(documentController:didCloseAll:contextInfo:) contextInfo:NULL];
  
  // Reopen the documents
  if ( mAllDocumentsWereClosed )
  {
    for ( NSURL* fileURL in documentFileURLs )
    {
      [self openDocumentWithContentsOfURL:fileURL display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
        /* do nothing */
      }];
    }
  }
}

- (void) openAllPreviousVoltaDocuments:(NSNotification*)notification
{
  if ( mAllDocumentsWereClosed )
  {
    for ( NSURL* fileURL in mAllPreviousDocumentURLs )
    {
      [self openDocumentWithContentsOfURL:fileURL display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
        /* do nothing */
      }];
    }
  }
}


- (void) voltaDocumentController:(NSDocumentController*)docController didCloseAll:(BOOL)didCloseAll contextInfo:(void *)contextInfo
{
  mAllDocumentsWereClosed = didCloseAll;
}

@end
