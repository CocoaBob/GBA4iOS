//
//  RSTWebViewController.m
//
//  Created by Riley Testut on 7/15/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "RSTWebViewController.h"
#import "NJKWebViewProgress.h"
#import "RSTSafariActivity.h"

@interface RSTWebViewController () <UIWebViewDelegate, NJKWebViewProgressDelegate, NSURLSessionDownloadDelegate>

@property (strong, nonatomic) NSURLRequest *currentRequest;
@property (strong, nonatomic) UIProgressView *progressView;
@property (strong, nonatomic) NJKWebViewProgress *webViewProgress;
@property (assign, nonatomic) BOOL loadingRequest; // Help prevent false positives

@property (strong, nonatomic) UIBarButtonItem *goBackButton;
@property (strong, nonatomic) UIBarButtonItem *goForwardButton;
@property (strong, nonatomic) UIBarButtonItem *shareButton;
@property (strong, nonatomic) UIBarButtonItem *flexibleSpaceButton;
@property (strong, nonatomic) UIBarButtonItem *fixedSpaceButton;

// Refreshing
@property (assign, nonatomic) UIBarButtonItem *refreshButton; // Assigned either loadButton or stopLoadButton
@property (strong, nonatomic) UIBarButtonItem *reloadButton;
@property (strong, nonatomic) UIBarButtonItem *stopLoadButton;

@end

@implementation RSTWebViewController

#pragma mark - Initialization

- (instancetype)initWithAddress:(NSString *)address
{
    return [self initWithURL:[NSURL URLWithString:address]];
}

- (instancetype)initWithURL:(NSURL *)url
{
    return [self initWithRequest:[NSURLRequest requestWithURL:url]];
}

- (instancetype)initWithRequest:(NSURLRequest *)request
{
    self = [super init];
    
    if (self)
    {
        _currentRequest = request;
        _loadingRequest = YES;
        
        _webViewProgress = [[NJKWebViewProgress alloc] init];
        _webViewProgress.webViewProxyDelegate = self;
        _webViewProgress.progressDelegate = self;
        
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        _progressView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        _progressView.trackTintColor = [UIColor clearColor];
        _progressView.alpha = 0.0;
        _progressView.progress = 0.0;
    }
    
    return self;
}

#pragma mark - Configure View

- (void)loadView
{
    self.webView = [[UIWebView alloc] init];
    self.webView.delegate = self.webViewProgress;
    self.webView.backgroundColor = [UIColor whiteColor];
    self.webView.scrollView.backgroundColor = [UIColor whiteColor];
    self.webView.scalesPageToFit = YES;
    self.view = self.webView;
    
    [self.webView loadRequest:self.currentRequest];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.progressView.frame = CGRectMake(0,
                                     CGRectGetHeight(self.navigationController.navigationBar.bounds) - CGRectGetHeight(self.progressView.bounds),
                                     CGRectGetWidth(self.navigationController.navigationBar.bounds),
                                     CGRectGetHeight(self.progressView.bounds));
    
    self.goBackButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Back Button"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
    self.goForwardButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Forward Button"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward:)];
    self.reloadButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload:)];
    self.stopLoadButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopLoading:)];
    self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareLink:)];
    self.flexibleSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    self.refreshButton = self.reloadButton;
    
    [self refreshToolbarItems];
    
    if (self.showDoneButton)
    {
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissWebViewController:)];
        [self.navigationItem setRightBarButtonItem:doneButton];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        if (self.presentingViewController)
        {
            // Presenting modally
            animated = NO;
        }
        
        [self.navigationController setToolbarHidden:NO animated:animated];
    }
    
    [self.navigationController.navigationBar addSubview:self.progressView];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        if (self.presentingViewController)
        {
            // Presenting modally
            animated = NO;
        }
        
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self hideProgressViewWithCompletion:^{
        [self.progressView removeFromSuperview];
    }];
}

- (void)refreshToolbarItems
{
    self.goBackButton.enabled = [self.webView canGoBack];
    self.goForwardButton.enabled = [self.webView canGoForward];
    
    // The following line is purposefully commented out. Sometimes, longrunning javascript or other elements may take longer to load, but to the user it sometimes looks like the web view has stalled.
    // We update these in didStartLoading and didFinishLoading to match the state of these buttons to the state of the progress indicator
    
    self.refreshButton = [self.webView isLoading] ? self.stopLoadButton : self.reloadButton;
    
    self.toolbarItems = @[self.goBackButton, self.flexibleSpaceButton, self.goForwardButton, self.flexibleSpaceButton, self.refreshButton, self.flexibleSpaceButton, self.shareButton];
}

#pragma mark - Navigation

- (void)goBack:(UIBarButtonItem *)sender
{
    [self.webView goBack];
}

- (void)goForward:(UIBarButtonItem *)sender
{
    [self.webView goForward];
}

#pragma mark - Refreshing

- (void)reload:(UIBarButtonItem *)sender
{
    [self.webView reload];
}

- (void)stopLoading:(UIBarButtonItem *)sender
{
    [self.webView stopLoading];
}

#pragma mark - Sharing

