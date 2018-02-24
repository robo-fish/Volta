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

#import "FXVoltaDocument.h"
#import <VoltaCore/VoltaLibraryProtocol.h>
#import "FXVoltaPluginsController.h"
#import "FXVoltaPlugin.h"
#import "FXVoltaLibrary.h"
#import "FXVoltaArchiver.h"
#import "FXAnimatedGearWheelButton.h"
#import "FXSchematicToNetlistConverter.h"
#import "FXVoltaErrors.h"
#import "VoltaSchematicEditor.h"
#import "VoltaNetlistEditor.h"
#import "VoltaCircuitSimulator.h"
#import "VoltaPlotter.h"
#import "FXSubcircuitEditor.h"
#import "FXSimulationObserver.h"
#import "FXClipView.h"
#import "FXTabView.h"
#import "FXVoltaPersistentMetaKeys.h"
#import "FXVoltaDocumentWindow.h"
#import "FXVoltaDocumentWindowController.h"
#import "FXDocumentUpgradeDialogAccessoryView.h"
#import "FXVoltaCircuitDomainAgent.h"
#import "FXSimulatorView.h"
#import "FXVoltaDocumentPrintingViewController.h"


#define FXMultipleDocumentContentTypes (0)


static NSString* VoltaFileContentType_Generic                                   = @"Volta file"; // any file with "volta" extension
static NSString* VoltaFileContentType_Netlist                                   = @"Netlist file"; // files with "cir" or "ckt" extension
#if FXMultipleDocumentContentTypes
static NSString* VoltaFileContentType_Circuit                                   = @"fish.robo.volta.circuit"; // exported UTI
static NSString* VoltaFileContentType_Circuit_Legacy                            = @"com.kulfx.volta.circuit"; // exported UTI
static NSString* VoltaFileContentType_Subcircuit                                = @"fish.robo.volta.subcircuit"; // exported UTI
static NSString* VoltaFileContentType_Subcircuit_Legacy                         = @"com.kulfx.volta.subcircuit"; // exported UTI
#else
static NSString* VoltaFileContentType_UTI                                       = @"fish.robo.volta"; // exported UTI
static NSString* VoltaFileContentType_UTI_Legacy                                = @"com.kulfx.volta"; // exported UTI
#endif
static NSString* VoltaDocumentToolbarItemIdentifier_Capture                     = @"Capture_ToolbarItem";
static NSString* VoltaDocumentToolbarItemIdentifier_Run                         = @"Run_ToolbarItem";
static NSString* VoltaDocumentToolbarItemIdentifier_SubcircuitIndicator         = @"SubcircuitIndicator_ToolbarItem";
static NSString* VoltaDocumentToolbarItemIdentifier_MaximizeSchematic           = @"MaximizeSchematic_ToolbarItem";
static NSString* VoltaDocumentToolbarItemIdentifier_Plot                        = @"Plot_ToolbarItem";
static NSString* VoltaDocumentToolbarItemIdentifier_OpenClosePlotter            = @"OpenClosePlotter_ToolbarItem";
static NSString* FXDocumentUpgradeWithoutAsking                                 = @"Upgrade Document Formats Without Asking";


@interface FXVoltaDocument () <VoltaSubcircuitEditorClient, NSToolbarDelegate, NSWindowDelegate>
@end


@implementation FXVoltaDocument
{
@private

  VoltaPTCircuitPtr          mCircuitData;
  id<VoltaLibrary>           mLibrary;
  id<VoltaNetlistEditor>     mNetlistEditor;
  id<VoltaSchematicEditor>   mSchematicEditor;
  id<VoltaCircuitSimulator>  mCircuitSimulator;
  id<VoltaPlotter>           mPlotter;
  id<VoltaSubcircuitEditor>  mSubcircuitEditor;

  FXSimulationObserver* mSimulationObserver;
  FXSimulatorView* mSimulatorView;

  NSToolbarItem*   mCaptureToolbarItem;
  NSToolbarItem*   mAnalyzeToolbarItem;
  NSToolbarItem*   mPlotToolbarItem;
  NSToolbarItem*   mSubcircuitIndicatorToolbarItem;
  NSToolbarItem*   mMaximizeSchematicToolbarItem;
  NSToolbarItem*   mOpenClosePlotterToolbarItem;

  NSMutableDictionary* mDocumentMetaData; // stored as meta data in the file, not the user prefs

  NSImage* mSubcircuitIndicatorImage;
}

@synthesize library = mLibrary;


+ (void) initialize
{
  [[NSUserDefaults standardUserDefaults] registerDefaults:@{ FXDocumentUpgradeWithoutAsking : @NO }];
}


/// Designated initializer. Automatically called by the other initializers.
- (id) init
{
  self = [super init];
  if ( self != nil )
  {
    mDocumentMetaData = [[NSMutableDictionary alloc] init];
    mSimulationObserver = [FXSimulationObserver new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSimulationHasFinishedNotification:) name:FXSimulationHasFinishedNotification object:mSimulationObserver];
  }
  return self;
}


- (id) initWithType:(NSString*)typeName error:(NSError**)outError
{
  // Initializations that must be done when creating new documents
  // but not when opening existing documents.
  if ( ![typeName isEqualToString:VoltaFileContentType_UTI] )
  {
    DebugLog( @"Initializing document with type \"%@\" but was expecting type \"%@\".", typeName, VoltaFileContentType_UTI );
  }
  self = [super initWithType:typeName error:outError];
  return self;
}


- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self]; FXIssue(98)
  FXDeallocSuper
}


#pragma mark NSDocument overrides


