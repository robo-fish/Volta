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

#import "FXVoltaDocumentPrintingViewController.h"
#import "VoltaSchematicEditor.h"
#import "VoltaCircuitSimulator.h"
#import "VoltaNetlistEditor.h"
#import "VoltaPlotter.h"
#import <FXKit/FXKit-Swift.h>


@interface FXVoltaDocumentPrintingViewController () <NSTextFieldDelegate>

@property (assign) IBOutlet NSButton* titleEnabler;
@property (assign) IBOutlet NSTextField* titleInputField;
@property (assign) IBOutlet NSButton* schematicEnabler;
@property (assign) IBOutlet NSButton* plotterEnabler;
@property (assign) IBOutlet NSPopUpButton* plotterOptionsSelector;
@property (assign) IBOutlet NSButton* netlistEnabler;
@property (assign) IBOutlet NSPopUpButton* netlistOptionsSelector;

/// These properties are used for bindings.
@property (nonatomic) BOOL printsSchematic;
@property (nonatomic) BOOL printsPlot;
@property (nonatomic) BOOL printsNetlist;
@property (nonatomic) BOOL printsHeader;
@property (nonatomic, readonly) BOOL schematicEnabled;
@property (nonatomic, readonly) BOOL plotEnabled;
@property (nonatomic, readonly) BOOL netlistEnabled;
@property (nonatomic, readonly) BOOL showsPlotOptions;
@property (nonatomic, readonly) BOOL showsNetlistOptions;
@property (nonatomic) NSString* headerTitle;
@property NSArray* plotterOptions;
@property (nonatomic) NSInteger selectedPlotterOption;

@end


NSString* const FXVoltaDocumentPrintSchematic = @"FXVoltaDocumentPrintSchematic";
NSString* const FXVoltaDocumentPrintPlot      = @"FXVoltaDocumentPrintPlot";
NSString* const FXVoltaDocumentPrintNetlist   = @"FXVoltaDocumentPrintNetlist";
NSString* const FXVoltaDocumentPrintHeader    = @"FXVoltaDocumentPrintHeader";


@implementation FXVoltaDocumentPrintingViewController
{
  NSView* mPreviewView;
  NSString* mHeaderTitle;
  NSPrintInfo* mPrintInfo;
  NSTextField* mTitleLabel;

@private
  id<VoltaSchematicEditor> mSchematicEditor;
  id<VoltaPlotter> mPlotter;
  id<VoltaNetlistEditor> mNetlistEditor;
  NSView* mSchematicPrintableView;
  NSView* mPlotterPrintableView;
  NSView* mNetlistPrintableView;
}


@synthesize headerTitle = mHeaderTitle;


+ (void) initialize
{
  [[NSUserDefaults standardUserDefaults] registerDefaults:@{
    FXVoltaDocumentPrintHeader    : @YES,
    FXVoltaDocumentPrintSchematic : @YES,
    FXVoltaDocumentPrintPlot      : @NO,
    FXVoltaDocumentPrintNetlist   : @NO
  }];
}


