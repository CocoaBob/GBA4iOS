//
//  GBAControllerSkinDownloadOperation.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GBAControllerSkin;

@interface GBAControllerSkinDownloadController : NSObject

@property (strong, nonatomic, readonly) NSProgress *progress;

- (void)retrieveControllerSkinGroupsWithCompletion:(void (^)(NSArray /* GBAControllerSkinGroup */ *groups, NSError *error))completion;
- (void)downloadRemoteControllerSkin:(GBAControllerSkin *)controllerSkin completion:(void (^)(NSURL *fileURL, NSError *error))completion;

- (NSArray /* NSURL */ *)imageURLsForControllerSkin:(GBAControllerSkin *)controllerSkin;

@end
