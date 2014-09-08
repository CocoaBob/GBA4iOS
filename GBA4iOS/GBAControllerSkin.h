//
//  GBAControllerSkin.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAControllerInput.h"

typedef NS_ENUM(NSInteger, GBAControllerSkinMapping)
{
    GBAControllerSkinMappingDPad,
    GBAControllerSkinMappingA,
    GBAControllerSkinMappingB,
    GBAControllerSkinMappingAB,
    GBAControllerSkinMappingL,
    GBAControllerSkinMappingR,
    GBAControllerSkinMappingStart,
    GBAControllerSkinMappingSelect,
    GBAControllerSkinMappingMenu,
    GBAControllerSkinMappingScreen,
    GBAControllerSkinMappingControllerImage,
};

typedef NS_ENUM(NSInteger, GBAControllerSkinType)
{
    GBAControllerSkinTypeGBA = 0,
    GBAControllerSkinTypeGBC = 1,
};

typedef NS_OPTIONS(NSInteger, GBAControllerSkinDeviceType)
{
    GBAControllerSkinDeviceTypeiPhone   = 1 << 0,
    GBAControllerSkinDeviceTypeiPad     = 1 << 2,
};

typedef NS_OPTIONS(NSInteger, GBAControllerSkinOrientation) // Yes, it's supposed to be a bitmask. Don't try to turn it into a normal enum like last time, dumbass.
{
    GBAControllerSkinOrientationPortrait   =    1 << 0,
    GBAControllerSkinOrientationLandscape  =    1 << 1,
};

extern NSString *const GBADefaultSkinIdentifier;

@interface GBAControllerSkin : NSObject <NSCoding>

@property (readonly, copy, nonatomic) NSString *filepath;
@property (readonly, copy, nonatomic) NSString *filename;

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *identifier;
@property (readonly, nonatomic) GBAControllerSkinType type;
@property (readonly, nonatomic) GBAControllerSkinDeviceType deviceType;
@property (readonly, nonatomic) GBAControllerSkinOrientation supportedOrientations;
@property (readonly, nonatomic) BOOL debug;
@property (readonly, nonatomic) NSString *designerName;
@property (readonly, nonatomic) NSURL *designerURL;

- (instancetype)initWithContentsOfFile:(NSString *)filepath;
- (instancetype)initWithRemoteDictionary:(NSDictionary *)dictionary;

+ (GBAControllerSkin *)controllerSkinWithContentsOfFile:(NSString *)filepath;
+ (GBAControllerSkin *)defaultControllerSkinForSkinType:(GBAControllerSkinType)skinType;
+ (GBAControllerSkin *)invisibleSkin; // Used when external controller is connected

+ (BOOL)extractSkinAtPathToSkinsDirectory:(NSString *)filepath;

- (UIImage *)imageForOrientation:(GBAControllerSkinOrientation)orientation;
- (BOOL)imageExistsForOrientation:(GBAControllerSkinOrientation)orientation;
- (BOOL)isTranslucentForOrientation:(GBAControllerSkinOrientation)orientation;
- (BOOL)isResizableForOrientation:(GBAControllerSkinOrientation)orientation;

- (CGRect)frameForMapping:(GBAControllerSkinMapping)mapping orientation:(GBAControllerSkinOrientation)orientation controllerDisplaySize:(CGSize)displaySize;
- (CGRect)frameForMapping:(GBAControllerSkinMapping)mapping orientation:(GBAControllerSkinOrientation)orientation controllerDisplaySize:(CGSize)displaySize useExtendedEdges:(BOOL)useExtendedEdges;

@end