- (void) close
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  FXRelease(mCaptureToolbarItem)
  mCaptureToolbarItem = nil;
  FXRelease(mAnalyzeToolbarItem)
  mAnalyzeToolbarItem = nil;
  FXRelease(mSubcircuitIndicatorToolbarItem)
  mSubcircuitIndicatorToolbarItem = nil;
  FXRelease(mMaximizeSchematicToolbarItem)
  mMaximizeSchematicToolbarItem = nil;
  FXRelease(mOpenClosePlotterToolbarItem)
  mOpenClosePlotterToolbarItem = nil;
  FXRelease(mPlotToolbarItem)
  mPlotToolbarItem = nil;

  FXRelease(mSubcircuitEditor)
  mSubcircuitEditor = nil;

  FXRelease(mDocumentMetaData)
  mDocumentMetaData = nil;

  FXRelease(mNetlistEditor)
  mNetlistEditor = nil;
  [mSchematicEditor closeEditor];
  mSchematicEditor = nil;
  FXRelease(mSchematicEditor)
  mSchematicEditor = nil;
  FXRelease(mCircuitSimulator)
  mCircuitSimulator = nil;

  self.library = nil;

  FXRelease(mSimulationObserver)
  mSimulationObserver = nil;

  FXRelease(mSimulatorView)
  mSimulatorView = nil;

  [super close];
}


- (void) makeWindowControllers
{
  FXVoltaDocumentWindowController* windowController = [[FXVoltaDocumentWindowController alloc] init];
  [windowController setNetlistEditorView:[[self netlistEditor] editorView] withMinimumSize:[[self netlistEditor] minimumViewSize]];
  mSimulatorView = [[FXSimulatorView alloc] initWithFrame:NSMakeRect(0, 0, 100, 200)];
  [windowController setSimulatorView:mSimulatorView withMinimumSize:mSimulatorView.minSize];
  [windowController setSubcircuitEditorView:[[self subcircuitEditor] view]  withMinimumViewSize:[[self subcircuitEditor] minimumViewSize]];
  [windowController setSchematicEditorView:[[self schematicEditor] schematicView] withMinimumSize:[[self schematicEditor] minimumViewSize]];
  [windowController setPlotterView:[[self plotter] view] withMinimumViewSize:[[self plotter] minimumViewSize]];
  [windowController setShouldCloseDocument:YES];
  [self addWindowController:windowController];
  FXRelease(windowController)

  [self initializeDocumentWindow:(FXVoltaDocumentWindow*)[windowController window]];
  [self updateWorkAreasWithCircuitData];
}


#if FXMultipleDocumentContentTypes
+ (NSArray*) writableTypes
{
  return @[VoltaFileContentType_Circuit, VoltaFileContentType_Subcircuit];
}


- (NSArray*) writableTypesForSaveOperation:(NSSaveOperationType)saveOperation
{
  return @[self.fileType]; // returning a single item prevents the save panel from showing the file format selection popup button
}
#endif


- (BOOL) readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
  BOOL success = NO;
  NSData* fileData = [NSData dataWithContentsOfURL:absoluteURL];
  [[self undoManager] disableUndoRegistration];

  if ( [typeName isEqualToString:VoltaFileContentType_Generic]
  #if FXMultipleDocumentContentTypes
    || [typeName isEqualToString:VoltaFileContentType_Circuit]
    || [typeName isEqualToString:VoltaFileContentType_Circuit_Legacy]
    || [typeName isEqualToString:VoltaFileContentType_Subcircuit]
    || [typeName isEqualToString:VoltaFileContentType_Subcircuit_Legacy]
  #else
    || [typeName isEqualToString:VoltaFileContentType_UTI]
    || [typeName isEqualToString:VoltaFileContentType_UTI_Legacy]
  #endif
      )
  {
    self.fileType = VoltaFileContentType_UTI;
    NSString* circuitDescription = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    FXAutorelease(circuitDescription)
    BOOL upgraded = NO;
    mCircuitData = [FXVoltaArchiver unarchiveCircuitFromString:circuitDescription formatUpgradedWhileUnarchiving:&upgraded error:outError];
    success = ( mCircuitData.get() != nullptr );
    if ( success && upgraded )
    {
      if ( [self userAllowsUpgradingArchivedCircuitAtLocation:absoluteURL] && [absoluteURL isFileURL] )
      {
        NSString* archivedUpgradedCircuit = [FXVoltaArchiver archiveCircuit:mCircuitData];
        [archivedUpgradedCircuit writeToURL:absoluteURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
      }
      else
      {
        success = NO;
      }
    }
  }
  else if ( [typeName isEqualToString:VoltaFileContentType_Netlist] )
  {
    self.fileType = VoltaFileContentType_UTI;
    mCircuitData = VoltaPTCircuitPtr( new VoltaPTCircuit );
    NSString* netlist = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    if ( netlist != nil )
    {
      mCircuitData->metaData.push_back( VoltaPTMetaDataItem( FXString((__bridge CFStringRef)FXVolta_Netlist), FXString((__bridge CFStringRef)netlist) ) );
      mCircuitData->metaData.push_back( VoltaPTMetaDataItem( FXString((__bridge CFStringRef)FXVoltaMac_SchematicEditorRelativeWidth), FXString("0") ) );
      success = YES;
    }
  }

  [[self undoManager] enableUndoRegistration];
  return success;
}


- (NSFileWrapper*) fileWrapperOfType:(NSString*)typeName error:(NSError **)outError
{
  NSData* fileData = nil;
  if ( [typeName isEqualToString:VoltaFileContentType_Generic]
  #if FXMultipleDocumentContentTypes
    || [typeName isEqualToString:VoltaFileContentType_Circuit]
    || [typeName isEqualToString:VoltaFileContentType_Subcircuit]
  #else
    || [typeName isEqualToString:VoltaFileContentType_UTI]
  #endif
    )
  {
  #if 1 || FXMultipleDocumentContentTypes
    if ( [typeName isEqualToString:VoltaFileContentType_Generic] )
    {
      DebugLog(@"Huh!? We shouldn't write out files with the generic content type name \"%@\".", VoltaFileContentType_Generic);
    }
  #endif
    VoltaPTCircuitPtr circuitData = [self collectCircuitDataForArchiving];
    if ( circuitData.get() != nullptr )
    {
      NSString* archiveContents = [FXVoltaArchiver archiveCircuit:circuitData];
      NSUInteger const dataLength = [archiveContents lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
      void* dataBuffer = malloc(dataLength);
      [archiveContents getBytes:dataBuffer maxLength:dataLength usedLength:NULL encoding:NSUTF8StringEncoding options:0 range:NSMakeRange(0, [archiveContents length]) remainingRange:NULL];
      fileData = [NSData dataWithBytesNoCopy:dataBuffer length:dataLength];
    }
  }
  NSFileWrapper* fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:fileData];
  FXAutorelease(fileWrapper)
  return fileWrapper;
}


