//
//  GBASettingsViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GBAROMTableViewController.h"

extern NSString *const GBASettingsDidChangeNotification;

static NSString *GBASettingsFrameSkipKey = @"frameSkip";
static NSString *GBASettingsAutosaveKey = @"autosave";
static NSString *GBASettingsMixAudioKey = @"mixAudio";
static NSString *GBASettingsVibrateKey = @"vibrate";
static NSString *GBASettingsShowFramerateKey = @"showFramerate";
static NSString *GBASettingsGBASkinsKey = @"gbaSkins";
static NSString *GBASettingsGBCSkinsKey = @"gbcSkins";
static NSString *GBASettingsControllerOpacity = @"controllerOpacity";

@interface GBASettingsViewController : UITableViewController

@property (assign, nonatomic) GBAROMTableViewControllerTheme theme;

+ (void)registerDefaults;

@end
