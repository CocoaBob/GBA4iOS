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

- (void)setDownloaded:(BOOL)downloaded
{
    if (_downloaded == downloaded)
    {
        return;
    }
    
    _downloaded = downloaded;
    
    if (downloaded)
    {
        self.textLabel.text = NSLocalizedString(@"Start Event", @"");
    }
    else
    {
        self.textLabel.text = NSLocalizedString(@"Download", @"");
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
