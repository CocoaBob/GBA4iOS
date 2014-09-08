//
//  GBAAcknowledgementsViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/3/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAAcknowledgementsViewController.h"

@interface GBAAcknowledgementsViewController ()

@property (strong, nonatomic) UITextView *textView;

@end

@implementation GBAAcknowledgementsViewController

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.title = NSLocalizedString(@"Acknowledgements", @"");
    }
    
    return self;
}

- (void)loadView
{
    UITextView *textView = [UITextView new];
    textView.selectable = NO;
    
    self.view = textView;
    self.textView = textView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSURL *acknowledgementsURL = [[NSBundle mainBundle] URLForResource:@"Acknowledgements" withExtension:@"html"];
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithFileURL:acknowledgementsURL options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType}  documentAttributes:nil error:nil];
    
    self.textView.attributedText = attributedString;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


@end
