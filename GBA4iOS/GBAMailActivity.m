//
//  GBAMailActivity.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/24/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAMailActivity.h"
#import "UIAlertView+RSTAdditions.h"
@import MessageUI;

@interface GBAMailActivity () <MFMailComposeViewControllerDelegate, UINavigationControllerDelegate>

@property (copy, nonatomic) NSURL *fileURL;

@end

@implementation GBAMailActivity

- (NSString *)activityType
{
    return NSStringFromClass([self class]);
}

- (NSString *)activityTitle
{
    return NSLocalizedString(@"Mail", @"");
}

- (UIImage *)_activityImage
{
    return [UIImage imageNamed:@"Mail_Activity_Icon"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    // I *should* check to see if the items are supported, but since I know the items I'm providing are, meh.
    return YES;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    self.fileURL = [activityItems firstObject];
}

- (UIViewController *)activityViewController
{
    NSData *data = [NSData dataWithContentsOfURL:self.fileURL];
    
    MFMailComposeViewController *mailComposeViewController = [[MFMailComposeViewController alloc] init];
    mailComposeViewController.mailComposeDelegate = self;
    [mailComposeViewController addAttachmentData:data mimeType:@"application/octet-stream" fileName:[[self.fileURL path] lastPathComponent]];
    
    return mailComposeViewController;
}

+ (UIActivityCategory)activityCategory
{
    return UIActivityCategoryShare;
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    if (result == MFMailComposeResultFailed)
    {
        return [self activityDidFinish:NO];
    }
    
    return [self activityDidFinish:YES];
}

@end