- (BOOL) revertToContentsOfURL:(NSURL*)url ofType:(NSString*)typeName error:(NSError**)outError
{
  if ( [super revertToContentsOfURL:url ofType:typeName error:outError] )
  {
    [[self circuitDocumentWindowController] prepareToRevertToOtherDocument];
    [self restoreCircuitData]; FXIssue(225)
    return YES;
  }
  return NO;
}


- (BOOL) hasUndoManager
{
  return YES;
}


#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
+ (BOOL) autosavesInPlace
{
  return YES;
}
#endif


#if VOLTA_SUPPORTS_ASYNCHRONOUS_SAVING
- (BOOL) canAsynchronouslyWriteToURL:(NSURL*)url
                              ofType:(NSString*)typeName
                    forSaveOperation:(NSSaveOperationType)saveOperation
{
  return [typeName isEqualToString:VoltaFileTypeName];
}
#endif


#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
+ (BOOL) canConcurrentlyReadDocumentsOfType:(NSString*)typeName
{
  // Concurrency depends on whether accessing the library is thread-safe.
  return NO; //[typeName isEqualToString:VoltaFileTypeName];
}
#endif


#if 0 && VOLTA_SUPPORTS_RESUME
- (void) restoreDocumentWindowWithIdentifier:(NSString *)identifier
                                       state:(NSCoder *)state
                           completionHandler:(void (^)(NSWindow *, NSError *))handler
{
  NSWindow* restoredWindow = nil;
  if ( [identifier isEqualToString:FXVoltaCircuitDocumentWindowIdentifier] )
  {
    [self makeWindowControllers];
    restoredWindow = [[self circuitDocumentWindowController] window];
  }
  handler( restoredWindow, nil );
}
#endif


NSString* FXResume_DocumentShowsSimulationResults = @"FXResume_DocumentShowsSimulationResults";

- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  FXIssue(177)
  [super encodeRestorableStateWithCoder:state];
  [[self schematicEditor] encodeRestorableState:state];
  BOOL const hasSimulationResults = [mSimulatorView hasSimulationResults];
  [state encodeBool:hasSimulationResults forKey:FXResume_DocumentShowsSimulationResults];
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  FXIssue(177)
  [super restoreStateWithCoder:state];
  [[self schematicEditor] restoreState:state];
  if ( [state decodeBoolForKey:FXResume_DocumentShowsSimulationResults] )
  {
    [self startOrStopSimulationWithError:NULL];
  }
}


- (NSPrintOperation*) printOperationWithSettings:(NSDictionary*)printSettings error:(NSError **)outError
{
  FXIssue(73)
  NSPrintInfo* printInfo = self.printInfo;
  [[printInfo dictionary] addEntriesFromDictionary:printSettings];
  NSArray* printables = @[self.schematicEditor, self.plotter]; // Supporting the netlist editor is too much work at the moment and probably requires using Text Kit.
  NSString* title = [self.displayName stringByDeletingPathExtension];
  FXVoltaDocumentPrintingViewController* printingController = [[FXVoltaDocumentPrintingViewController alloc] initWithPrintables:printables printInfo:printInfo title:title];
  NSPrintOperation* printOperation = [NSPrintOperation printOperationWithView:printingController.printPreviewView printInfo:printInfo];
  printOperation.canSpawnSeparateThread = NO;
  [[printOperation printPanel] addAccessoryController:printingController];
  FXRelease(printingController)
  return printOperation;
}


- (BOOL) presentError:(NSError*)error
{
  NSAlert* alert = [NSAlert alertWithError:error];
  [alert beginSheetModalForWindow:[[self circuitDocumentWindowController] window] completionHandler:^(NSModalResponse returnCode) {
    /* do nothing */
  }];
  return YES;
}


////////////////////////////////////////////////////////////////////////////////
#pragma mark NSToolbarDelegate


- (NSArray*) toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
  return [self toolbarDefaultItemIdentifiers:toolbar];
}


- (NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
  NSMutableArray* toolbarLayout = [NSMutableArray array];

  // Built-in toolbar items
  [toolbarLayout addObject:VoltaDocumentToolbarItemIdentifier_Plot];
  [toolbarLayout addObject:VoltaDocumentToolbarItemIdentifier_Capture];
  [toolbarLayout addObject:VoltaDocumentToolbarItemIdentifier_Run];

  [toolbarLayout addObject:NSToolbarSpaceItemIdentifier];

  // Schematic editor toolbar items
  id<VoltaSchematicEditor> schematicEditor = [self schematicEditor];
  if ( schematicEditor != nil )
  {
    NSArray* schematicToolbarItems = [schematicEditor toolbarItems];
    if ( schematicToolbarItems != nil )
    {
      for ( NSToolbarItem* item in schematicToolbarItems )
      {
        [toolbarLayout addObject:[item itemIdentifier]];
      }
    }
  }

  [toolbarLayout addObject:NSToolbarFlexibleSpaceItemIdentifier];
  [toolbarLayout addObject:VoltaDocumentToolbarItemIdentifier_SubcircuitIndicator];
  [toolbarLayout addObject:VoltaDocumentToolbarItemIdentifier_OpenClosePlotter];
  [toolbarLayout addObject:VoltaDocumentToolbarItemIdentifier_MaximizeSchematic];
  return toolbarLayout;
}


