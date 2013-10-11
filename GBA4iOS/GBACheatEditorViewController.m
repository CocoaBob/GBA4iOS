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
@property (weak, nonatomic) IBOutlet UITextView *codeTextView;

- (IBAction)saveCheat:(UIBarButtonItem *)sender;
- (IBAction)cancelSavingNewCheat:(UIBarButtonItem *)sender;

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
    
    while (text.length >= 1)
    {
        int16_t maxRange = MIN(text.length, 16);
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
    [self.tableView scrollRectToVisible:CGRectMake(0, 0, self.view.bounds.size.width, 10) animated:YES];
}

- (void)textFieldDidChange:(UITextField *)textField
{
    self.title = textField.text;
    
    self.navigationItem.rightBarButtonItem.enabled = (self.nameTextField.text.length > 0 && self.codeTextView.text.length > 0);
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
     [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:1] atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    NSInteger difference = textView.text.length - [[textView.text stringByRemovingWhitespace] length];
    
    if (text.length > 0)
    {
        if ((range.location - difference + 1) % 8 == 0)
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
    
    for (int i = 0; i < (int)text.length; i++)
    {
        if (i > 0)
        {
            if ((i + 1) % 16 == 0)
            {
                [formattedText appendFormat:@"%c\n", [text characterAtIndex:i]];
            }
            else if ((i + 1) % 8 == 0)
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
    
    //NSRange range = NSMakeRange(textView.text.length - 1, 1);
    //[textView scrollRangeToVisible:range];
    
    self.navigationItem.rightBarButtonItem.enabled = (self.nameTextField.text.length > 0 && self.codeTextView.text.length > 0);
    
}

@end
