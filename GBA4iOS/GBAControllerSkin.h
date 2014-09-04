//
//  GBAControllerSkin.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAControllerInput.h"

typedef NS_ENUM(NSInteger, GBAControllerSkinRect)
{
    GBAControllerSkinRectDPad,
    GBAControllerSkinRectA,
    GBAControllerSkinRectB,
    GBAControllerSkinRectAB,
    GBAControllerSkinRectL,
    GBAControllerSkinRectR,
    GBAControllerSkinRectStart,
    GBAControllerSkinRectSelect,
    GBAControllerSkinRectMenu,
    GBAControllerSkinRectScreen
};

typedef NS_ENUM(NSInteger, GBAControllerSkinType)
{
    GBAControllerSkinTypeGBA = 0,
    GBAControllerSkinTypeGBC = 1
};

typedef NS_OPTIONS(NSInteger, GBAControllerSkinOrientation) // Yes, it's supposed to be a bitmask. Don't try to turn it into a normal enum like last time, dumbass.
{
    GBAControllerSkinOrientationPortrait   =    1 << 0,
    GBAControllerSkinOrientationLandscape  =    1 << 1,
};

extern NSString *const GBADefaultSkinIdentifier;

@interface GBAControllerSkin : NSObject

@property (readonly, copy, nonatomic) NSString *filepath;

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *identifier;
@property (readonly, nonatomic) GBAControllerSkinType type;
@property (readonly, nonatomic) BOOL debug;

+ (GBAControllerSkin *)controllerSkinWithContentsOfFile:(NSString *)filepath;
+ (GBAControllerSkin *)defaultControllerSkinForSkinType:(GBAControllerSkinType)skinType;
+ (GBAControllerSkin *)invisibleSkin; // Used when external controller is connected

+ (BOOL)extractSkinAtPathToSkinsDirectory:(NSString *)filepath;

- (UIImage *)imageForOrientation:(GBAControllerSkinOrientation)orientation;
- (BOOL)imageExistsForOrientation:(GBAControllerSkinOrientation)orientation;
- (BOOL)isTranslucentForOrientation:(GBAControllerSkinOrientation)orientation;
- (CGRect)screenRectForOrientation:(GBAControllerSkinOrientation)orientation;
- (GBAControllerSkinOrientation)supportedOrientations;

- (CGRect)rectForButtonRect:(GBAControllerSkinRect)button orientation:(GBAControllerSkinOrientation)orientation; // Uses extended edges
- (CGRect)rectForButtonRect:(GBAControllerSkinRect)button orientation:(GBAControllerSkinOrientation)orientation extended:(BOOL)extended;

@end
