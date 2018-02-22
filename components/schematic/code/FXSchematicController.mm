#import "FXSchematicController.h"
#import "FXSchematic.h"
#import "FXSchematicUndoManager.h"
#import "FXSchematicTool.h"
#import "FXSchematicPaletteController.h"
#import "FXSchematicInspectorController.h"
#import "FXSchematicView.h"
#import "FXSchematicCapture.h"
#import "FXSchematicElement.h"
#import "FXSchematicElementGroup.h"
#import "FXSchematicConnector.h"
#import "FXSchematicPainter.h"
#import "FXSchematicUtilities.h"
#import "FXModel.h"
#import "FXElement.h"
#import "FXPath.h"
#import "FXCircle.h"
#import "FXShape.h"
#import "FXShapeRenderer.h"
#import "FXShapeConnectionPoint.h"
#import "FXAutoTool.h"
#import "FXVoltaCircuitDomainAgent.h"
#import "FXVoltaLibraryUtilities.h"


typedef NS_ENUM(NSInteger, FXSchematicUIAction)
{
  FXSchematicUIAction_Undefined = 0,
  FXSchematicUIAction_ToggleInspector,
  FXSchematicUIAction_RotateLeft,
  FXSchematicUIAction_RotateRight,
  FXSchematicUIAction_FlipHorizontally,
  FXSchematicUIAction_FlipVertically
};


static CGFloat const kMaxSchematicZoom = 2.0;
static CGFloat const kMinSchematicZoom = 1.0;
static CGFloat const kSchematicZoomStepSize = 0.25;


#pragma mark -


@interface FXSchematicFlippedView : NSView
@end
@implementation FXSchematicFlippedView
- (BOOL) isFlipped { return YES; }
@end


@interface FXSchematicFlippedClipView : NSClipView
@end
@implementation FXSchematicFlippedClipView
- (BOOL) isFlipped { return YES; }
@end


#pragma mark -


@implementation FXSchematicController
{
@private
  NSView<VoltaSchematicView>*        mSchematicView;
  FXSchematicPaletteController*      mSchematicPalette;
  FXSchematicInspectorController*    mSchematicInspector;

  NSScrollView*                      mSchematicScrollView;
  NSView*                            mSchematicAndInspectorContainerView;
  
  id<VoltaSchematic>                 mSchematic;
  CGRect                             mSchematicBoundingBox;
  FXSchematicUndoManager*            mSchematicUndoManager;
  
  id<FXSchematicTool>                mCurrentTool;
  
  NSToolbarItem*                     mToolbarItem_TogglePalette;
  NSToolbarItem*                     mToolbarItem_ToggleInspector;
  NSToolbarItem*                     mToolbarItem_ZoomSlider;
  
  NSMutableArray*                    mNamesOfSelectedElementsToBeReselected; // to restore selection after, e.g., undo actions

  CGFloat                            mAccumulatedMagnificationFromGesture;
}


- (id) init
{
  self = [super initWithNibName:nil bundle:nil];
  if ( self != nil )
  {
    mSchematicBoundingBox = CGRectZero;

    mSchematic = [FXSchematic new];
    NSAssert( mSchematic != nil, @"Could not create schematic." );
    mSchematicPalette = [FXSchematicPaletteController new];
    NSAssert( mSchematicPalette != nil, @"Could not create schematic palette." );
    [mSchematicPalette setGroupEditor:self];
    mSchematicInspector = [FXSchematicInspectorController new];
    NSAssert( mSchematicInspector != nil, @"Could not create schematic inspector." );
    [mSchematicInspector setVisible:YES];
    mSchematicUndoManager = [FXSchematicUndoManager new];
    NSAssert( mSchematicUndoManager != nil, @"Could not create schematic undo manager." );

    [self setUpSchematic:mSchematic];

    FXAutoTool* autoTool = [FXAutoTool new];
    [autoTool setSchematic:mSchematic];
    [self setCurrentTool:autoTool];
    FXRelease(autoTool)

    mNamesOfSelectedElementsToBeReselected = [[NSMutableArray alloc] initWithCapacity:32];

    mAccumulatedMagnificationFromGesture = 1.0;
  }
  return self;
}

- (void) dealloc
{
  [mSchematicView setEnabled:NO];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  FXRelease(mSchematic)
  FXRelease(mSchematicUndoManager)
  mSchematicUndoManager = nil;
  FXRelease(mToolbarItem_TogglePalette)
  FXRelease(mToolbarItem_ToggleInspector)
  FXRelease(mToolbarItem_ZoomSlider)
  FXRelease(mCurrentTool)
  FXRelease(mSchematicPalette)
  FXRelease(mSchematicInspector)
  FXRelease(mNamesOfSelectedElementsToBeReselected)
  FXDeallocSuper
}


#pragma mark Public


+ (NSArray*) mainMenuItems
{
  FXIssue(56)
  NSMenuItem* toggleInspector = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"Toggle Inspector") action:@selector(performSchematicUserInterfaceAction:) keyEquivalent:@"i"];
  [toggleInspector setKeyEquivalentModifierMask:(NSEventModifierFlagCommand|NSEventModifierFlagOption)];
    
  FXIssue(91)
  static UniChar const kLeftArrowCode = NSLeftArrowFunctionKey;
  static UniChar const kRightArrowCode = NSRightArrowFunctionKey;
  NSMenuItem* rotateLeft = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"Rotate +90˚") action:@selector(performSchematicUserInterfaceAction:) keyEquivalent:[NSString stringWithCharacters:&kLeftArrowCode length:1]];
  NSMenuItem* rotateRight = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"Rotate -90˚") action:@selector(performSchematicUserInterfaceAction:) keyEquivalent:[NSString stringWithCharacters:&kRightArrowCode length:1]];
  NSMenuItem* flipH = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"Flip horizontally") action:@selector(performSchematicUserInterfaceAction:) keyEquivalent:@"-"];
  NSMenuItem* flipV = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"Flip vertically") action:@selector(performSchematicUserInterfaceAction:) keyEquivalent:@"|"];

  [toggleInspector setTag:FXSchematicUIAction_ToggleInspector];
  [rotateLeft setTag:FXSchematicUIAction_RotateLeft];
  [rotateRight setTag:FXSchematicUIAction_RotateRight];
  [flipH setTag:FXSchematicUIAction_FlipHorizontally];
  [flipV setTag:FXSchematicUIAction_FlipVertically];

  NSArray* result = @[toggleInspector, rotateLeft, rotateRight, flipH, flipV];
  FXRelease(toggleInspector)
  FXRelease(rotateRight)
  FXRelease(rotateLeft)
  FXRelease(flipH)
  FXRelease(flipV)

  return result;
}


#pragma mark NSViewController overrides


