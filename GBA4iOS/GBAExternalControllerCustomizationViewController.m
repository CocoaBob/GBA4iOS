//
//  GBAExternalControllerCustomizationViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAExternalControllerCustomizationViewController.h"
#import "GBAControllerInput.h"
#import "GBAExternalController_Private.h"
#import "GBASettingsViewController.h"

#import "SMCalloutView.h"

SMCalloutAnimation SMCalloutAnimationNone = 18;

@interface GBAExternalControllerCustomizationViewController () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (weak, nonatomic) IBOutlet UIPickerView *pickerView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topPickerLayoutConstraint;

@property (weak, nonatomic) IBOutlet UIView *buttonLayoutView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topButtonLayoutViewLayoutConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomButtonLayoutViewLayoutConstraint;

@property (strong, nonatomic) SMCalloutView *calloutViewButtonA;
@property (strong, nonatomic) SMCalloutView *calloutViewButtonB;
@property (strong, nonatomic) SMCalloutView *calloutViewButtonX;
@property (strong, nonatomic) SMCalloutView *calloutViewButtonY;
@property (strong, nonatomic) SMCalloutView *calloutViewButtonL2;
@property (strong, nonatomic) SMCalloutView *calloutViewButtonR2;

@property (weak, nonatomic) IBOutlet UIButton *buttonA;
@property (weak, nonatomic) IBOutlet UIButton *buttonB;
@property (weak, nonatomic) IBOutlet UIButton *buttonX;
@property (weak, nonatomic) IBOutlet UIButton *buttonY;
@property (weak, nonatomic) IBOutlet UIButton *buttonL2;
@property (weak, nonatomic) IBOutlet UIButton *buttonR2;
@property (weak, nonatomic) UIButton *currentlySelectedButton;

@property (weak, nonatomic) IBOutlet UIView *leftHalfView;
@property (weak, nonatomic) IBOutlet UIView *rightHalfView;

@end

@implementation GBAExternalControllerCustomizationViewController

- (id)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"externalControllerCustomizationViewController"];
    if (self)
    {
        _calloutViewButtonA = [SMCalloutView new];
        _calloutViewButtonB = [SMCalloutView new];
        _calloutViewButtonX = [SMCalloutView new];
        _calloutViewButtonY = [SMCalloutView new];
        _calloutViewButtonL2 = [SMCalloutView new];
        _calloutViewButtonR2 = [SMCalloutView new];
        
        _calloutViewButtonA.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputA]];
        _calloutViewButtonB.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputB]];
        _calloutViewButtonX.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputX]];
        _calloutViewButtonY.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputY]];
        _calloutViewButtonL2.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputLeftTrigger]];
        _calloutViewButtonR2.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputRightTrigger]];
        
        // Presents warnings in Interface Builder because apparently they're deprecated
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
        self.buttonLayoutView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self presentCalloutViewsExceptCalloutView:nil withAnimation:SMCalloutAnimationBounce];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Button Mapping

- (void)setControllerButton:(GBAControllerButton)controllerButton forExternalControllerButtonInput:(GBAExternalControllerButtonInput)controllerButtonInput
{
    NSMutableDictionary *buttons = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:GBASettingsExternalControllerButtonsKey] mutableCopy];
    buttons[[GBAExternalController stringForButtonInput:controllerButtonInput]] = @(controllerButton);
    [[NSUserDefaults standardUserDefaults] setObject:buttons forKey:GBASettingsExternalControllerButtonsKey];
}

#pragma mark - Callout Views

- (void)presentCalloutViewsExceptCalloutView:(SMCalloutView *)exceptionCalloutView withAnimation:(SMCalloutAnimation)animation
{
    NSArray *calloutViews = @[self.calloutViewButtonA, self.calloutViewButtonB, self.calloutViewButtonX, self.calloutViewButtonY, self.calloutViewButtonL2, self.calloutViewButtonR2];
    
    for (SMCalloutView *calloutView in calloutViews)
    {
        if (calloutView != exceptionCalloutView)
        {
            [self presentCalloutView:calloutView withAnimation:animation];
        }
    }
}

