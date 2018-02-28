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

#import "FXVoltaMainController.h"
#import "FXVoltaDocumentController.h"
#import "FXVoltaPluginsController.h"
#import "FXVoltaLibrary.h"
#import "VoltaLibraryEditor.h"
#import "FXVoltaPlugin.h"
#import "VoltaSchematicEditor.h"
#import "FXVoltaDocumentWindow.h"
#import "FXVoltaDocument.h"
#import "FXSystemUtils.h"
#import "FXVoltaPreferencesController.h"

#if VOLTA_SUPPORTS_ICLOUD
#import "FXVoltaCloudController.h"
#endif

static NSString* FXVoltaHomePageAddress                                         = @"https://robo.fish/volta/help/v124/en/index.html";
static NSString* FXVoltaAboutWindowIdentifier                                   = @"AboutWindow";
static NSString* FXResume_VoltaAboutWindowCopyrightNoticeScrollPoint            = @"AboutWindowCopyrightNoticeScrollPoint";


@interface FXVoltaMainController ()
@property id<VoltaLibraryEditor> libraryEditor;
#if VOLTA_SUPPORTS_ICLOUD
@property FXVoltaCloudController* cloudController;
#endif
@end


@implementation FXVoltaMainController
{
@private
  FXVoltaLibrary* _library;
#if VOLTA_SUPPORTS_ICLOUD
  FXVoltaCloudController* _cloudController;
  BOOL _usingCloudLibrary;
  BOOL _copyLocalLibraryToCloudOnNextCloudLibrarySetup;
#endif
  NSMutableArray* _lastOpenDocumentURLs;

  BOOL _currentlySwitchingLibrary;
}

@synthesize menuItem_preferences = _preferencesMenuItem;
@synthesize menuItem_circuit = _circuitMenuItem;
@synthesize aboutPanel_copyrightTextView = _copyrightView;
@synthesize aboutPanel_versionView = _versionView;

- (id) init
{
  self = [super init];
  _currentlySwitchingLibrary = NO;
#if VOLTA_SUPPORTS_ICLOUD
  _usingCloudLibrary = NO;
  _copyLocalLibraryToCloudOnNextCloudLibrarySetup = NO;
#endif
  return self;
}


- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
#if VOLTA_SUPPORTS_ICLOUD
  self.cloudController = nil;
#endif
  self.libraryEditor = nil;
  FXRelease(mLibrary)
  FXRelease(mAboutPanel)
  FXDeallocSuper
}


- (void) awakeFromNib
{
  [self setUpLibrary];

#if VOLTA_HAS_PREFERENCES_PANEL
  [mPreferencesMenuItem setTarget:self];
  [mPreferencesMenuItem setAction:@selector(showPreferences:)];
#else
  // Hiding the Preferences menu item
  [_preferencesMenuItem setHidden:YES];
#endif
}


#pragma mark Public methods


#if VOLTA_HAS_PREFERENCES_PANEL
- (IBAction) action_showPreferences:(id)sender
{
  FXIssue(41)
  [[FXVoltaPreferencesController sharedController] showWindow:self];
}
#endif


- (IBAction) action_showAboutPanel:(id)sender
{
  [self.aboutPanel center];
  [self.aboutPanel makeKeyAndOrderFront:self];
}


- (IBAction) action_toggleLibraryEditor:(id)sender
{
  FXIssue(71)
  if ( [self.libraryEditor isVisible] )
  {
    [self.libraryEditor hide];
  }
  else
  {
    [self.libraryEditor show];
  }
}


- (IBAction) action_browseToVoltaHomepage:(id)sender
{
  if ( [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:FXVoltaHomePageAddress]] )
  {
    [self.aboutPanel orderOut:self];
  }
}


- (NSPanel*) aboutPanel
{
  if (_aboutPanel == nil)
  {
    [self buildAboutPanel];
  }
  return _aboutPanel;
}


