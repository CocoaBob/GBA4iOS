//
//  GBAExternalController.h
//  GBA4iOS
//
//  Created by Riley Testut on 11/22/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GBAControllerInput.h"
#import <GameController/GameController.h>

//#define USE_POLLING 1

@interface GBAExternalController : NSObject <GBAControllerInput>

@property (weak, nonatomic) id<GBAControllerInputDelegate> delegate;
@property (readonly, strong, nonatomic) GCController *controller;

+ (void)registerControllerDefaults;
+ (GBAExternalController *)externalControllerWithController:(GCController *)controller;

#ifdef USE_POLLING
- (void)updateControllerInputs;
#endif

@end
