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

#import "FXSchematicPaletteController.h"
#import "FXSchematicElement.h"
#import "VoltaSchematicElementGroup.h"
#import "FXSchematicPaletteElementsView.h"
#import "FXSchematicPaletteView.h"

static const CGFloat skPaletteHeight = 90.0;
static const CGFloat skElementsViewLeftMargin = 24;

static dispatch_queue_t sSchematicPaletteMenuUpdateQueue;

struct FXSchematicPaletteGCDQueues
{
  FXSchematicPaletteGCDQueues()
  {
    sSchematicPaletteMenuUpdateQueue = dispatch_queue_create("fish.robo.volta.palette_menu", DISPATCH_QUEUE_SERIAL);
  }
};

static FXSchematicPaletteGCDQueues sSchematicPaletteGCDQueues;


@implementation FXSchematicPaletteController
{
@private  
  /// maps group names to FXSchematicElementGroup instances
  NSMutableArray* mElementGroups;

  /// the name of the current selected palette
  NSString* mSelectedGroupName;

  BOOL mBatchEditingElementGroups;

  NSMenu* mGroupSelectionMenu;
  
  id<VoltaSchematicPaletteGroupEditor> __weak mGroupEditor;
  FXSchematicPaletteElementsView* mElementsView;
  NSScrollView* mElementsScrollView;
  NSPopUpButton* mGroupSelectionPopup;
  NSView* mScrollViewContainer;
}

@dynamic view;
@synthesize groupEditor = mGroupEditor;


- (id) init
{
  self = [super init];
  mElementGroups = [[NSMutableArray alloc] init];
  mGroupSelectionMenu = [[NSMenu alloc] initWithTitle:@"Palette Groups"];
  mBatchEditingElementGroups = NO;
  return self;
}


- (void) dealloc
{
  [mGroupSelectionMenu removeAllItems];
  FXRelease(mGroupSelectionMenu)
  FXRelease(mElementGroups)
  FXRelease(mSelectedGroupName)
  FXDeallocSuper
}


#pragma mark Public


- (void) setSelectedGroup:(NSString*)selectedGroupName
{
  [self setSelectedGroup:selectedGroupName animate:YES];
}


- (NSString*) selectedGroup
{
  return mBatchEditingElementGroups ? mSelectedGroupName : mElementsView.elements.name;
}


- (void) beginEditingElementGroups
{
  mBatchEditingElementGroups = YES;
}


- (void) endEditingElementGroups
{
  mBatchEditingElementGroups = NO;
  id<VoltaSchematicElementGroup> selectedGroup = nil;
  for ( id<VoltaSchematicElementGroup> group in mElementGroups )
  {
    if ( [group.name isEqualToString:mSelectedGroupName] )
    {
      selectedGroup = group;
      break;
    }
  }
  if ( (selectedGroup == nil) && ([mElementGroups count] > 0) )
  {
    selectedGroup = mElementGroups[0];
  }
  [self rebuildGroupChooserMenu];
  [self setSelectedGroup:selectedGroup.name animate:NO];
}


#pragma mark NSResponder overrides


- (void) encodeRestorableStateWithCoder:(NSCoder*)state
{
  [super encodeRestorableStateWithCoder:state];
  NSString* displayedGroupName = mElementsView.elements.name;
  if ( displayedGroupName != nil )
  {
    [state encodeObject:displayedGroupName forKey:@"SchematicPalette_DisplayedGroup"];
  }
}


- (void) restoreStateWithCoder:(NSCoder*)state
{
  [super restoreStateWithCoder:state];
  NSString* displayedGroupName = [state decodeObjectForKey:@"SchematicPalette_DisplayedGroup"];
  if ( displayedGroupName != nil )
  {
    [self setSelectedGroup:displayedGroupName animate:NO];
  }
}


#pragma mark NSViewController overrides