- (void) loadView
{
  const NSSize kSchematicSize = NSMakeSize( 600, 600 );
  const NSRect kSchematicFrame = NSMakeRect( 0, 0, kSchematicSize.width, kSchematicSize.height );

  NSView* paletteView = [mSchematicPalette view];
  const CGFloat kPaletteHeight = [paletteView frame].size.height;
  const NSRect skSchematicPaletteFrame = NSMakeRect(0, kSchematicSize.height - kPaletteHeight, kSchematicSize.width, kPaletteHeight);
  paletteView.frame = skSchematicPaletteFrame;
  paletteView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

  const NSRect kSchematicViewFrame = NSMakeRect( 0, 0, kSchematicSize.width, kSchematicSize.height - kPaletteHeight );
  mSchematicView = [[FXSchematicView alloc] initWithFrame:kSchematicViewFrame];
  [(FXSchematicView*)mSchematicView setController:self];
  mSchematicView.autoresizingMask = 0;

  mSchematicScrollView = [[NSScrollView alloc] initWithFrame:kSchematicViewFrame];
  mSchematicScrollView.autoresizesSubviews = YES;
  mSchematicScrollView.hasVerticalScroller = YES;
  mSchematicScrollView.hasHorizontalScroller = YES;
  mSchematicScrollView.autohidesScrollers = YES;
  mSchematicScrollView.usesPredominantAxisScrolling = NO;
  mSchematicScrollView.scrollerStyle = NSScrollerStyleOverlay;
  [mSchematicScrollView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
  FXSchematicFlippedClipView* clipView = [[FXSchematicFlippedClipView alloc] initWithFrame:kSchematicViewFrame];
  clipView.copiesOnScroll = NO;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleVoltaSchematicClipViewResizedNotification:) name:NSViewFrameDidChangeNotification object:clipView];
  mSchematicScrollView.contentView = clipView;
  FXRelease(clipView)
  mSchematicScrollView.documentView = mSchematicView;
  FXRelease(mSchematicView)

  NSView* inspectorView = [mSchematicInspector view];
  mSchematicAndInspectorContainerView = [[FXSchematicFlippedView alloc] initWithFrame:kSchematicViewFrame];
  mSchematicAndInspectorContainerView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  mSchematicAndInspectorContainerView.autoresizesSubviews = YES;
  [mSchematicAndInspectorContainerView addSubview:mSchematicScrollView];
  [mSchematicAndInspectorContainerView addSubview:inspectorView];
  FXRelease(mSchematicScrollView)

  [inspectorView setNextResponder:mSchematicView];

  NSView* containerView = [[NSView alloc] initWithFrame:kSchematicFrame];
  containerView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  containerView.autoresizesSubviews = YES;
  [containerView addSubview:paletteView];
  [containerView addSubview:mSchematicAndInspectorContainerView];
  FXRelease(mSchematicAndInspectorContainerView)

  self.view = containerView;
  FXRelease(containerView)
}


#pragma mark NSResponder overrides


NSString* FXResume_SelectedSchematicElements     = @"FXResume_SelectedSchematicElements";
NSString* FXResume_SchematicPaletteVisibility    = @"FXResume_SchematicPaletteVisibility";
NSString* FXResume_SchematicScrollPosition       = @"FXResume_SchematicScrollPosition";
NSString* FXResume_SchematicZoomFactor           = @"FXResume_SchematicZoomFactor";


- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  [super encodeRestorableStateWithCoder:state];
  [self encodeElementSelectionInState:state];
  [mSchematicPalette encodeRestorableStateWithCoder:state];
  [mSchematicInspector encodeRestorableStateWithCoder:state];

  NSPoint const scrollPosition = [[mSchematicScrollView contentView] documentVisibleRect].origin;
  [state encodePoint:scrollPosition forKey:FXResume_SchematicScrollPosition];
  [state encodeFloat:(float)mSchematic.scaleFactor forKey:FXResume_SchematicZoomFactor];

  [state encodeBool:[self isPaletteVisible] forKey:FXResume_SchematicPaletteVisibility];
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  [super restoreStateWithCoder:state];

  // The visibility of the palette needs to be restored first because it affects
  // the size of the canvas and, therefore, the other restored parts.

  if ( [state containsValueForKey:FXResume_SchematicPaletteVisibility] )
  {
    BOOL const paletteIsVisible = [state decodeBoolForKey:FXResume_SchematicPaletteVisibility];
    if ( !paletteIsVisible )
      [self hidePaletteWithAnimation:NO];
  }

  [mSchematicPalette restoreStateWithCoder:state];

  if ( [state containsValueForKey:FXResume_SchematicZoomFactor] )
  {
    float const zoomFactor = [state decodeFloatForKey:FXResume_SchematicZoomFactor];
    [self applyZoomFactor:zoomFactor updateSlider:YES];
    mAccumulatedMagnificationFromGesture = zoomFactor;
  }

  // Important: The scroll position must be restored after the restored zoom factor has been applied.
  if ( [state containsValueForKey:FXResume_SchematicScrollPosition] )
  {
    NSPoint const lastScrollPosition = [state decodePointForKey:FXResume_SchematicScrollPosition];
    [[mSchematicScrollView documentView] scrollPoint:lastScrollPosition];
  }

  [mSchematicInspector restoreStateWithCoder:state];
  [self restoreElementSelectionFromState:state];
}


#pragma mark VoltaSchematicEditor


- (void) setUndoManager:(NSUndoManager*)undoManager
{
  [mSchematicUndoManager setUndoManager:undoManager];
}


- (FXView*) schematicView
{
  return [self view];
}


- (CGSize) minimumViewSize
{
  if (mSchematicPalette != nil)
  {
    return CGSizeMake(mSchematicPalette.minWidth, mSchematicPalette.view.frame.size.height);
  }
  return CGSizeZero;
}


- (NSString*) archiveCircuit
{
  return nil;
}


- (VoltaPTSchematicPtr) capture
{
  return [FXSchematicCapture capture:mSchematic];
}


- (void) setLibrary:(id<VoltaLibrary>)library
{
  mSchematic.library = library;
  [library addObserver:self];
  [self updateSchematicPaletteElements];
}


- (void) setSchematicData:(VoltaPTSchematicPtr)schematicData
{
  NSAssert( mSchematic != nil, @"The library of the old schematic must be extracted." );
  [FXSchematicCapture restoreSchematic:mSchematic fromCapture:schematicData];
  [self applyZoomFactor:mSchematic.scaleFactor updateSlider:YES];
}


- (NSArray*) toolbarItems
{
  NSMutableArray* toolbarItems = [NSMutableArray arrayWithCapacity:3];

  if ( mToolbarItem_ToggleInspector == nil )
  {
    static NSImage* itemImage = nil; FXIssue(98) // Preventing memory leakage in the ImageIO lib
    if ( itemImage == nil )
    {
      itemImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"schematic_toolbar_inspector" ofType:@"png"]];
    }

    mToolbarItem_ToggleInspector =
      [self newToolbarItemWithIdentifier:@"SchematicEditorInspectorToggle"
                                   label:FXLocalizedString(@"ToolbarItemText_Inspector")
                                  action:@selector(toggleInspectorVisibility:)
                                 toolTip:FXLocalizedString(@"ToolbarItemText_ToggleInspector")
                                   image:itemImage];
  }
  [toolbarItems addObject:mToolbarItem_ToggleInspector];

  if ( mToolbarItem_TogglePalette == nil )
  {
    static NSImage* itemImage = nil; FXIssue(98) // Preventing memory leakage in the ImageIO lib
    if ( itemImage == nil )
    {
      itemImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"schematic_toolbar_library" ofType:@"png"]];
    }

    mToolbarItem_TogglePalette =
      [self newToolbarItemWithIdentifier:@"SchematicEditorPaletteToggle"
                                   label:FXLocalizedString(@"ToolbarItemText_Palette")
                                  action:@selector(togglePaletteVisibility:)
                                 toolTip:FXLocalizedString(@"ToolbarItemText_TogglePalette")
                                   image:itemImage];
  }
  [toolbarItems addObject:mToolbarItem_TogglePalette];

  if ( mToolbarItem_ZoomSlider == nil )
  {
    mToolbarItem_ZoomSlider = [self newZoomSliderToolbarItem];
  }
  [toolbarItems addObject:mToolbarItem_ZoomSlider];

  return toolbarItems;
}


