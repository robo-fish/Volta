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

#import "FXNetlistEditor.h"
#import "FXTextView.h"
#import "FXNetlistSyntaxHighlighter.h"


@implementation FXNetlistEditor
{
@private
  FXTextView* mTextView;
  __weak NSUndoManager* mUndoManager;
  BOOL mUndoEnabled;
}


- (id) init
{
  if ( (self = [super init]) != nil )
  {
    mTextView = nil;
    mUndoManager = nil;
  }
  return self;
}


- (void) dealloc
{
  mUndoManager = nil;
  FXRelease(mTextView)
  FXDeallocSuper
}


#pragma mark VoltaNetlistEditor


- (void) setNetlistString:(NSString*)netlistString
{
  [mTextView setString:netlistString];
}


- (NSString*) netlistString;
{
  return [mTextView string];
}


- (NSView*) editorView
{
  if ( mTextView == nil )
  {
    mTextView = [[FXTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    mTextView.gutterBackgroundColor = [NSColor colorWithDeviceRed:0.95 green:0.97 blue:0.95 alpha:1.0];
    mTextView.gutterSeparatorColor = [NSColor colorWithDeviceRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    mTextView.gutterTextColor = [NSColor colorWithDeviceRed:0.6 green:0.7 blue:0.6 alpha:1.0];
    mTextView.font = [NSFont fontWithName:@"Menlo" size:12];
    FXNetlistSyntaxHighlighter* syntaxHighlighter = [[FXNetlistSyntaxHighlighter alloc] init];
    mTextView.syntaxHighlighter = syntaxHighlighter;
    FXRelease(syntaxHighlighter)
    mTextView.delegate = self;
  }
  return mTextView;
}


- (CGSize) minimumViewSize
{
  return NSMakeSize(50, 20);
}


- (void) setUndoManager:(NSUndoManager*)undoManager
{
  mUndoManager = undoManager;
}


#pragma mark VoltaPrintable


- (FXView*) newPrintableView
{
  FXTextView* printableView = nil;
  if ( mTextView.string.length > 0 )
  {
    printableView = [FXTextView newPrintableInstance];
    printableView.syntaxHighlighter = mTextView.syntaxHighlighter;
    printableView.string = mTextView.string;
  }
  return printableView;
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


#pragma mark Private


- (void) undoTextChange:(NSString*)text
{
  NSString* currentText = [mTextView string];
  if ( ![currentText isEqualToString:text] )
  {
    // Creating a redo action
    [mUndoManager registerUndoWithTarget:self selector:@selector(undoTextChange:) object:currentText];
    [mUndoManager setActionName:FXLocalizedString(@"Action_edit_netlist")];
    // Applying the change
    [mTextView setString:text];
  }
}


#pragma mark FXTextViewDelegate


- (void) textWillChange:(FX(FXTextView)*)textView
{
  FXIssue(32)
  NSAssert( textView == mTextView, @"Message sent to wrong delegate." );
  if ( mUndoManager != nil )
  {
    [mUndoManager registerUndoWithTarget:self selector:@selector(undoTextChange:) object:[mTextView string]];
    [mUndoManager setActionName:FXLocalizedString(@"Action_edit_netlist")];
  }
}


- (void) textDidChange:(FX(FXTextView)*)textView
{
  NSAssert( textView == mTextView, @"Message sent to wrong delegate." );
}


@end