#if VOLTA_SUPPORTS_ICLOUD
- (void) action_useCloudLibrary:(id)sender
{
  if ( sender == self.menuItem_useCloudLibrary )
  {
    BOOL const useCloudLibrary = [self.menuItem_useCloudLibrary state] == NSOffState;
    self.cloudController.useCloudLibrary = useCloudLibrary;
  }
}


- (void) action_copyLocalLibrary:(id)sender
{
  NSInteger const choice = NSRunAlertPanel(FXLocalizedString(@"Cloud_CopyLibrary_Title"), FXLocalizedString(@"Cloud_CopyLocalLibrary_Message"), FXLocalizedString(@"Copy"), FXLocalizedString(@"Cancel"), nil);
  if ( choice == NSAlertDefaultReturn )
  {
    [self.cloudController copyContentsFromLibraryAtLocation:[FXVoltaLibrary localStandardRootLocation]];
  }
}


- (void) action_copyCloudLibrary:(id)sender
{
  NSInteger const choice = NSRunAlertPanel(FXLocalizedString(@"Cloud_CopyLibrary_Title"), FXLocalizedString(@"Cloud_CopyCloudLibrary_Message"), FXLocalizedString(@"Copy"), FXLocalizedString(@"Cancel"), nil);
  if ( choice == NSAlertDefaultReturn )
  {
    [self.cloudController copyCloudLibraryToLibraryAtLocation:[FXVoltaLibrary localStandardRootLocation]];
  }
}
#endif


#pragma mark NSApplicationDelegate


- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
  // Note: This method is called AFTER any documents from a previous session are restored.

  if ( FXVoltaPreferencesController.isInitialRun )
  {
    [self installInitialLibraryContent];
  }

  [self loadPlugins];
  [self buildCircuitMenu];

#if VOLTA_DEBUG
  [self buildDebugMenu];
  [[NSUserDefaults standardUserDefaults] setValue:@YES forKey:@"NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints"];
#endif

  if ( FXVoltaPreferencesController.isInitialRun )
  {
    NSDocument* document = (NSDocument*)[[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
    [self.libraryEditor show];
    [self positionTheLibraryWindowNextToTheWindowOfDocument:document];
    FXVoltaPreferencesController.isInitialRun = NO;
  }
}


- (void) applicationDidChangeScreenParameters:(NSNotification *)aNotification
{
  for ( NSDocument* document in [[NSDocumentController sharedDocumentController] documents] )
  {
    for ( NSWindowController* windowController in [document windowControllers] )
    {
      [self fitWindowIntoScreen:[windowController window]];
    }
  }
  [self fitWindowIntoScreen:self.libraryEditor.window];
  [self fitWindowIntoScreen:_aboutPanel];
}


- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
  return NSTerminateNow;
}


- (BOOL) applicationShouldOpenUntitledFile:(NSApplication*)sender
{
  return NO;
}


- (BOOL) applicationShouldHandleReopen:(NSApplication*)app hasVisibleWindows:(BOOL)flag
{
  return NO;
}


#pragma mark NSWindowRestoration


#if VOLTA_SUPPORTS_RESUME
+ (void) restoreWindowWithIdentifier:(NSString*)identifier
                               state:(NSCoder *)state
                   completionHandler:(void (^)(NSWindow *, NSError *))restorationHandler
{
  NSWindow* windowToRestore = nil;
  if ( [identifier isEqualToString:FXVoltaAboutWindowIdentifier] )
  {
    windowToRestore = [(FXVoltaMainController*)[NSApp delegate] aboutPanel];
  }
  restorationHandler(windowToRestore, nil);
}
#endif


#pragma mark NSWindowDelegate


- (void) window:(NSWindow*)window willEncodeRestorableState:(NSCoder*)state
{
  FXIssue(177)
  if ( window == self.aboutPanel )
  {
    NSScrollView* scrollView = [_copyrightView enclosingScrollView];
    NSAssert( scrollView != nil, @"The text view should have an enclosing scroll view." );
    NSPoint const scrollPoint = [scrollView documentVisibleRect].origin;
    [state encodePoint:scrollPoint forKey:FXResume_VoltaAboutWindowCopyrightNoticeScrollPoint];
  }
}


