//
//  GBAEventDistributionTableViewCell.h
//  GBA4iOS
//
//  Created by Riley Testut on 1/5/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GBAEventDistributionTableViewCell : UITableViewCell

@property (assign, nonatomic) BOOL downloaded;
@property (copy, nonatomic) NSDate *endDate;

@end
