//
//  GBAControllerSkin_Private.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/3/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAControllerSkin.h"

@interface GBAControllerSkin ()

- (NSDictionary *)dictionaryForOrientation:(GBAControllerSkinOrientation)orientation;
- (NSString *)keyForButtonRect:(GBAControllerSkinRect)button;
+ (NSString *)keyForCurrentDeviceWithDictionary:(NSDictionary *)dictionary;

// Should use -[GBAControllerView displayFrameForButtonRect:orientation:useExtendedEdges:] instead
- (CGRect)rectForButtonRect:(GBAControllerSkinRect)button orientation:(GBAControllerSkinOrientation)orientation useExtendedEdges:(BOOL)useExtendedEdges;
- (CGRect)screenRectForOrientation:(GBAControllerSkinOrientation)orientation;

@end