- (void) closeEditor
{
  [[mSchematic library] removeObserver:self]; // otherwise the library would continue retaining the receiver
}


- (void) encodeRestorableState:(NSCoder*)state
{
  [self encodeRestorableStateWithCoder:state];
}


- (void) restoreState:(NSCoder*)state
{
  [self restoreStateWithCoder:state];
}


- (void) enterViewingModeWithAnimation:(BOOL)animated
{
  [self hidePaletteWithAnimation:animated];
}


- (void) exitViewingModeWithAnimation:(BOOL)animated
{
  [self revealPaletteWithAnimation:animated];
}


#pragma mark VoltaPrintable


- (FXView*) newPrintableView
{
  FXSchematicView* view = nil;
  if ( mSchematic.numberOfElements > 0 )
  {
    view = [[FXSchematicView alloc] initWithFrame:self.view.frame];
    view.controller = self;
  }
  return view;
}


- (NSArray*) optionsForPrintableView:(FXView*)view
{
  return nil;
}


- (NSInteger) selectedOptionForPrintableView:(FXView*)view
{
  return -1;
}


- (void) selectOption:(NSInteger)optionIndex forPrintableView:(FXView*)view
{
}


#pragma mark VoltaLibraryObserver


- (void) handleVoltaLibraryPaletteChanged:(id<VoltaLibrary>)library
{
  if ( library == mSchematic.library )
    [self updateSchematicPaletteElements];
}


- (void) handleVoltaLibraryModelsChanged:(id<VoltaLibrary>)library
{
  [[NSNotificationCenter defaultCenter] postNotificationName:VoltaSchematicElementModelsDidChangeNotification object:mSchematic];
}


- (void) handleVoltaLibraryChangedSubcircuits:(id<VoltaLibrary>)library
{
  if ( library == mSchematic.library )
  {
    [mSchematicView refresh];
  }
}


#pragma mark VoltaSchematicPaletteGroupEditor


- (void) openGroupEditor
{
  [[mSchematic library] openEditor];
}


#pragma mark VoltaSchematicViewController


- (void) drawSchematicWithContext:(CGContextRef)context inView:(NSView*)schematicView
{
  if ( [NSGraphicsContext currentContextDrawingToScreen] )
  {
    NSRect const frameInWindow = [schematicView convertRect:[schematicView frame] toView:nil];
    CGRect const screenRect = [[schematicView window] convertRectToScreen:frameInWindow];
    if ( [mSchematic numberOfElements] > 0 )
    {
      [[FXSchematicPainter sharedPainter] drawSchematic:mSchematic viewRect:screenRect];
    }
    else
    {
      FXIssue(95)
      [self drawInstructions:screenRect];
    }
  }
  else
  {
    [self drawSchematicForPrintingWithContext:context inView:schematicView];
  }
}


- (BOOL) handleDropForDraggingInfo:(id<NSDraggingInfo>)info
{
  NSArray* allowedTypes = @[[FXElement class], [FXModel class], [FXSchematicElement class]];
  BOOL dataAccepted = NO;
  NSMutableArray* acceptedSchematicElements = [NSMutableArray arrayWithCapacity:[[[info draggingPasteboard] pasteboardItems] count]];
  NSRect const documentVisibleRect = [mSchematicScrollView documentVisibleRect];
  CGFloat const verticalScrollerOffset = mSchematicScrollView.frame.size.height - mSchematicScrollView.documentVisibleRect.size.height;

  [info enumerateDraggingItemsWithOptions:0 forView:self.view classes:allowedTypes searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
    NSPoint location = NSZeroPoint;
    NSPoint const itemLocation = draggingItem.draggingFrame.origin;
    for ( NSDraggingImageComponent* imageComponent in [draggingItem imageComponents] )
    {
      if ( [imageComponent.key isEqualToString:NSDraggingImageComponentIconKey] )
      {
        NSSize const imageSize = [(NSImage*)imageComponent.contents size];
        NSPoint const centerOffset = NSMakePoint(imageSize.width/2.0f, imageSize.height/2.0f);
        NSPoint const iconOrigin = imageComponent.frame.origin;
        location.x = itemLocation.x + iconOrigin.x + centerOffset.x;
        location.y = itemLocation.y + iconOrigin.y + centerOffset.y;
      #if SCHEMATIC_VIEW_IS_FLIPPED
        location.y = documentVisibleRect.size.height - location.y;
      #endif
        location.x += documentVisibleRect.origin.x;
        location.y += documentVisibleRect.origin.y + verticalScrollerOffset;
        break;
      }
    }

    id<VoltaSchematicElement> droppedSchematicElement = nil;

    if ( [draggingItem.item isKindOfClass:[FXSchematicElement class]] )
    {
      droppedSchematicElement = (FXSchematicElement*)draggingItem.item;
    }
    else if ( [draggingItem.item isKindOfClass:[FXModel class]] )
    {
      droppedSchematicElement = [self newSchematicElementForModel:(FXModel*)draggingItem.item];
      FXAutorelease(droppedSchematicElement)
    }
    else if ( [draggingItem.item isKindOfClass:[FXElement class]] )
    {
      droppedSchematicElement = [self newSchematicElementForElement:(FXElement*)draggingItem.item];
      FXAutorelease(droppedSchematicElement)
    }

    if ( droppedSchematicElement != nil )
    {
      location = FXSchematicUtilities::convertToSchematicSpace(location, mSchematic);
      [droppedSchematicElement setLocation:location];
      [acceptedSchematicElements addObject:droppedSchematicElement];
    }
  }];

  if ( [acceptedSchematicElements count] > 0 )
  {
    dataAccepted = YES;
    [self addElements:acceptedSchematicElements];
  }

  return dataAccepted;
}


