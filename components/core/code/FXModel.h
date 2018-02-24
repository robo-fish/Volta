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

#import "VoltaPersistentTypes.h"

@protocol FXShape, VoltaLibrary;

/// Objective-C wrapper for VoltaPTModelPtr
@interface FXModel : NSObject <NSCopying, NSCoding, NSPasteboardWriting, NSPasteboardReading>

@property (nonatomic, readonly) VoltaPTModelPtr persistentModel;
@property (readonly) id<FXShape> shape;
@property (nonatomic, copy, readonly) NSString* name;
@property (nonatomic, copy, readonly) NSString* vendor;
@property (nonatomic, readonly) VoltaModelType type;
@property (weak, nonatomic, readonly) NSString* subtype;
@property (nonatomic, readonly) BOOL isMutable;
@property (weak, nonatomic, readonly) NSURL* source;
@property (nonatomic, readonly) id<VoltaLibrary> library;
@property (nonatomic) NSMutableDictionary* displaySettings;

- (id) initWithPersistentModel:(VoltaPTModelPtr)model;

@end



@interface FXMutableModel : FXModel
- (void) setName:(NSString*)name;
- (void) setVendor:(NSString*)vendor;
- (void) setLibrary:(id<VoltaLibrary>)library;
@property id<FXShape> shape;
@end



extern NSString* FXPasteboardDataTypeModel;
extern NSString* FXPasteboardDataTypeModelGroup;
