//
//  GBABluetoothLinkViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/14/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBABluetoothLinkViewController.h"
#import "GBALinkViewControllerTableViewCell.h"
#import "GBALinkNearbyPeersHeaderFooterView.h"

#import "GBASettingsViewController.h"
#import "GBASettingsTableViewCell.h"

#import "GBABluetoothLinkManager.h"
#import "GBAPeer.h"

#define WIRELESS_LINKING_SECTION 0
#define CONNECTION_TYPE_SECTION 2
#define PLAYER_NAME_SECTION 1
#define CONNECTED_PEERS_SECTION 3
#define NEARBY_PEERS_SECTION 4

@interface GBABluetoothLinkViewController () <GBABluetoothLinkManagerDelegate, UITextFieldDelegate>

@property (strong, nonatomic) UISwitch *linkEnabledSwitch;
@property (strong, nonatomic) UISegmentedControl *peerTypeSegmentedControl;
@property (strong, nonatomic) UITextField *groupNameTextField;

@property (assign, nonatomic) GBALinkPeerType peerType;

@property (strong, nonatomic) NSMutableArray *connectedPeers;
@property (strong, nonatomic) NSMutableArray *nearbyPeers;

@end

@implementation GBABluetoothLinkViewController

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        self.title = NSLocalizedString(@"Wireless Linking", @"");
        
        _connectedPeers = [NSMutableArray array];
        _nearbyPeers = [NSMutableArray array];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Update UITableView layout
    self.peerType = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsLinkPeerType];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SwitchCell"];
    [self.tableView registerClass:[GBASettingsTableViewCell class] forCellReuseIdentifier:@"SegmentedControlCell"];
    [self.tableView registerClass:[GBASettingsTableViewCell class] forCellReuseIdentifier:@"PlayerNameCell"];
    [self.tableView registerClass:[GBALinkViewControllerTableViewCell class] forCellReuseIdentifier:@"LinkCell"];
    [self.tableView registerClass:[GBALinkNearbyPeersHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"NearbyPeersHeader"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[GBABluetoothLinkManager sharedManager] setDelegate:self];
    
    if ([[GBABluetoothLinkManager sharedManager] isEnabled])
    {
        [self enableLinking];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[GBABluetoothLinkManager sharedManager] setDelegate:nil];
    
    if (self.peerType == GBALinkPeerTypeClient)
    {
        [[GBABluetoothLinkManager sharedManager] stopScanningForPeers];
    }
    else
    {
        [[GBABluetoothLinkManager sharedManager] startAdvertisingPeer];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Linking -

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
    [[GBABluetoothLinkManager sharedManager] setPeerType:self.peerType];
    [[GBABluetoothLinkManager sharedManager] setEnabled:YES];
    
    [self.peerTypeSegmentedControl setEnabled:NO];
    
    NSRange range = NSMakeRange(0, 0);
    
    if (self.peerType == GBALinkPeerTypeServer)
    {
        range = NSMakeRange(CONNECTED_PEERS_SECTION, 1);
        [[GBABluetoothLinkManager sharedManager] startAdvertisingPeer];
    }
    else
    {
        range = NSMakeRange(CONNECTED_PEERS_SECTION, 2);
        [[GBABluetoothLinkManager sharedManager] startScanningForPeers];
    }
    
    if ([self.tableView numberOfSections] == 3)
    {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:range] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)disableLinking
{
    [[GBABluetoothLinkManager sharedManager] setEnabled:NO];
    [self.peerTypeSegmentedControl setEnabled:NO];
    
    NSRange range = NSMakeRange(0, 0);
    
    if (self.peerType == GBALinkPeerTypeServer)
    {
        range = NSMakeRange(CONNECTED_PEERS_SECTION, 1);
        [[GBABluetoothLinkManager sharedManager] stopAdvertisingPeer];
    }
    else
    {
        range = NSMakeRange(CONNECTED_PEERS_SECTION, 2);
        [[GBABluetoothLinkManager sharedManager] stopScanningForPeers];
    }
    
    if ([self.tableView numberOfSections] > 3)
    {
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndexesInRange:range] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)switchPeerType:(UISegmentedControl *)segmentedControl
{
    if (segmentedControl.selectedSegmentIndex == 0)
    {
        self.peerType = GBALinkPeerTypeServer;
    }
    else
    {
        self.peerType = GBALinkPeerTypeClient;
    }
}

- (void)connectPeer:(GBAPeer *)peer
{
    [self addConnectedPeer:peer];
    [self removeNearbyPeer:peer];
    
    [[GBABluetoothLinkManager sharedManager] connectPeer:peer];
}

#pragma mark - Helper Methods -

- (void)addNearbyPeer:(GBAPeer *)peer
{
    if ([self.nearbyPeers containsObject:peer] || [self.connectedPeers containsObject:peer])
    {
        return;
    }
    
    [self.nearbyPeers addObject:peer];
    
    if ([self.nearbyPeers count] == 1)
    {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:NEARBY_PEERS_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
        
        GBALinkNearbyPeersHeaderFooterView *headerFooterView = (GBALinkNearbyPeersHeaderFooterView *)[self.tableView headerViewForSection:NEARBY_PEERS_SECTION];
        [headerFooterView setShowsActivityIndicator:YES];
    }
    else
    {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:([self.nearbyPeers count] - 1) inSection:NEARBY_PEERS_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)addConnectedPeer:(GBAPeer *)peer
{
    NSInteger row = [self.connectedPeers indexOfObject:peer];
    
    if (row != NSNotFound)
    {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:CONNECTED_PEERS_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
        return;
    }
    
    [self.connectedPeers addObject:peer];
    
    if ([self.connectedPeers count] == 1)
    {
        // Reload when adding first row to show the header
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:CONNECTED_PEERS_SECTION] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:([self.connectedPeers count] - 1) inSection:CONNECTED_PEERS_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)removeNearbyPeer:(GBAPeer *)peer
{
    if (![self.nearbyPeers containsObject:peer])
    {
        return;
    }
    
    NSUInteger row = [self.nearbyPeers indexOfObject:peer];
    [self.nearbyPeers removeObjectAtIndex:row];
    
    if ([self.nearbyPeers count] == 0)
    {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:NEARBY_PEERS_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
        
        GBALinkNearbyPeersHeaderFooterView *headerFooterView = (GBALinkNearbyPeersHeaderFooterView *)[self.tableView headerViewForSection:NEARBY_PEERS_SECTION];
        [headerFooterView setShowsActivityIndicator:NO];
    }
    else
    {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:NEARBY_PEERS_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)removeConnectedPeer:(GBAPeer *)peer
{
    NSInteger row = [self.connectedPeers indexOfObject:peer];
    
    if (row == NSNotFound)
    {
        return;
    }
    
    [self.connectedPeers removeObjectAtIndex:row];
    
    if ([self.connectedPeers count] == 0)
    {
        // Reload when section is empty to hide the header
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:CONNECTED_PEERS_SECTION] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:CONNECTED_PEERS_SECTION]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - GBABluetoothLinkManagerDelegate -

- (void)linkManager:(GBABluetoothLinkManager *)linkManager didDiscoverPeer:(GBAPeer *)peer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView beginUpdates];
        
        if ([self.connectedPeers containsObject:peer])
        {
            // Name change
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:CONNECTED_PEERS_SECTION] withRowAnimation:UITableViewRowAnimationFade];
        }
        else if ([self.nearbyPeers containsObject:peer])
        {
            // Name change
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:NEARBY_PEERS_SECTION] withRowAnimation:UITableViewRowAnimationFade];
        }
        else
        {
            [self addNearbyPeer:peer];
        }
        
        [self.tableView endUpdates];
    });
}

