//
//  GBAEventDistributionTableViewCell.h
//  GBA4iOS
//
//  Created by Riley Testut on 1/5/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GBAEventDownloadState)
{
    GBAEventDownloadStateNotDownloaded,
    GBAEventDownloadStateDownloading,
    GBAEventDownloadStateDownloaded
};

@interface GBAEventDistributionTableViewCell : UITableViewCell

@property (assign, nonatomic) GBAEventDownloadState downloadState;
@property (copy, nonatomic) NSDate *endDate;

@end
