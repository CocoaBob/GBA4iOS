//
//  GBAEventDistributionTableViewCell.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/5/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAEventDistributionTableViewCell.h"
#import "NSDate+Comparing.h"

@interface GBAEventDistributionTableViewCell ()

@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@end

@implementation GBAEventDistributionTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.textLabel.text = NSLocalizedString(@"Download", @"");
        self.textLabel.textColor = GBA4iOS_PURPLE_COLOR;
        
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [_dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setDownloadState:(GBAEventDownloadState)downloadState
{
    if (_downloadState == downloadState)
    {
        return;
    }
    
    _downloadState = downloadState;
    
    switch (downloadState)
    {
        case GBAEventDownloadStateDownloaded:
            self.textLabel.text = NSLocalizedString(@"View Details", @"");
            break;
            
        case GBAEventDownloadStateDownloading:
            self.textLabel.text = NSLocalizedString(@"Downloading…", @"");
            break;
            
        case GBAEventDownloadStateNotDownloaded:
            self.textLabel.text = NSLocalizedString(@"Download", @"");
            break;
    }
}

- (void)setEndDate:(NSDate *)endDate
{
    if ([_endDate isEqualToDate:endDate])
    {
        return;
    }
    
    _endDate = endDate;
    
    NSString *dateString = nil;
    
    NSInteger daysUntilEndDate = [[NSDate date] daysUntilDate:endDate];
    
    if (daysUntilEndDate < 0)
    {
        self.detailTextLabel.text = nil;
        return;
    }
    
    if (daysUntilEndDate <= 1)
    {
        self.detailTextLabel.textColor = [UIColor redColor];
        
        if (daysUntilEndDate == 0)
        {
            dateString = NSLocalizedString(@"Today", @"");
        }
        else
        {
            dateString = NSLocalizedString(@"Tomorrow", @"");
        }
        
    }
    else
    {
        self.detailTextLabel.textColor = [UIColor grayColor];
        dateString = [self.dateFormatter stringFromDate:endDate];
    }
    
    self.detailTextLabel.text = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Ends", @"Date ends"), dateString];
}

@end
