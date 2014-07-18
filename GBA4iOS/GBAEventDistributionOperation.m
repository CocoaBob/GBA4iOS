//
//  GBAEventDistributionOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/16/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAEventDistributionOperation.h"

#import <AFNetworking/AFNetworking.h>

static NSString * const GBAEventDistributionRootAddress = @"http://gba4iosapp.com/delta/event_distribution/";

@implementation GBAEventDistributionOperation

- (void)checkForEventsWithCompletion:(GBAEventDistributionOperationCompletionBlock)completion
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString *address = [GBAEventDistributionRootAddress stringByAppendingPathComponent:@"events.json"];
    NSURL *URL = [NSURL URLWithString:address];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, NSArray *jsonObject, NSError *error) {
        
        NSMutableArray *events = [NSMutableArray array];
        
        for (NSDictionary *dictionary in jsonObject)
        {
            GBAEvent *event = [GBAEvent eventWithDictionary:dictionary];
            [events addObject:event];
        }
        
        DLog(@"Found events: %@", events);
        
        completion(events, error);
        
    }];
    
    DLog(@"Checking for events...");
    
    [dataTask resume];
}

@end
