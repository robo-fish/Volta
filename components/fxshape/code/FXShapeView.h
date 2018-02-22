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

#import "FXShape.h"


typedef NS_ENUM(short, FXShapeViewScaleMode)
{
  FXShapeViewScaleMode_None,
  FXShapeViewScaleMode_FitToView,       // up or down scaling
  FXShapeViewScaleMode_ScaleDownToFit,  // no scaling up
  FXShapeViewScaleMode_ScaleUpToFit     // no scaling down
};


typedef NS_ENUM(short, FXShapeViewVerticalAlignment)
{
  FXShapeViewVerticalAlignment_Top,
  FXShapeViewVerticalAlignment_Center,
  FXShapeViewVerticalAlignment_Bottom
};


@protocol FXShapeViewDelegate <NSObject>
- (NSArray*) provideObjectsForDragging;
@end


/// A view that can display an FXShape.
@interface FXShapeView : FXView

@property (nonatomic) id<FXShape> shape;
@property (nonatomic) NSDictionary* shapeAttributes;
@property (nonatomic, weak) id<FXShapeViewDelegate> delegate;
@property (nonatomic) BOOL isCached;
@property (nonatomic) BOOL isBordered;
@property (nonatomic) BOOL isDraggable;
@property (nonatomic) BOOL isSelected;
@property FXShapeViewScaleMode scaleMode;
@property (nonatomic) BOOL enabled;
@property (nonatomic) FXShapeViewVerticalAlignment verticalAlignment;
@property CGFloat rotation; ///< in radian
@property (nonatomic, copy) __attribute__((NSObject)) CGColorRef shapeColor;
@property (nonatomic, copy) __attribute__((NSObject)) CGColorRef selectedShapeColor;

- (NSImage*) draggingImage;

@end
