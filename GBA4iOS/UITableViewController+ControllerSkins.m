//
//  UITableViewController+ControllerSkins.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/7/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "UITableViewController+ControllerSkins.h"

@implementation UITableViewController (ControllerSkins)

- (void)updateRowHeightsForDisplayingControllerSkinsWithType:(GBAControllerSkinType)type
{
    CGFloat rowHeight = 150;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        GBAControllerSkin *controllerSkin = [GBAControllerSkin defaultControllerSkinForSkinType:type];
        UIImage *image = [controllerSkin imageForOrientation:GBAControllerSkinOrientationPortrait];
        
        CGFloat scale = CGRectGetWidth(self.view.bounds) / image.size.width;
        
        rowHeight = image.size.height * scale;
    }
    else
    {
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        if ([[UIScreen mainScreen] respondsToSelector:@selector(fixedCoordinateSpace)])
        {
            screenBounds = [[UIScreen mainScreen].fixedCoordinateSpace convertRect:[UIScreen mainScreen].bounds fromCoordinateSpace:[UIScreen mainScreen].coordinateSpace];
        }
        
        CGFloat shortestSide = fminf(CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
        
        CGFloat landscapeAspectRatio = CGRectGetWidth(screenBounds) / CGRectGetHeight(screenBounds);
        rowHeight = shortestSide * landscapeAspectRatio;
    }
    
    self.tableView.rowHeight = rowHeight;
    
    [self.tableView reloadData];
}

@end
