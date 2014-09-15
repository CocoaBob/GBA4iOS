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

#import "GBABluetoothLinkManager.h"
#import "GBAPeer.h"

BOOL transientLinkEnabled = NO;

@interface GBABluetoothLinkViewController () <GBABluetoothLinkManagerDelegate>

@property (strong, nonatomic) UISwitch *linkEnabledSwitch;
@property (strong, nonatomic) UISegmentedControl *peerTypeSegmentedControl;

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
        
        _peerType = GBALinkPeerTypeClient;
        
        [[GBABluetoothLinkManager sharedManager] setPeerType:_peerType];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SwitchCell"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"SegmentedControlCell"];
    [self.tableView registerClass:[GBALinkViewControllerTableViewCell class] forCellReuseIdentifier:@"LinkCell"];
    [self.tableView registerClass:[GBALinkNearbyPeersHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"NearbyPeersHeader"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[GBABluetoothLinkManager sharedManager] setDelegate:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[GBABluetoothLinkManager sharedManager] setDelegate:nil];
    
    transientLinkEnabled = NO;
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
    transientLinkEnabled = YES;
    
    [self.linkEnabledSwitch setOn:YES animated:YES];
    
    NSRange range = NSMakeRange(0, 0);
    
    if (self.peerType == GBALinkPeerTypeServer)
    {
        range = NSMakeRange(2, 1);
        [[GBABluetoothLinkManager sharedManager] startAdvertisingPeer];
    }
    else
    {
        range = NSMakeRange(2, 2);
        [[GBABluetoothLinkManager sharedManager] startScanningForPeers];
    }
    
    if ([self.tableView numberOfSections] == 2)
    {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndexesInRange:range] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)disableLinking
{
    transientLinkEnabled = NO;
    
    [self.linkEnabledSwitch setOn:NO animated:YES];
    
    NSRange range = NSMakeRange(0, 0);
    
    if (self.peerType == GBALinkPeerTypeServer)
    {
        range = NSMakeRange(2, 1);
        [[GBABluetoothLinkManager sharedManager] stopAdvertisingPeer];
    }
    else
    {
        range = NSMakeRange(2, 2);
        [[GBABluetoothLinkManager sharedManager] stopScanningForPeers];
    }
    
    if ([self.tableView numberOfSections] > 2)
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
    [self addNearbyPeer:peer];
    
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
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:3]] withRowAnimation:UITableViewRowAnimationFade];
        
        GBALinkNearbyPeersHeaderFooterView *headerFooterView = (GBALinkNearbyPeersHeaderFooterView *)[self.tableView headerViewForSection:3];
        [headerFooterView setShowsActivityIndicator:YES];
    }
    else
    {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:([self.nearbyPeers count] - 1) inSection:3]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)addConnectedPeer:(GBAPeer *)peer
{
    NSInteger row = [self.connectedPeers indexOfObject:peer];
    
    if (row != NSNotFound)
    {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:2]] withRowAnimation:UITableViewRowAnimationFade];
        return;
    }
    
    [self.connectedPeers addObject:peer];
    
    if ([self.connectedPeers count] == 1)
    {
        // Reload when adding first row to show the header
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:([self.connectedPeers count] - 1) inSection:2]] withRowAnimation:UITableViewRowAnimationFade];
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
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:3]] withRowAnimation:UITableViewRowAnimationFade];
        
        GBALinkNearbyPeersHeaderFooterView *headerFooterView = (GBALinkNearbyPeersHeaderFooterView *)[self.tableView headerViewForSection:3];
        [headerFooterView setShowsActivityIndicator:NO];
    }
    else
    {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:3]] withRowAnimation:UITableViewRowAnimationFade];
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
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:2]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - GBABluetoothLinkManagerDelegate -

- (void)linkManager:(GBABluetoothLinkManager *)linkManager didDiscoverPeer:(GBAPeer *)peer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView beginUpdates];
        [self addNearbyPeer:peer];
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (transientLinkEnabled)
    {
        if (self.peerType == GBALinkPeerTypeServer)
        {
            return 3;
        }
        else
        {
            // We always have 4 sections to keep the rest of the logic much simpler, even though we use a slightly hacky workaround to make the second section hidden
            return 4;
        }
    }
    
    return 2;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 3)
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
    if (section == 2)
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
    if (section == 2)
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
    if (section == 2)
    {
        return [self.connectedPeers count];
    }
    else if (section == 3)
    {
        if ([self.nearbyPeers count] > 0)
        {
            return [self.nearbyPeers count];
        }
        
        return 1;
    }
    
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 2)
    {
        if ([self.connectedPeers count] > 0)
        {
            return NSLocalizedString(@"Connected", @"");
        }
    }
    else if (section == 3)
    {
        return NSLocalizedString(@"Nearby", @"");
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
    else if (indexPath.section == 1)
    {
        identifier = @"SegmentedControlCell";
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
            switchView.on = transientLinkEnabled;
            [switchView addTarget:self action:@selector(toggleLinking:) forControlEvents:UIControlEventValueChanged];
            switchView;
        });
        cell.accessoryView = self.linkEnabledSwitch;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        cell.textLabel.text = self.title;
    }
    
    if (indexPath.section == 1 && self.peerTypeSegmentedControl == nil)
    {
        UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"Server", @""), NSLocalizedString(@"Client", @"")]];
        segmentedControl.selectedSegmentIndex = 1;
        [segmentedControl addTarget:self action:@selector(switchPeerType:) forControlEvents:UIControlEventValueChanged];
        self.peerTypeSegmentedControl = segmentedControl;
        
        cell.accessoryView = segmentedControl;
        
        CGFloat rightEdgeSpacing = 15;//CGRectGetMaxX(segmentedControl.frame) - CGRectGetWidth(cell.bounds);
        segmentedControl.bounds = CGRectMake(0, 0, CGRectGetWidth(cell.bounds) - rightEdgeSpacing * 2.0f, CGRectGetHeight(segmentedControl.bounds));
        
        segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (indexPath.section == 2)
    {
        GBAPeer *peer = self.connectedPeers[indexPath.row];
        cell.textLabel.text = peer.name;
        
        if (peer.state == GBAPeerStateConnected)
        {
            [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:NO];
        }
        else
        {
            [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:YES];
        }
    }
    else if (indexPath.section == 3)
    {
        if ([self.nearbyPeers count] == 0)
        {
            cell.textLabel.textColor = [UIColor grayColor];
            cell.textLabel.text = NSLocalizedString(@"Searching…", @"");
            
            [(GBALinkViewControllerTableViewCell *)cell setShowsActivityIndicator:YES];
        }
        else
        {
            GBAPeer *peer = self.nearbyPeers[indexPath.row];
            cell.textLabel.text = peer.name;
        }
    }
    
    return cell;
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
    
    [[GBABluetoothLinkManager sharedManager] setPeerType:peerType];
}

@end