- (void)linkManager:(GBABluetoothLinkManager *)linkManager didConnectPeer:(GBAPeer *)peer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.tableView beginUpdates];
        
        [self removeNearbyPeer:peer];
        [self addConnectedPeer:peer];
        
        [self.tableView endUpdates];
        
    });
}

- (void)linkManager:(GBABluetoothLinkManager *)linkManager didFailToConnectPeer:(GBAPeer *)peer error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.tableView beginUpdates];
        
        [self removeConnectedPeer:peer];
        [self addNearbyPeer:peer];
        
        [self.tableView endUpdates];
        
    });
}

- (void)linkManager:(GBABluetoothLinkManager *)linkManager didDisconnectPeer:(GBAPeer *)peer error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.tableView beginUpdates];
        
        [self removeConnectedPeer:peer];
        [self addNearbyPeer:peer];
        
        [self.tableView endUpdates];
        
    });
}

#pragma mark - UITableViewDelegate - 

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != NEARBY_PEERS_SECTION)
    {
        return;
    }
    
    if (indexPath.row == 0 && [self.nearbyPeers count] == 0)
    {
        return;
    }
    
    [self connectPeer:self.nearbyPeers[indexPath.row]];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UITableViewDataSource -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.peerType == GBALinkPeerTypeClient)
    {
        if ([[GBABluetoothLinkManager sharedManager] isEnabled])
        {
            // We always have 5 sections to keep the rest of the logic much simpler, even though we use a slightly hacky workaround to make the second section hidden
            return 5;
        }
    }
    else
    {
        if ([[GBABluetoothLinkManager sharedManager] isEnabled])
        {
            return 4;
        }
    }
    
    return 3;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.peerType == GBALinkPeerTypeClient)
    {
        if (section == NEARBY_PEERS_SECTION)
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
    }
    
    return [super tableView:tableView viewForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == CONNECTED_PEERS_SECTION)
    {
        if (self.peerType == GBALinkPeerTypeClient && [self.connectedPeers count] == 0)
        {
            return 1;
        }
    }
    
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == CONNECTED_PEERS_SECTION)
    {
        if (self.peerType == GBALinkPeerTypeClient && [self.connectedPeers count] == 0)
        {
            return 1;
        }
    }
    
    return UITableViewAutomaticDimension;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == CONNECTED_PEERS_SECTION)
    {
        if (self.peerType == GBALinkPeerTypeClient || [self.connectedPeers count] > 0)
        {
            return [self.connectedPeers count];
        }
    }
    else if (section == NEARBY_PEERS_SECTION)
    {
        if ([self.nearbyPeers count] > 0)
        {
            return [self.nearbyPeers count];
        }
    }
    
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == CONNECTION_TYPE_SECTION)
    {
        return NSLocalizedString(@"Connection Type", @"");
    }
    if (section == PLAYER_NAME_SECTION)
    {
        return NSLocalizedString(@"Player Name", @"");
    }
    else if (section == CONNECTED_PEERS_SECTION)
    {
        if (self.peerType == GBALinkPeerTypeServer || [self.connectedPeers count] > 0)
        {
            return NSLocalizedString(@"Connected", @"");
        }
    }
    else if (section == NEARBY_PEERS_SECTION)
    {
        return NSLocalizedString(@"Nearby Hosts", @"");
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = nil;
    
    if (indexPath.section == WIRELESS_LINKING_SECTION)
    {
        identifier = @"SwitchCell";
    }
    else if (indexPath.section == PLAYER_NAME_SECTION)
    {
        identifier = @"PlayerNameCell";
    }
    else if (indexPath.section == CONNECTION_TYPE_SECTION)
    {
        identifier = @"SegmentedControlCell";
    }
    else
    {
        identifier = @"LinkCell";
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    
    if (indexPath.section == WIRELESS_LINKING_SECTION && cell.accessoryView == nil)
    {
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [[GBABluetoothLinkManager sharedManager] isEnabled];
        [switchView addTarget:self action:@selector(toggleLinking:) forControlEvents:UIControlEventValueChanged];
        self.linkEnabledSwitch = switchView;
        
        cell.accessoryView = self.linkEnabledSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        cell.textLabel.text = self.title;
    }
    
    if (indexPath.section == PLAYER_NAME_SECTION)
    {
        UITextField *textField = [[UITextField alloc] init];
        textField.delegate = self;
        textField.returnKeyType = UIReturnKeyDone;
        textField.translatesAutoresizingMaskIntoConstraints = NO;
        textField.text = [[UIDevice currentDevice] name];
        
        [cell.contentView addSubview:textField];
        
        [(GBASettingsTableViewCell *)cell pinView:textField toEdge:UIRectEdgeLeft | UIRectEdgeRight withSpacing:GBASettingsTableViewCellDefaultSpacing];
        [(GBASettingsTableViewCell *)cell pinView:textField toEdge:UIRectEdgeTop | UIRectEdgeBottom withSpacing:0];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (indexPath.section == CONNECTION_TYPE_SECTION && self.peerTypeSegmentedControl == nil)
    {
        UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"Host", @""), NSLocalizedString(@"Join", @"")]];
        segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
        
        if (self.peerType == GBALinkPeerTypeClient)
        {
            segmentedControl.selectedSegmentIndex = 1;
        }
        else
        {
            segmentedControl.selectedSegmentIndex = 0;
        }
        
        [segmentedControl addTarget:self action:@selector(switchPeerType:) forControlEvents:UIControlEventValueChanged];
        self.peerTypeSegmentedControl = segmentedControl;
        
        [cell.contentView addSubview:segmentedControl];
        [(GBASettingsTableViewCell *)cell pinView:segmentedControl toEdge:UIRectEdgeLeft | UIRectEdgeRight withSpacing:GBASettingsTableViewCellDefaultSpacing];
        
        [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:segmentedControl
                                                                     attribute:NSLayoutAttributeCenterY
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:cell.contentView
                                                                     attribute:NSLayoutAttributeCenterY
                                                                    multiplier:1.0
                                                                      constant:0.0]];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (indexPath.section == CONNECTED_PEERS_SECTION)
    {
        if ([self.connectedPeers count] == 0)
        {
            cell.textLabel.textColor = [UIColor grayColor];
            cell.textLabel.text = NSLocalizedString(@"Waiting…", @"");
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:YES];
        }
        else
        {
            GBAPeer *peer = self.connectedPeers[indexPath.row];
            cell.textLabel.text = peer.name;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            if (peer.state == GBAPeerStateConnected)
            {
                [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:NO];
            }
            else
            {
                [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:YES];
            }
        }
    }
    else if (indexPath.section == NEARBY_PEERS_SECTION)
    {
        if ([self.nearbyPeers count] == 0)
        {
            cell.textLabel.textColor = [UIColor grayColor];
            cell.textLabel.text = NSLocalizedString(@"Searching…", @"");
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:YES];
        }
        else
        {
            GBAPeer *peer = self.nearbyPeers[indexPath.row];
            cell.textLabel.text = peer.name;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    }
    
    return cell;
}

