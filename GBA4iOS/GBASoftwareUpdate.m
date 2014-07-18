//
//  GBASoftwareUpdate.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/13/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASoftwareUpdate.h"

@interface GBASoftwareUpdate ()

@property (readwrite, copy, nonatomic) NSString *name;
@property (readwrite, copy, nonatomic) NSString *version;
@property (readwrite, copy, nonatomic) NSString *developer;
@property (readwrite, copy, nonatomic) NSString *releaseNotes;
@property (readwrite, copy, nonatomic) NSURL *url;
@property (readwrite, copy, nonatomic) NSString *minimumiOSVersion;
@property (readwrite, nonatomic) long long size;

@end

@implementation GBASoftwareUpdate

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    if (!dictionary)
    {
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _name = [dictionary[@"name"] copy];
        _version = [dictionary[@"version"] copy];
        _developer = [dictionary[@"developer"] copy];
        _releaseNotes = [dictionary[@"releaseNotes"] copy];
        _minimumiOSVersion = [dictionary[@"minimumiOSVersion"] copy];
        
        _url = [[NSURL URLWithString:dictionary[@"url"]] copy];
        _size = [dictionary[@"size"] longLongValue];
    }
    
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    if (data == nil || data.length == 0)
    {
        return nil;
    }
    
    self = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    return self;
}

- (NSData *)dataRepresentation
{
    return [NSKeyedArchiver archivedDataWithRootObject:self];
}

- (NSString *)localizedSize
{
    return [NSByteCountFormatter stringFromByteCount:self.size countStyle:NSByteCountFormatterCountStyleFile];
}

- (BOOL)isNewerThanAppVersion
{
    return ([[[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey] compare:self.version options:NSNumericSearch] == NSOrderedAscending);
}

- (BOOL)isSupportedOnCurrentiOSVersion
{
    return ([self.minimumiOSVersion compare:[[UIDevice currentDevice] systemVersion] options:NSNumericSearch] != NSOrderedDescending);
}

- (NSString *)description
{
    return self.name;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:NSStringFromSelector(@selector(name))];
    [aCoder encodeObject:self.version forKey:NSStringFromSelector(@selector(version))];
    [aCoder encodeObject:self.developer forKey:NSStringFromSelector(@selector(developer))];
    [aCoder encodeObject:self.releaseNotes forKey:NSStringFromSelector(@selector(releaseNotes))];
    [aCoder encodeObject:self.minimumiOSVersion forKey:NSStringFromSelector(@selector(minimumiOSVersion))];
    [aCoder encodeObject:self.url forKey:NSStringFromSelector(@selector(url))];
    [aCoder encodeObject:@(self.size) forKey:NSStringFromSelector(@selector(size))];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *name = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(name))];
    NSString *version = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(version))];
    NSString *developer = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(developer))];
    NSString *releaseNotes = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(releaseNotes))];
    NSString *minimumiOSVersion = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(minimumiOSVersion))];
    NSURL *url = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(url))];
    long long size = [[aDecoder decodeObjectForKey:NSStringFromSelector(@selector(size))] longLongValue];
    
    self = [self init];
    self.name = name;
    self.version = version;
    self.developer = developer;
    self.releaseNotes = releaseNotes;
    self.minimumiOSVersion = minimumiOSVersion;
    self.url = url;
    self.size = size;
    
    return self;
}

@end