- (void) updateDraggingItemsForDraggingInfo:(id<NSDraggingInfo>)info
{
  NSArray* acceptedTypes = @[[FXModel class], [FXElement class], [FXSchematicElement class]];
  info.draggingFormation = NSDraggingFormationNone;
  __block CGFloat firstItemVerticalPosition = 0;
    [info enumerateDraggingItemsWithOptions:0 forView:self.view classes:acceptedTypes searchOptions:@{} usingBlock:^(NSDraggingItem* draggingItem, NSInteger idx, BOOL *stop) {
    NSString* modelName = nil;
    NSString* modelVendor = nil;
    VoltaModelType modelType = VMT_Unknown;
    if ( [draggingItem.item isKindOfClass:[FXSchematicElement class]] )
    {
      FXSchematicElement* element = (FXSchematicElement*)draggingItem.item;
      modelType = element.type;
      modelVendor = element.modelVendor;
      modelName = element.modelName;
    }
    else
    {
      if ( [draggingItem.item isKindOfClass:[FXModel class]] )
      {
        FXModel* model = (FXModel*)draggingItem.item;
        modelName = model.name;
        modelVendor = model.vendor;
        modelType = model.type;
      }
      else if ( [draggingItem.item isKindOfClass:[FXElement class]] )
      {
        FXElement* element = (FXElement*)draggingItem.item;
        modelType = element.type;
        modelName = element.modelName;
        modelVendor = element.modelVendor;
      }
    }
    id<FXShape> elementShape = [[mSchematic library] shapeForModelType:modelType name:modelName vendor:modelVendor];
    [self setAttributesOfShape:elementShape fromDraggedItem:draggingItem.item];
    NSAssert(elementShape != nil, @"The shape should exist in the library.");
    if ( elementShape != nil )
    {
      BOOL const hiDPI = (self.view.window.backingScaleFactor > 1.5);
      NSImage* iconImage = [[FXShapeRenderer sharedRenderer] iconImageForShape:elementShape forHiDPI:hiDPI scaleFactor:mSchematic.scaleFactor];
      NSSize const imageSize = iconImage.size;
      CGFloat formationOffset = (idx > 0) ? (draggingItem.draggingFrame.origin.y - firstItemVerticalPosition) : 0;
      if ( idx == 0 )
      {
        firstItemVerticalPosition = draggingItem.draggingFrame.origin.y;
      }
      draggingItem.draggingFrame = NSMakeRect(round(-imageSize.width/2), formationOffset - round(imageSize.height/2), round(imageSize.width), round(imageSize.height));
      draggingItem.imageComponentsProvider = ^ {
        NSDraggingImageComponent* imageComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
        imageComponent.contents = iconImage;
        imageComponent.frame = NSMakeRect(0, 0, round(imageSize.width), round(imageSize.height));
        return @[imageComponent];
      };
    }
  }];
}


- (void) mouseDown:(NSEvent*)mouseEvent
{
  if ( mCurrentTool != nil )
  {
    CGPoint location = [self schematicLocationForEvent:mouseEvent];
    if ( [mCurrentTool mouseDown:mouseEvent schematicLocation:location] )
    {
      [mSchematicView refresh];
    }
  }
}


- (void) mouseUp:(NSEvent*)mouseEvent
{
  if ( mCurrentTool != nil )
  {
    CGPoint location = [self schematicLocationForEvent:mouseEvent];
    if ( [mCurrentTool mouseUp:mouseEvent schematicLocation:location] )
    {
      [mSchematicView refresh];
    }
  }
}


- (void) mouseDragged:(NSEvent*)mouseEvent
{
  CGPoint locationInView = [mSchematicView convertPoint:[mouseEvent locationInWindow] fromView:nil];
  CGPoint locationInSchematic = FXSchematicUtilities::convertToSchematicSpace(locationInView, mSchematic);

  if ( mCurrentTool != nil )
  {
    if ( [mCurrentTool mouseDragged:mouseEvent schematicLocation:locationInSchematic] )
    {
      [mSchematicView refresh];
    }
  }

  FXIssue(112)
  NSRect visibleRect = [mSchematicScrollView documentVisibleRect];
  if ( !NSPointInRect(locationInView, visibleRect) )
  {
    NSPoint scrollToPoint = locationInView;
    if ( (locationInView.x <= NSMaxX(visibleRect)) && (locationInView.x >= NSMinX(visibleRect)) )
    {
      scrollToPoint.x = NSMinX(visibleRect);
    }
    else if ( locationInView.x >= NSMaxX(visibleRect) )
    {
      scrollToPoint.x = locationInView.x - visibleRect.size.width;
    }

    if ( (locationInView.y <= NSMaxY(visibleRect)) && (locationInView.y >= NSMinY(visibleRect)) )
    {
      scrollToPoint.y = NSMinY(visibleRect);
    }
    else if ( locationInView.y >= NSMaxY(visibleRect) )
    {
      scrollToPoint.y = locationInView.y - visibleRect.size.height;
    }

    [mSchematicView scrollPoint:scrollToPoint];
  }
}


- (void) mouseMoved:(NSEvent*)mouseEvent
{
  if ( mCurrentTool != nil )
  {
    CGPoint location = [self schematicLocationForEvent:mouseEvent];
    if ( [mCurrentTool mouseMoved:mouseEvent schematicLocation:location connectionInfo:nullptr] )
    {
      [mSchematicView refresh];
    }
  }
}


- (void) keyDown:(NSEvent*)keyEvent
{
  static unsigned short const kEscapeKeyCode = 53;
  
  NSString* keyCharacters = [keyEvent characters];
  NSUInteger const modifiers = [keyEvent modifierFlags];

  if ( [keyCharacters length] == 1 )
  {
    unichar const keyCharacter = [keyCharacters characterAtIndex:0];
    unsigned short const keyCode = [keyEvent keyCode];
    if ( (keyCharacter == NSBackspaceCharacter) || (keyCharacter == NSDeleteCharacter) )
    {
      if ( [mCurrentTool toolExecuteDeleteKey] )
      {
        [mSchematicView refresh];
      }
    }
    else if ( keyCode == kEscapeKeyCode )
    {
      if ( [mCurrentTool toolExecuteEscapeKey] )
      {
        [mSchematicView refresh];
      }
    }
    else if ( [mCurrentTool toolHandleKeyPress:keyCharacter modifierFlags:modifiers] )
    {
      [mSchematicView refresh];
    }
  }
}


- (void) keyUp:(NSEvent*)keyEvent
{
  //DebugLog(@"schematic key up");
}


- (BOOL) performKeyEquivalent:(NSEvent*)keyEvent
{
  // Handling actions associated with standard keyboard shortcuts like Command + A.
  // These are not handled by menu items (see issue 23) because they are overloaded shortcuts,
  // depending on the view that currently has keyboard focus.
  BOOL handled = NO;
  if ( [[keyEvent characters] isEqualToString:@"a"] )
  {
    FXIssue(63)
    if ( [keyEvent modifierFlags] & NSEventModifierFlagOption )
    {
      [mSchematic unselectAll];
    }
    else
    {
      [mSchematic selectAll];
    }
    [mSchematicView refresh];
    handled = YES;
  }
  return handled;
}


- (void) gestureBegins
{
  mAccumulatedMagnificationFromGesture = mSchematic.scaleFactor;
}


- (void) gestureEnds
{
}