- (void) window:(NSWindow*)window didDecodeRestorableState:(NSCoder*)state
{
  FXIssue(177)
  if ( window == self.aboutPanel )
  {
    NSPoint const scrollPoint = [state decodePointForKey:FXResume_VoltaAboutWindowCopyrightNoticeScrollPoint];
    [_copyrightView scrollPoint:scrollPoint];
  }
}


#pragma mark NSMenuValidation


- (BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
  BOOL result = YES;
#if VOLTA_SUPPORTS_ICLOUD
  if ( (menuItem == self.menuItem_copyCloudLibrary)
    || (menuItem == self.menuItem_copyLocalLibrary)
    || (menuItem == self.menuItem_useCloudLibrary) )
  {
    result = self.cloudController.cloudStorageIsAvailable;
    if ( menuItem == self.menuItem_useCloudLibrary )
    {
      self.menuItem_useCloudLibrary.state = self.cloudController.nowUsingCloudLibrary ? NSOnState : NSOffState;
    }
  }
#endif
  return result;
}


#pragma mark Private methods


- (void) loadPlugins
{
  [FXVoltaPluginsController sharedController];
}


- (void) setUpLibrary
{
  NSURL* rootLocation = nil;

#if VOLTA_SUPPORTS_ICLOUD
  if ( [FXSystemUtils filePanelHasCloudSupport] )
  {
    FXVoltaCloudController* cloudController = [FXVoltaCloudController new];
    self.cloudController = cloudController;
    FXRelease(cloudController)
    _usingCloudLibrary = self.cloudController.cloudStorageIsAvailable && self.cloudController.useCloudLibrary;
    if ( _usingCloudLibrary )
    {
      rootLocation = [self.cloudController libraryStorageLocationForFolder:VoltaCloudFolderType_LibraryRoot];
      if (_copyLocalLibraryToCloudOnNextCloudLibrarySetup)
      {
        [self.cloudController copyContentsFromLibraryAtLocation:[FXVoltaLibrary localStandardRootLocation]];
        _copyLocalLibraryToCloudOnNextCloudLibrarySetup = NO;
      }
      self.menuItem_useCloudLibrary.state = NSOnState;
    }
    else
    {
      self.menuItem_useCloudLibrary.state = NSOffState;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleCloudLibraryStateChanged:) name:FXVoltaCloudLibraryStateDidChangeNotification object:nil];
  }
  else
  {
    self.menuItem_cloudLibrary.hidden = YES;
    self.menuItem_cloudLibrarySeparator.hidden = YES;
  }
#endif

  _library = [[FXVoltaLibrary alloc] initWithRootLocation:rootLocation];
  NSAssert(_library != nil, @"The library could not be created.");

  id<VoltaLibraryEditor> libraryEditor = (id<VoltaLibraryEditor>)[[[FXVoltaPluginsController sharedController] activePluginForType:VoltaPluginType_LibraryEditor] newPluginImplementer];
  NSAssert( (libraryEditor != nil) && [libraryEditor conformsToProtocol:@protocol(VoltaLibraryEditor)], @"Could not load library editor plug-in." );
  libraryEditor.library = _library;
#if VOLTA_SUPPORTS_ICLOUD
  libraryEditor.cloudLibraryController = self.cloudController;
#endif
  self.libraryEditor = libraryEditor;
  FXRelease(libraryEditor)

  [(FXVoltaDocumentController*)[NSDocumentController sharedDocumentController] setLibrary:_library];
}


