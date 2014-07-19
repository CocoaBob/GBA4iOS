//
//  GBASoftwareUpdateOperation.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/13/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GBASoftwareUpdate.h"

typedef void (^GBASoftwareUpdateCompletionBlock)(GBASoftwareUpdate *softwareUpdate, NSError *error);

@interface GBASoftwareUpdateOperation : NSObject

@property (nonatomic, assign) BOOL performsNoOperation;

- (void)checkForUpdateWithCompletion:(GBASoftwareUpdateCompletionBlock)completionBlock;

@end