- (NSToolbarItem*) toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
  NSToolbarItem* requestedItem = nil;

  if ([itemIdentifier isEqualToString:VoltaDocumentToolbarItemIdentifier_Plot])
  {
    FXIssue(62)
    if (mPlotToolbarItem == nil)
    {
      mPlotToolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:VoltaDocumentToolbarItemIdentifier_Plot];
      mPlotToolbarItem.label = FXLocalizedString(@"WorkflowAction_Plot");
      mPlotToolbarItem.action = @selector(handleToolbarAction_Plot:);
      mPlotToolbarItem.target = self;
      mPlotToolbarItem.toolTip = FXLocalizedString(@"ToolbarItemToolTip_Plot");
      NSImage* toolbarImage = [NSImage imageNamed:@"document_plot.png"];
      NSAssert( toolbarImage != nil, @"The plot image is missing." );
      mPlotToolbarItem.image = toolbarImage;
    }
    requestedItem = mPlotToolbarItem;
  }
  else if ([itemIdentifier isEqualToString:VoltaDocumentToolbarItemIdentifier_Capture])
  {
    if (mCaptureToolbarItem == nil)
    {
      mCaptureToolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:VoltaDocumentToolbarItemIdentifier_Capture];
      mCaptureToolbarItem.label = FXLocalizedString(@"WorkflowAction_Capture");
      mCaptureToolbarItem.action = @selector(handleToolbarAction_Capture:);
      mCaptureToolbarItem.target = self;
      mCaptureToolbarItem.toolTip = FXLocalizedString(@"ToolbarItemToolTip_Capture");
      NSImage* toolbarImage = [NSImage imageNamed:@"document_schematic_capture.png"];
      NSAssert( toolbarImage != nil, @"The schematic capture image is missing." );
      [mCaptureToolbarItem setImage:toolbarImage];
    }
    requestedItem = mCaptureToolbarItem;
  }
  else if ([itemIdentifier isEqualToString:VoltaDocumentToolbarItemIdentifier_Run])
  {
    if (mAnalyzeToolbarItem == nil)
    {
      mAnalyzeToolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:VoltaDocumentToolbarItemIdentifier_Capture];
      mAnalyzeToolbarItem.label = FXLocalizedString(@"WorkflowAction_Analyze");
      mAnalyzeToolbarItem.toolTip = FXLocalizedString(@"ToolbarItemToolTip_Analyze");
      FXAnimatedGearWheelButton* gears = [[FXAnimatedGearWheelButton alloc] initWithFrame:NSMakeRect(0,0,32,32)];
      gears.action = @selector(handleToolbarAction_Analyze:);
      gears.target = self;
      gears.enabled = YES;
      mAnalyzeToolbarItem.view = gears;
      FXRelease(gears)
    }
    requestedItem = mAnalyzeToolbarItem;
  }
  else if ( [itemIdentifier isEqualToString:VoltaDocumentToolbarItemIdentifier_OpenClosePlotter] )
  {
    if ( mOpenClosePlotterToolbarItem == nil )
    {
      mOpenClosePlotterToolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:VoltaDocumentToolbarItemIdentifier_OpenClosePlotter];
      mOpenClosePlotterToolbarItem.label = @"";
      mOpenClosePlotterToolbarItem.action = @selector(togglePlotterPanel:);
      mOpenClosePlotterToolbarItem.target = [self circuitDocumentWindowController];
      mOpenClosePlotterToolbarItem.toolTip = FXLocalizedString(@"ToolbarItemToolTip_TogglePlotter");
      NSImage* toolbarImage = [NSImage imageNamed:@"document_plotter_open_close.png"];
      NSAssert( toolbarImage != nil, @"The plotter open/close image is missing." );
      mOpenClosePlotterToolbarItem.image = toolbarImage;
    }
    requestedItem = mOpenClosePlotterToolbarItem;
  }
  else if ( [itemIdentifier isEqualToString:VoltaDocumentToolbarItemIdentifier_SubcircuitIndicator] )
  {
    if ( mSubcircuitIndicatorToolbarItem == nil )
    {
      mSubcircuitIndicatorToolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:VoltaDocumentToolbarItemIdentifier_SubcircuitIndicator];
      mSubcircuitIndicatorToolbarItem.label = @"";
      mSubcircuitIndicatorToolbarItem.toolTip = FXLocalizedString(@"ToolbarItemToolTip_SubcircuitEditor");
      mSubcircuitIndicatorImage = [NSImage imageNamed:@"document_subcircuit_indicator.png"];
      FXRetain(mSubcircuitIndicatorImage)
      NSAssert( mSubcircuitIndicatorImage != nil, @"The subcircuit indicator image is missing." );
      mSubcircuitIndicatorToolbarItem.image = nil;
    }
    requestedItem = mSubcircuitIndicatorToolbarItem;
  }
  else if ( [itemIdentifier isEqualToString:VoltaDocumentToolbarItemIdentifier_MaximizeSchematic] )
  {
    FXIssue(08)
    if ( mMaximizeSchematicToolbarItem == nil )
    {
      mMaximizeSchematicToolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:VoltaDocumentToolbarItemIdentifier_MaximizeSchematic];
      [mMaximizeSchematicToolbarItem setLabel:@""];
      [mMaximizeSchematicToolbarItem setAction:@selector(toggleCircuitProcessorsPanel:)];
      [mMaximizeSchematicToolbarItem setTarget:[self circuitDocumentWindowController]];
      [mMaximizeSchematicToolbarItem setToolTip:FXLocalizedString(@"ToolbarItemToolTip_ToggleNetlist")];
      NSImage* toolbarImage = [NSImage imageNamed:@"document_schematic_maximize"];
      NSAssert( toolbarImage != nil, @"The netlist open/close image is missing." );
      [mMaximizeSchematicToolbarItem setImage:toolbarImage];
    }
    requestedItem = mMaximizeSchematicToolbarItem;
  }
	else
	{
		// Check if the schematic editor has the requested item
		id<VoltaSchematicEditor> schematicEditor = [self schematicEditor];
		NSArray* schematicToolbarItems = [schematicEditor toolbarItems];
		for ( NSToolbarItem* item in schematicToolbarItems )
		{
			if ( [[item itemIdentifier] isEqualToString:itemIdentifier] )
			{
				requestedItem = item;
				break;
			}
		}
	}

	return requestedItem;
}


- (BOOL) validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	BOOL enable = YES;
#if 0
	if ( [[toolbarItem itemIdentifier] isEqualToString:VoltaDocumentToolbarItemIdentifier_Capture] )
	{
		enable = YES;
	}
	else if ( [[toolbarItem itemIdentifier] isEqualToString:VoltaDocumentToolbarItemIdentifier_Run] )
	{
		enable = YES;
	}
