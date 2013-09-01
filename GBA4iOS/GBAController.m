//
//  GBAController.m
//  GBA4iOS
//
//  Created by Yvette Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAController.h"
#import "UIScreen+Widescreen.h"

static NSString *GBAScreenTypeiPhone = @"iPhone";
static NSString *GBAScreenTypeRetina = @"Retina";
static NSString *GBAScreenTypeRetina4 = @"Retina 4";
static NSString *GBAScreenTypeiPad = @"iPad";

@interface GBAController ()

@property (copy, nonatomic) NSDictionary *infoDictionary;

@end

@implementation GBAController

- (instancetype)initWithContentsOfFile:(NSString *)filepath
{
    self = [super init];
    if (self)
    {
        _filepath = [filepath copy];
        _infoDictionary = [[NSDictionary dictionaryWithContentsOfFile:[_filepath stringByAppendingPathComponent:@"Info.plist"]] copy];
        
        if (_infoDictionary == nil)
        {
            return nil;
        }
    }
    
    return self;
}

+ (GBAController *)controllerWithContentsOfFile:(NSString *)filepath
{
    GBAController *controller = [[GBAController alloc] initWithContentsOfFile:filepath];
    return controller;
}

- (NSString *)name
{
    NSString *filename = [self.filepath lastPathComponent];
    return [filename stringByDeletingPathExtension];
}

- (UIImage *)imageForOrientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *assets = dictionary[@"Assets"];
    
    NSString *key = [self keyForCurrentDeviceWithDictionary:assets];
    NSString *relativePath = assets[key];
    
    NSString *filepath = [self.filepath stringByAppendingPathComponent:relativePath];
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    
    if ([key isEqualToString:GBAScreenTypeiPhone] || [key isEqualToString:GBAScreenTypeiPad])
    {
        scale = 1.0f; // In case of a skin without retina artwork
    }
    
    UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfFile:filepath] scale:scale];
    
    return image;
}

- (CGRect)rectForButtonRect:(GBAControllerRect)button orientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *layout = dictionary[@"Layout"];
    
    NSString *key = [self keyForCurrentDeviceWithDictionary:layout];
    NSDictionary *rect = layout[key];
    
    key = [self keyForButtonRect:button];
    NSDictionary *buttonRect = rect[key];
    
    return CGRectMake([buttonRect[@"X"] floatValue], [buttonRect[@"Y"] floatValue], [buttonRect[@"Width"] floatValue], [buttonRect[@"Height"] floatValue]);
}

- (NSString *)keyForButtonRect:(GBAControllerRect)button
{
    NSString *key = nil;
    switch (button) {
        case GBAControllerRectDPad:
            key = @"D-Pad";
            break;
            
        case GBAControllerRectA:
            key = @"A";
            break;
            
        case GBAControllerRectB:
            key = @"B";
            break;
            
        case GBAControllerRectAB:
            key = @"AB";
            break;
            
        case GBAControllerRectStart:
            key = @"Start";
            break;
            
        case GBAControllerRectSelect:
            key = @"Select";
            break;
            
        case GBAControllerRectL:
            key = @"L";
            break;
            
        case GBAControllerRectR:
            key = @"R";
            break;
            
        case GBAControllerRectMenu:
            key = @"Menu";
            break;
            
        case GBAControllerRectScreen:
            key = @"Screen";
            break;
    }
    
    return key;
}

- (NSString *)keyForCurrentDeviceWithDictionary:(NSDictionary *)dictionary
{
    NSString *key = nil;
    
    if ([[UIScreen mainScreen] scale] == 2.0)
    {
        if ([[UIScreen mainScreen] isWidescreen])
        {
            if ([dictionary objectForKey:GBAScreenTypeRetina4])
            {
                key = GBAScreenTypeRetina4;
            }
            else if ([dictionary objectForKey:GBAScreenTypeRetina])
            {
                key = GBAScreenTypeRetina;
            }
            else {
                key = GBAScreenTypeiPhone;
            }
            
        }
        else
        {
            if ([dictionary objectForKey:GBAScreenTypeRetina])
            {
                key = GBAScreenTypeRetina;
            }
            else {
                key = GBAScreenTypeiPhone;
            }
        }
    }
    else
    {
        key = GBAScreenTypeiPhone;
    }
    
    return key;
}

- (NSDictionary *)dictionaryForOrientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = nil;
    
    switch (orientation) {
        case GBAControllerOrientationPortrait:
            dictionary = self.infoDictionary[@"Portrait"];
            break;
            
        case GBAControllerOrientationLandscape:
            dictionary = self.infoDictionary[@"Landscape"];
            break;
    }
    
    return dictionary;
}

- (GBAControllerOrientation)supportedOrientations
{
    GBAControllerOrientation supportedOrientations = 0;
    
    if ([self dictionaryForOrientation:GBAControllerOrientationPortrait])
    {
        supportedOrientations |= GBAControllerOrientationPortrait;
    }
    
    if ([self dictionaryForOrientation:GBAControllerOrientationLandscape])
    {
        supportedOrientations |= GBAControllerOrientationLandscape;
    }
        
    return supportedOrientations;
}

@end