- (id) initWithPrintables:(NSArray *)printables printInfo:(NSPrintInfo*)printInfo title:(NSString*)title
{
  self = [super initWithNibName:@"VoltaDocumentPrintingAccessoryView" bundle:[NSBundle bundleForClass:[self class]]];
  if (self != nil)
  {
    for ( NSObject <VoltaPrintable> * printable in printables )
    {
      if ( [printable conformsToProtocol:@protocol(VoltaSchematicEditor)] )
      {
        mSchematicEditor = (id<VoltaSchematicEditor>)printable;
      }
      else if ( [printable conformsToProtocol:@protocol(VoltaPlotter)] )
      {
        mPlotter = (id<VoltaPlotter>)printable;
      }
      else if ( [printable conformsToProtocol:@protocol(VoltaNetlistEditor)] )
      {
        mNetlistEditor = (id<VoltaNetlistEditor>)printable;
      }
    }

    mSchematicPrintableView = [mSchematicEditor newPrintableView];
    if ( mSchematicPrintableView == nil )
    {
      [[NSUserDefaults standardUserDefaults] setBool:NO forKey:FXVoltaDocumentPrintSchematic];
    }

    mPlotterPrintableView = [mPlotter newPrintableView];
    if ( mPlotterPrintableView == nil )
    {
      [[NSUserDefaults standardUserDefaults] setBool:NO forKey:FXVoltaDocumentPrintPlot];
    }
    self.plotterOptions = [mPlotter optionsForPrintableView:mPlotterPrintableView];

    mNetlistPrintableView = [mNetlistEditor newPrintableView];
    if ( mNetlistPrintableView == nil )
    {
      [[NSUserDefaults standardUserDefaults] setBool:NO forKey:FXVoltaDocumentPrintNetlist];
    }

    mPrintInfo = printInfo;
    mPrintInfo.horizontallyCentered = YES;
    mPrintInfo.verticallyCentered = YES;
    mPrintInfo.horizontalPagination = NSFitPagination;
    mPrintInfo.verticalPagination = NSFitPagination;

    mPreviewView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 300)];
    mTitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 30)];
    mTitleLabel.bordered = NO;
  mTitleLabel.alignment = NSTextAlignmentCenter;
    mTitleLabel.font = [NSFont fontWithName:@"Times" size:18];
    mTitleLabel.textColor = [NSColor colorWithDeviceWhite:0.6 alpha:1];
    mHeaderTitle = title;
    [self updatePrintPreviewFromModel];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mSchematicEditor)
  FXRelease(mNetlistEditor)
  FXRelease(mPlotter)
  FXRelease(mTitleLabel)
  FXDeallocSuper
}


#pragma mark Public


- (NSView*) printPreviewView
{
  return mPreviewView;
}


#pragma mark NSKeyValueObserving


+ (BOOL) automaticallyNotifiesObserversForKey:(NSString *)key
{
  BOOL doNotNotify = [key isEqualToString:@"printsPlot"]
    || [key isEqualToString:@"printsSchematic"]
    || [key isEqualToString:@"printsNetlist"]
    || [key isEqualToString:@"printsHeader"]
    || [key isEqualToString:@"headerTitle"]
    || [key isEqualToString:@"selectedPlotterOption"];
  return !doNotNotify;
}


#pragma mark NSPrintPanelAccessorizing


- (NSArray*) localizedSummaryItems
{
  return @[
    @{
      NSPrintPanelAccessorySummaryItemNameKey : FXLocalizedString(@"Include schematic"),
      NSPrintPanelAccessorySummaryItemDescriptionKey : (self.printsSchematic ? FXLocalizedString(@"Yes") : FXLocalizedString(@"No"))
    },
    @{
      NSPrintPanelAccessorySummaryItemNameKey : FXLocalizedString(@"Include plot"),
      NSPrintPanelAccessorySummaryItemDescriptionKey : (self.printsPlot ? FXLocalizedString(@"Yes") : FXLocalizedString(@"No"))
    }
  ];
}


- (NSSet*) keyPathsForValuesAffectingPreview
{
  return [NSSet setWithObjects:
    @"printsSchematic",
    @"printsPlot",
    @"printsNetlist",
    @"printsHeader",
    @"headerTitle",
    @"selectedPlotterOption",
    nil];
}


#pragma mark Private


- (void) updatePrintPreviewFromModel
{
  @synchronized(self)
  {
    [self adjustViewSizeToPage];
    mTitleLabel.stringValue = self.headerTitle;
    mTitleLabel.hidden = !self.printsHeader;
    mPreviewView.subviews = @[];
    [mPreviewView removeConstraints:[mPreviewView constraints]];
    BOOL const schematic = self.printsSchematic && (mSchematicPrintableView != nil);
    BOOL const plot = self.printsPlot && (mPlotterPrintableView != nil);
    if ( schematic && plot )
    {
      if ( mPrintInfo.orientation == NSPaperOrientationPortrait )
      {
        [self layoutWithTopView:mSchematicPrintableView andBottomView:mPlotterPrintableView];
      }
      else
      {
        [self layoutWithLeftView:mSchematicPrintableView andRightView:mPlotterPrintableView];
      }
    }
    else
    {
      if (schematic)
        [self layoutWithSingleView:mSchematicPrintableView];
      else if ( plot )
        [self layoutWithSingleView:mPlotterPrintableView];
      else if ( self.printsHeader )
        [self layoutHeaderOnly];
    }
    [mPreviewView layoutSubtreeIfNeeded];
  }
}