#endif
	return enable;
}


#pragma mark VoltaSubcircuitEditorClient


- (void) subcircuitEditor:(id<VoltaSubcircuitEditor>)editor changedActivationState:(BOOL)active
{
  if ( editor == mSubcircuitEditor )
  {
    [self showSubcircuitIndicator:active];
  #if FXMultipleDocumentContentTypes
    [self setFileType:(active ? VoltaFileContentType_Subcircuit : VoltaFileContentType_Circuit)];
  #endif
  }
}


#pragma mark Public


- (void) setLibrary:(id<VoltaLibrary>)library
{
  if ( library != mLibrary )
  {
    FXRelease(mLibrary)
    mLibrary = library;
    FXRetain(mLibrary)

    [[self schematicEditor] setLibrary:mLibrary];
  }
}


+ (NSArray*) mainMenuItems
{
  NSMenuItem* plot = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"WorkflowAction_Plot") action:@selector(handleToolbarAction_Plot:) keyEquivalent:@"p"];
  [plot setKeyEquivalentModifierMask:(NSEventModifierFlagCommand|NSEventModifierFlagOption)];
  NSMenuItem* capture = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"WorkflowAction_Capture") action:@selector(handleToolbarAction_Capture:) keyEquivalent:@"c"];
  [capture setKeyEquivalentModifierMask:(NSEventModifierFlagCommand|NSEventModifierFlagOption)];
  NSMenuItem* analyze = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"WorkflowAction_Analyze") action:@selector(handleToolbarAction_Analyze:) keyEquivalent:@"a"];
  [analyze setKeyEquivalentModifierMask:(NSEventModifierFlagCommand|NSEventModifierFlagOption)];
  NSArray* result = @[plot, capture, analyze];
  FXRelease(plot)
  FXRelease(capture)
  FXRelease(analyze)
  return result;
}


#pragma mark Private


- (id<VoltaNetlistEditor>) netlistEditor
{
  if ( mNetlistEditor == nil )
  {
    NSObject* newNetlistEditorPlugin = [[[FXVoltaPluginsController sharedController] activePluginForType:VoltaPluginType_NetlistEditor] newPluginImplementer];
    NSAssert( (newNetlistEditorPlugin != nil) && [newNetlistEditorPlugin conformsToProtocol:@protocol(VoltaNetlistEditor)], @"Got wrong plugin." );
    mNetlistEditor = (id<VoltaNetlistEditor>) newNetlistEditorPlugin;
    [mNetlistEditor setUndoManager:[self undoManager]];
  }
  return mNetlistEditor;
}


- (id<VoltaSchematicEditor>) schematicEditor
{
  if ( mSchematicEditor == nil )
  {
    NSObject* newSchematicEditor = [[[FXVoltaPluginsController sharedController] activePluginForType:VoltaPluginType_SchematicEditor] newPluginImplementer];
    NSAssert( (newSchematicEditor != nil) && [newSchematicEditor conformsToProtocol:@protocol(VoltaSchematicEditor)], @"Got wrong plugin." );
    mSchematicEditor = (id<VoltaSchematicEditor>) newSchematicEditor;
    [mSchematicEditor setUndoManager:[self undoManager]];
  }
  return mSchematicEditor;
}


- (id<VoltaCircuitSimulator>) circuitSimulator
{
  if ( mCircuitSimulator == nil )
  {
    NSObject* newCircuitSimulatorPlugin = [[[FXVoltaPluginsController sharedController] activePluginForType:VoltaPluginType_Simulator] newPluginImplementer];
    NSAssert( (newCircuitSimulatorPlugin != nil) && [newCircuitSimulatorPlugin conformsToProtocol:@protocol(VoltaCircuitSimulator)], @"Got wrong plugin." );
    mCircuitSimulator = (id<VoltaCircuitSimulator>) newCircuitSimulatorPlugin;
  }
  return mCircuitSimulator;
}


- (id<VoltaPlotter>) plotter
{
  if ( mPlotter == nil )
  {
    NSObject* newPlotterPluginInstance = [[[FXVoltaPluginsController sharedController] activePluginForType:VoltaPluginType_Plotter] newPluginImplementer];
    NSAssert( (newPlotterPluginInstance != nil) && [newPlotterPluginInstance conformsToProtocol:@protocol(VoltaPlotter)], @"Got wrong plugin." );
    mPlotter = (id<VoltaPlotter>) newPlotterPluginInstance;
  }
  return mPlotter;
}


- (id<VoltaSubcircuitEditor>) subcircuitEditor
{
  if ( mSubcircuitEditor == nil )
  {
    mSubcircuitEditor = (id<VoltaSubcircuitEditor>)[[[FXVoltaPluginsController sharedController] activePluginForType:VoltaPluginType_SubcircuitEditor] newPluginImplementer];
    NSAssert( mSubcircuitEditor != nil, @"Could not load subcircuit editor plugin." );
    [mSubcircuitEditor setUndoManager:[self undoManager]];
    [mSubcircuitEditor setClient:self];
  }
  return mSubcircuitEditor;
}


- (void) handleToolbarAction_Capture:(id)sender
{
  [[self plotter] clear];
  [mSimulatorView clearOutput];
  [self convertSchematicToNetlist:YES];
}


- (void) handleToolbarAction_Plot:(id)sender
{
  [[self plotter] clear];
  [mSimulatorView clearOutput];
  NSError* error = nil;
  if ( ![self convertRunAndPlotWithError:&error] )
  {
    if ( error != nil )
    {
      [self presentError:error];
    }
  }
}


- (void) handleToolbarAction_Analyze:(id)sender
{
  NSError* error = nil;
  [[self plotter] clear];
  [mSimulatorView clearOutput];
  if ( ![self startOrStopSimulationWithError:&error] )
  {
    if ( error != nil )
    {
      [self presentError:error];
    }
  }
}


