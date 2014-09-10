//
//  GBASoftwareUpdateViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 2/10/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBASoftwareUpdateViewController.h"
#import "GBASoftwareUpdateOperation.h"

#import "UIAlertView+RSTAdditions.h"

@interface GBASoftwareUpdateViewController ()

@property (strong, nonatomic) GBASoftwareUpdate *softwareUpdate;

@property (strong, nonatomic) UILabel *statusLabel;
@property (strong, nonatomic) UIActivityIndicatorView *statusActivityIndicatorView;
@property (strong, nonatomic) NSLayoutConstraint *statusLabelHorizontalLayoutConstraint;

@property (weak, nonatomic) IBOutlet UILabel *softwareUpdateNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *softwareUpdateDeveloperLabel;
@property (weak, nonatomic) IBOutlet UILabel *softwareUpdateSizeLabel;
@property (weak, nonatomic) IBOutlet UITextView *softwareUpdateDescriptionTextView;

@end

@implementation GBASoftwareUpdateViewController

- (instancetype)init
{
    return [self initWithSoftwareUpdate:nil];
}

- (instancetype)initWithSoftwareUpdate:(GBASoftwareUpdate *)softwareUpdate
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"softwareUpdateViewController"];
    if (self)
    {
        _softwareUpdate = softwareUpdate;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    self.statusLabel = ({
        UILabel *label = [[UILabel alloc] init];
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.text = NSLocalizedString(@"Checking for Update…", @"");
        label.textColor = [UIColor grayColor];
        label.font = [UIFont systemFontOfSize:15.0f];
        [label sizeToFit];
        label;
    });
    
    self.statusActivityIndicatorView = ({
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
        activityIndicatorView.hidesWhenStopped = YES;
        
        activityIndicatorView;
    });
    
    UIView *view = [UIView new];
    self.tableView.backgroundView = view;
    [view addSubview:self.statusLabel];
    [view addSubview:self.statusActivityIndicatorView];
    
    NSMutableArray *constraints = [NSMutableArray array];
    
    self.statusLabelHorizontalLayoutConstraint = [NSLayoutConstraint constraintWithItem:self.statusLabel
                                                                              attribute:NSLayoutAttributeCenterX
                                                                              relatedBy:NSLayoutRelationEqual
                                                                                 toItem:self.tableView.backgroundView
                                                                              attribute:NSLayoutAttributeCenterX
                                                                             multiplier:1.0
                                                                               constant:0.0];
    [constraints addObject:self.statusLabelHorizontalLayoutConstraint];
    
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.statusLabel
                                              attribute:NSLayoutAttributeCenterY
                                              relatedBy:NSLayoutRelationEqual
                                                 toItem:self.tableView.backgroundView
                                              attribute:NSLayoutAttributeCenterY
                                             multiplier:1.0
                                               constant:0.0]];
    
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.statusActivityIndicatorView
                                                        attribute:NSLayoutAttributeLeft
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.statusLabel
                                                        attribute:NSLayoutAttributeRight
                                                       multiplier:1.0
                                                         constant:5.0]];
    
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.statusActivityIndicatorView
                                                        attribute:NSLayoutAttributeCenterY
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.tableView.backgroundView
                                                        attribute:NSLayoutAttributeCenterY
                                                       multiplier:1.0
                                                         constant:0.0]];
    
    [self.tableView.backgroundView addConstraints:constraints];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.softwareUpdate == nil)
    {
        [self checkForUpdate];
    }
    else
    {
        [self refreshViewWithSoftwareUpdateInfo];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Check For Update

- (void)checkForUpdate
{
    CGFloat constant = -((CGRectGetWidth(self.statusLabel.bounds) + CGRectGetWidth(self.statusActivityIndicatorView.bounds) + 5) - CGRectGetWidth(self.statusLabel.bounds))/2.0f;
    self.statusLabelHorizontalLayoutConstraint.constant = constant;
    self.statusLabel.text = NSLocalizedString(@"Checking for Update…", @"");
    
    [self.tableView.backgroundView updateConstraints];
    
    [self.statusActivityIndicatorView startAnimating];
    
    GBASoftwareUpdateOperation *softwareUpdateOperation = [GBASoftwareUpdateOperation new];
    [softwareUpdateOperation checkForUpdateWithCompletion:^(GBASoftwareUpdate *softwareUpdate, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.statusActivityIndicatorView stopAnimating];
            self.statusLabelHorizontalLayoutConstraint.constant = 0;
            
            if (error)
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithError:error cancelButtonTitle:NSLocalizedString(@"Cancel", @"")];
                [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                    [self.navigationController popToRootViewControllerAnimated:YES];
                }];
                
                self.statusLabel.text = NSLocalizedString(@"Failed to check for update.", @"");
                
                [UIView transitionWithView:self.statusLabel duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    [self.tableView.backgroundView layoutIfNeeded];
                } completion:nil];
                
                return;
            }
            
            if (![softwareUpdate isNewerThanAppVersion] || ![softwareUpdate isSupportedOnCurrentiOSVersion])
            {
                NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey];
                NSString *upToDateMessage = [NSString stringWithFormat:@"GBA4iOS %@\n%@", bundleVersion, NSLocalizedString(@"Your software is up to date.", @"")];
                
                self.statusLabel.text = upToDateMessage;
                
                [UIView transitionWithView:self.statusLabel duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    [self.tableView.backgroundView layoutIfNeeded];
                } completion:nil];
                
                [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
                
                return;
            }
            
            self.softwareUpdate = softwareUpdate;
            [self refreshViewWithSoftwareUpdateInfo];
            
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
            
        });
    }];
}

- (void)refreshViewWithSoftwareUpdateInfo
{
    self.softwareUpdateNameLabel.text = self.softwareUpdate.name;
    self.softwareUpdateDeveloperLabel.text = self.softwareUpdate.developer;
    self.softwareUpdateDescriptionTextView.text = self.softwareUpdate.releaseNotes;
    self.softwareUpdateSizeLabel.text = self.softwareUpdate.localizedSize;
    
    [UIView transitionWithView:self.tableView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.statusLabel.alpha = 0.0;
        [self.tableView reloadData];
    } completion:nil];
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.softwareUpdate == nil)
    {
        return 0;
    }
    
    return [super numberOfSectionsInTableView:tableView];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return 70 + [self.softwareUpdateDescriptionTextView sizeThatFits:CGSizeMake(CGRectGetWidth(self.view.bounds), FLT_MAX)].height + 1; // Add one to ensure iOS 7 UITextView displays all lines of text
    }
    
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Are you sure you want to update GBA4iOS?", @"")
                                                        message:NSLocalizedString(@"Before updating, make sure you have set the date back on this device at least 24 hours. Failure to do so may result in an incomplete update and prevent the app from opening.", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                              otherButtonTitles:NSLocalizedString(@"Update", @""), nil];
        [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            
            if (buttonIndex == 1)
            {
                [[UIApplication sharedApplication] openURL:self.softwareUpdate.url];
            }
            
        }];
    }
    
    [self.tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
}

@end
