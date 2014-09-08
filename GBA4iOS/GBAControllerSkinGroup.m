//
//  GBAControllerSkinGroup.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinGroup.h"
#import "GBAControllerSkinDownloadController.h"

@interface GBAControllerSkinGroup ()

@property (copy, nonatomic, readwrite) NSString *name;
@property (copy, nonatomic, readwrite) NSString *blurb;
@property (copy, nonatomic, readwrite) NSArray /* GBAControllerSkin */ *skins;

@end

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

#pragma mark - NSCoding -

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *name = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(name))];
    NSString *blurb = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(blurb))];
    NSArray *skins = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(skins))];
    
    self = [self init];
    self.name = name;
    self.blurb = blurb;
    self.skins = skins;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:NSStringFromSelector(@selector(name))];
    [aCoder encodeObject:self.blurb forKey:NSStringFromSelector(@selector(blurb))];
    [aCoder encodeObject:self.skins forKey:NSStringFromSelector(@selector(skins))];
}

#pragma mark - Filter Skin -

- (void)filterSkinsForDeviceType:(GBAControllerSkinDeviceType)deviceType controllerSkinType:(GBAControllerSkinType)controllerSkinType
{
    NSMutableArray *filteredSkins = [NSMutableArray array];
    
    for (GBAControllerSkin *skin in self.skins)
    {
        if (skin.type == controllerSkinType && (skin.deviceType & deviceType) == deviceType)
        {
            [filteredSkins addObject:skin];
        }
    }
    
    self.skins = filteredSkins;
}

- (BOOL)containsControllerSkinsForDeviceType:(GBAControllerSkinDeviceType)deviceType
{
    for (GBAControllerSkin *skin in self.skins)
    {
        if ((skin.deviceType & deviceType) == deviceType)
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
        if (skin.type == controllerSkinType)
        {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Comparison -

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[GBAControllerSkinGroup class]])
    {
        return NO;
    }
    
    GBAControllerSkinGroup *group = object;
    
    return ([self.name isEqualToString:group.name] && [self.blurb isEqualToString:group.blurb] && [self.skins isEqual:group.skins]);
}

- (NSUInteger)hash
{
    return [self.name hash] + [self.blurb hash];// + [self.skins hash]; Never include something in the hash that can be modified later
}

#pragma mark - Getters/Setters -

- (NSArray *)imageURLs
{
    GBAControllerSkin *skin = [self.skins firstObject];
    
    GBAControllerSkinDownloadController *downloadController = [GBAControllerSkinDownloadController new];
    return [downloadController imageURLsForControllerSkin:skin];
}

@end
