//
//  GBAWebViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/26/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

// RSTWebViewController is not meant to be subclassed, but eh I need to to achieve some features

#import "GBAWebViewController.h"

@interface RSTWebViewController ()

@property (strong, nonatomic) UIProgressView *progressView;

- (void)webViewDidFinishLoad:(UIWebView *)webView;

@end

@interface GBAWebViewController ()

@end

@implementation GBAWebViewController

- (instancetype)initWithROMType:(GBAROMType)romType
{
    self = [super initWithAddress:[self googleSearchLink]];
    
    if (self)
    {
        _romType = romType;
    }
    
    return self;
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
