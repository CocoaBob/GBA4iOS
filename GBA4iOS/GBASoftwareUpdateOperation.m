//
//  GBASoftwareUpdateOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/13/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASoftwareUpdateOperation.h"

#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>

static NSString * const GBASoftwareUpdateRootAddress = @"http://gba4iosapp.com/delta/software_update/";

@implementation GBASoftwareUpdateOperation

- (void)checkForUpdateWithCompletion:(GBASoftwareUpdateCompletionBlock)completionBlock
{
    if (self.performsNoOperation)
    {
        if (completionBlock)
        {
            completionBlock(nil, nil);
        }
        
        return;
    }
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString *address = [GBASoftwareUpdateRootAddress stringByAppendingPathComponent:@"update.json"];
    NSURL *URL = [NSURL URLWithString:address];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, NSDictionary *jsonObject, NSError *error) {
        
        GBASoftwareUpdate *softwareUpdate = [[GBASoftwareUpdate alloc] initWithDictionary:jsonObject];
        
        DLog(@"Found software update: %@", softwareUpdate);
        
        completionBlock(softwareUpdate, error);
    }];
    
    DLog(@"Checking for Software Updates...");
    
    [dataTask resume];
}

@end
