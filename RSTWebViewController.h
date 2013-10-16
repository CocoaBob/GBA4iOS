//
//  RSTWebViewController.h
//
//  Created by Riley Testut on 7/15/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "NSURLSessionTask+UniqueTaskIdentifier.h"

typedef void(^RSTWebViewControllerStartDownloadBlock)(BOOL shouldContinue);

typedef NS_OPTIONS(NSInteger, RSTWebViewControllerSharingActivity) {
    RSTWebViewControllerSharingActivityNone = 0,
    RSTWebViewControllerSharingActivitySafari = 1 << 0,
    RSTWebViewControllerSharingActivityChrome = 1 << 1,
    RSTWebViewControllerSharingActivityMail = 1 << 2,
    RSTWebViewControllerSharingActivityCopy = 1 << 3,
    RSTWebViewControllerSharingActivityMessage = 1 << 4,
    RSTWebViewControllerSharingActivityAll = 2,
};

@class RSTWebViewController;

@protocol RSTWebViewControllerDelegate <NSObject>

/**
 *	Called when the web view is actually done loading content, unlike the UIWebViewDelegate method
 *  webViewDidFinishLoad: which is called after every frame.
 *
 *	@param	webViewController	The RSTWebViewController loading the content
 */
- (void)webViewControllerDidFinishLoad:(RSTWebViewController *)webViewController;

@end

@protocol RSTWebViewControllerDownloadDelegate <NSObject>

@optional

// Return YES to tell RSTWebViewController to create a NSURLSession object and start a NSURLSessionDownloadTask.
// Or, if you choose to, you can return NO, and then implement your own downloading logic via NSURLSession with the NSURLRequest
- (BOOL)webViewController:(RSTWebViewController *)webViewController shouldStartDownloadWithRequest:(NSURLRequest *)request;

// If implemented, you must call startDownloadBlock, or else the download will never start. This was you can display an alert to the user asking if they want to download the file.
// If needed, you can keep a reference to the NSURLSessionDownloadTask to suspend/cancel during the download. You can access the original request via downloadTask.originalRequest, or the current one via downloadTask.currentRequest
- (void)webViewController:(RSTWebViewController *)webViewController willStartDownloadWithTask:(NSURLSessionDownloadTask *)downloadTask startDownloadBlock:(RSTWebViewControllerStartDownloadBlock)completionHandler;

// Called periodically during download to allow you to keep track of progress
- (void)webViewController:(RSTWebViewController *)webViewController downloadTask:(NSURLSessionDownloadTask *)downloadTask totalBytesDownloaded:(int64_t)totalBytesDownloaded totalBytesExpected:(int64_t)totalBytesExpected;

// Download finished. You MUST read or copy the file over to your local directory before this message returns, as iOS deletes it straight afterwards.
// Due to Apple's implementation of NSURLSession, webViewController:didCompleteDownloadWithError: will still be called with a nil error.
- (void)webViewController:(RSTWebViewController *)webViewController downloadTask:(NSURLSessionDownloadTask *)downloadTask didDownloadFileToURL:(NSURL *)fileURL;

// Last method before the download task is truly finished. Error may be nil if no error occured.
- (void)webViewController:(RSTWebViewController *)webViewController downloadTask:(NSURLSessionDownloadTask *)downloadTask didCompleteDownloadWithError:(NSError *)error;

@end

@interface RSTWebViewController : UIViewController

/**
 *	The object that acts as the delegate of the receiving RSTWebViewController.
 */
@property (weak, nonatomic) id <RSTWebViewControllerDelegate> delegate;

/**
 *	Delegate object to be notified about the file downloading process.
 */
@property (weak, nonatomic) id <RSTWebViewControllerDownloadDelegate> downloadDelegate;

// UIWebView used to display webpages
@property (strong, nonatomic) UIWebView *webView;

// Included UIActivities to be displayed when sharing a link. Default is RSTWebViewControllerSharingActivityAll
@property (assign, nonatomic) RSTWebViewControllerSharingActivity supportedSharingActivities;

// Additional UIActivities to be displayed when sharing a link
@property (copy, nonatomic) NSArray /* UIActivity */ *additionalSharingActivities;

// Set to YES when presenting modally to show a Done button that'll dismiss itself. Must be set before presentation.
@property (assign, nonatomic) BOOL showDoneButton;

- (instancetype)initWithAddress:(NSString *)address;
- (instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithRequest:(NSURLRequest *)request;

@end