- (void) shutDownLibrary
{
#if VOLTA_SUPPORTS_ICLOUD
  [[NSNotificationCenter defaultCenter] removeObserver:self name:FXVoltaCloudLibraryStateDidChangeNotification object:nil];
#endif
  @autoreleasepool
  {
    [self.libraryEditor.window close];
    self.libraryEditor.library = nil;
    self.libraryEditor = nil;
  #if VOLTA_SUPPORTS_ICLOUD
    _copyLocalLibraryToCloudOnNextCloudLibrarySetup = self.cloudController.userWantsLocalLibraryToBeCopied;
    self.cloudController = nil;
  #endif
    [(FXVoltaDocumentController*)[NSDocumentController sharedDocumentController] setLibrary:nil];
    [_library shutDown];
    FXRelease(mLibrary)
    _library = nil;
  }
}


FXIssue(23)
- (void) buildCircuitMenu
{
  // Normally, AppKit automatically enables or disables menu items by looking
  // for methods in the responder chain of the current key view that match
  // the actions of the menu items. In our architecture, however, not all target
  // objects of the menu actions are along the responder chain. Therefore, the
  // circuit menu items have fixed targets and we must replace the whole menu
  // each time a different circuit document becomes key.

  // Important: Making sure that unused menu items are removed from their menus. Otherwise AppKit bails out.
  [[_circuitMenuItem submenu] removeAllItems];

  NSMenu* newCircuitMenu = [[NSMenu alloc] initWithTitle:FXLocalizedString(@"Circuit")];

  for ( NSMenuItem* menuItem in [FXVoltaDocument mainMenuItems] )
  {
    [newCircuitMenu addItem:menuItem];
  }

  [newCircuitMenu addItem:[NSMenuItem separatorItem]];

  FXVoltaPlugin* schematicEditorPlugin = [[FXVoltaPluginsController sharedController] activePluginForType:VoltaPluginType_SchematicEditor];
  for ( NSMenuItem* menuItem in [schematicEditorPlugin mainMenuItems] )
  {
    [newCircuitMenu addItem:menuItem];
  }

  [_circuitMenuItem setSubmenu:newCircuitMenu];
  FXRelease(newCircuitMenu)
}


#if VOLTA_DEBUG
- (void) buildDebugMenu
{
  NSMenu* mainMenu = [NSApp mainMenu];
  NSMenu* debugMenu = [[NSMenu alloc] initWithTitle:@"DEBUG"];
  NSMenuItem* debugMenuItem = [[NSMenuItem alloc] initWithTitle:@"DEBUG" action:NULL keyEquivalent:@""];
  [mainMenu addItem:debugMenuItem];
  [mainMenu setSubmenu:debugMenu forItem:debugMenuItem];
  FXRelease(debugMenu)
  FXRelease(debugMenuItem)

  [debugMenu addItemWithTitle:@"Run UI Test" action:@selector(runUITest:) keyEquivalent:@""];

  NSMenuItem* toggleBoundingBoxItem = [[NSMenuItem alloc] initWithTitle:@"Show schematic bounding box" action:@selector(showSchematicBoundingBox:) keyEquivalent:@""];
  toggleBoundingBoxItem.state = [[[NSUserDefaults standardUserDefaults] objectForKey:@"FXVoltaDebug_ShowSchematicBoundingBox"] boolValue] ? NSOnState : NSOffState;
  toggleBoundingBoxItem.target = self;
  [debugMenu addItem:toggleBoundingBoxItem];

  NSMenuItem* toggleElementBoundingBoxItem = [[NSMenuItem alloc] initWithTitle:@"Show schematic element bounding boxes" action:@selector(showSchematicElementBoundingBoxes:) keyEquivalent:@""];
  toggleElementBoundingBoxItem.state = [[[NSUserDefaults standardUserDefaults] objectForKey:@"FXVoltaDebug_ShowSchematicElementBoundingBoxes"] boolValue] ? NSOnState : NSOffState;
  toggleElementBoundingBoxItem.target = self;
  [debugMenu addItem:toggleElementBoundingBoxItem];
}

- (void) showSchematicBoundingBox:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  BOOL showBoundingBox = ![(NSNumber*)[userDefaults objectForKey:@"FXVoltaDebug_ShowSchematicBoundingBox"] boolValue];
  [userDefaults setObject:@(showBoundingBox) forKey:@"FXVoltaDebug_ShowSchematicBoundingBox"];
  [(NSMenuItem*)sender setState:(showBoundingBox ? NSOnState : NSOffState)];
}

