//
//  GBAExternalControllerCustomizationViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 12/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAExternalControllerCustomizationViewController.h"

#import "SMCalloutView.h"

@interface GBAExternalControllerCustomizationViewController ()

@property (strong, nonatomic) SMCalloutView *calloutViewButtonA;
@property (strong, nonatomic) SMCalloutView *calloutViewButtonB;
@property (strong, nonatomic) SMCalloutView *calloutViewButtonX;
@property (strong, nonatomic) SMCalloutView *calloutViewButtonY;
@property (strong, nonatomic) SMCalloutView *calloutViewTriggerL2;
@property (strong, nonatomic) SMCalloutView *calloutViewTriggerR2;

@property (weak, nonatomic) IBOutlet UIButton *buttonA;
@property (weak, nonatomic) IBOutlet UIButton *buttonB;
@property (weak, nonatomic) IBOutlet UIButton *buttonX;
@property (weak, nonatomic) IBOutlet UIButton *buttonY;

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
        _calloutViewTriggerL2 = [SMCalloutView new];
        _calloutViewTriggerR2 = [SMCalloutView new];
        
        _calloutViewButtonA.title = @"Select";
        _calloutViewButtonB.title = @"Fast Forward";
        _calloutViewButtonX.title = @"Sustain Button";
        _calloutViewButtonY.title = @"Start";
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
    
    [self presentCalloutViews];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Callout Views

- (void)presentCalloutViews
{
    [self.calloutViewButtonA presentCalloutFromRect:self.buttonA.frame inView:self.view constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionAny animated:YES];
    [self.calloutViewButtonB presentCalloutFromRect:self.buttonB.frame inView:self.view constrainedToView:self.rightHalfView permittedArrowDirections:SMCalloutArrowDirectionAny animated:YES];
    [self.calloutViewButtonX presentCalloutFromRect:self.buttonX.frame inView:self.view constrainedToView:self.leftHalfView permittedArrowDirections:SMCalloutArrowDirectionAny animated:YES];
    [self.calloutViewButtonY presentCalloutFromRect:self.buttonY.frame inView:self.view constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionAny animated:YES];
    //[self.calloutViewButtonA presentCalloutFromRect:self.buttonA.frame inView:self.view constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionAny animated:YES];
    //[self.calloutViewButtonA presentCalloutFromRect:self.buttonA.frame inView:self.view constrainedToView:self.view permittedArrowDirections:SMCalloutArrowDirectionAny animated:YES];
}

@end
