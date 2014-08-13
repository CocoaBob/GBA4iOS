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

typedef NS_OPTIONS(NSInteger, GBAControllerOrientation) // Yes, it's supposed to be a bitmask. Don't try to turn it into a normal enum like last time, dumbass.
{
    GBAControllerSkinOrientationPortrait   =    1 << 0,
    GBAControllerSkinOrientationLandscape  =    1 << 1,
};

static NSString *GBAScreenTypeiPhone = @"iPhone";
static NSString *GBAScreenTypeiPhoneWidescreen = @"iPhone Widescreen";
static NSString *GBAScreenTypeiPad = @"iPad";
static NSString *GBAScreenTypeiPadRetina = @"iPad Retina";

static NSString *GBADefaultSkinIdentifier = @"com.GBA4iOS.default";

@interface GBAControllerSkin : NSObject

@property (readonly, copy, nonatomic) NSString *filepath;
@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, assign, nonatomic) GBAControllerSkinType type;
@property (readonly, assign, nonatomic) BOOL debug;

+ (GBAControllerSkin *)controllerSkinWithContentsOfFile:(NSString *)filepath;
+ (GBAControllerSkin *)defaultControllerSkinForSkinType:(GBAControllerSkinType)skinType;
+ (GBAControllerSkin *)invisibleSkin; // Used when external controller is connected

+ (BOOL)extractSkinAtPathToSkinsDirectory:(NSString *)filepath;

- (UIImage *)imageForOrientation:(GBAControllerOrientation)orientation;
- (BOOL)imageExistsForOrientation:(GBAControllerOrientation)orientation;
- (NSDictionary *)dictionaryForOrientation:(GBAControllerOrientation)orientation;
- (NSString *)keyForButtonRect:(GBAControllerSkinRect)button;
- (GBAControllerOrientation)supportedOrientations;
+ (NSString *)keyForCurrentDeviceWithDictionary:(NSDictionary *)dictionary;
- (NSString *)identifier;
- (CGRect)screenRectForOrientation:(GBAControllerOrientation)orientation;

- (CGRect)rectForButtonRect:(GBAControllerSkinRect)button orientation:(GBAControllerOrientation)orientation; // Uses extended edges
- (CGRect)rectForButtonRect:(GBAControllerSkinRect)button orientation:(GBAControllerOrientation)orientation extended:(BOOL)extended;

@end
