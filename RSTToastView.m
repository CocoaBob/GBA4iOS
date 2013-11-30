//
//  RSTToastView.m
//  GBA4iOS
//
//  Created by Riley Testut on 11/28/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "RSTToastView.h"

@interface RSTPresentationWindow : UIWindow

@end

@implementation RSTPresentationWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    return NO;
}

@end

const CGFloat RSTToastViewCornerRadiusAutomaticDimension = -1816.1816;

NSString *const RSTToastViewWillShowNotification = @"RSTToastViewWillShowNotification";
NSString *const RSTToastViewDidShowNotification = @"RSTToastViewDidShowNotification";
NSString *const RSTToastViewWillHideNotification = @"RSTToastViewWillHideNotification";
NSString *const RSTToastViewDidHideNotification = @"RSTToastViewDidHideNotification";

NSString *const RSTToastViewWasTappedNotification = @"RSTToastViewWasTappedNotification";

static RSTToastView *_globalToastView;

#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)

@interface RSTToastView ()

@property (nonatomic, readwrite, assign, getter = isVisible) BOOL visible;

@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, strong) CALayer *borderLayer;
@property (nonatomic, strong) NSTimer *hidingTimer;

@property (nonatomic, assign) UIRectEdge presentedEdge;
@property (nonatomic, assign) BOOL presentAfterHiding;
@property (nonatomic, weak) UIView *presentationView; // Need to keep reference even after it is removed from superview

@end

@implementation RSTToastView

#pragma mark - Life Cycle

- (instancetype)initWithMessage:(NSString *)message
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        // Private
        _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _messageLabel.textColor = [UIColor whiteColor];
        [self addSubview:_messageLabel];
        
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rst_toastViewWasTapped:)];
        [self addGestureRecognizer:_tapGestureRecognizer];
        
        // Misc.
        
        self.clipsToBounds = YES;
        
        // Public
        self.showsActivityIndicator = NO;
        
        _backgroundColor = GBA4iOS_PURPLE_COLOR;
        _borderColor = [UIColor colorWithWhite:1.0f alpha:1.0f];
        
        // Can't set through setter directly (http://petersteinberger.com/blog/2013/uiappearance-for-custom-views/)
        // self.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
        
        self.messageLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
        self.messageLabel.text = message;
        
        _borderWidth = 5.0f;
        _cornerRadius = 10.0f;
        
        _presentationEdge = UIRectEdgeBottom;
        _edgeSpacing = 10.0f;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rst_willShowToastView:) name:RSTToastViewWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rst_didHideToastView:) name:RSTToastViewDidHideNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rst_willChangeStatusBarOrientation:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    }
    return self;
}

+ (RSTToastView *)toastViewWithMessage:(NSString *)message
{
    return [[RSTToastView alloc] initWithMessage:message];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Presentation

+ (void)show
{
    [_globalToastView show];
}

+ (void)showWithMessage:(NSString *)message
{
    [RSTToastView showWithMessage:message duration:0];
}

+ (void)showWithMessage:(NSString *)message duration:(NSTimeInterval)duration
{
    [RSTToastView showWithMessage:message inView:[RSTToastView presentationWindow] duration:duration];
}

+ (void)showWithMessage:(NSString *)message inView:(UIView *)view
{
    [RSTToastView showWithMessage:message inView:view duration:0];
}

+ (void)showWithMessage:(NSString *)message inView:(UIView *)view duration:(NSTimeInterval)duration
{
    [RSTToastView rst_showWithMessage:message inView:view duration:duration showsActivityIndicator:NO];
}

+ (void)showWithActivityMessage:(NSString *)message
{
    [RSTToastView showWithActivityMessage:message duration:0];
}

+ (void)showWithActivityMessage:(NSString *)message duration:(NSTimeInterval)duration
{
    [RSTToastView showWithActivityMessage:message inView:[RSTToastView presentationWindow] duration:duration];
}

+ (void)showWithActivityMessage:(NSString *)message inView:(UIView *)view
{
    [RSTToastView showWithActivityMessage:message inView:view duration:0];
}

+ (void)showWithActivityMessage:(NSString *)message inView:(UIView *)view duration:(NSTimeInterval)duration
{
    [RSTToastView rst_showWithMessage:message inView:view duration:duration showsActivityIndicator:YES];
}

+ (void)rst_showWithMessage:(NSString *)message inView:(UIView *)view duration:(NSTimeInterval)duration showsActivityIndicator:(BOOL)showsActivityIndicator
{
    _globalToastView = ({
        RSTToastView *toastView = [RSTToastView toastViewWithMessage:message];
        toastView.showsActivityIndicator = showsActivityIndicator;
        
        if (duration > 0)
        {
            toastView.hidingTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:toastView selector:@selector(hide) userInfo:nil repeats:NO];
        }
        
        toastView;
    });
    
    [_globalToastView showInView:view duration:duration];
}

