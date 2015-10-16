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

#import "GBACalloutView.h"

SMCalloutAnimation SMCalloutAnimationNone = 18;

@interface GBAExternalControllerCustomizationViewController () <UIPickerViewDataSource, UIPickerViewDelegate, GBACalloutViewInteractionDelegate>
{
    GBACalloutView *_movedCalloutView;
    CGRect _movedCalloutViewOriginalRect;
}

@property (weak, nonatomic) IBOutlet UIPickerView *pickerView;
@property (weak, nonatomic) IBOutlet UIToolbar *pickerBarBackgroundToolbar;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topPickerLayoutConstraint;

@property (weak, nonatomic) IBOutlet UIView *buttonLayoutView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topButtonLayoutViewLayoutConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomButtonLayoutViewLayoutConstraint;

@property (strong, nonatomic) GBACalloutView *calloutViewButtonA;
@property (strong, nonatomic) GBACalloutView *calloutViewButtonB;
@property (strong, nonatomic) GBACalloutView *calloutViewButtonX;
@property (strong, nonatomic) GBACalloutView *calloutViewButtonY;
@property (strong, nonatomic) GBACalloutView *calloutViewButtonL2;
@property (strong, nonatomic) GBACalloutView *calloutViewButtonR2;

@property (weak, nonatomic) IBOutlet UIButton *buttonA;
@property (weak, nonatomic) IBOutlet UIButton *buttonB;
@property (weak, nonatomic) IBOutlet UIButton *buttonX;
@property (weak, nonatomic) IBOutlet UIButton *buttonY;
@property (weak, nonatomic) IBOutlet UIButton *buttonL2;
@property (weak, nonatomic) IBOutlet UIButton *buttonR2;
@property (weak, nonatomic) UIButton *currentlySelectedButton;
@property (weak, nonatomic) GBACalloutView *currenlyMovingCalloutView;

@property (weak, nonatomic) IBOutlet UIView *leftHalfView;
@property (weak, nonatomic) IBOutlet UIView *rightHalfView;

@property (strong, nonatomic) NSArray *calloutViewArray;

@end

@implementation GBAExternalControllerCustomizationViewController

- (id)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Settings" bundle:nil];
    self = [storyboard instantiateViewControllerWithIdentifier:@"externalControllerCustomizationViewController"];
    if (self)
    {
        _calloutViewButtonA = [GBACalloutView new];
        _calloutViewButtonB = [GBACalloutView new];
        _calloutViewButtonX = [GBACalloutView new];
        _calloutViewButtonY = [GBACalloutView new];
        _calloutViewButtonL2 = [GBACalloutView new];
        _calloutViewButtonR2 = [GBACalloutView new];
        
        _calloutViewButtonA.interactionDelegate = self;
        _calloutViewButtonB.interactionDelegate = self;
        _calloutViewButtonX.interactionDelegate = self;
        _calloutViewButtonY.interactionDelegate = self;
        _calloutViewButtonL2.interactionDelegate = self;
        _calloutViewButtonR2.interactionDelegate = self;
        
        [self updateCalloutViews];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.buttonLayoutView.backgroundColor = [UIColor groupTableViewBackgroundColor];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
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

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Button Mapping

- (void)setControllerButton:(GBAControllerButton)controllerButton forExternalControllerButtonInput:(GBAExternalControllerButtonInput)controllerButtonInput
{
    NSMutableDictionary *buttons = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:GBASettingsExternalControllerButtonsKey] mutableCopy];
    buttons[[GBAExternalController keyForButtonInput:controllerButtonInput]] = @(controllerButton);
    [[NSUserDefaults standardUserDefaults] setObject:buttons forKey:GBASettingsExternalControllerButtonsKey];
}

- (void)switchControllerButtonForInput:(GBAExternalControllerButtonInput)firstInput withControllerButtonForInput:(GBAExternalControllerButtonInput)secondInput
{
    UIButton *button = [self buttonForCalloutView:_movedCalloutView];
    
    NSDictionary *dictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:GBASettingsExternalControllerButtonsKey];
    GBAControllerButton firstControllerButton = [dictionary[[GBAExternalController keyForButtonInput:firstInput]] integerValue];
    GBAControllerButton secondControllerButton = [dictionary[[GBAExternalController keyForButtonInput:secondInput]] integerValue];
    
    [self setControllerButton:secondControllerButton forExternalControllerButtonInput:firstInput];
    [self setControllerButton:firstControllerButton forExternalControllerButtonInput:secondInput];
}

#pragma mark - Callout Views

- (void)presentCalloutViewsExceptCalloutView:(GBACalloutView *)exceptionCalloutView withAnimation:(SMCalloutAnimation)animation
{
    for (GBACalloutView *calloutView in [self calloutViewArray])
    {
        if (calloutView != exceptionCalloutView)
        {
            [self presentCalloutView:calloutView withAnimation:animation];
        }
    }
}