- (void) handleMagnificationGesture:(CGFloat)magnification
{
  mAccumulatedMagnificationFromGesture += magnification;
  mAccumulatedMagnificationFromGesture = MAX(MIN(mAccumulatedMagnificationFromGesture, kMaxSchematicZoom), kMinSchematicZoom);
  if ( ABS(mAccumulatedMagnificationFromGesture - mSchematic.scaleFactor) >= kSchematicZoomStepSize )
  {
    CGFloat const zoomFactor = mSchematic.scaleFactor + (round((mAccumulatedMagnificationFromGesture - mSchematic.scaleFactor) / kSchematicZoomStepSize) * kSchematicZoomStepSize);
    [self applyZoomFactor:zoomFactor updateSlider:YES];
  }
}


- (void) handleUserInterfaceActionForTag:(NSInteger)tag
{
  switch( tag )
  {
    case FXSchematicUIAction_ToggleInspector:
      [self toggleInspectorVisibility:nil];
      break;
    case FXSchematicUIAction_RotateLeft:
      [[mSchematicInspector elementInspector] rotateInspectedElementsPlus90:nil];
      break;
    case FXSchematicUIAction_RotateRight:
      [[mSchematicInspector elementInspector] rotateInspectedElementsMinus90:nil];
      break;
    case FXSchematicUIAction_FlipHorizontally:
      [[mSchematicInspector elementInspector] flipInspectedElementsHorizontally:nil];
      break;
    case FXSchematicUIAction_FlipVertically:
      [[mSchematicInspector elementInspector] flipInspectedElementsVertically:nil];
    default:
      break;
  }
}


#pragma mark NSUserInterfaceValidations


- (BOOL) validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
  BOOL result = YES;
  if ( [item action] == @selector(performSchematicUserInterfaceAction:) )
  {
    switch( [item tag] )
    {
      case FXSchematicUIAction_RotateLeft:
      case FXSchematicUIAction_RotateRight:
      case FXSchematicUIAction_FlipHorizontally:
      case FXSchematicUIAction_FlipVertically:
        FXIssue(136)
        result = [[mSchematicInspector elementInspector] isInspecting];
        break;
      case FXSchematicUIAction_ToggleInspector:
      default:
        result = YES;
    }
  }
  return result;
}


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

#pragma mark NSAnimationDelegate


- (void) animationDidEnd:(NSAnimation*)animation
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if ( [self isPaletteVisible] )
    {
      [[mSchematicPalette view] setNeedsDisplay:YES];
    }
    [[[mSchematicPalette view] window] invalidateRestorableState];
  });
}


#pragma mark Private


- (void) toggleInspectorVisibility:(id)sender
{
  [mSchematicInspector setVisible:![mSchematicInspector visible]];
}


- (BOOL) isPaletteVisible
{
  NSRect const paletteFrame = [[mSchematicPalette view] frame];
  NSRect const parentFrame = [[self view] frame];
  return NSPointInRect(paletteFrame.origin, parentFrame);
}


- (void) repositionPaletteAtHeight:(CGFloat)height withAnimation:(BOOL)animated
{
  NSRect const paletteCurrentFrame = [[mSchematicPalette view] frame];
  NSRect const schematicCurrentFrame = [mSchematicAndInspectorContainerView frame];

  CGFloat const parentHeight = [[self view] frame].size.height;
  NSRect paletteNewFrame = paletteCurrentFrame;
  paletteNewFrame.origin.y = height;
  NSRect schematicNewFrame = schematicCurrentFrame;
  schematicNewFrame.size.height = MIN(parentHeight, height);

  if ( animated )
  {
    NSDictionary* paletteAnimation = @{
      NSViewAnimationTargetKey     : [mSchematicPalette view],
      NSViewAnimationStartFrameKey : [NSValue valueWithRect:paletteCurrentFrame],
      NSViewAnimationEndFrameKey   : [NSValue valueWithRect:paletteNewFrame]
    };

    NSDictionary* schematicAnimation = @{
      NSViewAnimationTargetKey     : mSchematicAndInspectorContainerView,
      NSViewAnimationStartFrameKey : [NSValue valueWithRect:schematicCurrentFrame],
      NSViewAnimationEndFrameKey   : [NSValue valueWithRect:schematicNewFrame],
    };

    NSViewAnimation* animation = [[NSViewAnimation alloc] initWithViewAnimations:@[paletteAnimation, schematicAnimation]];
    [animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
    [animation setAnimationCurve:NSAnimationLinear];
    [animation setDuration:0.12];
    [animation setFrameRate:0.0];
    [animation setDelegate:self];
    [animation startAnimation];
  }
  else
  {
    [[mSchematicPalette view] setFrame:paletteNewFrame];
    [mSchematicAndInspectorContainerView setFrame:schematicNewFrame];
    [[[mSchematicPalette view] window] invalidateRestorableState];
  }
}


- (void) hidePaletteWithAnimation:(BOOL)animated
{
  [self repositionPaletteAtHeight:([[self view] frame].size.height + 1.0) withAnimation:animated];
}


- (void) revealPaletteWithAnimation:(BOOL)animated
{
  CGFloat newPaletteOriginY = [[self view] frame].size.height - [[mSchematicPalette view] frame].size.height;
  [self repositionPaletteAtHeight:newPaletteOriginY withAnimation:animated];
}


- (void) togglePaletteVisibility:(id)sender
{
  if ( [self isPaletteVisible] )
  {
    [self hidePaletteWithAnimation:YES];
  }
  else
  {
    [self revealPaletteWithAnimation:YES];
  }
}


- (void) handleZoomSlider:(id)sender
{
  NSSlider* zoomSlider = (NSSlider*)[mToolbarItem_ZoomSlider view];
  CGFloat const scaleFactor = zoomSlider.floatValue;
  mToolbarItem_ZoomSlider.label = [self zoomLabelForScaleFactor:scaleFactor];
  [self applyZoomFactor:scaleFactor updateSlider:NO];
  mAccumulatedMagnificationFromGesture = scaleFactor;
}


- (void) setCurrentTool:(id<FXSchematicTool>)tool
{
  if ( mCurrentTool != tool )
  {
    mCurrentTool.schematic = nil;
    FXRelease(mCurrentTool)
    mCurrentTool = tool;
    FXRetain(mCurrentTool)
    mCurrentTool.schematic = mSchematic;
  }
}


- (void) setUpSchematic:(id <VoltaSchematic>)schematic
{
  [mSchematicInspector setSchematic:schematic];
  [mSchematicUndoManager setSchematic:schematic];

  if ( mCurrentTool != nil )
  {
    [mCurrentTool setSchematic:schematic];
    [mCurrentTool activate];
  }

  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(handleSchematicWillRestoreFromCapture:) name:FXSchematicCaptureWillRestoreSchematicNotification object:mSchematic];
  [notificationCenter addObserver:self selector:@selector(handleSchematicDidRestoreFromCapture:) name:FXSchematicCaptureDidRestoreSchematicNotification object:mSchematic];
  [notificationCenter addObserver:self selector:@selector(handleSchematicElementUpdates:) name:VoltaSchematicElementUpdateNotification object:mSchematic];
  [notificationCenter addObserver:self selector:@selector(handleVoltaSchematicElementModelsWillChange:) name:VoltaSchematicElementModelsWillChangeNotification object:mSchematic];
  [notificationCenter addObserver:self selector:@selector(handleVoltaSchematicElementModelsDidChange:) name:VoltaSchematicElementModelsDidChangeNotification object:mSchematic];
  [notificationCenter addObserver:self selector:@selector(handleVoltaSchematicBoundingBoxNeedsUpdate:) name:VoltaSchematicBoundingBoxNeedsUpdateNotification object:mSchematic]; FXIssue(112)
}