- (void) adjustViewSizeToPage
{
  NSRect const pageBounds = mPrintInfo.imageablePageBounds;
  NSSize portraitPageSize = pageBounds.size;
  portraitPageSize.width -= mPrintInfo.leftMargin + mPrintInfo.rightMargin;
  portraitPageSize.height -= mPrintInfo.bottomMargin + mPrintInfo.topMargin;
  mPreviewView.frame = NSMakeRect(0, 0, portraitPageSize.width, portraitPageSize.height);
}


static CGFloat const kLayoutMargin = 16;


- (void) layoutWithLeftView:(NSView*)leftView andRightView:(NSView*)rightView
{
  if ( self.printsHeader )
  {
    NSTextField* title = mTitleLabel;
    [title sizeToFit];
    mPreviewView.subviews = @[title, leftView, rightView];
    [FXViewUtils layoutIn:mPreviewView
            visualFormats:@[ @"H:|[title]|",
                             @"H:|[leftView(viewWidth)]-(margin)-[rightView]|",
                             @"V:|[title]-(margin)-[leftView]|",
                             @"V:|[title]-(margin)-[rightView]|"]
              metricsInfo:@{ @"margin" : @(kLayoutMargin) ,
                             @"viewWidth" : @(floor((mPreviewView.frame.size.width - kLayoutMargin)/2)) }
                viewsInfo:NSDictionaryOfVariableBindings(title, leftView, rightView)];
  }
  else
  {
    mPreviewView.subviews = @[leftView, rightView];
    [FXViewUtils layoutIn:mPreviewView
            visualFormats:@[ @"H:|[leftView(viewWidth)]-(margin)-[rightView]|",
                             @"V:|[leftView]|",
                             @"V:|[rightView]|"]
              metricsInfo:@{ @"margin" : @(kLayoutMargin) ,
                             @"viewWidth" : @(floor((mPreviewView.frame.size.width - kLayoutMargin)/2)) }
                viewsInfo:NSDictionaryOfVariableBindings(leftView, rightView)];
  }
}


- (void) layoutWithTopView:(NSView*)topView andBottomView:(NSView*)bottomView
{
  if ( self.printsHeader )
  {
    NSTextField* title = mTitleLabel;
    mPreviewView.subviews = @[title, topView, bottomView];
    [FXViewUtils layoutIn:mPreviewView
            visualFormats:@[@"H:|[title]|",
                            @"H:|[topView]|",
                            @"H:|[bottomView]|",
                            @"V:|[title]-(margin)-[topView(topHeight)]-(margin)-[bottomView]|"]
              metricsInfo:@{ @"margin" : @(kLayoutMargin) ,
                             @"topHeight" : @(floor(mPreviewView.frame.size.height/2) - kLayoutMargin) }
                viewsInfo:NSDictionaryOfVariableBindings(title, topView, bottomView)];
  }
  else
  {
    mPreviewView.subviews = @[topView, bottomView];
    [FXViewUtils layoutIn:mPreviewView
            visualFormats:@[@"H:|[topView]|", @"H:|[bottomView]|", @"V:|[topView(height)]-(margin)-[bottomView]|"]
              metricsInfo:@{ @"margin" : @(kLayoutMargin) , @"height" : @(floor(mPreviewView.frame.size.height/2) - kLayoutMargin) }
                viewsInfo:NSDictionaryOfVariableBindings(topView, bottomView)];
  }
}


- (void) layoutWithSingleView:(NSView*)view
{
  if ( self.printsHeader )
  {
    NSTextField* title = mTitleLabel;
    mPreviewView.subviews = @[title, view];
    [FXViewUtils layoutIn:mPreviewView
            visualFormats:@[@"H:|[title]|", @"H:|[view]|", @"V:|[title]-(margin)-[view]|"]
              metricsInfo:@{ @"margin" : @(kLayoutMargin) }
                viewsInfo:NSDictionaryOfVariableBindings(title, view)];
  }
  else
  {
    mPreviewView.subviews = @[view];
    [FXViewUtils layoutIn:mPreviewView
            visualFormats:@[@"H:|[view]|", @"V:|[view]|"]
              metricsInfo:nil
                viewsInfo:NSDictionaryOfVariableBindings(view)];
  }
}