- (void)show
{
    [self showForDuration:0];
}

- (void)showForDuration:(NSTimeInterval)duration
{
    [self showInView:[RSTToastView presentationWindow] duration:duration];
}

- (void)showInView:(UIView *)view
{
    [self showInView:view duration:0];
}

- (void)showInView:(UIView *)view duration:(NSTimeInterval)duration
{
    if ([self isVisible])
    {
        self.presentAfterHiding = YES;
        [self hide];
        return;
    }
    
    if (duration > 0)
    {
        self.hidingTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(hide) userInfo:nil repeats:NO];
    }
    
    self.presentedEdge = self.presentationEdge;
    self.presentationView = view;
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    // Don't set a nil window equal to the key window here, in case interface rotated and a toast view is still around even if it's container view isn't, so it doesn't get added to the window
    if (view == [RSTToastView presentationWindow])
    {
        transform = [RSTToastView rst_transformForInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
    }
    
    self.transform = transform;
    
    [self rst_refreshLayout];
    
    CGRect initialFrame = [RSTToastView rst_initialFrameForToastView:self];
    CGRect finalFrame = [RSTToastView rst_finalFrameForToastView:self];
    
    self.frame = initialFrame;
    [view addSubview:self];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RSTToastViewWillShowNotification object:self];
    
    self.visible = YES;
    
    [UIView animateWithDuration:.8 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0 options:0 animations:^{
        self.frame = finalFrame;
    } completion:^(BOOL finished) {
        [[NSNotificationCenter defaultCenter] postNotificationName:RSTToastViewDidShowNotification object:self];
    }];
}

#pragma mark - Updating

+ (void)updateWithMessage:(NSString *)message
{
    [_globalToastView setMessage:message];
    [_globalToastView setShowsActivityIndicator:NO];
}

+ (void)updateWithActivityMessage:(NSString *)message
{
    [_globalToastView setMessage:message];
    [_globalToastView setShowsActivityIndicator:YES];
}

- (void)rst_refreshLayout
{
    self.backgroundColor = _backgroundColor;
    
    [self.messageLabel sizeToFit];
    
    CGFloat buffer = 10.0f;
    
    CGFloat width = CGRectGetWidth(self.messageLabel.bounds) + buffer * 2.0f;
    CGFloat height = CGRectGetHeight(self.messageLabel.bounds) + buffer;
    
    if (![self.activityIndicatorView isHidden])
    {
        width += CGRectGetWidth(self.activityIndicatorView.bounds) + buffer / 2.0f;
        height = CGRectGetHeight(self.activityIndicatorView.bounds) + buffer;
    }
    
    self.bounds = CGRectMake(0, 0, width, height);
    
    self.activityIndicatorView.center = CGPointMake(CGRectGetMaxX(self.bounds) - buffer - CGRectGetMidX(self.activityIndicatorView.bounds), CGRectGetMidY(self.bounds));
    
    self.messageLabel.frame = CGRectIntegral(CGRectMake(buffer, (height - CGRectGetHeight(self.messageLabel.bounds))/2.0f, CGRectGetWidth(self.messageLabel.bounds), CGRectGetHeight(self.messageLabel.bounds)));
    
    CGFloat cornerRadius = self.cornerRadius;
    
    if (cornerRadius == RSTToastViewCornerRadiusAutomaticDimension)
    {
        cornerRadius = CGRectGetHeight(self.bounds) / 2.0;
    }
    
    self.layer.cornerRadius = cornerRadius;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    // Drawing code
}

#pragma mark - Dismissal

+ (void)hide
{
    [_globalToastView hide];
}

- (void)hide
{
    [self.hidingTimer invalidate];
    
    CGRect initialFrame = [RSTToastView rst_initialFrameForToastView:self];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RSTToastViewWillHideNotification object:self];
    
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.frame = initialFrame;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        self.visible = NO;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:RSTToastViewDidHideNotification object:self];
    }];
}

#pragma mark - Interaction

- (void)rst_toastViewWasTapped:(UITapGestureRecognizer *)tapGestureRecognizer
{
    [[NSNotificationCenter defaultCenter] postNotificationName:RSTToastViewWasTappedNotification object:self];
}

#pragma mark - Helper Methods

+ (CGAffineTransform)rst_transformForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            transform = CGAffineTransformIdentity;
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(270.0f));
            break;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(180.0f));
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(90.0f));
            break;
    }
    
    return transform;
}