#pragma mark - UITextFieldDelegate -

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if ([[[GBABluetoothLinkManager sharedManager] name] isEqualToString:textField.text])
    {
        return;
    }
    
    [[GBABluetoothLinkManager sharedManager] setName:textField.text];
    
    if ([[GBABluetoothLinkManager sharedManager] isEnabled])
    {
        [[GBABluetoothLinkManager sharedManager] stopAdvertisingPeer];
        [[GBABluetoothLinkManager sharedManager] startAdvertisingPeer];
    }
}

#pragma mark - Getters/Setters

- (void)setPeerType:(GBALinkPeerType)peerType
{
    if (_peerType == peerType)
    {
        return;
    }
    
    _peerType = peerType;
    
    if (peerType == GBALinkPeerTypeServer)
    {
        self.peerTypeSegmentedControl.selectedSegmentIndex = 0;
    }
    else
    {
        self.peerTypeSegmentedControl.selectedSegmentIndex = 1;
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:peerType forKey:GBASettingsLinkPeerType];
    [[GBABluetoothLinkManager sharedManager] setPeerType:peerType];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (peerType == GBALinkPeerTypeClient)
        {
            if ([[GBABluetoothLinkManager sharedManager] isEnabled])
            {
                if ([self.tableView numberOfSections] < 4)
                {
                    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:NEARBY_PEERS_SECTION] withRowAnimation:UITableViewRowAnimationFade];
                }
            }
        }
        else
        {
            if ([self.tableView numberOfSections] > 3)
            {
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:NEARBY_PEERS_SECTION] withRowAnimation:UITableViewRowAnimationFade];
            }
        }
    });
}

@end
