//
//  GBAEventDistributionOperation.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/16/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GBAEvent.h"

extern NSString * const GBAEventDistributionRootAddress;

typedef void (^GBAEventDistributionOperationCompletionBlock)(NSArray *events, NSError *error);

@interface GBAEventDistributionOperation : NSObject

@property (assign, nonatomic) BOOL performsNoOperation;

- (void)checkForEventsWithCompletion:(GBAEventDistributionOperationCompletionBlock)completion;

@end