- (void)shareLink:(UIBarButtonItem *)barButtonItem
{
    NSString *currentAddress = [self.webView stringByEvaluatingJavaScriptFromString:@"window.location.href"];
    NSURL *url = [NSURL URLWithString:currentAddress];
    
    NSArray *applicationActivities = [self applicationActivities];
   // NSArray *
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:applicationActivities];
    activityViewController.excludedActivityTypes = [self excludedActivityTypes];
    [self presentViewController:activityViewController animated:YES completion:NULL];
}

- (NSArray *)applicationActivities
{
    BOOL useAllActivities = (self.supportedSharingActivities & RSTWebViewControllerSharingActivityAll) == RSTWebViewControllerSharingActivityAll;
    
    NSMutableArray *applicationActivities = [NSMutableArray array];
    
    if (((self.supportedSharingActivities & RSTWebViewControllerSharingActivitySafari) == RSTWebViewControllerSharingActivitySafari) || useAllActivities)
    {
        RSTSafariActivity *activity = [[RSTSafariActivity alloc] init];
        [applicationActivities addObject:activity];
    }
    
    return applicationActivities;
}

- (NSArray *)excludedActivityTypes
{
    return nil;
}

#pragma mark - Progress View

- (void)showProgressView
{
    [UIView animateWithDuration:0.4 animations:^{
        self.progressView.alpha = 1.0;
    }];
}

- (void)hideProgressViewWithCompletion:(void (^)(void))completion
{
    [UIView animateWithDuration:0.4 animations:^{
        self.progressView.alpha = 0.0;
    } completion:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = 0.0;
        });
        
        if (completion) {
            completion();
        }
    }];
}

- (void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress
{
    if (self.loadingRequest)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Prevent the progress view from ever resetting back to a smaller progress value.
            // It's also common for the progress to be 1.0, and then start showing the actual progress. So this is the *only* exception to the don't-display-less-progress rule.
            if ((progress > self.progressView.progress) || self.progressView.progress >= 1.0f)
            {
                if (self.progressView.alpha == 0.0)
                {
                    [self didStartLoading];
                }
                
                [self.progressView setProgress:progress animated:YES];
            }
            
            if (progress >= 1.0)
            {
                [self didFinishLoading];
            }
        });
    }
}

#pragma mark - UIWebViewController delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	// Called multiple times per loading of a large web page, so we do our start methods in webViewProgress:updateProgress:
    
    [self refreshToolbarItems];
}


- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.navigationItem.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.currentRequest = self.webView.request;
    // Don't hide progress view here, as the webpage isn't necessarily visible yet
    
    [self refreshToolbarItems];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self refreshToolbarItems];
    
    [self didFinishLoading];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    self.loadingRequest = YES;
    
    if ([self.downloadDelegate respondsToSelector:@selector(webViewController:shouldStartDownloadWithRequest:)])
    {
        if ([self.downloadDelegate webViewController:self shouldStartDownloadWithRequest:request])
        {
            [self startDownloadWithRequest:request];
        }
    }
    
    return YES;
}

#pragma mark - Private


- (void)didStartLoading
{
    [self showProgressView];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [self refreshToolbarItems];
}

- (void)didFinishLoading
{
    self.loadingRequest = NO;
    [self hideProgressViewWithCompletion:NULL];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    [self refreshToolbarItems];
    
    if ([self.delegate respondsToSelector:@selector(webViewControllerDidFinishLoad:)])
    {
        [self.delegate webViewControllerDidFinishLoad:self];
    }
}

#pragma mark - Downloading

- (void)startDownloadWithRequest:(NSURLRequest *)request
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.allowsCellularAccess = YES;
    configuration.discretionary = NO;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithRequest:request];
    downloadTask.uniqueTaskIdentifier = [[NSUUID UUID] UUIDString];
    
    if ([self.downloadDelegate respondsToSelector:@selector(webViewController:willStartDownloadWithTask:startDownloadBlock:)])
    {
        [self.downloadDelegate webViewController:self willStartDownloadWithTask:downloadTask startDownloadBlock:^(BOOL shouldContinue)
        {
            if (shouldContinue)
            {
                [downloadTask resume];
            }
            else
            {
                [downloadTask cancel];
            }
        }];
    }
    else
    {
        [downloadTask resume];
    }
    
}

#pragma mark - NSURLSession delegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if ([self.downloadDelegate respondsToSelector:@selector(webViewController:downloadTask:totalBytesDownloaded:totalBytesExpected:)])
    {
        [self.downloadDelegate webViewController:self downloadTask:downloadTask totalBytesDownloaded:totalBytesWritten totalBytesExpected:totalBytesExpectedToWrite];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    if ([self.downloadDelegate respondsToSelector:@selector(webViewController:downloadTask:didDownloadFileToURL:)])
    {
        [self.downloadDelegate webViewController:self downloadTask:downloadTask didDownloadFileToURL:location];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if ([self.downloadDelegate respondsToSelector:@selector(webViewController:downloadTask:didCompleteDownloadWithError:)])
    {
        [self.downloadDelegate webViewController:self downloadTask:(NSURLSessionDownloadTask *)task didCompleteDownloadWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    // TODO: Support download resuming
}

#pragma mark - Dismissal

- (void)dismissWebViewController:(UIBarButtonItem *)barButtonItem
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Interface Orientation

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - Memory Management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [self.webView stopLoading];
 	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    self.webView.delegate = nil;
}

@end
