//
//  GBASyncOperation.h
//  GBA4iOS
//
//  Created by Riley Testut on 12/4/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>

#import "RSTToastView.h"

@class GBASyncOperation;

@protocol GBASyncOperationDelegate <NSObject>

@optional
- (BOOL)syncOperation:(GBASyncOperation *)syncOperation shouldShowToastView:(RSTToastView *)toastView;

@end

@interface GBASyncOperation : NSOperation

@property (readonly, atomic) BOOL isExecuting;
@property (readonly, atomic) BOOL isFinished;

@property (weak, nonatomic) id<GBASyncOperationDelegate> delegate;
@property (strong, nonatomic) RSTToastView *toastView;

- (void)finish;

@end
