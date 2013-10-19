//
//  GBANewCheatViewController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/21/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBACheatEditorViewController.h"

@interface NSString (RemoveWhitespace)

- (NSString *)stringByRemovingWhitespace;

@end

@implementation NSString (RemoveWhitespace)

// Doesn't try to remove all whitespace, but these are the only ones we have to worry about
- (NSString *)stringByRemovingWhitespace
{
    NSMutableString *text = [self mutableCopy];
    [text replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, text.length)];
    [text replaceOccurrencesOfString:@"\n" withString:@"" options:0 range:NSMakeRange(0, text.length)];
    
    return text;
}

@end

@interface GBACheatEditorViewController () <UITextViewDelegate, UITextFieldDelegate> {
    NSRange _selectionRange;
}

@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UISegmentedControl *codeTypeSegmentedControl;
@property (weak, nonatomic) IBOutlet UITextView *codeTextView;

- (IBAction)saveCheat:(UIBarButtonItem *)sender;
- (IBAction)cancelSavingNewCheat:(UIBarButtonItem *)sender;
- (IBAction)switchCheatType:(UISegmentedControl *)sender;

@end

@implementation GBACheatEditorViewController

- (id)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    self = [storyboard instantiateViewControllerWithIdentifier:@"cheatEditorViewController"];
    if (self)
    {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.cheat)
    {
        self.title = self.cheat.name;
        self.nameTextField.text = self.cheat.name;
        
        switch (self.cheat.type)
        {
            case GBACheatCodeTypeActionReplay:
                self.codeTypeSegmentedControl.selectedSegmentIndex = 0;
                break;
                
            case GBACheatCodeTypeGameSharkV3:
                self.codeTypeSegmentedControl.selectedSegmentIndex = 1;
                break;
                
            case GBACheatCodeTypeCodeBreaker:
                self.codeTypeSegmentedControl.selectedSegmentIndex = 2;
                break;
        }
        
        NSMutableString *codes = [NSMutableString string];
        
        for (NSString *code in self.cheat.codes)
        {
            [codes appendString:code];
        }
        
        self.codeTextView.text = codes;
        [self textViewDidChange:self.codeTextView];
    }
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.nameTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.nameTextField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}


- (IBAction)switchCheatType:(UISegmentedControl *)sender
{
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    [self textViewDidChange:self.codeTextView];
}

- (GBACheatCodeType)currentCheatCodeType
{
    if (self.codeTypeSegmentedControl.selectedSegmentIndex == 1)
    {
        return GBACheatCodeTypeGameSharkV3;
    }
    else if (self.codeTypeSegmentedControl.selectedSegmentIndex == 2)
    {
        return GBACheatCodeTypeCodeBreaker;
    }
    
    return GBACheatCodeTypeActionReplay;
}


- (IBAction)saveCheat:(UIBarButtonItem *)sender
{
    NSArray *codes = [self codesFromTextView];
    
    GBACheat *cheat = [self.cheat copy];
    
    if (self.cheat == nil)
    {
        cheat = [[GBACheat alloc] initWithName:self.nameTextField.text codes:codes];
    }
    else
    {
        cheat = [self.cheat copy];
        cheat.name = self.nameTextField.text;
        cheat.codes = codes;
    }
    
    cheat.type = [self currentCheatCodeType];
    
    if ([self.delegate respondsToSelector:@selector(cheatEditorViewController:didSaveCheat:)])
    {
        [self.delegate cheatEditorViewController:self didSaveCheat:cheat];
    }
}

- (IBAction)cancelSavingNewCheat:(UIBarButtonItem *)sender
{
    if ([self.delegate respondsToSelector:@selector(cheatEditorViewControllerDidCancel:)])
    {
        [self.delegate cheatEditorViewControllerDidCancel:self];
    }
}

- (NSArray *)codesFromTextView
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    NSMutableString *text = [[self.codeTextView.text stringByRemovingWhitespace] mutableCopy];
    
    NSUInteger codeLength = 12u;
    
    if ([self currentCheatCodeType] == GBACheatCodeTypeGameSharkV3 || [self currentCheatCodeType] == GBACheatCodeTypeActionReplay)
    {
        codeLength = 16u;
    }
    
    while (text.length >= 1)
    {
        int16_t maxRange = MIN(text.length, codeLength);
        NSRange range = NSMakeRange(0, maxRange);
        NSString *code = [text substringWithRange:range];
        [array addObject:code];
        [text deleteCharactersInRange:range];
    }
    
    return array;
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    // Have to animate it manually ourselves, or else it conflicts with the default table view behavior of only scrolling to the text field and not the entire section (including header)
    [UIView animateWithDuration:0.3 animations:^{
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }];
}