- (void) handleSchematicElementUpdates:(NSNotification*)notification
{
  NSAssert( [notification object] == mSchematic, @"Can not receive notification from other schematic." );
  [mSchematicView refresh];
}


- (void) handleSchematicWillRestoreFromCapture:(NSNotification*)notification
{
  //DebugLog(@"Getting names of all selected elements");
  @synchronized( mNamesOfSelectedElementsToBeReselected )
  {
    [mNamesOfSelectedElementsToBeReselected removeAllObjects];
    for ( id<VoltaSchematicElement> element in [mSchematic selectedElements] )
    {
      [mNamesOfSelectedElementsToBeReselected addObject:[element name]];
    }
  }
  [mSchematic unselectAll];
}


- (void) handleSchematicDidRestoreFromCapture:(NSNotification*)notification
{
#if 0
  FXIssue(175)
  [self replaceElementsWithUnknownModelTypes];
  [self replaceElementsWithUnknownModels];
#endif

  @synchronized( mNamesOfSelectedElementsToBeReselected )
  {
    if ( [mNamesOfSelectedElementsToBeReselected count] > 0 )
    {
      for ( id<VoltaSchematicElement> element in [mSchematic elements] )
      {
        for ( NSString* selectedElementName in mNamesOfSelectedElementsToBeReselected )
        {
          if ( [selectedElementName isEqualToString:[element name]] )
          {
            [mSchematic select:element];
          }
        }
      }
      [mNamesOfSelectedElementsToBeReselected removeAllObjects];
    }
  }
  [mSchematicInspector update];
}


- (id<VoltaSchematicElement>) newSchematicElementFromPersistentElement:(VoltaPTElement const &)element
{
  id<VoltaSchematicElement> result = nil;

  NSAssert( [mSchematic library] != nil, @"This method must be able to access the library." );
  VoltaPTModelPtr model = [[mSchematic library] modelForElement:element];
  if ( model.get() == nullptr )
  {
    model = [[mSchematic library] defaultModelForType:element.type];
  }
  if ( model.get() != nullptr )
  {
    result = [self newSchematicElementForPersistentModel:model];
    [result setName:[NSString stringWithString:(__bridge NSString*)element.name.cfString()]];
    for( VoltaPTProperty const & property : element.properties )
    {
      NSString* propertyName = [NSString stringWithString:(__bridge NSString*)property.name.cfString()];
      NSString* propertyValue = [NSString stringWithString:(__bridge NSString*)property.value.cfString()];
      [result setPropertyValue:propertyValue forKey:propertyName];
    }
  }
  return result;
}


- (id<VoltaSchematicElement>) newSchematicElementForModel:(FXModel*)modelWrapper
{
  id<VoltaSchematicElement> result = nil;
  if ( modelWrapper != nil )
  {
    VoltaPTModelPtr model = [modelWrapper persistentModel];
    result = [self newSchematicElementForPersistentModel:model];
    [modelWrapper.displaySettings enumerateKeysAndObjectsUsingBlock:^(NSString* key, id obj, BOOL *stop) {
      [result setPropertyValue:obj forKey:key];
    }];
  }
  return result;
}


- (id<VoltaSchematicElement>) newSchematicElementForPersistentModel:(VoltaPTModelPtr)model
{
  id<VoltaSchematicElement> result = nil;
  if ( model.get() != nullptr )
  {
    NSString* elementNamePrefix = model->elementNamePrefix.empty() ? nil : (__bridge NSString*)model->elementNamePrefix.cfString();

    FXSchematicElement* newElement = [FXSchematicElement new];
    newElement.modelName = [NSString stringWithString:(__bridge NSString*)model->name.cfString()];
    newElement.modelVendor = [NSString stringWithString:(__bridge NSString*)model->vendor.cfString()];
    newElement.type = model->type;
    newElement.name = (elementNamePrefix != nil) ? elementNamePrefix : newElement.modelName;
    newElement.location = FXPointMake(model->shape.width/2, model->shape.height/2);
    newElement.rotation = 0.0f;
    newElement.schematic = mSchematic;

    switch ( model->labelPosition )
    {
      case VoltaPTLabelPosition::Top:    [newElement setLabelPosition:SchematicRelativePosition_Top]; break;
      case VoltaPTLabelPosition::Bottom: [newElement setLabelPosition:SchematicRelativePosition_Bottom]; break;
      case VoltaPTLabelPosition::Right:  [newElement setLabelPosition:SchematicRelativePosition_Right];  break;
      case VoltaPTLabelPosition::Left:   [newElement setLabelPosition:SchematicRelativePosition_Left];  break;
      default: [newElement setLabelPosition:SchematicRelativePosition_None];
    }

    VoltaPTPropertyVector const elementProperties = FXVoltaCircuitDomainAgent::circuitElementParametersForModel(model);
    for( VoltaPTProperty const & property : elementProperties )
    {
      NSString* propertyName = [NSString stringWithString:(__bridge NSString*) property.name.cfString()];
      NSString* propertyValue = [NSString stringWithString:(__bridge NSString*)property.value.cfString()];
      [newElement setPropertyValue:propertyValue forKey:propertyName];
    }

    result = newElement;
  }
  return result;
}


- (id<VoltaSchematicElement>) newSchematicElementForElement:(FXElement*)element
{
  id<VoltaSchematicElement> result = nil;
  if ( element != nil )
  {
    FXSchematicElement* newElement = [FXSchematicElement new];
    newElement.modelName = element.modelName;
    newElement.modelVendor = element.modelVendor;
    newElement.type = element.type;
    newElement.name = element.name;
    newElement.labelPosition = (SchematicRelativePosition)element.labelPosition;
    newElement.rotation = 0.0f;
    newElement.schematic = mSchematic;
    [element.properties enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
      [newElement setPropertyValue:value forKey:(NSString*)key];
    }];
    id<FXShape> shape = [[mSchematic library] shapeForModelType:element.type name:element.modelName vendor:element.modelVendor];
    if ( shape != nil )
    {
      newElement.location = FXPointMake(shape.size.width/2, shape.size.height/2);
    }
    result = newElement;
  }
  return result;
}