- (void) showSchematicElementBoundingBoxes:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  BOOL showBoundingBox = ![(NSNumber*)[userDefaults objectForKey:@"FXVoltaDebug_ShowSchematicElementBoundingBoxes"] boolValue];
  [userDefaults setObject:@(showBoundingBox) forKey:@"FXVoltaDebug_ShowSchematicElementBoundingBoxes"];
  [(NSMenuItem*)sender setState:(showBoundingBox ? NSOnState : NSOffState)];
}
#endif


- (void) buildAboutPanel
{
  if ( [[NSBundle mainBundle] loadNibNamed:@"VoltaAboutWindow" owner:self topLevelObjects:NULL] )
  {
    NSAssert( _aboutPanel != nil, @"The About window does not exist." );
    [_aboutPanel setTitle:FXLocalizedString(@"AboutWindowTitle")];
  #if VOLTA_SUPPORTS_RESUME
    [_aboutPanel setIdentifier:FXVoltaAboutWindowIdentifier];
    [_aboutPanel setRestorable:YES];
    [_aboutPanel setRestorationClass:[self class]];
    [_aboutPanel setDelegate:self];
  #endif
    
    NSAssert( _versionView != nil, @"The version field must exist in the About panel." );
    NSDictionary* bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSAssert( bundleInfoDictionary != nil, @"The app bundle does not contain a plist." );
    if ( bundleInfoDictionary != nil )
    {
      NSString* bundleVersionString = [bundleInfoDictionary valueForKey:@"CFBundleShortVersionString"];
      NSAssert( bundleVersionString != nil, @"The app bundle plist does not contain the version string." );
      [_versionView setString:bundleVersionString];
    }
    
    NSAssert( _copyrightView != nil, @"The copyright message view must exist in the About panel." );
    NSScrollView* scrollView = [_copyrightView enclosingScrollView];
    [[scrollView verticalScroller] setControlSize:NSControlSizeSmall];
    [scrollView setScrollerKnobStyle:NSScrollerKnobStyleLight];
    // Simplifying the link text attributes of the text view so that the attributes in the HTML are observed.
    NSMutableDictionary* linkTextAttributes = [NSMutableDictionary dictionaryWithDictionary:[_copyrightView linkTextAttributes]];
    [linkTextAttributes removeObjectForKey:NSForegroundColorAttributeName];
    [linkTextAttributes removeObjectForKey:NSUnderlineStyleAttributeName];
    [_copyrightView setLinkTextAttributes:linkTextAttributes];
    NSURL* creditsPageLocation = [[NSBundle mainBundle] URLForResource:@"Credits" withExtension:@"html"];
    if (creditsPageLocation != nil)
    {
      NSAttributedString* creditsString = [[NSAttributedString alloc] initWithURL:creditsPageLocation options:@{} documentAttributes:nil error:NULL];
      NSAssert( creditsString != nil, @"The credits file is missing!" );
      if ( creditsString == nil )
      {
        [_copyrightView setString:FXLocalizedString(@"AboutText")];
      }
      else
      {
        [[_copyrightView textStorage] setAttributedString:creditsString];
        [_copyrightView scrollToBeginningOfDocument:self];
      }
      FXRelease(creditsString)
    }
    [_copyrightView setAlignment:NSTextAlignmentCenter range:NSMakeRange(0, [[_copyrightView string] length])];
  }
}


