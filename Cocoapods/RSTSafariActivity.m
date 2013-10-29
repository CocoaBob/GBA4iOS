//
//  RSTSafariActivity.m
//
//  Created by Riley Testut on 9/11/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "RSTSafariActivity.h"

@interface RSTSafariActivity ()

@property (copy, nonatomic) NSURL *url;

@end

@implementation RSTSafariActivity

#pragma mark - UIActivity subclass

- (NSString *)activityType
{
    return NSStringFromClass([self class]);
}

- (NSString *)activityTitle
{
    return NSLocalizedString(@"Safari", @"");
}

- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"safari"];
}


- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    id activityItem = [self firstValidActivityItemForActivityItems:activityItems];
    
    return (activityItem != nil);
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    id activityItem = [self firstValidActivityItemForActivityItems:activityItems];
    
    if ([activityItem isKindOfClass:[NSString class]])
    {
        self.url = [NSURL URLWithString:(NSString *)activityItem];
    }
    else
    {
        self.url = activityItem;
    }
}

- (void)performActivity
{
    BOOL finished = [[UIApplication sharedApplication] openURL:self.url];
    
    [self activityDidFinish:finished];
}

+ (UIActivityCategory)activityCategory
{
    return UIActivityCategoryShare;
}

#pragma mark - Helper Methods

- (id)firstValidActivityItemForActivityItems:(NSArray *)activityItems
{
    for (id activityItem in activityItems)
    {
        if ([activityItem isKindOfClass:[NSString class]])
        {
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:activityItem]])
            {
                return activityItem;
            }
        }
        else if ([activityItem isKindOfClass:[NSURL class]])
        {
            if ([[UIApplication sharedApplication] canOpenURL:activityItem])
            {
                return activityItem;
            }
        }
    }
    
    return nil;
}

@end