- (void) layoutHeaderOnly
{
  NSTextField* title = mTitleLabel;
  mPreviewView.subviews = @[title];
  [FXViewUtils layoutIn:mPreviewView
          visualFormats:@[@"H:|[title]|", @"V:|[title]"]
            metricsInfo:nil
              viewsInfo:NSDictionaryOfVariableBindings(title)];
}


- (BOOL) printsSchematic
{
  @synchronized(self)
  {
    return [[NSUserDefaults standardUserDefaults] boolForKey:FXVoltaDocumentPrintSchematic];
  }
}


- (void) setPrintsSchematic:(BOOL)print
{
  @synchronized(self)
  {
    [self willChangeValueForKey:@"printsSchematic"];
    [[NSUserDefaults standardUserDefaults] setBool:print forKey:FXVoltaDocumentPrintSchematic];
    [self updatePrintPreviewFromModel];
    [self didChangeValueForKey:@"printsSchematic"];
  }
}


- (BOOL) printsPlot
{
  @synchronized(self)
  {
    return [[NSUserDefaults standardUserDefaults] boolForKey:FXVoltaDocumentPrintPlot];
  }
}


- (void) setPrintsPlot:(BOOL)print
{
  @synchronized(self)
  {
    [self willChangeValueForKey:@"printsPlot"];
    [[NSUserDefaults standardUserDefaults] setBool:print forKey:FXVoltaDocumentPrintPlot];
    [self updatePrintPreviewFromModel];
    [self didChangeValueForKey:@"printsPlot"];
  }
}


- (BOOL) printsNetlist
{
  @synchronized(self)
  {
    return [[NSUserDefaults standardUserDefaults] boolForKey:FXVoltaDocumentPrintNetlist];
  }
}


- (void) setPrintsNetlist:(BOOL)print
{
  @synchronized(self)
  {
    [self willChangeValueForKey:@"printsPlot"];
    [[NSUserDefaults standardUserDefaults] setBool:print forKey:FXVoltaDocumentPrintNetlist];
    [self updatePrintPreviewFromModel];
    [self didChangeValueForKey:@"printsPlot"];
  }
}


- (BOOL) printsHeader
{
  @synchronized(self)
  {
    return [[NSUserDefaults standardUserDefaults] boolForKey:FXVoltaDocumentPrintHeader];
  }
}


- (void) setPrintsHeader:(BOOL)print
{
  @synchronized(self)
  {
    [self willChangeValueForKey:@"printsHeader"];
    [[NSUserDefaults standardUserDefaults] setBool:print forKey:FXVoltaDocumentPrintHeader];
    [self updatePrintPreviewFromModel];
    [self didChangeValueForKey:@"printsHeader"];
  }
}


- (void) setHeaderTitle:(NSString*)title
{
  @synchronized(self)
  {
    [self willChangeValueForKey:@"headerTitle"];
    mHeaderTitle = (title != nil) ? title : @"";
    [self updatePrintPreviewFromModel];
    [self didChangeValueForKey:@"headerTitle"];
  }
}


- (BOOL) schematicEnabled
{
  return mSchematicPrintableView != nil;
}


- (BOOL) plotEnabled
{
  return mPlotterPrintableView != nil;
}


- (BOOL) netlistEnabled
{
  return mNetlistPrintableView != nil;
}


- (BOOL) showsPlotOptions
{
  return self.plotterOptions.count > 1;
}


- (BOOL) showsNetlistOptions
{
  return (mNetlistEditor != nil) && ([[mNetlistEditor optionsForPrintableView:mNetlistPrintableView] count] > 1);
}


- (NSInteger) selectedPlotterOption
{
  return [mPlotter selectedOptionForPrintableView:mPlotterPrintableView];
}


- (void) setSelectedPlotterOption:(NSInteger)selectedPlotterOption
{
  @synchronized(self)
  {
    [self willChangeValueForKey:@"selectedPlotterOption"];
    [mPlotter selectOption:selectedPlotterOption forPrintableView:mPlotterPrintableView];
    [self updatePrintPreviewFromModel];
    [self didChangeValueForKey:@"selectedPlotterOption"];
  }
}


@end