- (void) fitWindowIntoScreen:(NSWindow*)window
{
  if ( window == nil )
  {
    return;
  }
  
  NSRect const currentWindowFrame = [window frame];
  NSRect const screenFrame = [[window screen] visibleFrame];
  if ( !NSContainsRect(screenFrame, currentWindowFrame) )
  {
    NSRect newWindowFrame = currentWindowFrame;

    // Adjusting size
    if ( newWindowFrame.size.width > screenFrame.size.width )
    {
      newWindowFrame.size.width = screenFrame.size.width;
    }
    if ( newWindowFrame.size.height > screenFrame.size.height )
    {
      newWindowFrame.size.height = screenFrame.size.height;
    }
    
    // Adjusting position
    if ( newWindowFrame.origin.x < screenFrame.origin.x )
    {
      newWindowFrame.origin.x = screenFrame.origin.x;
    }
    else if ( (newWindowFrame.origin.x + newWindowFrame.size.width) > (screenFrame.origin.x + screenFrame.size.width) )
    {
      newWindowFrame.origin.x = screenFrame.origin.x + screenFrame.size.width - newWindowFrame.size.width;
    }
    if ( newWindowFrame.origin.y < screenFrame.origin.y )
    {
      newWindowFrame.origin.y = screenFrame.origin.y;
    }
    else if ( (newWindowFrame.origin.y + newWindowFrame.size.height) > (screenFrame.origin.y + screenFrame.size.height) )
    {
      newWindowFrame.origin.y = screenFrame.origin.y + screenFrame.size.height - newWindowFrame.size.height;
    }

    if ( !NSEqualRects(currentWindowFrame, newWindowFrame) )
    {
      [window setFrame:newWindowFrame display:YES animate:YES];
    }
  }
}


NSString* kVoltaFileExtension = @"volta";


/// Copies the given files to the folder at the given location without replacing existing files.
/// @param prefix The prefix that a source files name can have and that will be stripped from the target file name. Can be nil.
/// @param localize Whether to look up the target file name in the localization table after stripping the prefix (if given).
- (void) copyFiles:(NSArray*)sourceFileLocations toFolder:(NSURL*)targetFolderLocation localizeFileNames:(BOOL)localize stripPrefix:(NSString*)prefix
{
  NSAssert(targetFolderLocation != nil, @"The installation location is not valid.");
  if ( (targetFolderLocation != nil) && [targetFolderLocation isFileURL] )
  {
    NSString* folderPath = [targetFolderLocation path];
    NSFileManager* fm = [NSFileManager defaultManager];
    BOOL isFolder = NO;
    BOOL const folderExists = [fm fileExistsAtPath:folderPath isDirectory:&isFolder] && isFolder;
    NSAssert( folderExists, @"The installation target folder should already exist." );
    if ( folderExists )
    {
      NSArray* targetFolderContents = [fm contentsOfDirectoryAtPath:folderPath error:NULL];
      for ( NSURL* sourceFileLocation in sourceFileLocations )
      {
        NSString* finalFileName = [sourceFileLocation lastPathComponent];
        if ( (prefix != nil) && [finalFileName hasPrefix:prefix] && ([finalFileName length] > [prefix length]) )
        {
          finalFileName = [finalFileName substringFromIndex:[prefix length]];
        }
        if (localize)
        {
          finalFileName = [FXLocalizedString([finalFileName stringByDeletingPathExtension]) stringByAppendingPathExtension:[finalFileName pathExtension]];
        }
        if ( ![targetFolderContents containsObject:finalFileName] )
        {
          NSURL* targetFileLocation = [targetFolderLocation URLByAppendingPathComponent:finalFileName];
          [fm copyItemAtURL:sourceFileLocation toURL:targetFileLocation error:NULL];
        }
      }
    }
  }
}


- (NSArray*) filesWithPrefix:(NSString*)prefix atLocation:(NSURL*)folderLocation
{
  NSMutableArray* result = [NSMutableArray arrayWithCapacity:5];
  NSFileManager* fm = [NSFileManager defaultManager];
  NSArray* resourceFiles = [fm contentsOfDirectoryAtURL:folderLocation includingPropertiesForKeys:nil options:0 error:NULL];
  for ( NSString* resourceFile in resourceFiles )
  {
    if ( [[resourceFile lastPathComponent] hasPrefix:prefix] )
    {
      [result addObject:resourceFile];
    }
  }
  return result;
}


