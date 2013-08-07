//
//  GBATransparentTableViewHeaderFooterView.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/5/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBATransparentTableViewHeaderFooterView.h"

@interface GBATransparentTableViewHeaderFooterView ()

@property (strong, nonatomic) UIView *originalBackgroundView;

@end

@implementation GBATransparentTableViewHeaderFooterView

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.tintColor = [UIColor redColor];
        
        self.originalBackgroundView = [self.backgroundView snapshotViewAfterScreenUpdates:NO];
        
        UIView *background = [[UIView alloc] init];
        background.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
        self.backgroundView = self.originalBackgroundView;
    }
    
    return self;
}

@end