- (void) loadView
{
  NSRect const dummyFrame = NSMakeRect(0, 0, 100, skPaletteHeight);
  NSView* view = [[FXSchematicPaletteView alloc] initWithFrame:dummyFrame];
  view.autoresizingMask = (NSViewHeightSizable | NSViewWidthSizable);
  [self setView:view];
  FXRelease(view)

  [self createElementsView];
  [self createGroupSelectionPopup];
  [self layOutViews];
  if ( [mElementGroups count] > 0 )
  {
    [self setSelectedGroup:[(id<VoltaSchematicElementGroup>)mElementGroups[0] name] animate:NO];
  }
}


#pragma mark VoltaSchematicPalette implementation


- (void) addElementGroup:(id<VoltaSchematicElementGroup>)group
{
  @synchronized(mElementGroups)
  {
    if ( ![mElementGroups containsObject:[group name]] )
    {
      [mElementGroups addObject:group];

      if ( !mBatchEditingElementGroups && ([mElementGroups count] == 1) )
      {
        [mElementsView setElements:group animate:!mBatchEditingElementGroups];
      }
    }
    else if ( !mBatchEditingElementGroups && [[group name] isEqualToString:[[mElementsView elements] name]] )
    {
      // If the group is already shown in the elements viewer strip it may need a refresh.
      [mElementsView refresh];
    }
  }
  if ( !mBatchEditingElementGroups )
  {
    [self rebuildGroupChooserMenu];
  }
}


- (void) removeAllElementGroups
{
  @synchronized(mElementGroups)
  {
    [mElementGroups removeAllObjects];
    [mElementsView setElements:nil animate:NO];
    if ( !mBatchEditingElementGroups )
    {
      [mElementsView refresh];
    }
  }
  if ( !mBatchEditingElementGroups )
  {
    [self rebuildGroupChooserMenu];
  }
}


- (CGFloat) minWidth
{
  return mElementsScrollView.frame.origin.x + 1;
}


#pragma mark Private


- (void) setSelectedGroup:(NSString*)groupName animate:(BOOL)animate
{
  @synchronized(mElementGroups)
  {
    if ( mBatchEditingElementGroups )
    {
      if ( mSelectedGroupName != groupName )
      {
        FXRelease(mSelectedGroupName)
        mSelectedGroupName = [groupName copy];
      }
    }
    else
    {
      id<VoltaSchematicElementGroup> displayedGroup = nil;
      for ( id<VoltaSchematicElementGroup> group in mElementGroups )
      {
        if ( [[group name] isEqualToString:groupName] )
        {
          displayedGroup = group;
          break;
        }
      }
      if ( (displayedGroup == nil) && ([mElementGroups count] > 0) )
      {
        displayedGroup = mElementGroups[0];
      }
      if ( !mBatchEditingElementGroups )
      {
        [mElementsView setElements:displayedGroup animate:animate];
      }
      [mGroupSelectionPopup selectItemWithTitle:displayedGroup.name];
    }
  }
  [[self.view window] invalidateRestorableState];
}


- (void) rebuildGroupChooserMenu
{
  dispatch_async(sSchematicPaletteMenuUpdateQueue, ^{
    @synchronized(mElementGroups)
    {
      [mGroupSelectionMenu removeAllItems];
      if ( [mElementGroups count] > 0 )
      {
        for ( id<VoltaSchematicElementGroup> group in mElementGroups )
        {
          NSString* groupName = [group name];
          NSMenuItem* groupMenuItem = [[NSMenuItem alloc] initWithTitle:groupName action:@selector(selectGroup:) keyEquivalent:@""];
          [groupMenuItem setTarget:self];
          [mGroupSelectionMenu addItem:groupMenuItem];
          FXRelease(groupMenuItem)
        }
        [mGroupSelectionMenu addItem:[NSMenuItem separatorItem]];
      }
      NSMenuItem* editItem = [[NSMenuItem alloc] initWithTitle:FXLocalizedString(@"Edit…") action:@selector(selectGroup:) keyEquivalent:@""];
      [editItem setTarget:self];
      [editItem setRepresentedObject:mElementGroups]; // Retains mElementGroups. This prevents users from fouling up the app by creating a custom group named "Edit…"
      [mGroupSelectionMenu addItem:editItem];
      FXRelease(editItem)
    }
  });
}