- (void)textFieldDidChange:(UITextField *)textField
{
    self.title = textField.text;
    
    self.navigationItem.rightBarButtonItem.enabled = (self.nameTextField.text.length > 0 && self.codeTextView.text.length > 0);
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2] atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    NSInteger difference = textView.text.length - [[textView.text stringByRemovingWhitespace] length];
    
    NSUInteger codeLength = 12u;
    
    if ([self currentCheatCodeType] == GBACheatCodeTypeGameSharkV3 || [self currentCheatCodeType] == GBACheatCodeTypeActionReplay)
    {
        codeLength = 16u;
    }
    
    if (text.length > 0)
    {
        if ((([self currentCheatCodeType] == GBACheatCodeTypeGameSharkV3 || [self currentCheatCodeType] == GBACheatCodeTypeActionReplay) && (range.location - difference + 1) % 8 == 0) ||
            ([self currentCheatCodeType] == GBACheatCodeTypeCodeBreaker && ((range.location - difference + 1) % codeLength == 0 || (range.location - difference + 1 - 8) % codeLength == 0)))
        {
            _selectionRange = NSMakeRange(range.location + 2, 0);
        }
        else
        {
            _selectionRange = NSMakeRange(range.location + 1, 0);
        }
    }
    else
    {
        _selectionRange = NSMakeRange(range.location, 0);
    }
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
    NSString *text = [textView.text stringByRemovingWhitespace];
    
    NSMutableString *formattedText = [NSMutableString string];
    
    NSUInteger codeLength = 12u;
    
    if ([self currentCheatCodeType] == GBACheatCodeTypeGameSharkV3 || [self currentCheatCodeType] == GBACheatCodeTypeActionReplay)
    {
        codeLength = 16u;
    }
    
    for (int i = 0; i < (int)text.length; i++)
    {
        if (i > 0)
        {
            if ((i + 1) % codeLength == 0)
            {
                [formattedText appendFormat:@"%c\n", [text characterAtIndex:i]];
            }
            else if ((([self currentCheatCodeType] == GBACheatCodeTypeGameSharkV3 || [self currentCheatCodeType] == GBACheatCodeTypeActionReplay) && (i + 1) % 8 == 0) ||
                     ([self currentCheatCodeType] == GBACheatCodeTypeCodeBreaker && (i + 1 - 8) % codeLength == 0 && i != 3))
            {
                [formattedText appendFormat:@"%c ", [text characterAtIndex:i]];
            }
            else
            {
                [formattedText appendFormat:@"%c", [text characterAtIndex:i]];
            }
        }
        else
        {
            [formattedText appendFormat:@"%c", [text characterAtIndex:i]];
        }
    }
    
    textView.text = [formattedText uppercaseString];
    
    [textView setSelectedRange:_selectionRange];
    
    self.navigationItem.rightBarButtonItem.enabled = (self.nameTextField.text.length > 0 && self.codeTextView.text.length > 0);
    
}

#pragma mark - UITableView Data Source

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 1)
    {
        if ([self currentCheatCodeType] == GBACheatCodeTypeCodeBreaker)
        {
            return NSLocalizedString(@"Code format is XXXXXXXX YYYY.", @"The X's and Y's are just to show placeholder characters. No need to translate them");
        }
        else if ([self currentCheatCodeType] == GBACheatCodeTypeGameSharkV3)
        {
            return NSLocalizedString(@"Code format is XXXXXXXX YYYYYYYY.\nGameShark SP codes are not supported, only GameShark Advance.", @"The X's and Y's are just to show placeholder characters. No need to translate them");
        }
        else
        {
            return NSLocalizedString(@"Code format is XXXXXXXX YYYYYYYY.", @"The X's and Y's are just to show placeholder characters. No need to translate them");
        }
    }
    
    return [super tableView:tableView titleForFooterInSection:section];
}

@end
