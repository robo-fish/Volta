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

@protocol FXShape;
@class FXShapeView;

@interface FXLibraryEditorCellView : NSView
{
@protected
  FXShapeView* mShapeView;
}

@property (nonatomic, readonly) NSTextField* primaryField;
@property (nonatomic, readonly) NSTextField* secondaryField;
@property (nonatomic, readonly) NSTextField* singlePropertyField;
@property (nonatomic, readonly) NSButton* actionButton;
@property (nonatomic) BOOL isEditable;
@property (nonatomic) BOOL showsLockSymbol;
@property (nonatomic) BOOL showsActionButton;
@property (nonatomic) SEL heightChangeAction;
@property (nonatomic, unsafe_unretained) id heightChangeTarget;
@property (nonatomic) CGFloat leftIndentation;

- (void) setPropertyKeys:(NSArray*)propertyKeys;

- (void) setShape:(id<FXShape>)newShape;

- (CGFloat) height;

- (void) updateDisplay;

- (NSArray*) draggingImageComponents;

@end


extern NSString* const FXLibraryEditorCell_PropertiesAreExpanded;
extern NSString* const FXLibraryEditorCell_PropertiesHaveBeenEdited;

