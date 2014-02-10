//
//  GBABetaTesterCreditsViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 2/8/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBABetaTesterCreditsViewController.h"

#import <RSTWebViewController.h>

@interface GBABetaTesterCreditsViewController ()

@property (nonatomic, copy) NSArray *betaTesters;

@end

@implementation GBABetaTesterCreditsViewController

- (id)init
{
    self = [self initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self)
    {
        self.title = NSLocalizedString(@"Beta Testers", @"");
        self.betaTesters = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"betaTesters" ofType:@"plist"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.betaTesters count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.betaTesters[section] count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"Cell"];
    }
    
    cell.textLabel.text = self.betaTesters[indexPath.section][indexPath.row][@"name"];
    
    NSString *twitterUsername = self.betaTesters[indexPath.section][indexPath.row][@"twitterUsername"];
    NSString *url = self.betaTesters[indexPath.section][indexPath.row][@"url"];
    
    if ([twitterUsername length] > 0)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    else if ([url length] > 0)
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    else
    {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"Press Beta Testers", @"");
    }
    else if (section == 1)
    {
        return NSLocalizedString(@"Beta Testers", @"");
    }
    
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == [tableView numberOfSections] - 1)
    {
        return NSLocalizedString(@"Tap a name to go to their Twitter profile or personal website.", @"");
    }
    
    return nil;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *betaTester = self.betaTesters[indexPath.section][indexPath.row];
    
    NSString *twitterUsername = betaTester[@"twitterUsername"];
    NSString *url = betaTester[@"url"];
    
    if ([twitterUsername length] > 0)
    {
        [self openTwitterProfileForUsername:twitterUsername];
    }
    else if ([url length] > 0)
    {
        RSTWebViewController *webViewController = [[RSTWebViewController alloc] initWithAddress:url];
        [self.navigationController pushViewController:webViewController animated:YES];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)openTwitterProfileForUsername:(NSString *)username
{
    NSString *scheme = @"";
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot://"]]) // Tweetbot
    {
        scheme = [NSString stringWithFormat:@"tweetbot:///user_profile/%@", username];
    }
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitterrific://"]]) // Twitterrific
    {
        scheme = [NSString stringWithFormat:@"twitterrific:///profile?screen_name=%@", username];
    }
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) // Twitter
    {
        scheme = [NSString stringWithFormat:@"twitter://user?screen_name=%@", username];
    }
    else // Twitter website
    {
        scheme = [NSString stringWithFormat:@"http://twitter.com/%@", username];
    }
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:scheme]];
}


@end
