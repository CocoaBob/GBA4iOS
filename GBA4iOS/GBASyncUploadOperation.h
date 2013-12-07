//
//  GBASyncUploadOperation.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBASyncFileOperation.h"

@interface GBASyncUploadOperation : GBASyncFileOperation

@property (assign, nonatomic) BOOL updatesDeviceUploadHistoryUponCompletion;

@end