- (void)presentCalloutView:(GBACalloutView *)calloutView withAnimation:(SMCalloutAnimation)animation
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
        [self.calloutViewButtonA presentCalloutFromRect:self.buttonA.frame inView:self.buttonLayoutView constrainedToView:[self constraintViewForButton:self.buttonA] permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonB == calloutView)
    {
        [self.calloutViewButtonB presentCalloutFromRect:self.buttonB.frame inView:self.buttonLayoutView constrainedToView:[self constraintViewForButton:self.buttonB] permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonX == calloutView)
    {
        [self.calloutViewButtonX presentCalloutFromRect:self.buttonX.frame inView:self.buttonLayoutView constrainedToView:[self constraintViewForButton:self.buttonX] permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonY == calloutView)
    {
        [self.calloutViewButtonY presentCalloutFromRect:self.buttonY.frame inView:self.buttonLayoutView constrainedToView:[self constraintViewForButton:self.buttonY] permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonL2 == calloutView)
    {
        [self.calloutViewButtonL2 presentCalloutFromRect:self.buttonL2.frame inView:self.buttonLayoutView constrainedToView:[self constraintViewForButton:self.buttonL2] permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
    else if (self.calloutViewButtonR2 == calloutView)
    {
        [self.calloutViewButtonR2 presentCalloutFromRect:self.buttonR2.frame inView:self.buttonLayoutView constrainedToView:[self constraintViewForButton:self.buttonR2] permittedArrowDirections:SMCalloutArrowDirectionAny animated:animated];
    }
}

- (void)dismissAllCalloutViewsExceptCalloutView:(GBACalloutView *)exceptionCalloutView
{
    for (GBACalloutView *calloutView in [self calloutViewArray])
    {
        if (calloutView != exceptionCalloutView)
        {
            [calloutView dismissCalloutAnimated:YES];
        }
    }
}

- (void)updateCalloutViews
{
    self.calloutViewButtonA.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputA]];
    self.calloutViewButtonB.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputB]];
    self.calloutViewButtonX.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputX]];
    self.calloutViewButtonY.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputY]];
    self.calloutViewButtonL2.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputLeftTrigger]];
    self.calloutViewButtonR2.title = [self nameForControllerButton:[GBAExternalController controllerButtonForControllerButtonInput:GBAExternalControllerButtonInputRightTrigger]];
    
    [self presentCalloutViewsExceptCalloutView:nil withAnimation:SMCalloutAnimationNone];
}

- (void)moveCalloutView:(GBACalloutView *)calloutView toFrameForButton:(UIButton *)button completion:(void (^)(BOOL finished))completionBlock
{
    // Little hacky, we make a hidden callout view, "present" it, then use that frame to move the visible one
    GBACalloutView *tempCalloutView = [calloutView copy];
    tempCalloutView.hidden = YES;
    [tempCalloutView presentCalloutFromRect:button.frame inView:self.buttonLayoutView constrainedToView:[self constraintViewForButton:button] permittedArrowDirections:SMCalloutArrowDirectionDown animated:NO];
    
    [UIView animateWithDuration:0.3 animations:^{
        calloutView.frame = tempCalloutView.frame;
    } completion:completionBlock];
    
    [tempCalloutView dismissCalloutAnimated:NO];
}

#pragma mark - GBACalloutView Delegate

- (BOOL)calloutViewShouldBeginTranslating:(GBACalloutView *)calloutView
{
    if (self.currentlySelectedButton || self.currenlyMovingCalloutView)
    {
        return NO;
    }
    
    self.currenlyMovingCalloutView = calloutView;
    
    return YES;
}

- (void)calloutViewWasTapped:(GBACalloutView *)calloutView
{
    UIButton *button = [self buttonForCalloutView:calloutView];
    [self pressedButton:button];
}

- (void)calloutViewWillBeginTranslating:(GBACalloutView *)calloutView
{
    [self.buttonLayoutView bringSubviewToFront:calloutView];
}

- (void)calloutView:(GBACalloutView *)calloutView didTranslate:(CGPoint)translation
{
    // calloutView.center is offset by approximately +38 points, weird. This fixes that
    CGPoint correctedCenter = CGPointMake(CGRectGetMidX(calloutView.frame), CGRectGetMidY(calloutView.frame));
    GBACalloutView *destinationCalloutView = [self calloutViewForPoint:correctedCenter excludeCalloutView:calloutView];
    
    // If a callout view was moved to make way for the currently being dragged
    // callout view, and either the destination callout view doesn't match the
    // moved callout view or they do match but the user returned to the currently
    // being dragged callout view's original frame, then we return the moved
    // callout view to its original spot.
    if (_movedCalloutView && (destinationCalloutView != _movedCalloutView || (destinationCalloutView == _movedCalloutView && !CGRectContainsPoint(_movedCalloutViewOriginalRect, correctedCenter))))
    {
        UIButton *button = [self buttonForCalloutView:_movedCalloutView];
        [self moveCalloutView:_movedCalloutView toFrameForButton:button completion:nil];
        
        _movedCalloutView = nil;
        _movedCalloutViewOriginalRect = CGRectZero;
        
        return;
    }
    
    if (destinationCalloutView == nil || _movedCalloutView == destinationCalloutView)
    {
        return;
    }
    
    _movedCalloutView = destinationCalloutView;
    _movedCalloutViewOriginalRect = destinationCalloutView.frame;
    
    UIButton *button = [self buttonForCalloutView:calloutView];
    [self moveCalloutView:destinationCalloutView toFrameForButton:button completion:nil];
}

