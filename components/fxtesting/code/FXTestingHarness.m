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

#import "FXTestingHarness.h"
#include <objc/objc-runtime.h>

@interface FXTestingHarness ()

@property (assign) IBOutlet NSWindow* harnessWindow;
@property (assign) IBOutlet NSTextView* logOutputView;
@property (assign) IBOutlet NSBox* containerView;

- (IBAction) runTests:(id)sender;

@end


@implementation FXTestingHarness
{
@private
  NSWindow* mHarnessWindow;
  NSView* mTestableView;
  NSTextView* mLogOutputView;
  NSBox* mContainerView;
  id mTestProvider;

  NSDictionary* mDefaultMessageAttributes;
  NSDictionary* mErrorMessageAttributes;
  NSDictionary* mSuccessMessageAttributes;

  NSMutableArray* mErrorMessages;
  NSMutableArray* mLogMessages;
}

@synthesize logOutputView = mLogOutputView;
@synthesize containerView = mContainerView;
@synthesize harnessWindow = mHarnessWindow;


- (id) initWithTestableView:(NSView*)view testProvider:(id)provider;
{
  if ( (self = [super init]) != nil )
  {
    mTestableView = view;
    mTestProvider = provider;
    FXRetain(mTestableView)
    [NSBundle loadNibNamed:@"TestingHarness" owner:self];
    NSColor* redColor = [NSColor colorWithDeviceRed:0.7 green:0 blue:0 alpha:1];
    NSColor* greenColor = [NSColor colorWithDeviceRed:0 green:0.7 blue:0 alpha:1];
    mDefaultMessageAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor blackColor], NSForegroundColorAttributeName, nil];
    mErrorMessageAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:redColor, NSForegroundColorAttributeName, nil];
    mSuccessMessageAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:greenColor, NSForegroundColorAttributeName, nil];
    mErrorMessages = [[NSMutableArray alloc] initWithCapacity:5];
    mLogMessages = [[NSMutableArray alloc] initWithCapacity:5];
  }
  return self;
}


- (void) dealloc
{
  FXRelease(mLogMessages)
  FXRelease(mErrorMessages)
  FXRelease(mTestableView)
  FXRelease(mDefaultMessageAttributes)
  FXRelease(mErrorMessageAttributes)
  FXRelease(mSuccessMessageAttributes)
  FXDeallocSuper
}


#pragma mark Public


- (void) log:(NSString*)message
{
  [mLogMessages addObject:message];
}


- (void) logError:(NSString*)message
{
  [mErrorMessages addObject:message];
}


#pragma mark NSObject overrides


- (void) awakeFromNib
{
  if ( mTestableView != nil )
  {
    [mContainerView setFrameSize:[mTestableView frame].size];
    [mContainerView setContentView:mTestableView];
    [mHarnessWindow makeKeyAndOrderFront:self];
  }
}


#pragma mark Private


- (void) logMessage:(NSString*)message withAttributes:(NSDictionary*)textAttributes
{
  if ( (message != nil) && (textAttributes != nil) )
  {
    message = [message stringByAppendingString:@"\n"];
    [self appendText:message withAttributes:textAttributes];
  }
}


- (void) appendText:(NSString*)text withAttributes:(NSDictionary*)textAttributes
{
  NSAttributedString* attributedText = [[NSAttributedString alloc] initWithString:text attributes:textAttributes];
  [[mLogOutputView textStorage] appendAttributedString:attributedText];
  FXRelease(attributedText)
}


- (IBAction) runTests:(id)sender
{
  if ( mTestProvider != nil )
  {
    Class clientClass = object_getClass(mTestProvider);
    unsigned int numMethods = 0;
    Method* methods = class_copyMethodList(clientClass, &numMethods);
    for ( unsigned int i = 0; i < numMethods; i++ )
    {
      Method method = methods[i];
      SEL methodSelector = method_getName(method);
      const char* methodName = sel_getName(methodSelector);
      if ( methodName != NULL )
      {
      #if 0
        unsigned int numMethods = method_getNumberOfArguments(method);
        if ( numMethods == 3 )
      #endif
        {
          static char const * const skTestMethodPrefix = "test";
          if ( strstr(methodName, skTestMethodPrefix) == methodName )
          {
            [self runTestWithSelector:methodSelector];
          }
        }
      }
    }
  }
}


- (void) runTestWithSelector:(SEL)testMethod
{
  [mErrorMessages removeAllObjects];
  [mLogMessages removeAllObjects];
  [self appendText:[NSString stringWithFormat:@"%s...", sel_getName(testMethod)] withAttributes:mDefaultMessageAttributes];
  [mTestProvider performSelector:testMethod];
  if ( [mErrorMessages count] > 0 )
  {
    [self appendText:@" Failed\n" withAttributes:mErrorMessageAttributes];
    for (NSString* message in mErrorMessages)
    {
      [self appendText:[NSString stringWithFormat:@"   %@\n", message] withAttributes:mErrorMessageAttributes];
    }
  }
  else
  {
    [self appendText:@" Success\n" withAttributes:mSuccessMessageAttributes];
  }
  if ( [mLogMessages count] > 0 )
  {
    for ( NSString* message in mLogMessages )
    {
      [self appendText:[NSString stringWithFormat:@"   %@\n", message] withAttributes:mDefaultMessageAttributes];
    }
  }
}


@end