/// @return YES if successful
/// @param revealResult if YES the netlist editor will be revealed after the conversion
- (BOOL) convertSchematicToNetlist:(BOOL)revealResult
{
  BOOL success = NO;
  id<VoltaSchematicEditor> schematicEditor = [self schematicEditor];
  if ( (schematicEditor != nil) )
  {
    VoltaPTSchematicPtr schematicData = [schematicEditor capture];
    if ( schematicData->elements.empty() )
    {
      NSWindow* window = [[self circuitDocumentWindowController] window];
      NSAlert* alert = [[NSAlert alloc] init];
      alert.messageText = FXLocalizedString(@"WorkflowAction_Capture");
      alert.informativeText = FXLocalizedString(@"CapturingEmptySchematicMessage");
      [alert addButtonWithTitle:FXLocalizedString(@"OK")];
      [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        /* do nothing */
      }];
    }
    else
    {
      VoltaPTSubcircuitDataPtr subcircuitData = [[self subcircuitEditor] subcircuitData];
      FXSchematicToNetlistConversionResult conversionResult = FXSchematicToNetlistConverter::convert(schematicData, subcircuitData, mLibrary);
      FXString allErrors;
      for( FXString const & errorMessage : conversionResult.errors )
      {
        allErrors = allErrors + FXString("Error: ").localize(@"ConversionErrors") + errorMessage + "\n";
      }

      success = allErrors.empty();

      NSString* newNetlist = success ? (__bridge NSString*)conversionResult.output.cfString() : [NSString stringWithFormat:@"%@\n%@", conversionResult.output.cfString(), allErrors.cfString()];
      id<VoltaNetlistEditor> myNetlistEditor = [self netlistEditor];
      if ( myNetlistEditor != nil )
      {
        NSString* currentNetlist = [[myNetlistEditor netlistString] copy]; // note: making a copy is important
        if ( (currentNetlist == nil) || ![currentNetlist isEqualToString:newNetlist] )
        {
          FXIssue(46)
          [[self undoManager] registerUndoWithTarget:self selector:@selector(undoRedoSchematicToNetlist:) object:((currentNetlist != nil) ? currentNetlist : @"")];
          [[self undoManager] setActionName:FXLocalizedString(@"Action_capture")];

          [myNetlistEditor setNetlistString:newNetlist];
        }
        FXRelease(currentNetlist)

        FXIssue(95)
        if ( revealResult && ([newNetlist length] > 0) )
        {
          [[self circuitDocumentWindowController] revealNetlistEditor];
        }
      }
    }
  }
  return success;
}


/// @return YES if successful
- (BOOL) startOrStopSimulationWithError:(NSError**)simulationError
{
  BOOL success = NO;
  id<VoltaCircuitSimulator> simulator = [self circuitSimulator];
  if ( simulator == nil )
  {
    if ( simulationError != NULL )
    {
      *simulationError = [FXVoltaError errorWithCode:FXVoltaError_NoSimulator];
    }
  }
  else
  {
    if ( [mSimulationObserver currentSimulation] == VoltaInvalidSimulationID )
    {
      // Starting a simulation.
      [mSimulationObserver reset];

      VoltaCircuitID circuit = [simulator createCircuit];
      id circuitData = nil;
          
      switch ( [simulator circuitDescriptionType] )
      {
        case VoltaCDT_SPICE3:
        case VoltaCDT_PSPICE:
        case VoltaCDT_Gnucap:
        {
          NSString* netlistString = [[self netlistEditor] netlistString];
          if ( [netlistString length] == 0 )
          {
            if ( simulationError != NULL )
            {
              *simulationError = [FXVoltaError errorWithCode:FXVoltaError_NoSimulatorInput];
            }
            return NO;
          }
          circuitData = [netlistString copy];
          FXAutorelease(circuitData)
        }
        default:
          break;
      }
      if ( circuitData != nil )
      {
        if ( [simulator setDescription:(void*)circuitData forCircuit:circuit error:simulationError] )
        {
          VoltaSimulationID newSimulation = [simulator createSimulation:circuit];
          [mSimulationObserver setCurrentSimulation:newSimulation];
          [simulator setObserver:mSimulationObserver forSimulation:newSimulation];
          if ( [simulator startSimulation:newSimulation error:simulationError] )
          {
            [mSimulatorView clearOutput];
            NSView* toolbarView = [mAnalyzeToolbarItem view];
            if ( [toolbarView isKindOfClass:[FXAnimatedGearWheelButton class]] )
            {
              FXAnimatedGearWheelButton* gearWheelButton = (FXAnimatedGearWheelButton*)toolbarView;
              [gearWheelButton startAnimation];
            }
            success = YES;
          }
          else
          {
            [mSimulationObserver setCurrentSimulation:VoltaInvalidSimulationID];
          }
        }
      }
    }
    else
    {
      // Stopping the current running simulation

      if  ( [simulator stopSimulation:[mSimulationObserver currentSimulation] error:simulationError] )
      {
        if ( [simulator simulationExists:[mSimulationObserver currentSimulation]] )
        {
          // Hmm.. Apparently @selector(simulator:finishedSimulation:) was not called, so we need to clean up here.
          [simulator removeSimulation:[mSimulationObserver currentSimulation]];
        }
        [mSimulationObserver setCurrentSimulation:VoltaInvalidSimulationID];

        // Stop the GUI animation
        NSView* toolbarView = [mAnalyzeToolbarItem view];
        if ( [toolbarView isKindOfClass:[FXAnimatedGearWheelButton class]] )
        {
          FXAnimatedGearWheelButton* gearWheelButton = (FXAnimatedGearWheelButton*)toolbarView;
          [gearWheelButton stopAnimation];
        }

        success = YES;
      }
    }
  }
  return success;
}


/// @return YES if successful
- (BOOL) convertRunAndPlotWithError:(NSError**)error
{
  BOOL success = NO;
  if ( ![self convertSchematicToNetlist:NO] )
  {
    [[self circuitDocumentWindowController] revealNetlistEditor];
  }
  else if ( [self startOrStopSimulationWithError:error] )
  {
    success = YES;
  }
  return success;
}


