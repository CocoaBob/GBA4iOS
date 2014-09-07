//
//  GBAControllerSkinGroup.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinGroup.h"
#import "GBAControllerSkinDownloadController.h"

@implementation GBAControllerSkinGroup

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    NSParameterAssert(dictionary);
    
    self = [super init];
    if (self)
    {
        _name = [dictionary[@"name"] copy];
        _blurb = [dictionary[@"blurb"] copy];
        
        NSMutableArray *skins = [NSMutableArray array];
        NSArray *skinDictionaries = [dictionary[@"skins"] copy];
        
        for (NSDictionary *skinDictionary in skinDictionaries)
        {
            GBAControllerSkin *skin = [[GBAControllerSkin alloc] initWithRemoteDictionary:skinDictionary];
            [skins addObject:skin];
        }
        
        _skins = [skins copy];
    }
    
    return self;
}

#pragma mark - Retrieving Information -

- (BOOL)containsControllerSkinsForDeviceType:(GBAControllerSkinDeviceType)deviceType
{
    for (GBAControllerSkin *skin in self.skins)
    {
        if (skin.deviceType & deviceType)
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)containsControllerSkinsForControllerSkinType:(GBAControllerSkinType)controllerSkinType
{
    for (GBAControllerSkin *skin in self.skins)
    {
        if (skin.type & controllerSkinType)
        {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Getters/Setters -

- (NSArray *)imageURLs
{
    GBAControllerSkin *skin = [self.skins firstObject];
    
    GBAControllerSkinDownloadController *downloadController = [GBAControllerSkinDownloadController new];
    return [downloadController imageURLsForControllerSkin:skin];
}

@end
