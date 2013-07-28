//
//  GBAControllerSkin.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GBAControllerSkinOrientation)
{
    GBAControllerSkinOrientationPortrait = 0,
    GBAControllerSkinOrientationLandscape = 1
};

typedef NS_ENUM(NSInteger, GBAControllerItem)
{
    GBAControllerItemDPad,
    GBAControllerItemA,
    GBAControllerItemB,
    GBAControllerItemAB,
    GBAControllerItemL,
    GBAControllerItemR,
    GBAControllerItemStart,
    GBAControllerItemSelect,
    GBAControllerItemMenu,
    GBAControllerItemScreen
};

@interface GBAControllerSkin : NSObject

- (instancetype)initWithDirectory:(NSString *)directory;

- (UIImage *)imageForOrientation:(GBAControllerSkinOrientation)orientation;
- (CGRect)rectForItem:(GBAControllerItem)item orientation:(GBAControllerSkinOrientation)orientation;

@end
