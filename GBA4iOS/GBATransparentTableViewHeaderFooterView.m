//
//  GBATransparentTableViewHeaderFooterView.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBATransparentTableViewHeaderFooterView.h"
#import "GBAROMTableViewController.h"

@interface GBATransparentTableViewHeaderFooterView ()

@property (strong, nonatomic) UIView *originalBackgroundView;
@property (strong, nonatomic) UIView *translucentBackgroundView;

@end

@implementation GBATransparentTableViewHeaderFooterView

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self)
    {
        
        self.originalBackgroundView = [self.backgroundView snapshotViewAfterScreenUpdates:NO];
        
        self.translucentBackgroundView = ({
            UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
            view.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
            view;
        });
    }
    
    return self;
}

- (void)setTheme:(GBAROMTableViewControllerTheme)theme
{
    _theme = theme;
    
    switch (theme) {
        case GBAROMTableViewControllerThemeOpaque:
            self.backgroundView = self.originalBackgroundView;
            break;
            
        case GBAROMTableViewControllerThemeTranslucent: {
            self.tintColor = [UIColor clearColor];
            self.backgroundView = self.translucentBackgroundView;
            break;
        }
    }
}

@end
