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
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithFileURL:acknowledgementsURL options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType}  documentAttributes:nil error:nil];
    
    [attributedString enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, attributedString.length) options:0 usingBlock:^(UIFont *font, NSRange range, BOOL *stop) {
        
        UIFontDescriptorSymbolicTraits symbolicTraits = font.fontDescriptor.symbolicTraits;
        
        UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
        fontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:symbolicTraits];
        UIFont *newFont = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
        
        [attributedString addAttribute:NSFontAttributeName value:newFont range:range];
        
    }];
    
    self.textView.attributedText = attributedString;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


@end
