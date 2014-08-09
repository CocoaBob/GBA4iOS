//
//  KeyboardViewController.m
//  GBA4Keyboard
//
//  Created by Riley Testut on 6/23/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAKeyboardViewController.h"

#import "GBAControllerInput.h"
#import "GBAExternalController.h"
#import "GBAControllerView.h"
#import "GBAControllerSkin.h"

@interface GBAKeyboardViewController () <GBAControllerInputDelegate>

@end

@implementation GBAKeyboardViewController

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
    
    [self importDefaultGBASkin];
    
    GBAControllerSkin *controllerSkin = [GBAControllerSkin defaultControllerSkinForSkinType:GBAControllerSkinTypeGBA];
    
    GBAControllerView *controllerView = [[GBAControllerView alloc] init];
    controllerView.controllerSkin = controllerSkin;
    controllerView.delegate = self;
    controllerView.orientation = GBAControllerSkinOrientationPortrait;
    controllerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.inputView addSubview:controllerView];
        
    NSArray *horizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[controllerView]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(controllerView)];
    NSArray *verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[controllerView]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(controllerView)];
    [self.inputView addConstraints:horizontalConstraints];
    [self.inputView addConstraints:verticalConstraints];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated
}

#pragma mark - Controller Skin

- (void)importDefaultGBASkin
{
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"Default_New" ofType:@"gbaskin"];
    
    NSString *destinationPath = [[self GBASkinsDirectory] stringByAppendingPathComponent:GBADefaultSkinIdentifier];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath])
    {
        //return;
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
    
    [GBAControllerSkin extractSkinAtPathToSkinsDirectory:filepath];
}

- (NSString *)skinsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return [documentsDirectory stringByAppendingPathComponent:@"Skins"];
}

- (NSString *)GBASkinsDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager]; // Thread-safe as of iOS 5 WOOHOO
    NSString *gbaSkinsDirectory = [[self skinsDirectory] stringByAppendingPathComponent:@"GBA"];
    
    NSError *error = nil;
    if (![fileManager createDirectoryAtPath:gbaSkinsDirectory withIntermediateDirectories:YES attributes:nil error:&error])
    {
        NSLog(@"%@", error);
    }
    
    return gbaSkinsDirectory;
}

#pragma mark - GBAControllerInputDelegate

- (void)controllerInput:(id)controllerInput didPressButtons:(NSSet *)buttons
{
    if ([buttons containsObject:@(GBAControllerButtonA)])
    {
        [self.textDocumentProxy insertText:@"A"];
    }
    else if ([buttons containsObject:@(GBAControllerButtonB)])
    {
        [self.textDocumentProxy insertText:@"B"];
    }
    else if ([buttons containsObject:@(GBAControllerButtonL)])
    {
        [self.textDocumentProxy insertText:@"L"];
    }
    else if ([buttons containsObject:@(GBAControllerButtonR)])
    {
        [self.textDocumentProxy insertText:@"R"];
    }
    else if ([buttons containsObject:@(GBAControllerButtonSelect)])
    {
        [self.textDocumentProxy insertText:@"This keyboard is awesome! "];
    }
    else if ([buttons containsObject:@(GBAControllerButtonStart)])
    {
        [self.textDocumentProxy insertText:@"GBA4iOS is the best app ever! "];
    }
    else if ([buttons containsObject:@(GBAControllerButtonLeft)])
    {
        [self.textDocumentProxy deleteBackward];
    }
    else if ([buttons containsObject:@(GBAControllerButtonRight)])
    {
        [self.textDocumentProxy insertText:@" "];
    }
    else if ([buttons containsObject:@(GBAControllerButtonUp)])
    {
        [self.textDocumentProxy adjustTextPositionByCharacterOffset:1];
    }
    else if ([buttons containsObject:@(GBAControllerButtonDown)])
    {
        [self.textDocumentProxy adjustTextPositionByCharacterOffset:-1];
    }
    
    [[UIDevice currentDevice] playInputClick];
}

- (void)controllerInput:(id)controllerInput didReleaseButtons:(NSSet *)buttons
{
    
}

- (void)controllerInputDidPressMenuButton:(id)controllerInput
{
    [self advanceToNextInputMode];
}

#pragma mark - Keyboard

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
    
}

@end
