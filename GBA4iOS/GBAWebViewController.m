//
//  GBAWebViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/26/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAWebViewController.h"
#import "GBASettingsViewController.h"
#import "GBAWebBrowserHomepageViewController.h"

@interface GBAWebViewController ()
{
    BOOL _reloadWhenVisible;
}

@end

@implementation GBAWebViewController

- (instancetype)init
{
    GBAWebBrowserHomepage homepage = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsSelectedHomepageKey];
    NSString *address = [self addressForHomepage:homepage];
    
    self = [super initWithAddress:address];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:GBASettingsDidChangeNotification object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GBASettingsDidChangeNotification object:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        [self.navigationController setToolbarHidden:NO animated:NO];
    }
    
    if (_reloadWhenVisible)
    {
        GBAWebBrowserHomepage homepage = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsSelectedHomepageKey];
        NSString *address = [self addressForHomepage:homepage];
        
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:address]]];
        
        _reloadWhenVisible = NO;
    }
}

#pragma mark - Settings Notification -

- (void)settingsDidChange:(NSNotification *)notification
{
    if ([notification.userInfo[@"key"] isEqualToString:GBASettingsSelectedHomepageKey] || [notification.userInfo[@"key"] isEqualToString:GBASettingsCustomHomepageKey])
    {
        _reloadWhenVisible = YES;
    }
}

#pragma mark - Helper Methods -

- (NSString *)addressForHomepage:(GBAWebBrowserHomepage)homepage
{
    NSString *address = @"http://google.com";
    
    switch (homepage)
    {
        case GBAWebBrowserHomepageGoogle:
            address = @"http://www.google.com";
            break;
            
        case GBAWebBrowserHomepageYahoo:
            address = @"http://www.yahoo.com";
            break;
            
        case GBAWebBrowserHomepageBing:
            address = @"http://www.bing.com";
            break;
            
        case GBAWebBrowserHomepageGameFAQs:
            address = @"http://www.gamefaqs.com";
            break;
            
        case GBAWebBrowserHomepageSuperCheats:
            address = @"http://www.supercheats.com";
            break;
            
        case GBAWebBrowserHomepageCustom:
        {
            address = [[NSUserDefaults standardUserDefaults] objectForKey:GBASettingsCustomHomepageKey];
            
            if (address.length == 0)
            {
                address = @"http://gba4iosapp.com";
            }
            
            NSURLComponents *components = [NSURLComponents componentsWithString:address];
            
            if (components.scheme == nil)
            {
                components.scheme = @"http";
                
                address = [components string];
            }
            
            break;
        }
            
        default:
            break;
    }
    
    return address;
}

@end
