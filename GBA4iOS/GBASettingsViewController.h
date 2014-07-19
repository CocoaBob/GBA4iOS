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
extern NSString *const GBASettingsDropboxStatusChangedNotification;

static NSString *GBASettingsFrameSkipKey = @"frameSkip";
static NSString *GBASettingsAutosaveKey = @"autosave";
static NSString *GBASettingsPreferExternalAudioKey = @"preferExternalAudio";
static NSString *GBASettingsVibrateKey = @"vibrate";
static NSString *GBASettingsShowFramerateKey = @"showFramerate";
static NSString *GBASettingsGBASkinsKey = @"gbaSkins";
static NSString *GBASettingsGBCSkinsKey = @"gbcSkins";
static NSString *GBASettingsControllerOpacityKey = @"controllerOpacity";
static NSString *GBASettingsDropboxSyncKey = @"dropboxSync";
static NSString *GBASettingsExternalControllerButtonsKey = @"externalControllerButtons";
static NSString *GBASettingsAirPlayEnabled = @"airPlayEnabled";
static NSString *GBASettingsSoftwareUpdatePushNotifications = @"softwareUpdatePushNotifications";
static NSString *GBASettingsEventDistributionPushNotifications = @"eventDistributionPushNotifications";

@class GBASettingsViewController;

@protocol GBASettingsViewControllerDelegate <NSObject>

- (void)settingsViewControllerWillDismiss:(GBASettingsViewController *)settingsViewController;

@end


@interface GBASettingsViewController : UITableViewController

@property (weak, nonatomic) id<GBASettingsViewControllerDelegate> delegate;

+ (void)registerDefaults;

@end
