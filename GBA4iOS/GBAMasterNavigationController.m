//
//  GBAMasterNavigationController.m
//  GBA4iOS
//
//  Created by Riley Testut on 10/1/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAMasterNavigationController.h"

static void *GBAMasterNavigationControllerContext = &GBAMasterNavigationControllerContext;

@interface GBAMasterNavigationController ()

@end

@implementation GBAMasterNavigationController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UISplitViewController *splitViewController = [UISplitViewController new];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && [splitViewController respondsToSelector:@selector(primaryColumnWidth)])
    {
        [self.view addObserver:self forKeyPath:@"frame" options:0 context:GBAMasterNavigationControllerContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != GBAMasterNavigationControllerContext)
    {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    rst_dispatch_sync_on_main_thread(^{
        
        [self.view removeObserver:self forKeyPath:@"frame"];
        
        CGRect bounds = self.view.frame;
        bounds.size.width = MIN(self.splitViewController.primaryColumnWidth, CGRectGetWidth(bounds));
        self.view.bounds = bounds;
        
        CGRect frame = self.view.frame;
        frame.origin = CGPointZero;
        self.view.frame = frame;
        
        [self.view layoutIfNeeded];
        
        [self.view addObserver:self forKeyPath:@"frame" options:0 context:GBAMasterNavigationControllerContext];
        
    });
    
}

@end