- (void)presentCalloutView:(SMCalloutView *)calloutView withAnimation:(SMCalloutAnimation)animation
{
    BOOL animated = YES;
    
    if (animation == SMCalloutAnimationNone)
    {
        animated = NO;
    }
    else
    {
        [calloutView setPresentAnimation:animation];
    }
    
    if (self.calloutViewButtonA == calloutView)
    {
        [self.calloutViewButtonA presentCalloutFromRect:self.buttonA.frame inView:self.buttonLayoutView constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonB == calloutView)
    {
        [self.calloutViewButtonB presentCalloutFromRect:self.buttonB.frame inView:self.buttonLayoutView constrainedToView:self.rightHalfView permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonX == calloutView)
    {
        [self.calloutViewButtonX presentCalloutFromRect:self.buttonX.frame inView:self.buttonLayoutView constrainedToView:self.leftHalfView permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonY == calloutView)
    {
        [self.calloutViewButtonY presentCalloutFromRect:self.buttonY.frame inView:self.buttonLayoutView constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonL2 == calloutView)
    {
        [self.calloutViewButtonL2 presentCalloutFromRect:self.buttonL2.frame inView:self.buttonLayoutView constrainedToView:self.leftHalfView permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonR2 == calloutView)
    {
        [self.calloutViewButtonR2 presentCalloutFromRect:self.buttonR2.frame inView:self.buttonLayoutView constrainedToView:self.rightHalfView permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
}

- (void)dismissAllCalloutViewsExceptCalloutView:(SMCalloutView *)exceptionCalloutView
{
    NSArray *calloutViews = @[self.calloutViewButtonA, self.calloutViewButtonB, self.calloutViewButtonX, self.calloutViewButtonY, self.calloutViewButtonL2, self.calloutViewButtonR2];
    
    for (SMCalloutView *calloutView in calloutViews)
    {
        if (calloutView != exceptionCalloutView)
        {
            [calloutView dismissCalloutAnimated:YES];
        }
    }
}

#pragma mark - IBActions

- (IBAction)pressedButton:(UIButton *)sender
{
    if (sender == self.currentlySelectedButton)
    {
        [self animateToShowAllButtons];
        
        return;
    }

    [self animateToShowButton:sender];
}

- (IBAction)dismissPicker:(UIButton *)sender
{
    if (self.currentlySelectedButton == nil)
    {
        return;
    }
    
    [self animateToShowAllButtons];
}

#pragma mark - Animations

- (void)animateToShowButton:(UIButton *)button
{
    CGFloat pickerHeight = CGRectGetHeight(self.pickerView.bounds);
    CGFloat offset = (CGRectGetMaxY(button.frame) - (CGRectGetHeight(self.view.bounds) - pickerHeight));
    
    // Button is below where picker will be
    if (offset > 0)
    {
        offset += 10;
    }
    else
    {
        offset = 0;
    }
    
    NSDictionary *buttons = [[NSUserDefaults standardUserDefaults] dictionaryForKey:GBASettingsExternalControllerButtonsKey];
    GBAExternalControllerButtonInput input = [self externalControllerButtonInputForButton:button];
    GBAControllerButton controllerButton = [buttons[[GBAExternalController stringForButtonInput:input]] integerValue];
    
    [self.pickerView selectRow:[self rowForControllerButton:controllerButton] inComponent:0 animated:YES];
    
    self.topButtonLayoutViewLayoutConstraint.constant = -offset;
    self.bottomButtonLayoutViewLayoutConstraint.constant = -offset;
    self.topPickerLayoutConstraint.constant = -(pickerHeight + offset);
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
    
    SMCalloutView *calloutView = [self calloutViewForButton:button];
    
    if ([calloutView superview] == nil)
    {
        [self presentCalloutView:calloutView withAnimation:SMCalloutAnimationFade];
    }
    
    [self dismissAllCalloutViewsExceptCalloutView:calloutView];
    
    self.currentlySelectedButton = button;
}

- (void)animateToShowAllButtons
{
    self.topButtonLayoutViewLayoutConstraint.constant = 0;
    self.bottomButtonLayoutViewLayoutConstraint.constant = 0;
    self.topPickerLayoutConstraint.constant = 0;
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
    
    SMCalloutView *calloutView = [self calloutViewForButton:self.currentlySelectedButton];
    [self presentCalloutViewsExceptCalloutView:calloutView withAnimation:SMCalloutAnimationFade];
    
    self.currentlySelectedButton = nil;
}

#pragma mark - UIPickerView Data Source

// Rows
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return 8;
}

// Columns
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
    
}

#pragma mark - UIPickerView Delegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    GBAControllerButton button = [self controllerButtonForRow:row];
    NSString *name = [self nameForControllerButton:button];
    return name;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    GBAControllerButton button = [self controllerButtonForRow:row];
    NSString *name = [self nameForControllerButton:button];
    
    SMCalloutView *calloutView = [self calloutViewForButton:self.currentlySelectedButton];
    calloutView.title = name;
    [self presentCalloutView:calloutView withAnimation:SMCalloutAnimationNone];
    
    GBAExternalControllerButtonInput controllerButtonInput = [self externalControllerButtonInputForButton:self.currentlySelectedButton];
    [self setControllerButton:button forExternalControllerButtonInput:controllerButtonInput];
}

#pragma mark - Helper Methods

- (NSString *)nameForControllerButton:(GBAControllerButton)controllerButton
{
    NSString *name = nil;
    
    switch (controllerButton)
    {
        case GBAControllerButtonA:
            name = @"A";
            break;
            
        case GBAControllerButtonB:
            name = @"B";
            break;
            
        case GBAControllerButtonStart:
            name = NSLocalizedString(@"Start", @"");
            break;
            
        case GBAControllerButtonSelect:
            name = NSLocalizedString(@"Select", @"");
            break;
            
        case GBAControllerButtonL:
            name = NSLocalizedString(@"L", @"");
            break;
            
        case GBAControllerButtonR:
            name = NSLocalizedString(@"R", @"");
            break;
            
        case GBAControllerButtonSustainButton:
            name = NSLocalizedString(@"Sustain Button", @"");
            break;
            
        case GBAControllerButtonFastForward:
            name = NSLocalizedString(@"Fast Forward", @"");
            break;
            
        default:
            name = NSLocalizedString(@"Unknown", @"");
            break;
    }
    
    return name;
}

- (SMCalloutView *)calloutViewForButton:(UIButton *)button
{
    if (button == self.buttonA)
    {
        return self.calloutViewButtonA;
    }
    else if (button == self.buttonB)
    {
        return self.calloutViewButtonB;
    }
    else if (button == self.buttonX)
    {
        return self.calloutViewButtonX;
    }
    else if (button == self.buttonY)
    {
        return self.calloutViewButtonY;
    }
    else if (button == self.buttonL2)
    {
        return self.calloutViewButtonL2;
    }
    else if (button == self.buttonR2)
    {
        return self.calloutViewButtonR2;
    }
    
    return nil;
}

- (GBAControllerButton)controllerButtonForRow:(NSInteger)row
{
    GBAControllerButton button = GBAControllerButtonA;
    
    switch (row) {
        case 0:
            button = GBAControllerButtonA;
            break;
            
        case 1:
            button = GBAControllerButtonB;
            break;
            
        case 2:
            button = GBAControllerButtonStart;
            break;
            
        case 3:
            button = GBAControllerButtonSelect;
            break;
            
        case 4:
            button = GBAControllerButtonL;
            break;
            
        case 5:
            button = GBAControllerButtonR;
            break;
            
        case 6:
            button = GBAControllerButtonSustainButton;
            break;
            
        case 7:
            button = GBAControllerButtonFastForward;
            break;
    }
    
    return button;
}

- (NSInteger)rowForControllerButton:(GBAControllerButton)controllerButton
{
    NSInteger row = 0;
    
    switch (controllerButton) {
        case GBAControllerButtonA:
            row = 0;
            break;
            
        case GBAControllerButtonB:
            row = 1;
            break;
            
        case GBAControllerButtonStart:
            row = 2;
            break;
            
        case GBAControllerButtonSelect:
            row = 3;
            break;
            
        case GBAControllerButtonL:
            row = 4;
            break;
            
        case GBAControllerButtonR:
            row = 5;
            break;
            
        case GBAControllerButtonSustainButton:
            row = 6;
            break;
            
        case GBAControllerButtonFastForward:
            row = 7;
            break;
            
        default:
            break;
    }
    
    return row;
}

- (GBAExternalControllerButtonInput)externalControllerButtonInputForButton:(UIButton *)button
{
    if (button == self.buttonA)
    {
        return GBAExternalControllerButtonInputA;
    }
    else if (button == self.buttonB)
    {
        return GBAExternalControllerButtonInputB;
    }
    else if (button == self.buttonX)
    {
        return GBAExternalControllerButtonInputX;
    }
    else if (button == self.buttonY)
    {
        return GBAExternalControllerButtonInputY;
    }
    else if (button == self.buttonL2)
    {
        return GBAExternalControllerButtonInputLeftTrigger;
    }
    else if (button == self.buttonR2)
    {
        return GBAExternalControllerButtonInputRightTrigger;
    }
    
    return GBAExternalControllerButtonInputA;
}

@end
