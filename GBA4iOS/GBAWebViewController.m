//
//  GBAWebViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/26/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

// RSTWebViewController is not meant to be subclassed, but eh I need to to achieve some features

#import "GBAWebViewController.h"
#import "GBAWebViewControllerURLCache.h"

@interface RSTWebViewController ()

@property (strong, nonatomic) UIProgressView *progressView;

- (void)webViewDidFinishLoad:(UIWebView *)webView;

@end

@interface GBAWebViewController () <RSTWebViewControllerDelegate>

@property (assign, nonatomic) BOOL loadingGoogleSearchRequest;
@property (assign, nonatomic) NSInteger initialLoadingGoogleSearchRequestCount;

@end

@implementation GBAWebViewController

+ (void)initialize
{
    GBAWebViewControllerURLCache *cache = [[GBAWebViewControllerURLCache alloc] init];
    [NSURLCache setSharedURLCache:cache];
}

- (instancetype)initWithROMType:(GBAROMType)romType
{
    self = [super initWithAddress:[self googleSearchLink]];
    
    if (self)
    {
        _romType = romType;
        _loadingGoogleSearchRequest = YES;
        
        self.progressView.hidden = YES;
        
        [(GBAWebViewControllerURLCache *)[NSURLCache sharedURLCache] setReplaceInitialRequestWithBlankPage:YES];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [super webViewDidFinishLoad:webView];
    
    if (self.loadingGoogleSearchRequest)
    {
        self.initialLoadingGoogleSearchRequestCount++;
        
        if (self.initialLoadingGoogleSearchRequestCount >= 2)
        {
            self.loadingGoogleSearchRequest = NO;
            self.initialLoadingGoogleSearchRequestCount = 0;
            [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[self coolROMURLAddress]]]];
            
            self.progressView.progress = 0;
            self.progressView.hidden = NO;
        }
    }
}

#pragma mark - Helper Methods

- (NSString *)coolROMURLAddress
{
    if (self.romType == GBAROMTypeGBA)
    {
        return @"http://m.coolrom.com/roms/gba/";
    }
    else
    {
        return @"http://m.coolrom.com/roms/gbc/";
    }
}

- (NSString *)googleSearchLink
{
    if (self.romType == GBAROMTypeGBA)
    {
        return @"http://www.google.com/search?q=download+GBA+roms+coolrom&ie=UTF-8&oe=UTF-8&hl=en&client=safari";
    }
    else
    {
        return @"http://www.google.com/search?q=download+GBC+roms+coolrom&ie=UTF-8&oe=UTF-8&hl=en&client=safari";
    }
}

@end
