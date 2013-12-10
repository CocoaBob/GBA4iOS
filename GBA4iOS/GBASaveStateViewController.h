//
//  GBASaveStateViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/15/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RSTFileBrowserViewController.h"
#import "GBAROM.h"

#import "UITableViewController+Theming.h"

typedef NS_ENUM(NSInteger, GBASaveStateViewControllerMode)
{
    GBASaveStateViewControllerModeSaving = 0,
    GBASaveStateViewControllerModeLoading = 1
};

@class GBASaveStateViewController;

@protocol GBASaveStateViewControllerDelegate <NSObject>

@optional
- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController willSaveStateWithFilename:(NSString *)filename;
- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController didSaveStateWithFilename:(NSString *)filename;
- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController willLoadStateWithFilename:(NSString *)filename;
- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController didLoadStateWithFilename:(NSString *)filename;
- (void)saveStateViewControllerWillDismiss:(GBASaveStateViewController *)saveStateViewController;

@end

@interface GBASaveStateViewController : UITableViewController <GBAThemedTableViewController>

@property (weak, nonatomic) id <GBASaveStateViewControllerDelegate> delegate;
@property (readonly, assign, nonatomic) GBASaveStateViewControllerMode mode;
@property (readonly, strong, nonatomic) GBAROM *rom;

- (instancetype)initWithROM:(GBAROM *)rom mode:(GBASaveStateViewControllerMode)mode;

@end