- (void) updateSchematicPaletteElements
{
  __block NSString* previousActiveGroupName = [[mSchematicPalette selectedGroup] copy];
  [mSchematicPalette beginEditingElementGroups];
  [mSchematicPalette removeAllElementGroups];
  id<VoltaLibrary> library = [mSchematic library];
  [library iterateOverElementGroupsByApplyingBlock:^(VoltaPTElementGroup const & elementGroup, BOOL* stop) {
    FXIssue(04)
    NSMutableArray* libraryElements = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)elementGroup.elements.size()];
    for( VoltaPTElement const & element : elementGroup.elements )
    {
      id<VoltaSchematicElement> newElement = [self newSchematicElementFromPersistentElement:element];
      if ( newElement != nil )
      {
        [libraryElements addObject:newElement];
      }
      FXRelease(newElement)
    }
    NSString* groupName = (__bridge NSString*) elementGroup.name.cfString();
    FXSchematicElementGroup* newGroup = [[FXSchematicElementGroup alloc] initWithName:groupName isLibrary:YES groupElements:libraryElements];
    [mSchematicPalette addElementGroup:newGroup];
    FXRelease(newGroup)
    FXRelease(libraryElements)

    if ( previousActiveGroupName == nil )
    {
      previousActiveGroupName = [groupName copy];
    }
  }];
  if ( previousActiveGroupName != nil )
  {
    [mSchematicPalette setSelectedGroup:previousActiveGroupName];
    FXRelease(previousActiveGroupName)
    previousActiveGroupName = nil;
  }
  [mSchematicPalette endEditingElementGroups];
}


- (void) handleVoltaSchematicElementModelsWillChange:(NSNotification*)notification
{
  if ( (notification == nil) || ([notification object] == mSchematic) )
  {
    FXIssue(129)
    NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_model_change") };
    [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];
  }
}


- (void) handleVoltaSchematicElementModelsDidChange:(NSNotification*)notification
{
  if ( (notification == nil) || ([notification object] == mSchematic) )
  {
    [mSchematicView refresh];
  }
}


- (void) handleVoltaSchematicBoundingBoxNeedsUpdate:(NSNotification*)notification
{
  if ([notification object] == mSchematic)
  {
    [self applyCurrentSchematicBoundingBox];
  }
}


- (void) handleVoltaSchematicClipViewResizedNotification:(NSNotification*)notification
{
  NSSize newSize = [mSchematicScrollView contentSize];
  CGFloat const scaledTotalWidth = ceil(NSMaxX(mSchematicBoundingBox) * mSchematic.scaleFactor);
  CGFloat const scaledTotalHeight = ceil(NSMaxY(mSchematicBoundingBox) * mSchematic.scaleFactor);
  if ( newSize.width < scaledTotalWidth )
  {
    newSize.width = scaledTotalWidth;
  }
  if ( newSize.height < scaledTotalHeight )
  {
    newSize.height = scaledTotalHeight;
  }
  [mSchematicView setFrameSize:newSize];
}


- (CGPoint) schematicLocationForEvent:(NSEvent*)mouseEvent
{
  CGPoint location = [mSchematicView convertPoint:[mouseEvent locationInWindow] fromView:nil];
  location = FXSchematicUtilities::convertToSchematicSpace(location, mSchematic);
  return location;
}


- (void) drawInstructions:(NSRect)rect
{
  static NSDictionary* skTextAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
    [NSFont fontWithName:@"Lucida Grande" size:18.0], NSFontAttributeName,
    [NSColor colorWithDeviceWhite:0.8 alpha:0.7], NSForegroundColorAttributeName,
    nil];
  NSString* instructionString = FXLocalizedString(@"SchematicBeginnerInstructions");
  NSSize textSize = [instructionString sizeWithAttributes:skTextAttributes];
#if SCHEMATIC_VIEW_IS_FLIPPED
  NSPoint textPosition = NSMakePoint(0.5 * (rect.size.width - textSize.width), 0.4 * rect.size.height);
#else
  NSPoint textPosition = NSMakePoint(0.5 * (rect.size.width - textSize.width), 0.6 * rect.size.height);
#endif
  [instructionString drawAtPoint:textPosition withAttributes:skTextAttributes];
}


- (void) processSchematicElementsWithInvalidModelsByPerformingBlock:(void(^)(id<VoltaSchematicElement> element, BOOL* stop))block
{
  id<VoltaLibrary> library = [mSchematic library];

  for ( id<VoltaSchematicElement> element in [mSchematic elements] )
  {
    __block BOOL stopSchematicElementIteration = NO;

    [library iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr currentModelGroup, BOOL* stop) {
      if ( currentModelGroup->modelType == [element type] )
      {
        BOOL foundModel = NO;
        for (VoltaPTModelPtr currentModel : currentModelGroup->models)
        {
          if ( [(__bridge NSString*)currentModel->name.cfString() isEqualToString:[element modelName]]
              && [(__bridge NSString*)currentModel->vendor.cfString() isEqualToString:[element modelVendor]] )
          {
            foundModel = YES;
            break;
          }
        }
        if ( !foundModel )
        {
          block(element, &stopSchematicElementIteration);
        }
        *stop = YES;
      }
    }];

    if ( stopSchematicElementIteration )
    {
      break;
    }
  }
}


- (void) replaceElementsWithUnknownModelTypes
{
  FXIssue(175)
  // Replacing elements with text elements if the model type is unknown.
}


- (void) replaceElementsWithUnknownModels
{
  FXIssue(175)
  id<VoltaLibrary> library = [mSchematic library];
  
  // Collecting elements with unknown models
  
  // Presenting the elements to the user and prompting for action (automatic conversion/don't change/edit list)
  
  // Depending on the user's response modify the element model data or leave unchanged.
  for ( id<VoltaSchematicElement> element in [mSchematic elements] )
  {
    if ( [element type] == VMT_Unknown )
      continue;

    __block BOOL foundMatchingModel = NO;
    [library iterateOverModelGroupsByApplyingBlock:^(VoltaPTModelGroupPtr group, BOOL* stop) {
      if (group->modelType == element.type)
      {
        for ( auto & model : group->models )
        {
          if ( (model->name == FXString((__bridge CFStringRef)[element modelName]))
            && (model->vendor == FXString((__bridge CFStringRef)[element modelVendor])) )
          {
            foundMatchingModel = YES;
            *stop = YES;
            break;
          }
        }
      }
    }];
    if ( !foundMatchingModel )
    {
      VoltaPTModelPtr defaultModel = [library defaultModelForType:element.type];
      [element setModelName:(__bridge NSString*)defaultModel->name.cfString()];
      [element setModelVendor:(__bridge NSString*)defaultModel->vendor.cfString()];
    }
  }  
}


- (NSToolbarItem*) newToolbarItemWithIdentifier:(NSString*)identifier
                                          label:(NSString*)label
                                         action:(SEL)action
                                        toolTip:(NSString*)toolTip
                                          image:(NSImage*)itemImage
{
  NSToolbarItem* toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
  toolbarItem.label = label;
  toolbarItem.action = action;
  toolbarItem.target = self;
  toolbarItem.toolTip = toolTip;
  if ( itemImage != nil )
  {
    toolbarItem.image = itemImage;
  }
  return toolbarItem;
}


