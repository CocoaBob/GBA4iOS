//
//  RSTFileBrowserViewController.h
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RSTFileBrowserViewController;

@protocol RSTFileBrowserViewControllerControllerDelegate <NSObject>
@optional

- (void)fileBrowserViewController:(RSTFileBrowserViewController *)fileBrowserViewController didRefreshDirectory:(NSString *)directory;

@end

@interface RSTFileBrowserViewController : UITableViewController

@property (weak, nonatomic) id <RSTFileBrowserViewControllerControllerDelegate> delegate;

@property (copy, nonatomic) NSString *currentDirectory; // The directory where it will look for files.

@property (assign, nonatomic) BOOL showFileExtensions; // Defaults to NO

@property (copy, nonatomic) NSArray *supportedFileExtensions; // If nil, shows all files

@property (assign, nonatomic) BOOL showFolders; // Defaults to NO

@property (assign, nonatomic) BOOL showSectionTitles; // Defaults to NO

- (void)refreshDirectory; // Refreshes directory (no duh)

- (NSString *)filepathForIndexPath:(NSIndexPath *)indexPath; // Returns absolute filepath of item at indexPath

- (NSString *)filenameForIndexPath:(NSIndexPath *)indexPath; // Subclasses can call to retrieve name to display in custom tableView:cellForRowAtIndexPath: methods

@end