+ (UIViewController *)rst_viewControllerForView:(UIView *)view {
    // From http://stackoverflow.com/a/10964295
    
    /// Finds the view's view controller.
    
    // Take the view controller class object here and avoid sending the same message iteratively unnecessarily.
    Class vcc = [UIViewController class];
    
    // Traverse responder chain. Return first found view controller, which will be the view's view controller.
    UIResponder *responder = view;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass: vcc]) {
            return (UIViewController *)responder;
        }
    }
    
    // If the view controller isn't found, return nil.
    return nil;
}

+ (UIRectEdge)correctedRectEdgeInPresentationWindowFromRectEdge:(UIRectEdge)rectEdge forInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    UIRectEdge correctedRectEdge = rectEdge;
    
    switch (interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            switch (rectEdge)
            {
                case UIRectEdgeTop:
                    correctedRectEdge = UIRectEdgeLeft;
                    break;
                    
                case UIRectEdgeLeft:
                    correctedRectEdge = UIRectEdgeBottom;
                    break;
                    
                case UIRectEdgeRight:
                    correctedRectEdge = UIRectEdgeTop;
                    break;
                    
                default:
                    correctedRectEdge = UIRectEdgeRight;
                    break;
            }
            
            break;
        }
            
        case UIInterfaceOrientationLandscapeRight:
        {
            switch (rectEdge)
            {
                case UIRectEdgeTop:
                    correctedRectEdge = UIRectEdgeRight;
                    break;
                    
                case UIRectEdgeLeft:
                    correctedRectEdge = UIRectEdgeTop;
                    break;
                    
                case UIRectEdgeRight:
                    correctedRectEdge = UIRectEdgeBottom;
                    break;
                    
                default:
                    correctedRectEdge = UIRectEdgeLeft;
                    break;
            }
            
            break;
        }
            
        case UIInterfaceOrientationPortraitUpsideDown:
        {
            switch (rectEdge)
            {
                case UIRectEdgeTop:
                    correctedRectEdge = UIRectEdgeBottom;
                    break;
                    
                case UIRectEdgeLeft:
                    correctedRectEdge = UIRectEdgeRight;
                    break;
                    
                case UIRectEdgeRight:
                    correctedRectEdge = UIRectEdgeLeft;
                    break;
                    
                default:
                    correctedRectEdge = UIRectEdgeTop;
                    break;
            }
            
            break;
        }
            
        default:
            break;
    }
    
    return correctedRectEdge;
}

+ (CGRect)rst_initialFrameForToastView:(RSTToastView *)toastView
{
    UIView *view = toastView.presentationView;
    CGPoint origin = CGPointZero;
    CGSize size = toastView.bounds.size;
    
    CGFloat edgeBuffer = 40.0f; // Intentionally not self.edgeSpacing; this should be consistent.
    
    UIRectEdge rectEdge = toastView.presentedEdge;
    
    if (view == [RSTToastView presentationWindow])
    {
        rectEdge = [self correctedRectEdgeInPresentationWindowFromRectEdge:rectEdge forInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation];
        
        if (rectEdge == UIRectEdgeLeft || rectEdge == UIRectEdgeRight)
        {
            size = CGSizeMake(size.height, size.width);
        }
        
    }
    
    switch (rectEdge)
    {
        case UIRectEdgeTop:
        {
            origin = CGPointMake((CGRectGetWidth(view.bounds) / 2.0f) - (size.width / 2.0f), -(size.height + edgeBuffer));
            break;
        }
            
        case UIRectEdgeLeft:
        {
            origin = CGPointMake(-(size.width + edgeBuffer), (CGRectGetHeight(view.bounds) / 2.0f) - (size.height / 2.0f));
            break;
        }
            
        case UIRectEdgeRight:
        {
            origin = CGPointMake(CGRectGetWidth(view.bounds) + edgeBuffer, (CGRectGetHeight(view.bounds) / 2.0f) - (size.height / 2.0f));
            break;
        }
            
        default: // Bottom or any other edge
        {
            origin = CGPointMake((CGRectGetWidth(view.bounds) / 2.0f) - (size.width / 2.0f), CGRectGetHeight(view.bounds) + edgeBuffer);
            break;
        }
    }
    
    return CGRectIntegral((CGRect){origin, size});
}