- (VoltaPTCircuitPtr) collectCircuitDataForArchiving
{
#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
  // Currently, this data collection operation finishes very quickly.
  // If, in the future, it should take longer to save a document we
  // should check for user activity and abort if we are in implicit cancellable mode
  //    [self autosavingIsImplicitlyCancellable]
#endif
  VoltaPTCircuitPtr circuitData( new VoltaPTCircuit );
  circuitData->schematicData = [[self schematicEditor] capture];
  circuitData->subcircuitData = [[self subcircuitEditor] subcircuitData];

  {
    FXIssue(223)
    BOOL const isSubcircuitWithSchematic = circuitData->subcircuitData->enabled && !circuitData->schematicData->elements.empty();
    BOOL const netlistIsEmpty = ([[[self netlistEditor] netlistString] length] == 0);
    if ( isSubcircuitWithSchematic && netlistIsEmpty )
    {
      [[self undoManager] disableUndoRegistration];
      [self convertSchematicToNetlist:NO];
      [[self undoManager] enableUndoRegistration];
    }
  }

  [self collectDocumentSettings];
  [mDocumentMetaData enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop)
   {
     VoltaPTMetaDataItem metaDataItem;
     metaDataItem.first = (__bridge CFStringRef)key;
     metaDataItem.second = (__bridge CFStringRef)value;
     circuitData->metaData.push_back( metaDataItem );
   }];

  return circuitData;
}


- (void) collectDocumentSettingsForNetlist
{
  FXIssue(39)
  @synchronized( mDocumentMetaData )
  {
    NSString* netlistString = [[self netlistEditor] netlistString];
    if ( [netlistString length] > 0 )
    {
      [mDocumentMetaData setValue:netlistString forKey:FXVolta_Netlist];
    }
  }
}


- (void) collectDocumentSettings
{
  FXIssue(12)
  @synchronized( mDocumentMetaData )
  {
    [mDocumentMetaData removeAllObjects];
  }
  [mDocumentMetaData addEntriesFromDictionary:[[self circuitDocumentWindowController] collectDocumentSettings]];
  [self collectDocumentSettingsForNetlist];
}


- (void) applyDocumentSettingsToNetlist
{
  FXIssue(39)
  @synchronized( mDocumentMetaData )
  {
    NSString* netlist = [mDocumentMetaData valueForKey:FXVolta_Netlist];
    if ( netlist != nil )
    {
      [[self netlistEditor] setNetlistString:netlist];
    }
  }
}


- (void) applyDocumentSettings
{
  [[self circuitDocumentWindowController] applyDocumentSettings:mDocumentMetaData];
  [self applyDocumentSettingsToNetlist];
}


- (VoltaPTSchematicPtr) createSchematic
{
  VoltaPTSchematicPtr schematic(new VoltaPTSchematic);
  schematic->properties = FXVoltaCircuitDomainAgent::circuitParameters();
  return schematic;
};


- (void) resetWorkAreas
{
  [[self schematicEditor] setSchematicData:[self createSchematic]];
  [[self netlistEditor] setNetlistString:@""];
  [[self plotter] clear];
  [mSimulatorView clearOutput];
  [[self circuitDocumentWindowController] selectCircuitProcessorsTabWithTitle:FXLocalizedString(@"Simulator")];
}


- (void) updateWorkAreasWithCircuitData
{
  [self resetWorkAreas];

  if ( mCircuitData.get() != nullptr )
  {
  #if FXMultipleDocumentContentTypes
    [self setFileType:VoltaFileContentType_Circuit];
  #endif

    if ( mCircuitData->schematicData.get() != nullptr )
    {
      [[self schematicEditor] setSchematicData:mCircuitData->schematicData];
      [[[self schematicEditor] schematicView] setNeedsDisplay:YES];
    }
    
    if ( mCircuitData->subcircuitData.get() != nullptr )
    {
      [[self subcircuitEditor] setSubcircuitData:mCircuitData->subcircuitData];
      if ( mCircuitData->subcircuitData->enabled )
      {
        [self showSubcircuitIndicator:YES];
      #if FXMultipleDocumentContentTypes
        [self setFileType:VoltaFileContentType_Subcircuit];
      #endif
      }
    }

    FXIssue(95)
    if ( [[self subcircuitEditor] subcircuitData]->enabled )
    {
      [[self circuitDocumentWindowController] selectCircuitProcessorsTabWithTitle:FXLocalizedString(@"Subcircuit")];
    }

    for( VoltaPTMetaDataItem& metaDataItem : mCircuitData->metaData )
    {
      NSString* itemKey = (__bridge NSString*) metaDataItem.first.cfString();
      NSString* itemValue = [NSString stringWithString:(__bridge NSString*)metaDataItem.second.cfString()];
      //DebugLog( @"meta data: %@ -> %@", itemKey, itemValue );
      [mDocumentMetaData setValue:itemValue forKey:itemKey];
    }
  }

  [self applyDocumentSettings];
}


- (void) restoreCircuitData
{
  [self updateWorkAreasWithCircuitData];
}


- (void) updateDocumentEditedStatus:(NSNotification*)notification
{
  [[self circuitDocumentWindowController] setDocumentEdited:[self isDocumentEdited]]; FXIssue(32)
}


- (void) undoRedoSchematicToNetlist:(NSString*)newNetlist
{
  FXIssue(46)
  if ([self netlistEditor] != nil)
  {
    if (newNetlist == nil)
    {
      newNetlist = @"";
    }
    NSString* currentNetlist = [[[self netlistEditor] netlistString] copy]; // note: making a copy is important
    if ( ![newNetlist isEqualToString:currentNetlist] )
    {
      [[self undoManager] registerUndoWithTarget:self selector:@selector(undoRedoSchematicToNetlist:) object:currentNetlist];
      [[self undoManager] setActionName:FXLocalizedString(@"Action_capture")];
      [[self netlistEditor] setNetlistString:newNetlist];

      [self updateDocumentEditedStatus:nil];
    }
    FXRelease(currentNetlist)
  }
}


