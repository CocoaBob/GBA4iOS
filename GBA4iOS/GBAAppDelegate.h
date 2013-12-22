//
//  GBAAppDelegate.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const GBAUserRequestedToPlayROMNotification;

@interface GBAAppDelegate : UIResponder <UIApplicationDelegate, UISplitViewControllerDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
