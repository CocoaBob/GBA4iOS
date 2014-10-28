//
//  GBALinkViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 4/10/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBALinkViewController.h"
#import "GBASettingsViewController.h"
#import "GBALinkManager.h"
#import "GBALinkViewControllerTableViewCell.h"
#import "GBALinkNearbyPeersHeaderFooterView.h"

#import "UIAlertView+RSTAdditions.h"
#import "MCPeerID+Conveniences.h"

@import MultipeerConnectivity;

@interface GBALinkViewController () <MCNearbyServiceBrowserDelegate, GBALinkManagerDelegate>

@property (strong, nonatomic) UISwitch *linkEnabledSwitch;

@property (strong, nonatomic) NSMutableArray *connectedPeers;
@property (strong, nonatomic) NSMutableArray *nearbyPeers;

@property (strong, nonatomic) MCNearbyServiceBrowser *nearbyServiceBrowser;

@end

@implementation GBALinkViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        self.title = NSLocalizedString(@"Wireless Linking", @"");
        
        MCSession *session = [[GBALinkManager sharedManager] session];
        
        _connectedPeers = [NSMutableArray arrayWithArray:[session connectedPeers]];
        _nearbyPeers = [NSMutableArray new];
        
        _nearbyServiceBrowser = ({
            MCNearbyServiceBrowser *nearbyServiceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:session.myPeerID serviceType:GBALinkSessionServiceType];
            nearbyServiceBrowser.delegate = self;
            nearbyServiceBrowser;
        });
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SwitchCell"];
    [self.tableView registerClass:[GBALinkViewControllerTableViewCell class] forCellReuseIdentifier:@"LinkCell"];
    [self.tableView registerClass:[GBALinkNearbyPeersHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"NearbyPeersHeader"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[GBALinkManager sharedManager] setDelegate:self];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsLinkEnabled])
    {
        [self.nearbyServiceBrowser startBrowsingForPeers];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsLinkEnabled])
    {
        [self.nearbyServiceBrowser stopBrowsingForPeers];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Linking

- (void)toggleLinking:(UISwitch *)sender
{
    if ([sender isOn])
    {
        [self enableLinking];
    }
    else
    {
        [self disableLinking];
    }
}

- (void)enableLinking
{
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:GBASettingsLinkEnabled];
    
    if ([self.tableView numberOfSections] == 1)
    {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)] withRowAnimation:UITableViewRowAnimationFade];
    }
    
    [self.linkEnabledSwitch setOn:YES animated:YES];
    
    [[GBALinkManager sharedManager] start];
    
    [self.nearbyServiceBrowser startBrowsingForPeers];
}

- (void)disableLinking
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:GBASettingsLinkEnabled];
    
    if ([self.tableView numberOfSections] > 1)
    {
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)] withRowAnimation:UITableViewRowAnimationFade];
    }
    
    [self.linkEnabledSwitch setOn:NO animated:YES];
    
    [[GBALinkManager sharedManager] stop];
    
    [self.nearbyPeers removeAllObjects];
    [self.connectedPeers removeAllObjects];
    
    [self.nearbyServiceBrowser stopBrowsingForPeers];
}

- (void)sendInvitationToPeer:(MCPeerID *)peerID
{
    peerID.rst_state = MCSessionStateConnecting;
    
    [self removeNearbyPeer:peerID];
    [self addConnectedPeer:peerID];
    
    [self.nearbyServiceBrowser invitePeer:peerID toSession:[[GBALinkManager sharedManager] session] withContext:nil timeout:0];
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    peerID.rst_discoveryInfo = info;
    [self addNearbyPeer:peerID];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    [self removeNearbyPeer:peerID];
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    [self disableLinking];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithError:error cancelButtonTitle:NSLocalizedString(@"OK", @"")];
    [alert show];
}

#pragma mark - GBALinkManagerDelegate

- (void)linkManager:(GBALinkManager *)linkManager peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsLinkEnabled])
    {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.tableView beginUpdates];
        
        if (state == MCSessionStateNotConnected)
        {
            [self removeConnectedPeer:peerID];
            [self addNearbyPeer:peerID];
        }
        else
        {
            [self removeNearbyPeer:peerID];
            [self addConnectedPeer:peerID];
        }
        
        [self.tableView endUpdates];
        
    });
}

#pragma mark - Helper Methods

