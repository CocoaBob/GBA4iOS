//
//  GBAControllerView.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerView.h"
#import "UIScreen+Widescreen.h"

static NSString *GBAScreenTypeiPhone = @"iPhone";
static NSString *GBAScreenTypeRetina = @"Retina";
static NSString *GBAScreenTypeRetina4 = @"Retina 4";
static NSString *GBAScreenTypeiPad = @"iPad";

@interface GBAControllerView ()

@property (copy, nonatomic) NSDictionary *infoDictionary;
@property (strong, nonatomic) UIImageView *imageView;

@property (strong, nonatomic) UIView *overlayView;

@end

@implementation GBAControllerView

#pragma mark - Init

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (void)initialize
{
    //self.multipleTouchEnabled = YES;s
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    
    self.imageView = ({
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self addSubview:imageView];
        imageView;
    });
    
    self.orientation = GBAControllerOrientationPortrait;
}

#pragma mark - Getters / Setters

- (void)setSkinFilepath:(NSString *)skinFilepath
{
    _skinFilepath = [skinFilepath copy];
    _infoDictionary = [NSDictionary dictionaryWithContentsOfFile:[skinFilepath stringByAppendingPathComponent:@"Info.plist"]];
}

- (void)setOrientation:(GBAControllerOrientation)orientation
{
    _orientation = orientation;
    
    [self update];
}

#pragma mark - UIView subclass

- (CGSize)intrinsicContentSize
{
    return self.imageView.image.size;
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.superview touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.superview touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.superview touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.superview touchesEnded:touches withEvent:event];
}

#pragma mark - Public

- (void)showButtonRects
{
    self.overlayView = (
    {
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        view.userInteractionEnabled = NO;
        [self addSubview:view];
        view;
    });
    
    void(^AddOverlayForButton)(GBAControllerButton button) = ^(GBAControllerButton button)
    {
        UILabel *overlay = [[UILabel alloc] initWithFrame:[self rectForButton:button]];
        overlay.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5];
        overlay.text = [self keyForButton:button];
        overlay.adjustsFontSizeToFitWidth = YES;
        overlay.textColor = [UIColor whiteColor];
        overlay.font = [UIFont boldSystemFontOfSize:18.0f];
        overlay.textAlignment = NSTextAlignmentCenter;
        [self addSubview:overlay];
    };
    
    AddOverlayForButton(GBAControllerButtonDPad);
    AddOverlayForButton(GBAControllerButtonA);
    AddOverlayForButton(GBAControllerButtonB);
    AddOverlayForButton(GBAControllerButtonAB);
    AddOverlayForButton(GBAControllerButtonL);
    AddOverlayForButton(GBAControllerButtonR);
    AddOverlayForButton(GBAControllerButtonStart);
    AddOverlayForButton(GBAControllerButtonSelect);
    AddOverlayForButton(GBAControllerButtonMenu);
    
    // AddOverlayForButton(GBAControllerButtonScreen);
}

- (void)hideButtonRects
{
    [self.overlayView removeFromSuperview];
    self.overlayView = nil;
}

#pragma mark - Private

- (void)update
{
    self.imageView.image = [self imageForOrientation:self.orientation];
    [self invalidateIntrinsicContentSize];
}

#pragma mark - Private Helper Methods

- (UIImage *)imageForOrientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *assets = dictionary[@"Assets"];
    
    NSString *key = [self keyForCurrentDeviceWithDictionary:assets];
    NSString *relativePath = assets[key];
    
    NSString *filepath = [self.skinFilepath stringByAppendingPathComponent:relativePath];
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    
    if ([key isEqualToString:GBAScreenTypeiPhone] || [key isEqualToString:GBAScreenTypeiPad])
    {
        scale = 1.0f; // In case of a skin without retina artwork
    }
    
    UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfFile:filepath] scale:scale];
    
    return image;
}

- (CGRect)rectForButton:(GBAControllerButton)button
{
    NSDictionary *dictionary = [self dictionaryForOrientation:self.orientation];
    NSDictionary *layout = dictionary[@"Layout"];
    
    NSString *key = [self keyForCurrentDeviceWithDictionary:layout];
    NSDictionary *rect = layout[key];
    
    key = [self keyForButton:button];
    NSDictionary *buttonRect = rect[key];
    
    return CGRectMake([buttonRect[@"X"] floatValue], [buttonRect[@"Y"] floatValue], [buttonRect[@"Width"] floatValue], [buttonRect[@"Height"] floatValue]);
}

- (NSString *)keyForButton:(GBAControllerButton)button
{
    NSString *key = nil;
    switch (button) {
        case GBAControllerButtonDPad:
            key = @"D-Pad";
            break;
            
        case GBAControllerButtonA:
            key = @"A";
            break;
            
        case GBAControllerButtonB:
            key = @"B";
            break;
            
        case GBAControllerButtonAB:
            key = @"AB";
            break;
            
        case GBAControllerButtonStart:
            key = @"Start";
            break;
            
        case GBAControllerButtonSelect:
            key = @"Select";
            break;
            
        case GBAControllerButtonL:
            key = @"L";
            break;
            
        case GBAControllerButtonR:
            key = @"R";
            break;
            
        case GBAControllerButtonMenu:
            key = @"Menu";
            break;
            
        case GBAControllerButtonScreen:
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

@end