+ (CGRect)rst_finalFrameForToastView:(RSTToastView *)toastView
{
    UIView *view = toastView.presentationView;
    CGPoint origin = CGPointZero;
    CGSize size = toastView.bounds.size;
    
    UIRectEdge rectEdge = toastView.presentedEdge;
    
    if (view == [RSTToastView presentationWindow])
    {
        rectEdge = [self correctedRectEdgeInPresentationWindowFromRectEdge:rectEdge forInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation];
        
        if (rectEdge == UIRectEdgeLeft || rectEdge == UIRectEdgeRight)
        {
            size = CGSizeMake(size.height, size.width);
        }
        
    }
    
    switch (rectEdge)
    {
        case UIRectEdgeTop:
        {
            origin = CGPointMake((CGRectGetWidth(view.bounds) / 2.0f) - (size.width / 2.0f), toastView.edgeSpacing);
            break;
        }
            
        case UIRectEdgeLeft:
        {
            origin = CGPointMake(toastView.edgeSpacing, (CGRectGetHeight(view.bounds) / 2.0f) - (size.height / 2.0f));
            break;
        }
            
        case UIRectEdgeRight:
        {
            origin = CGPointMake(CGRectGetWidth(view.bounds) - (size.width + toastView.edgeSpacing), (CGRectGetHeight(view.bounds) / 2.0f) - (size.height / 2.0f));
            break;
        }
            
        default: // Bottom or any other edge
        {
            origin = CGPointMake((CGRectGetWidth(view.bounds) / 2.0f) - (size.width / 2.0f), CGRectGetHeight(view.bounds) - (size.height + toastView.edgeSpacing));
            break;
        }
    }
    
    return CGRectIntegral((CGRect){origin, size});
}


#pragma mark - Notifications

- (void)rst_willShowToastView:(NSNotification *)notification
{
    RSTToastView *toastView = [notification object];
    
    // If the new toast view is presenting from the same edge as the current toast view, hide the current one
    if (self.presentationEdge == toastView.presentationEdge && [self isVisible])
    {
        [self hide];
    }
}

- (void)rst_didHideToastView:(NSNotification *)notification
{
    RSTToastView *toastView = [notification object];
    
    if (self != toastView)
    {
        return;
    }
    
    if (self.presentAfterHiding)
    {
        [self showInView:self.presentationView];
        self.presentAfterHiding = NO;
    }
}

- (void)rst_willChangeStatusBarOrientation:(NSNotification *)notification
{
    if (![self isVisible])
    {
        return;
    }
    
    UIInterfaceOrientation interfaceOrientation = [[notification userInfo][UIApplicationStatusBarOrientationUserInfoKey] integerValue];
    
    self.presentAfterHiding = YES;
    [self hide];
}


#pragma mark - Getters/Setters

- (void)setPresentationEdge:(UIRectEdge)presentationEdge
{
    UIRectEdge sanitizedPresentationEdge = UIRectEdgeBottom;
    
    if (presentationEdge & UIRectEdgeBottom)
    {
        sanitizedPresentationEdge = UIRectEdgeBottom;
    }
    else if (presentationEdge & UIRectEdgeTop)
    {
        sanitizedPresentationEdge = UIRectEdgeTop;
    }
    else if (presentationEdge & UIRectEdgeLeft)
    {
        sanitizedPresentationEdge = UIRectEdgeLeft;
    }
    else if (presentationEdge & UIRectEdgeRight)
    {
        sanitizedPresentationEdge = UIRectEdgeRight;
    }
    
    _presentationEdge = presentationEdge;
}

- (void)setMessage:(NSString *)message
{
    if ([self.messageLabel.text isEqualToString:message])
    {
        return;
    }
    
    self.messageLabel.text = message;
    
    [self rst_refreshLayout];
}

- (NSString *)message
{
    return self.messageLabel.text;
}

- (void)setFont:(UIFont *)font
{
    // Update any logic here in the initialization method too
    if ([self.messageLabel.font isEqual:font])
    {
        return;
    }
    
    self.messageLabel.font = font;
    
    [self rst_refreshLayout];
}

- (UIFont *)font
{
    return [self.messageLabel font];
}

- (void)setShowsActivityIndicator:(BOOL)showsActivityIndicator
{
    if ([self.activityIndicatorView isAnimating] == showsActivityIndicator)
    {
        return;
    }
    
    if (showsActivityIndicator)
    {
        [self.activityIndicatorView startAnimating];
    }
    else
    {
        [self.activityIndicatorView stopAnimating];
    }
    
    [self rst_refreshLayout];
}

- (BOOL)showsActivityIndicator
{
    return [self.activityIndicatorView isAnimating];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    _backgroundColor = [backgroundColor copy];
    
    [super setBackgroundColor:backgroundColor];
}

+ (RSTPresentationWindow *)presentationWindow
{
    static RSTPresentationWindow *_presentationWindow = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _presentationWindow = [[RSTPresentationWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        _presentationWindow.windowLevel = (UIWindowLevelNormal + UIWindowLevelStatusBar) / 2.0f;
        [_presentationWindow setHidden:NO];
    });
    return _presentationWindow;
}

@end
