//
//  UIActionSheet+RSTAdditions.m
//
//  Created by Riley Testut on 8/4/13.
//
//  Block-based action sheets based on Simplifying UIAlertView with Blocks ( http://nscookbook.com/2013/04/ios-programming-recipe-22-simplify-uialertview-with-blocks/ )
//

#import "UIActionSheet+RSTAdditions.h"

#import <objc/runtime.h>

#pragma mark - Private Category

@interface UIActionSheet (RSTAdditionsPrivate)

@property (copy, nonatomic) RSTActionSheetSelectionHandler selectionHandler;
@property (assign, nonatomic) id<UIActionSheetDelegate> proxyDelegate;

@end

@implementation UIActionSheet (RSTAdditionsPrivate)
@dynamic selectionHandler;
@dynamic proxyDelegate;

- (void)setSelectionHandler:(RSTActionSheetSelectionHandler)selectionHandler
{
    objc_setAssociatedObject(self, @selector(selectionHandler), selectionHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (RSTActionSheetSelectionHandler)selectionHandler
{
    return objc_getAssociatedObject(self, @selector(selectionHandler));
}

- (void)setProxyDelegate:(id<UIActionSheetDelegate>)proxyDelegate
{
    objc_setAssociatedObject(self, @selector(proxyDelegate), proxyDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<UIActionSheetDelegate>)proxyDelegate
{
    return objc_getAssociatedObject(self, @selector(proxyDelegate));
}

@end

@implementation UIActionSheet (RSTAdditions)

#pragma mark - Designated Initializer

- (instancetype)initWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    self = [self initWithTitle:title delegate:nil cancelButtonTitle:nil destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:nil];
    
    NSString *buttonTitle = nil;
    va_list argumentList;
    
    if (otherButtonTitles)
    {
        [self addButtonWithTitle:otherButtonTitles];
        
        va_start(argumentList, otherButtonTitles);
        
        while ((buttonTitle = va_arg(argumentList, NSString *)))
        {
            [self addButtonWithTitle:buttonTitle];
        }
        
        va_end(argumentList);
    }
    
    NSInteger index = [self addButtonWithTitle:cancelButtonTitle];
    [self setCancelButtonIndex:index];
    
    return self;
}


#pragma mark - Show Action Sheet

- (void)showFromTabBar:(UITabBar *)view selectionHandler:(RSTActionSheetSelectionHandler)selectionHandler
{
    self.proxyDelegate = self.delegate;
    self.delegate = (id<UIActionSheetDelegate>)[self class];
    self.selectionHandler = selectionHandler;
    
    [self showFromTabBar:view];
}

- (void)showFromToolbar:(UIToolbar *)view selectionHandler:(RSTActionSheetSelectionHandler)completionHandler
{
    self.proxyDelegate = self.delegate;
    self.delegate = (id<UIActionSheetDelegate>)[self class];
    self.selectionHandler = completionHandler;
    
    [self showFromToolbar:view];
}

- (void)showInView:(UIView *)view selectionHandler:(RSTActionSheetSelectionHandler)completionHandler
{
    self.proxyDelegate = self.delegate;
    self.delegate = (id<UIActionSheetDelegate>)[self class];
    self.selectionHandler = completionHandler;
    
    [self showInView:view];
}

- (void)showFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated selectionHandler:(RSTActionSheetSelectionHandler)completionHandler
{
    self.proxyDelegate = self.delegate;
    self.delegate = (id<UIActionSheetDelegate>)[self class];
    self.selectionHandler = completionHandler;
    
    [self showFromBarButtonItem:item animated:animated];
}

- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated selectionHandler:(RSTActionSheetSelectionHandler)completionHandler
{
    self.proxyDelegate = self.delegate;
    self.delegate = (id<UIActionSheetDelegate>)[self class];
    self.selectionHandler = completionHandler;
    
    [self showFromRect:rect inView:view animated:animated];
}

#pragma mark - Delegate Methods

+ (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    actionSheet.selectionHandler(actionSheet, buttonIndex);
    
    if ([actionSheet.proxyDelegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)])
    {
        [actionSheet.proxyDelegate actionSheet:actionSheet clickedButtonAtIndex:buttonIndex];
    }
}

+ (void)actionSheetCancel:(UIActionSheet *)actionSheet
{
    if ([actionSheet.proxyDelegate respondsToSelector:@selector(actionSheetCancel:)])
    {
        [actionSheet.proxyDelegate actionSheetCancel:actionSheet];
    }
}

+ (void)willPresentActionSheet:(UIActionSheet *)actionSheet
{
    if ([actionSheet.proxyDelegate respondsToSelector:@selector(willPresentActionSheet:)])
    {
        [actionSheet.proxyDelegate willPresentActionSheet:actionSheet];
    }
}

+ (void)didPresentActionSheet:(UIActionSheet *)actionSheet
{
    if ([actionSheet.proxyDelegate respondsToSelector:@selector(didPresentActionSheet:)])
    {
        [actionSheet.proxyDelegate didPresentActionSheet:actionSheet];
    }
}

+ (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([actionSheet.proxyDelegate respondsToSelector:@selector(actionSheet:willDismissWithButtonIndex:)])
    {
        [actionSheet.proxyDelegate actionSheet:actionSheet willDismissWithButtonIndex:buttonIndex];
    }
}

+ (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([actionSheet.proxyDelegate respondsToSelector:@selector(actionSheet:didDismissWithButtonIndex:)])
    {
        [actionSheet.proxyDelegate actionSheet:actionSheet didDismissWithButtonIndex:buttonIndex];
    }
}

@end
