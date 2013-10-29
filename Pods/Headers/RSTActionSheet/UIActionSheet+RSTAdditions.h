//
//  UIActionSheet+RSTAdditions.h
//
//  Created by Riley Testut on 8/4/13.
//
//  Block-based action sheets based on Simplifying UIAlertView with Blocks ( http://nscookbook.com/2013/04/ios-programming-recipe-22-simplify-uialertview-with-blocks/ )
//

#import <UIKit/UIKit.h>

typedef void(^RSTActionSheetSelectionHandler)(UIActionSheet *actionSheet, NSInteger buttonIndex);

@interface UIActionSheet (RSTAdditions)

// Shows action sheet, and calls completionHandler when user dismisses action sheet. If setting a delegate, be careful not to implement the same selection logic in both selectionHandler and actionSheet:clickedButtonAtIndex:.
- (void)showFromTabBar:(UITabBar *)view selectionHandler:(RSTActionSheetSelectionHandler)selectionHandler;
- (void)showFromToolbar:(UIToolbar *)view selectionHandler:(RSTActionSheetSelectionHandler)selectionHandler;
- (void)showInView:(UIView *)view selectionHandler:(RSTActionSheetSelectionHandler)selectionHandler;
- (void)showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated selectionHandler:(RSTActionSheetSelectionHandler)selectionHandler;
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated selectionHandler:(RSTActionSheetSelectionHandler)selectionHandler;

@end
