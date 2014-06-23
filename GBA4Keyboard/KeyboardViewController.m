//
//  KeyboardViewController.m
//  GBA4Keyboard
//
//  Created by Riley Testut on 6/23/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "KeyboardViewController.h"

#import "GBAControllerInput.h"
#import "GBAExternalController.h"
#import "GBAControllerView.h"
#import "GBAControllerSkin.h"

@interface KeyboardViewController ()

@property (strong, nonatomic) UIButton *nextKeyboardButton;

@end

@implementation KeyboardViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // Perform custom initialization work here
    }
    return self;
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    // Add custom view sizing constraints here
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Perform custom UI setup here
    self.nextKeyboardButton = [UIButton buttonWithType:UIButtonTypeSystem];
    
    [self.nextKeyboardButton setTitle:NSLocalizedString(@"GBA4iOS Keyboard", @"Title for 'Next Keyboard' button") forState:UIControlStateNormal];
    [self.nextKeyboardButton sizeToFit];
    self.nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.nextKeyboardButton addTarget:self action:@selector(advanceToNextInputMode) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.nextKeyboardButton];
    
    NSLayoutConstraint *nextKeyboardButtonLeftSideConstraint = [NSLayoutConstraint constraintWithItem:self.nextKeyboardButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
    NSLayoutConstraint *nextKeyboardButtonBottomConstraint = [NSLayoutConstraint constraintWithItem:self.nextKeyboardButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
    [self.view addConstraints:@[nextKeyboardButtonLeftSideConstraint, nextKeyboardButtonBottomConstraint]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated
}

- (void)textWillChange:(id<UITextInput>)textInput
{
    // The app is about to change the document's contents. Perform any preparation here.
}

- (void)textDidChange:(id<UITextInput>)textInput
{
    // The app has just changed the document's contents, the document context has been updated.
    
    UIColor *textColor = nil;
    if (self.textDocumentProxy.keyboardAppearance == UIKeyboardAppearanceDark)
    {
        textColor = [UIColor whiteColor];
    }
    else
    {
        textColor = [UIColor blackColor];
    }
    
    [self.nextKeyboardButton setTitleColor:textColor forState:UIControlStateNormal];
}

@end
