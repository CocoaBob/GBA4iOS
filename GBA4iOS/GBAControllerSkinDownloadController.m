//
//  GBAControllerSkinDownloadOperation.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinDownloadController.h"
#import "GBAControllerSkinGroup.h"
#import "GBAControllerSkin_Private.h"

#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/AFURLResponseSerialization.h>

NSString * const GBAControllerSkinsRootAddress = @"http://gba4iosapp.com/delta/controller_skins/";

static void *GBAControllerSkinDownloadControllerContext = &GBAControllerSkinDownloadControllerContext;

@interface GBAControllerSkinResponseSerializer : AFJSONResponseSerializer

@end

@implementation GBAControllerSkinResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error
{
    NSArray *responseObject = [super responseObjectForResponse:response data:data error:error];
    
    NSMutableArray *groups = [NSMutableArray array];
    
    for (NSDictionary *groupDictionary in responseObject)
    {
        GBAControllerSkinGroup *group = [[GBAControllerSkinGroup alloc] initWithDictionary:groupDictionary];
        [groups addObject:group];
    }
    
    return groups;
}

@end

@implementation GBAControllerSkinDownloadController

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _progress = ({
            NSProgress *progress = [[NSProgress alloc] initWithParent:nil userInfo:0];
            progress;
        });
    }
    
    return self;
}

#pragma mark - Networking -

- (void)retrieveControllerSkinGroupsWithCompletion:(void (^)(NSArray *, NSError *))completion
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    manager.responseSerializer = [GBAControllerSkinResponseSerializer serializer];
    
    NSString *address = [GBAControllerSkinsRootAddress stringByAppendingPathComponent:@"root.json"];
    NSURL *URL = [NSURL URLWithString:address];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, NSArray *groups, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error)
            {
                if (completion)
                {
                    completion(nil, error);
                }
                return;
            }
            
            completion(groups, error);
        });
    }];
    
    [dataTask resume];
}

- (void)downloadRemoteControllerSkin:(GBAControllerSkin *)controllerSkin completion:(void (^)(NSURL *fileURL, NSError *))completion
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString *address = [GBAControllerSkinsRootAddress stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/%@", [GBAControllerSkinDownloadController stringForControllerSkinType:controllerSkin.type], controllerSkin.identifier, controllerSkin.filename]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:address]];
    
    NSProgress *progress = nil;
    
    __strong NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:&progress destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        
        NSString *filepath = [[targetPath path] stringByDeletingPathExtension];
        filepath = [filepath stringByAppendingPathExtension:controllerSkin.filename.pathExtension];
        
        return [NSURL fileURLWithPath:filepath];
        
    } completionHandler:^(NSURLResponse *response, NSURL *fileURL, NSError *error)
                                                       {
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               if (error)
                                                               {
                                                                   if (completion)
                                                                   {
                                                                       completion(nil, error);
                                                                   }
                                                                   
                                                                   [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                                                   
                                                                   return;
                                                               }
                                                               
                                                               if (completion)
                                                               {
                                                                   completion(fileURL, error);
                                                               }
                                                               
                                                               [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                                                           });
                                                       }];
    
    [progress addObserver:self forKeyPath:@"totalUnitCount" options:NSKeyValueObservingOptionNew context:GBAControllerSkinDownloadControllerContext];
    [progress addObserver:self forKeyPath:@"completedUnitCount" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:GBAControllerSkinDownloadControllerContext];
    
    [downloadTask resume];
}

- (NSArray *)imageURLsForControllerSkin:(GBAControllerSkin *)controllerSkin
{
    NSMutableArray *imageURLs = [NSMutableArray array];
    
    if ([controllerSkin imageExistsForOrientation:GBAControllerSkinOrientationPortrait])
    {
        NSDictionary *dictionary = [controllerSkin dictionaryForOrientation:GBAControllerSkinOrientationPortrait];
        NSDictionary *assets = dictionary[GBAControllerSkinAssetsKey];
        
        NSString *screenType = [controllerSkin screenTypeForCurrentDeviceWithDictionary:assets orientation:GBAControllerSkinOrientationPortrait];
        NSString *relativePath = assets[screenType];
        
        NSString *address = [GBAControllerSkinsRootAddress stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/%@", [GBAControllerSkinDownloadController stringForControllerSkinType:controllerSkin.type], controllerSkin.identifier, relativePath]];
        
        [imageURLs addObject:[NSURL URLWithString:address]];
    }
    
    if ([controllerSkin imageExistsForOrientation:GBAControllerSkinOrientationLandscape])
    {
        NSDictionary *dictionary = [controllerSkin dictionaryForOrientation:GBAControllerSkinOrientationLandscape];
        NSDictionary *assets = dictionary[GBAControllerSkinAssetsKey];
        
        NSString *screenType = [controllerSkin screenTypeForCurrentDeviceWithDictionary:assets orientation:GBAControllerSkinOrientationLandscape];
        NSString *relativePath = assets[screenType];
        
        NSString *address = [GBAControllerSkinsRootAddress stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/%@", [GBAControllerSkinDownloadController stringForControllerSkinType:controllerSkin.type], controllerSkin.identifier, relativePath]];
        
        [imageURLs addObject:[NSURL URLWithString:address]];
    }

    return imageURLs;
}

#pragma mark - KVO -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != GBAControllerSkinDownloadControllerContext)
    {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    if ([keyPath isEqualToString:@"completedUnitCount"])
    {
        NSProgress *progress = object;
        
        rst_dispatch_sync_on_main_thread(^{
            
            int64_t previousProgress = [change[NSKeyValueChangeOldKey] integerValue];
            int64_t currentProgress = [change[NSKeyValueChangeNewKey] integerValue];
            
            self.progress.completedUnitCount = self.progress.completedUnitCount + (currentProgress - previousProgress);
            
            if (progress.fractionCompleted == 1)
            {
                [progress removeObserver:self forKeyPath:@"completedUnitCount" context:GBAControllerSkinDownloadControllerContext];
                self.progress.completedUnitCount = 0.0;
                self.progress.totalUnitCount = 0.0;
            }
        });
        
    }
    else if ([keyPath isEqualToString:@"totalUnitCount"])
    {
        NSProgress *progress = object;
        
        [self.progress setTotalUnitCount:self.progress.totalUnitCount + progress.totalUnitCount];
        
        [progress removeObserver:self forKeyPath:@"totalUnitCount" context:GBAControllerSkinDownloadControllerContext];
        
    }
}

#pragma mark - Helper Methods -

+ (NSString *)stringForControllerSkinType:(GBAControllerSkinType)type
{
    NSString *skinType = nil;
    
    switch (type)
    {
        case GBAControllerSkinTypeGBA:
            skinType = @"gba";
            break;
            
        case GBAControllerSkinTypeGBC:
            skinType = @"gbc";
            break;
    }
    
    return skinType;
}

@end
