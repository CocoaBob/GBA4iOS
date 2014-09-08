//
//  GBAControllerSkinGroup.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GBAControllerSkin.h"

@interface GBAControllerSkinGroup : NSObject <NSCoding>

@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *blurb;
@property (copy, nonatomic, readonly) NSArray /* GBAControllerSkin */ *skins;
@property (nonatomic, readonly) NSArray /* NSURL */ *imageURLs;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (void)filterSkinsForDeviceType:(GBAControllerSkinDeviceType)deviceType controllerSkinType:(GBAControllerSkinType)controllerSkinType;

@end
