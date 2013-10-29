//
//  UIAlertView+RSTAdditions.h
//
//  Created by Riley Testut on 7/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//
//  Block-based alerts based on Simplifying UIAlertView with Blocks ( http://nscookbook.com/2013/04/ios-programming-recipe-22-simplify-uialertview-with-blocks/ )
//  Error-based alerts based on Showing Meaningful Alerts ( http://blog.mugunthkumar.com/coding/objective-c-showing-meaningful-error-alerts/ )
//

#import <UIKit/UIKit.h>

typedef void(^RSTAlertViewSelectionHandler)(UIAlertView *alertView, NSInteger buttonIndex);

@interface UIAlertView (RSTAdditions)

// Creates alert displaying human-readable information from the error. cancelButtonTitle defaults to NSLocalizedString(@"OK", @"")
- (instancetype)initWithError:(NSError *)error;
- (instancetype)initWithError:(NSError *)error cancelButtonTitle:(NSString *)cancelButtonTitle;
- (instancetype)initWithError:(NSError *)error cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

// Shows alert, and calls selectionHandler when user dismisses alert. If setting a delegate, be careful not to implement the same selection logic in both selectionHandler and alertView:clickedButtonAtIndex:
- (void)showWithSelectionHandler:(RSTAlertViewSelectionHandler)selectionHandler;

@end
