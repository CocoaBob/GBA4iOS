//
//  UIAlertView+RSTAdditions.m
//
//  Created by Riley Testut on 7/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//
//  Block-based alerts based on Simplifying UIAlertView with Blocks ( http://nscookbook.com/2013/04/ios-programming-recipe-22-simplify-uialertview-with-blocks/ )
//  Error-based alerts based on Showing Meaningful Alerts ( http://blog.mugunthkumar.com/coding/objective-c-showing-meaningful-error-alerts/ )
//

#import "UIAlertView+RSTAdditions.h"

#import <objc/runtime.h>

#pragma mark - Private Category

@interface UIAlertView (RSTAdditionsPrivate)

@property (copy, nonatomic) RSTAlertViewSelectionHandler selectionHandler;
@property (assign, nonatomic) id<UIAlertViewDelegate> proxyDelegate;

@end

@implementation UIAlertView (RSTAdditionsPrivate)
@dynamic selectionHandler;
@dynamic proxyDelegate;

- (void)setSelectionHandler:(RSTAlertViewSelectionHandler)selectionHandler
{
    objc_setAssociatedObject(self, @selector(selectionHandler), selectionHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (RSTAlertViewSelectionHandler)selectionHandler
{
    return objc_getAssociatedObject(self, @selector(selectionHandler));
}

- (void)setProxyDelegate:(id<UIAlertViewDelegate>)proxyDelegate
{
    objc_setAssociatedObject(self, @selector(proxyDelegate), proxyDelegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<UIAlertViewDelegate>)proxyDelegate
{
    return objc_getAssociatedObject(self, @selector(proxyDelegate));
}

@end

#pragma mark - Public Category

@implementation UIAlertView (RSTAdditions)

#pragma mark - Designated Initializer

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    self = [self initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
    
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
    
    return self;
}

#pragma mark - Error Alerts

- (instancetype)initWithError:(NSError *)error
{
    return [self initWithError:error cancelButtonTitle:NSLocalizedString(@"OK", @"RSTAlertView Dismiss Button Title")];
}

- (instancetype)initWithError:(NSError *)error cancelButtonTitle:(NSString *)cancelButtonTitle
{
    return [self initWithError:error cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
}

- (instancetype)initWithError:(NSError *)error cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    self = [self initWithTitle:[error localizedDescription] message:[error localizedRecoverySuggestion] delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
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
    
    return self;
}

#pragma mark - Show Alert

- (void)showWithSelectionHandler:(RSTAlertViewSelectionHandler)selectionHandler
{
    self.proxyDelegate = self.delegate;
    self.delegate = [self class];
    self.selectionHandler = selectionHandler;
    
    [self show];
}

#pragma mark - Delegate Methods

+ (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    alertView.selectionHandler(alertView, buttonIndex);
    
    if ([alertView.proxyDelegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)])
    {
        [alertView.proxyDelegate alertView:alertView clickedButtonAtIndex:buttonIndex];
    }
}

+ (void)alertViewCancel:(UIAlertView *)alertView
{
    if ([alertView.proxyDelegate respondsToSelector:@selector(alertViewCancel:)])
    {
        [alertView.proxyDelegate alertViewCancel:alertView];
    }
}

+ (void)willPresentAlertView:(UIAlertView *)alertView
{
    if ([alertView.proxyDelegate respondsToSelector:@selector(willPresentAlertView:)])
    {
        [alertView.proxyDelegate willPresentAlertView:alertView];
    }
}

+ (void)didPresentAlertView:(UIAlertView *)alertView
{
    if ([alertView.proxyDelegate respondsToSelector:@selector(didPresentAlertView:)])
    {
        [alertView.proxyDelegate didPresentAlertView:alertView];
    }
}

+ (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([alertView.proxyDelegate respondsToSelector:@selector(alertView:willDismissWithButtonIndex:)])
    {
        [alertView.proxyDelegate alertView:alertView willDismissWithButtonIndex:buttonIndex];
    }
}

+ (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([alertView.proxyDelegate respondsToSelector:@selector(alertView:didDismissWithButtonIndex:)])
    {
        [alertView.proxyDelegate alertView:alertView didDismissWithButtonIndex:buttonIndex];
    }
}

+ (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    if ([alertView.proxyDelegate respondsToSelector:@selector(alertViewShouldEnableFirstOtherButton:)])
    {
        return [alertView.proxyDelegate alertViewShouldEnableFirstOtherButton:alertView];
    }
    
    return YES;
}

@end
