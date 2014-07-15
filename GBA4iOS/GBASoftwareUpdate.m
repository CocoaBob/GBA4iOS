//
//  GBASoftwareUpdate.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/13/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASoftwareUpdate.h"

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
        _version = [dictionary[@"version"] copy];
        _name = [dictionary[@"name"] copy];
        _developer = [dictionary[@"developer"] copy];
        _description = [dictionary[@"description"] copy];
        _minimumiOSVersion = [dictionary[@"minimumiOSVersion"] copy];
        
        _url = [[NSURL URLWithString:dictionary[@"url"]] copy];
        _size = [dictionary[@"size"] longLongValue];
    }
    
    return self;
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

@end