- (void)calloutViewDidFinishTranslating:(GBACalloutView *)calloutView
{
    self.currenlyMovingCalloutView = nil;
    
    if (_movedCalloutView == nil)
    {
        UIButton *button = [self buttonForCalloutView:calloutView];
        [self moveCalloutView:calloutView toFrameForButton:button completion:nil];
        
        return;
    }
    
    UIButton *movedCalloutViewButton = [self buttonForCalloutView:_movedCalloutView];
    UIButton *movingCalloutViewButton = [self buttonForCalloutView:calloutView];
    [self switchControllerButtonForInput:[self externalControllerButtonInputForButton:movedCalloutViewButton] withControllerButtonForInput:[self externalControllerButtonInputForButton:movingCalloutViewButton]];
    
    [self moveCalloutView:calloutView toFrameForButton:movedCalloutViewButton completion:^(BOOL finished) {
        [self updateCalloutViews];
    }];
   
    
    _movedCalloutView = nil;
    _movedCalloutViewOriginalRect = CGRectZero;
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
        offset += 15;
    }
    else
    {
        offset = 0;
    }
    
    NSDictionary *buttons = [[NSUserDefaults standardUserDefaults] dictionaryForKey:GBASettingsExternalControllerButtonsKey];
    GBAExternalControllerButtonInput input = [self externalControllerButtonInputForButton:button];
    GBAControllerButton controllerButton = [buttons[[GBAExternalController keyForButtonInput:input]] integerValue];
    
    // Only animate the picker if it's already visible
    BOOL animated = (self.currentlySelectedButton != nil);
    [self.pickerView selectRow:[self rowForControllerButton:controllerButton] inComponent:0 animated:animated];
    
    self.topButtonLayoutViewLayoutConstraint.constant = -offset;
    self.bottomButtonLayoutViewLayoutConstraint.constant = offset;
    self.topPickerLayoutConstraint.constant = -(pickerHeight  - offset);
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
    
    GBACalloutView *calloutView = [self calloutViewForButton:button];
    
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
    
    GBACalloutView *calloutView = [self calloutViewForButton:self.currentlySelectedButton];
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
    
    GBACalloutView *calloutView = [self calloutViewForButton:self.currentlySelectedButton];
    calloutView.title = name;
    [self presentCalloutView:calloutView withAnimation:SMCalloutAnimationNone];
    
    GBAExternalControllerButtonInput controllerButtonInput = [self externalControllerButtonInputForButton:self.currentlySelectedButton];
    [self setControllerButton:button forExternalControllerButtonInput:controllerButtonInput];
}

#pragma mark - Helper Methods

- (GBACalloutView *)calloutViewForPoint:(CGPoint)point excludeCalloutView:(GBACalloutView *)excludedCalloutView
{
    for (GBACalloutView *calloutView in [self calloutViewArray])
    {
        if (calloutView == excludedCalloutView)
        {
            continue;
        }
        
        CGRect rect = calloutView.frame;
        
        if (CGRectContainsPoint(rect, point))
        {
            return calloutView;
        }
        
    }
    
    if (CGRectContainsPoint(_movedCalloutViewOriginalRect, point))
    {
        return _movedCalloutView;
    }
    
    return nil;
}

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
            name = @"L";
            break;
            
        case GBAControllerButtonR:
            name = @"R";
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

- (GBACalloutView *)calloutViewForButton:(UIButton *)button
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

- (UIButton *)buttonForCalloutView:(GBACalloutView *)calloutView
{
    if (calloutView == self.calloutViewButtonA)
    {
        return self.buttonA;
    }
    else if (calloutView == self.calloutViewButtonB)
    {
        return self.buttonB;
    }
    else if (calloutView == self.calloutViewButtonX)
    {
        return self.buttonX;
    }
    else if (calloutView == self.calloutViewButtonY)
    {
        return self.buttonY;
    }
    else if (calloutView == self.calloutViewButtonL2)
    {
        return self.buttonL2;
    }
    else if (calloutView == self.calloutViewButtonR2)
    {
        return self.buttonR2;
    }
    
    return nil;
}

- (UIView *)constraintViewForButton:(UIButton *)button
{
    if (button == self.buttonX || button == self.buttonL2)
    {
        return self.leftHalfView;
    }
    
    if (button == self.buttonB || button == self.buttonR2)
    {
        return self.rightHalfView;
    }
    
    return self.buttonLayoutView;
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

- (NSArray *)calloutViewArray
{
    if (_calloutViewArray == nil)
    {
        _calloutViewArray = @[self.calloutViewButtonA, self.calloutViewButtonB, self.calloutViewButtonX, self.calloutViewButtonY, self.calloutViewButtonL2, self.calloutViewButtonR2];
    }
    
    return _calloutViewArray;
}

@end