- (void) initializeDocumentWindow:(FXVoltaDocumentWindow*)window
{
  [self createToolbarForWindow:window];

  FXIssue(37)
  // This is also needed to make sure the actions of schematic-related menu items (in the main menu) are handled.
  [window makeFirstResponder:[[self schematicEditor] schematicView]];

#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(handleWindowWillEnterVersionBrowser:) name:NSWindowWillEnterVersionBrowserNotification object:window];
  [notificationCenter addObserver:self selector:@selector(handleWindowWillExitVersionBrowser:) name:NSWindowWillExitVersionBrowserNotification object:window];
  if ( [self isInViewingMode] )
  {
    window.toolbar.visible = NO;
    [[self schematicEditor] enterViewingModeWithAnimation:NO];
  }
#endif
}


- (void) createToolbarForWindow:(NSWindow*)window
{
  // In Volta, toolbars of different documents are not synced. Therefore, each has a separate identifier.
  static NSUInteger toolbarCounter = 1;
  static NSString* VoltaDocumentToolbarIdentifier = @"VoltaDocumentWindowToolbar";
  NSString* toolbarIdentifier = [NSString stringWithFormat:@"%@%ld", VoltaDocumentToolbarIdentifier, toolbarCounter++];
  NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:toolbarIdentifier];
  toolbar.allowsUserCustomization = NO;
  toolbar.autosavesConfiguration = NO;
  toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
  toolbar.sizeMode = NSToolbarSizeModeRegular;
  toolbar.delegate = self;
  [window setToolbar:toolbar];
  FXRelease(toolbar)
}


- (FXVoltaDocumentWindowController*) circuitDocumentWindowController
{
  NSArray* docWindowControllers = [self windowControllers];
  NSAssert( [docWindowControllers count] == 1, @"A Volta document has only one window." );
  return [docWindowControllers lastObject];
}


- (void) showSubcircuitIndicator:(BOOL)show
{
  mSubcircuitIndicatorToolbarItem.image = show ? mSubcircuitIndicatorImage : nil;
  mSubcircuitIndicatorToolbarItem.action = show ? @selector(revealSubcircuitEditor:) : 0;
  mSubcircuitIndicatorToolbarItem.target = show ? [self circuitDocumentWindowController] : nil;
}


- (void) handleSimulationHasFinishedNotification:(NSNotification*)notification
{
  FXSimulationObserver* simulationObserver = [notification object];
  NSAssert( (simulationObserver != nil) && [simulationObserver isKindOfClass:[FXSimulationObserver class]], @"Invalid notification object" );
  [mSimulatorView showOutput:[simulationObserver currentSimulationRawResults]];

  // Stopping GUI animation
  {
    NSView* toolbarView = [mAnalyzeToolbarItem view];
    if ( [toolbarView isKindOfClass:[FXAnimatedGearWheelButton class]] )
    {
      FXAnimatedGearWheelButton* gearWheelButton = (FXAnimatedGearWheelButton*)toolbarView;
      [gearWheelButton stopAnimation];
    }
  }

  if ( [mSimulationObserver currentSimulationResults]->analyses.empty() )
  {
    // Probably an error occurred. Displaying raw simulator output.
    [[self plotter] clear];
    [[self circuitDocumentWindowController] revealSimulatorOutput];
  }
  else
  {
    [[self plotter] setSimulationData:[mSimulationObserver currentSimulationResults]];
    [[self circuitDocumentWindowController] revealPlotter];
  }
}


#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
- (void) handleWindowWillEnterVersionBrowser:(NSNotification*)notification
{
  FXIssue(220)
  [[self schematicEditor] enterViewingModeWithAnimation:NO];
}


- (void) handleWindowWillExitVersionBrowser:(NSNotification*)notification
{
  FXIssue(220)
  [[self schematicEditor] exitViewingModeWithAnimation:NO];
}
#endif


- (BOOL) userAllowsUpgradingArchivedCircuitAtLocation:(NSURL*)circuitDocumentLocation
{
  BOOL result = YES;
  if ( ![[[NSUserDefaults standardUserDefaults] objectForKey:FXDocumentUpgradeWithoutAsking] boolValue] )
  {
    NSString* fileName = (circuitDocumentLocation != nil) ? [circuitDocumentLocation lastPathComponent] : @"";
    BOOL const withSource = ([fileName length] > 0);
    NSString* title = withSource ? [NSString stringWithFormat:FXLocalizedString(@"ArchiveUpgradePrompt_Title"), fileName] : FXLocalizedString(@"ArchiveUpgradePrompt_Title_Without_Source");
    NSString* message = withSource ? [NSString stringWithFormat:FXLocalizedString(@"ArchiveUpgradePrompt_Message"), fileName] : FXLocalizedString(@"ArchiveUpgradePrompt_Message_Without_Source");
    NSString* upgradeButtonTitle = FXLocalizedString(@"ArchiveUpgradePrompt_Upgrade");
    NSString* alwaysButtonTitle = FXLocalizedString(@"ArchiveUpgradePrompt_AlwaysUpgrade");
    NSString* abortButtonTitle = FXLocalizedString(@"ArchiveUpgradePrompt_Abort");
    NSAlert* upgradeAlert = [[NSAlert alloc] init];
    upgradeAlert.messageText = title;
    upgradeAlert.informativeText = message;
    [upgradeAlert addButtonWithTitle:upgradeButtonTitle];
    [upgradeAlert addButtonWithTitle:abortButtonTitle];
    [upgradeAlert addButtonWithTitle:alwaysButtonTitle];
    //NSAlert* upgradeAlert = [NSAlert alertWithMessageText:title defaultButton:upgradeButtonTitle alternateButton:abortButtonTitle otherButton:alwaysButtonTitle informativeTextWithFormat:@"%@", message];
    FXDocumentUpgradeDialogAccessoryView* accessoryView = [FXDocumentUpgradeDialogAccessoryView new];
    accessoryView.filePath = circuitDocumentLocation;
    accessoryView.translatesAutoresizingMaskIntoConstraints = NO;
    upgradeAlert.accessoryView = accessoryView;
    FXRelease(accessoryView)
    NSInteger userChoice = [upgradeAlert runModal];
    if ( userChoice == NSAlertThirdButtonReturn )
    {
      [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:FXDocumentUpgradeWithoutAsking];
    }
    else if ( userChoice == NSAlertSecondButtonReturn )
    {
      result = NO;
    }
  }
  return result;
}


@end