- (void)addNearbyPeer:(MCPeerID *)peerID
{
    if ([self.nearbyPeers containsObject:peerID] || [self.connectedPeers containsObject:peerID])
    {
        return;
    }
    
    [self.nearbyPeers addObject:peerID];
    
    if ([self.nearbyPeers count] == 1)
    {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:2]] withRowAnimation:UITableViewRowAnimationFade];
        
        GBALinkNearbyPeersHeaderFooterView *headerFooterView = (GBALinkNearbyPeersHeaderFooterView *)[self.tableView headerViewForSection:2];
        [headerFooterView setShowsActivityIndicator:YES];
    }
    else
    {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:([self.nearbyPeers count] - 1) inSection:2]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)addConnectedPeer:(MCPeerID *)peerID
{
    NSInteger row = [self.connectedPeers indexOfObject:peerID];
    
    if (row != NSNotFound)
    {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
        return;
    }
    
    [self.connectedPeers addObject:peerID];
    
    if ([self.connectedPeers count] == 1)
    {
        // Reload when adding first row to show the header
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:([self.connectedPeers count] - 1) inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)removeNearbyPeer:(MCPeerID *)peerID
{
    if (![self.nearbyPeers containsObject:peerID])
    {
        return;
    }
    
    NSUInteger row = [self.nearbyPeers indexOfObject:peerID];
    [self.nearbyPeers removeObjectAtIndex:row];
    
    if ([self.nearbyPeers count] == 0)
    {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:2]] withRowAnimation:UITableViewRowAnimationFade];
        
        GBALinkNearbyPeersHeaderFooterView *headerFooterView = (GBALinkNearbyPeersHeaderFooterView *)[self.tableView headerViewForSection:2];
        [headerFooterView setShowsActivityIndicator:NO];
    }
    else
    {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:2]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)removeConnectedPeer:(MCPeerID *)peerID
{
    NSInteger row = [self.connectedPeers indexOfObject:peerID];
    
    if (row == NSNotFound)
    {
        return;
    }
    
    [self.connectedPeers removeObjectAtIndex:row];
    
    if ([self.connectedPeers count] == 0)
    {
        // Reload when section is empty to hide the header
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
    }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsLinkEnabled])
    {
        // We always have 3 sections to keep the rest of the logic much simpler, even though we use a slightly hacky workaround to make the second section hidden
        return 3;
    }
    
    return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 2)
    {
        GBALinkNearbyPeersHeaderFooterView *headerFooterView = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"NearbyPeersHeader"];
        
        if ([self.nearbyPeers count] == 0)
        {
            [headerFooterView setShowsActivityIndicator:NO];
        }
        else
        {
            [headerFooterView setShowsActivityIndicator:YES];
        }
        
        return headerFooterView;
    }
    
    return [super tableView:tableView viewForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 1)
    {
        if ([self.connectedPeers count] == 0)
        {
            return 1;
        }
    }
    
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 1)
    {
        if ([self.connectedPeers count] == 0)
        {
            return 1;
        }
    }
    
    return UITableViewAutomaticDimension;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 1;
    }
    else if (section == 1)
    {
        return [self.connectedPeers count];
    }
    else if (section == 2)
    {
        if ([self.nearbyPeers count] > 0)
        {
            return [self.nearbyPeers count];
        }
        
        return 1;
    }
    
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 1)
    {
        if ([self.connectedPeers count] > 0)
        {
            return NSLocalizedString(@"Connected", @"");
        }
    }
    else if (section == 2)
    {
        return NSLocalizedString(@"Nearby", @"");
    }
    
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"Wireless Linking uses either local Wi-Fi or Bluetooth. However, for best performance, all devices should be connected to the same Wi-Fi network.", @"");
    }
    
    return nil;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = nil;
    
    if (indexPath.section == 0)
    {
        identifier = @"SwitchCell";
    }
    else
    {
        identifier = @"LinkCell";
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    
    if (indexPath.section == 0 && cell.accessoryView == nil)
    {
        self.linkEnabledSwitch = ({
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsLinkEnabled];
            [switchView addTarget:self action:@selector(toggleLinking:) forControlEvents:UIControlEventValueChanged];
            switchView;
        });
        cell.accessoryView = self.linkEnabledSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        cell.textLabel.text = self.title;
    }
    
    if (indexPath.section == 1)
    {
        MCPeerID *peerID = self.connectedPeers[indexPath.row];
        cell.textLabel.text = peerID.displayName;
        
        if (peerID.rst_state == MCSessionStateConnected)
        {
            [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:NO];
        }
        else
        {
            [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:YES];
        }
    }
    else if (indexPath.section == 2)
    {
        if ([self.nearbyPeers count] == 0)
        {
            cell.textLabel.textColor = [UIColor grayColor];
            cell.textLabel.text = NSLocalizedString(@"Searching…", @"");
            
            [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:YES];
        }
        else
        {
            MCPeerID *peerID = self.nearbyPeers[indexPath.row];
            cell.textLabel.text = peerID.displayName;
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 2)
    {
        return;
    }
    
    if (indexPath.row == 0 && [self.nearbyPeers count] == 0)
    {
        return;
    }
    
    [self sendInvitationToPeer:self.nearbyPeers[indexPath.row]];
}


@end