- (void) installInitialLibraryContent
{
  FXIssue(234)
  NSURL* bundleResourcesLocation = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]];
  {
    NSArray* paletteFileLocations = [self filesWithPrefix:@"Palette_" atLocation:bundleResourcesLocation];
    [self copyFiles:paletteFileLocations toFolder:[_library paletteLocation] localizeFileNames:YES stripPrefix:nil];
  }
  {
    FXIssue(123)
    NSString* prefix = @"Subcircuit_";
    NSArray* subcircuitFileLocations = [self filesWithPrefix:prefix atLocation:bundleResourcesLocation];
    [self copyFiles:subcircuitFileLocations toFolder:[_library subcircuitsLocation] localizeFileNames:NO stripPrefix:prefix];
  }
  {
    NSString* prefix = @"Models_";
    NSArray* modelFileLocations = [self filesWithPrefix:prefix atLocation:bundleResourcesLocation];
    [self copyFiles:modelFileLocations toFolder:[_library modelsLocation] localizeFileNames:NO stripPrefix:prefix];
  }
}


- (void) switchLibrary
{
  _currentlySwitchingLibrary = YES;
  NSDocumentController* docController = [NSDocumentController sharedDocumentController];
  if ( _lastOpenDocumentURLs != nil )
  {
    FXRelease(mLastOpenDocumentURLs)
  }
  _lastOpenDocumentURLs = [[NSMutableArray alloc] initWithCapacity:[[docController documents] count]];
  for ( NSDocument* document in [docController documents] )
  {
    NSURL* fileURL = [document fileURL];
    if ( fileURL != nil )
    {
      [_lastOpenDocumentURLs addObject:fileURL];
    }
  }
  [docController closeAllDocumentsWithDelegate:self didCloseAllSelector:@selector(documentController:didCloseAll:contextInfo:) contextInfo:NULL];
}


- (void) documentController:(NSDocumentController*)docController didCloseAll:(BOOL)didCloseAll contextInfo:(void*)contextInfo
{
  if ( didCloseAll && _currentlySwitchingLibrary )
  {
    NSRect const libraryWindowFrame = self.libraryEditor.window.frame;
    [self shutDownLibrary];
    [self setUpLibrary];
    [self.libraryEditor.window setFrame:libraryWindowFrame display:YES];
    [self.libraryEditor show];
  }
  for ( NSURL* documentFileURL in _lastOpenDocumentURLs )
  {
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:documentFileURL display:YES completionHandler:NULL];
  }
  _currentlySwitchingLibrary = NO;
}


#if VOLTA_SUPPORTS_ICLOUD
- (void) handleCloudLibraryStateChanged:(NSNotification*)notification
{
  if (_usingCloudLibrary != self.cloudController.useCloudLibrary)
  {
    [self switchLibrary];
  }
}
#endif


- (void) positionTheLibraryWindowNextToTheWindowOfDocument:(NSDocument*)document
{
  if ( document != nil )
  {
    NSArray* windowControllers = document.windowControllers;
    if (windowControllers.count > 0)
    {
      NSWindow* documentWindow = [[windowControllers objectAtIndex:0] window];
      if ( documentWindow.isVisible )
      {
        NSScreen* windowScreen = documentWindow.screen;
        NSRect const docWindowFrame = documentWindow.frame;
        NSWindow* libraryWindow = self.libraryEditor.window;
        if ( (docWindowFrame.origin.x - libraryWindow.frame.size.width) >= windowScreen.frame.origin.x )
        {
          CGFloat const kWindowMargin = 6;
          libraryWindow.frameTopLeftPoint = NSMakePoint(NSMinX(docWindowFrame) - libraryWindow.frame.size.width - kWindowMargin, NSMaxY(docWindowFrame));
        }
      }
      [documentWindow makeKeyAndOrderFront:self];
    }
  }
}


#if VOLTA_DEBUG
- (void) runUITest:(id)sender
{
  DebugLog(@"Implementation of UI test is missing.");
}
#endif


@end
