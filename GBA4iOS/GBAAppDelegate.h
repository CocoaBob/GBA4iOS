//
//  GBAAppDelegate.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#if TARGET_IPHONE_SIMULATOR && !(SIMULATOR)

#error This target cannot be compiled for the simulator. To compile for simulator, use the GBA4iOS-Simulator target.

#elif !(TARGET_IPHONE_SIMULATOR) && SIMULATOR

#error This target cannot be compiled for device. To compile for device, use the GBA4iOS target, not GBA4iOS-Simulator.

#endif

extern NSString * const GBAUserRequestedToPlayROMNotification;

@interface GBAAppDelegate : UIResponder <UIApplicationDelegate, UISplitViewControllerDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
