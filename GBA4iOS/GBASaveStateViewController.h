//
//  GBASaveStateViewController.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/15/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <RSTFileBrowserViewController.h>

typedef NS_ENUM(NSInteger, GBASaveStateViewControllerMode)
{
    GBASaveStateViewControllerModeSaving = 0,
    GBASaveStateViewControllerModeLoading = 1
};

@class GBASaveStateViewController;

@protocol GBASaveStateViewControllerDelegate <NSObject>

@optional
- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController willSaveStateToPath:(NSString *)filepath;
- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController didSaveStateToPath:(NSString *)filepath;
- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController willLoadStateFromPath:(NSString *)filepath;
- (void)saveStateViewController:(GBASaveStateViewController *)saveStateViewController didLoadStateFromPath:(NSString *)filepath;

@end

@interface GBASaveStateViewController : UITableViewController

@property (weak, nonatomic) id <GBASaveStateViewControllerDelegate> delegate;
@property (readonly, copy, nonatomic) NSString *saveStateDirectory;
@property (readonly, assign, nonatomic) GBASaveStateViewControllerMode mode;

- (instancetype)initWithSaveStateDirectory:(NSString *)directory mode:(GBASaveStateViewControllerMode)mode;

@end