- (NSToolbarItem*) newZoomSliderToolbarItem
{
  NSToolbarItem* result = [[NSToolbarItem alloc] initWithItemIdentifier:@"SchematicEditorZoom"];
  result.toolTip = FXLocalizedString(@"ToolbarItemText_Zoom");
  NSSlider* slider = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 44, 20)];
  slider.maxValue = kMaxSchematicZoom;
  slider.minValue = kMinSchematicZoom;
  slider.numberOfTickMarks = 1 + round((kMaxSchematicZoom - kMinSchematicZoom) / kSchematicZoomStepSize);
  slider.allowsTickMarkValuesOnly = YES;
  [(NSSliderCell*)[slider cell] setControlSize:NSControlSizeSmall];
  result.view = slider;
  result.minSize = NSMakeSize(44, 24);
  result.maxSize = result.minSize;
  result.target = self;
  result.action = @selector(handleZoomSlider:);
  result.label = [self zoomLabelForScaleFactor:slider.floatValue];
  FXRelease(slider)
  return result;
}


- (NSString*) zoomLabelForScaleFactor:(float)value
{
  NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
  formatter.numberStyle = NSNumberFormatterPercentStyle;
  NSNumber* valueNumber = [NSNumber numberWithFloat:value];
  NSString* result = [formatter stringFromNumber:valueNumber];
  FXRelease(formatter)
  return result;
}


- (void) applyZoomFactor:(float)zoomFactor updateSlider:(BOOL)updateSlider
{
  if ( updateSlider )
  {
    NSSlider* zoomSlider = (NSSlider*)[mToolbarItem_ZoomSlider view];
    zoomSlider.floatValue = zoomFactor;
    mToolbarItem_ZoomSlider.label = [self zoomLabelForScaleFactor:zoomFactor];
  }
  mSchematic.scaleFactor = zoomFactor;
  [self applyCurrentSchematicBoundingBox];
  [mSchematicView refresh];
}


- (void) addElements:(NSArray*)newElements
{
  NSDictionary* undoUserInfo = @{ @"ActionName" : FXLocalizedString(@"Action_add_component") };
  [[NSNotificationCenter defaultCenter] postNotificationName:FXSchematicCreateUndoPointNotification object:mSchematic userInfo:undoUserInfo];

  for ( FXSchematicElement* acceptedElement in newElements )
  {
    [acceptedElement setSchematic:nil];
    if ( acceptedElement.type == VMT_Node )
    {
      FXIssue(80)
      acceptedElement.name = @"";
    }
    [mSchematic checkAndAssignUniqueName:acceptedElement];
    [mSchematic addElement:acceptedElement];
    [acceptedElement setSchematic:mSchematic];
  }

  FXIssue(112)
  [self applyCurrentSchematicBoundingBox];

  [mSchematicView refresh];
}


- (void) encodeElementSelectionInState:(NSCoder*)state
{
  FXIssue(177)
  NSSet* selectedElementNames = [mSchematic selectedElements];
  NSMutableArray* selection = [[NSMutableArray alloc] initWithCapacity:[selectedElementNames count]];
  for ( id<VoltaSchematicElement> element in selectedElementNames )
  {
    [selection addObject:[element name]];
  }
  [state encodeObject:selection forKey:FXResume_SelectedSchematicElements];
  FXRelease(selection)
}


- (void) restoreElementSelectionFromState:(NSCoder*)state
{
  FXIssue(177)
  if ( [state containsValueForKey:FXResume_SelectedSchematicElements] )
  {
    NSArray* selectedElementNames = [state decodeObjectForKey:FXResume_SelectedSchematicElements];
    if ( [selectedElementNames count] > 0 )
    {
      NSMutableSet* selectedElements = [[NSMutableSet alloc] initWithCapacity:[selectedElementNames count]];
      NSSet* allElements = [mSchematic elements];
      for ( NSString* elementName in selectedElementNames )
      {
        for ( id<VoltaSchematicElement> element in allElements )
        {
          if ( [[element name] isEqualToString:elementName] )
          {
            [selectedElements addObject:element];
            break;
          }
        }
      }
      [mSchematic selectElementsInSet:selectedElements];
      FXRelease(selectedElements)
    }
  }
}


- (void) applyCurrentSchematicBoundingBox
{
  FXIssue(112)
  mSchematicBoundingBox = [mSchematic boundingBoxWithContext:NULL];
  NSRect originBox = NSMakeRect(MIN(0,mSchematicBoundingBox.origin.x), MIN(0,mSchematicBoundingBox.origin.y), fabs(mSchematicBoundingBox.origin.x), fabs(mSchematicBoundingBox.origin.y));
  mSchematicBoundingBox = NSUnionRect(mSchematicBoundingBox, originBox);
  CGFloat const scaledTotalWidth = ceil(NSMaxX(mSchematicBoundingBox) * mSchematic.scaleFactor);
  CGFloat const scaledTotalHeight = ceil(NSMaxY(mSchematicBoundingBox) * mSchematic.scaleFactor);
  CGSize const clipViewSize = [mSchematicScrollView contentSize];
  mSchematicView.frame = NSMakeRect(0, 0, MAX(scaledTotalWidth, clipViewSize.width), MAX(scaledTotalHeight, clipViewSize.height));
}


- (void) setAttributesOfShape:(id<FXShape>)shape fromDraggedItem:(id)item
{
  if ( [shape doesOwnDrawing] )
  {
    if ( [item isKindOfClass:[FXModel class]] )
    {
      FXModel* model = (FXModel*)item;
      shape.attributes = [NSDictionary dictionaryWithDictionary:model.displaySettings];
    }
    else if ([item isKindOfClass:[FXElement class]])
    {
      shape.attributes = [(FXElement*)item properties];
    }
    else if ([item isKindOfClass:[FXSchematicElement class]])
    {
      FXSchematicElement* schematicElement = (FXSchematicElement*)item;
      __block NSMutableDictionary* shapeAttributes = [[NSMutableDictionary alloc] initWithCapacity:schematicElement.numberOfProperties];
      [schematicElement enumeratePropertiesUsingBlock:^(NSString* key, id value, BOOL* stop) {
        shapeAttributes[key] = value;
      }];
      shape.attributes = shapeAttributes;
      FXRelease(shapeAttributes)
    }
  }
}


- (void) drawSchematicForPrintingWithContext:(CGContextRef)context inView:(NSView*)schematicView
{
  CGFloat const savedScale = mSchematic.scaleFactor;
  CGRect const unscaledSchematicRect = [mSchematic boundingBoxWithContext:context];
  NSSize const viewSize = schematicView.frame.size;
  CGFloat const scale = MIN( viewSize.width / unscaledSchematicRect.size.width, viewSize.height / unscaledSchematicRect.size.height );
  mSchematic.scaleFactor = scale;

  CGFloat const offsetX = viewSize.width/2 - scale * NSMidX(unscaledSchematicRect);
  CGFloat const offsetY = viewSize.height/2 - scale * NSMidY(unscaledSchematicRect);

  CGContextSaveGState(context);
  CGContextTranslateCTM(context, offsetX, offsetY);

  if ( [mSchematic numberOfElements] > 0 )
  {
    [[FXSchematicPainter sharedPainter] drawSchematic:mSchematic viewRect:CGRectZero];
  }

  CGContextRestoreGState(context);

  mSchematic.scaleFactor = savedScale;
}


@end