- (void) selectGroup:(id)sender
{
  NSAssert( [sender isKindOfClass:[NSMenuItem class]], @"Unexpected sender." );
  @synchronized(mElementGroups)
  {
    NSString* selectedGroupName = nil;
    if ( [(NSMenuItem*)sender representedObject] == mElementGroups )
    {
      [mGroupEditor openGroupEditor];
    }
    else
    {
      selectedGroupName = [(NSMenuItem*)sender title];
    }
    [self setSelectedGroup:selectedGroupName animate:YES];
  }
}


- (void) createElementsView
{
  NSRect const dummyFrame = NSMakeRect(skElementsViewLeftMargin, 0, 100, skPaletteHeight);
  mElementsView = [[FXSchematicPaletteElementsView alloc] initWithFrame:dummyFrame];

  mElementsScrollView = [[NSScrollView alloc] initWithFrame:dummyFrame];
  mElementsScrollView.hasHorizontalScroller = YES;
  mElementsScrollView.scrollerStyle = NSScrollerStyleOverlay;
  mElementsScrollView.scrollerKnobStyle = NSScrollerKnobStyleDark;
  mElementsScrollView.autohidesScrollers = YES;
  mElementsScrollView.drawsBackground = NO;
  mElementsScrollView.verticalScrollElasticity = NSScrollElasticityNone;
  mElementsScrollView.documentView = mElementsView;
  [[mElementsScrollView contentView] setCopiesOnScroll:YES];

  mScrollViewContainer = [[NSView alloc] initWithFrame:dummyFrame];
  [mScrollViewContainer addSubview:mElementsScrollView];
  [[self view] addSubview:mScrollViewContainer];

  FXRelease(mElementsView)
  FXRelease(mElementsScrollView)
  FXRelease(mScrollViewContainer)
}


- (void) createGroupSelectionPopup
{
  mGroupSelectionPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 12)];
  mGroupSelectionPopup.pullsDown = NO;
  mGroupSelectionPopup.bordered = NO;
  mGroupSelectionPopup.preferredEdge = NSMaxXEdge;
  mGroupSelectionPopup.action = @selector(selectGroup:);
  mGroupSelectionPopup.target = self;
  mGroupSelectionPopup.menu = mGroupSelectionMenu;
  [[self view] addSubview:mGroupSelectionPopup];
  FXRelease(mGroupSelectionPopup)
}


- (void) layOutViews
{
  // Note: There seems to be a bug in NSScrollView that requires an embedding view of the same size in order for the overlay scroll bars to work correctly.
  NSView* chooser = mGroupSelectionPopup;
  NSView* scroller = mElementsScrollView;
  NSView* scrollerContainer = mScrollViewContainer;
  chooser.translatesAutoresizingMaskIntoConstraints = NO;
  scroller.translatesAutoresizingMaskIntoConstraints = NO;
  scrollerContainer.translatesAutoresizingMaskIntoConstraints = NO;
  NSDictionary* views = NSDictionaryOfVariableBindings(chooser, scroller, scrollerContainer);
  NSDictionary* metrics = @{
    @"paletteHeight"      : @(skPaletteHeight),
    @"elementsLeftMargin" : @(skElementsViewLeftMargin)
  };
  [scrollerContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[scroller]|" options:0 metrics:nil views:views]];
  [scrollerContainer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[scroller]|" options:0 metrics:nil views:views]];
  NSArray* constraints = @[
    @"|-4-[chooser(14)]",
    @"|-elementsLeftMargin-[scrollerContainer]|",
    @"V:|[scrollerContainer]|",
    @"V:|-4-[chooser]"
  ];
  for ( NSString* constraint in constraints )
  {
    [[self view] addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:constraint options:0 metrics:metrics views:views]];
  }
}


@end
