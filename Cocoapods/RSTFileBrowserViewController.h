//
//  RSTFileBrowserViewController.h
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

// Defines a yet undocumented method to add a warning if super isn't called. (via Peter Steinberger)
#ifndef NS_REQUIRES_SUPER
#if __has_attribute(objc_requires_super)
#define NS_REQUIRES_SUPER __attribute((objc_requires_super))
#else
#define NS_REQUIRES_SUPER
#endif
#endif

@class RSTFileBrowserViewController;

@protocol RSTFileBrowserViewControllerControllerDelegate <NSObject>
@optional

// Called whenever the file browser refreshes the file list either manually or automatically
- (void)fileBrowserViewController:(RSTFileBrowserViewController *)fileBrowserViewController didRefreshDirectory:(NSString *)directory;

@end

@interface RSTFileBrowserViewController : UITableViewController

@property (weak, nonatomic) id <RSTFileBrowserViewControllerControllerDelegate> delegate;

// The directory where the file browser will look for files.
@property (copy, nonatomic) NSString *currentDirectory;

// Determines whether file extensions are shown on the right side of the screen. Defaults to NO
@property (assign, nonatomic) BOOL showFileExtensions;

// If nil, will show all files
@property (copy, nonatomic) NSArray /* NSString */ *supportedFileExtensions;

// Determines whether folders are shown amongst files. Tapping one will by default change the directory to the selected folder. Defaults to NO.
@property (assign, nonatomic) BOOL showFolders;

// Determines whether section titles are shown on the right side of the screen. Defaults to NO
@property (assign, nonatomic) BOOL showSectionTitles;

// Automatically refresh tableView when files change in currentDirectory. Defaults to YES
@property (assign, nonatomic) BOOL refreshAutomatically;


/* Directory Contents */

// Determines whether unavailable files are included with the below contents methods. Defaults to NO
@property (assign, nonatomic) BOOL showUnavailableFiles;

// An array of all files in the current directory that are unavilable because they are in the process of being copied over.
@property (readonly, nonatomic) NSArray *unavailableFiles;

// An array of all files in the current directory, both supported and not supported, including unavailable files.
@property (readonly, copy, nonatomic) NSArray *allFiles;

// An array of all files in the current directory that have one of the supported file extensions, including unavailable files.
@property (readonly, copy, nonatomic) NSArray *supportedFiles;

// An array of all files in the current directory that do not have one of the supported file extensions, including unavailable files.
@property (readonly, copy, nonatomic) NSArray *unsupportedFiles;

// Determines whether the file browser should respond to directory content changes
@property (assign, nonatomic, getter = isIgnoringDirectoryContentChanges) BOOL ignoreDirectoryContentChanges;


// Refreshes UI to show all files in the current directory
- (void)refreshDirectory;

// Convenience method to easily delete a file at an index path and optionally animate the deletion from the table view.
- (void)deleteFileAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

/* Helper methods */

// Returns absolute filepath for file in current directory
- (NSString *)filepathForFilename:(NSString *)filename;

// Returns filename located index path
- (NSString *)filenameForIndexPath:(NSIndexPath *)indexPath;

// Returns absolute filepath of item at indexPath
- (NSString *)filepathForIndexPath:(NSIndexPath *)indexPath;

// Subclasses can call to retrieve name to display in custom tableView:cellForRowAtIndexPath: methods, or override to provide custom file names
// By default, returns the filename without the file extension
- (NSString *)displayNameForIndexPath:(NSIndexPath *)indexPath;



/* Subclassing methods */

// Subclasses can override to change how extensions are displayed
- (NSString *)visibleFileExtensionForIndexPath:(NSIndexPath *)indexPath;

// Override to get notified of refreshes of the current directory
- (void)didRefreshCurrentDirectory NS_REQUIRES_SUPER;

@end
