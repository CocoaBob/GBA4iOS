//
//  RSTFileBrowserViewController.m
//
//  Created by InfiniDev on 6/9/13.
//  Copyright (c) 2013 InfiniDev. All rights reserved.
//

#import "RSTFileBrowserViewController.h"
#import "RSTDirectoryMonitor.h"
#import "RSTFileBrowserTableViewCell.h"

@interface RSTFileBrowserViewController ()
{
    BOOL _performedInitialRefresh;
}

@property (strong, nonatomic) NSMutableDictionary *fileDictionary;
@property (strong, nonatomic) NSArray *sections;
@property (strong, nonatomic) RSTDirectoryMonitor *directoryMonitor;
@property (strong, nonatomic) NSArray *contents;

@property (readwrite, copy, nonatomic) NSArray *allFiles;
@property (readwrite, copy, nonatomic) NSArray *supportedFiles;
@property (readwrite, copy, nonatomic) NSArray *unsupportedFiles;

@property (assign, nonatomic) NSInteger ignoreDirectoryContentChangesCount;

@end

@implementation RSTFileBrowserViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self)
    {
        [self initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (void)initialize
{
    _fileDictionary = [[NSMutableDictionary alloc] init];
    _sections = [@"A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|#" componentsSeparatedByString:@"|"];
    _showSectionTitles = YES;
    _refreshAutomatically = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerClass:[RSTFileBrowserTableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!_performedInitialRefresh)
    {
        _performedInitialRefresh = YES;
        
        [self refreshDirectory];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public

- (NSString *)filepathForFilename:(NSString *)file
{
    return [self.currentDirectory stringByAppendingPathComponent:file];
}

- (NSString *)filepathForIndexPath:(NSIndexPath *)indexPath
{
    NSString *filename = [self filenameForIndexPath:indexPath];
    return [self filepathForFilename:filename];
}

- (NSString *)filenameForIndexPath:(NSIndexPath *)indexPath
{
    NSArray *sections = [self.fileDictionary objectForKey:[self.sections objectAtIndex:indexPath.section]];
    
    if (indexPath.row >= (NSInteger)[sections count])
    {
        return nil;
    }
    
    NSString *fileName = [sections objectAtIndex:indexPath.row];
    return [fileName copy];
}

- (NSString *)displayNameForIndexPath:(NSIndexPath *)indexPath
{
    NSString *displayName = [self filenameForIndexPath:indexPath];
    return [displayName stringByDeletingPathExtension];
}

- (NSString *)visibleFileExtensionForIndexPath:(NSIndexPath *)indexPath
{
    NSString *filepath = [self filepathForIndexPath:indexPath];
    NSString *extension = [filepath pathExtension];
    
    return extension;
}

- (void)deleteFileAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    [self setIgnoreDirectoryContentChanges:YES];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *filepath = [self filepathForIndexPath:indexPath];
    
    [fileManager removeItemAtPath:filepath error:NULL];
    
    // Delete the row from the data source
    [UIView animateWithDuration:0.4 animations:^{
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } completion:^(BOOL finished) {
         [self setIgnoreDirectoryContentChanges:NO];
     }];
}

#pragma mark - Refreshing Data

- (void)refreshDirectory
{
    NSMutableDictionary *fileDictionary = [NSMutableDictionary dictionary];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *allFiles = nil;
    
    if (self.showUnavailableFiles)
    {
        allFiles = [self.directoryMonitor allFiles];
    }
    else
    {
        allFiles = [self.directoryMonitor availableFiles];
    }
    
    NSMutableArray *supportedFiles = [NSMutableArray array];
    NSMutableArray *unsupportedFiles = [NSMutableArray array];
    
    NSArray *extensions = [self.supportedFileExtensions copy];
    
    for (NSString *filename in allFiles)
    {
        BOOL fileSupported = NO;
        BOOL isDirectory = NO;
        
        [fileManager fileExistsAtPath:[self.currentDirectory stringByAppendingPathComponent:filename] isDirectory:&isDirectory];
        
        if (isDirectory)
        {
            fileSupported = self.showFolders;
        }
        else
        {
            if ([self.supportedFileExtensions count] == 0)
            {
                fileSupported = YES;
            }
            else
            {
                for (NSString *extension in extensions)
                {
                    if ([[[filename pathExtension] lowercaseString] isEqualToString:[extension lowercaseString]])
                    {
                        fileSupported = YES;
                        break;
                    }
                }
            }
        }
        
        if (fileSupported)
        {
            NSString *characterIndex = [filename substringWithRange:NSMakeRange(0,1)];
            characterIndex = [characterIndex uppercaseString];
            
            if ([characterIndex rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location == NSNotFound)
            {
                characterIndex = @"#";
            }
            
            NSMutableArray *sectionArray = fileDictionary[characterIndex];
            if (sectionArray == nil)
            {
                sectionArray = [[NSMutableArray alloc] init];
            }
            [sectionArray addObject:filename];
            fileDictionary[characterIndex] = sectionArray;
            
            [supportedFiles addObject:filename];
        }
        else
        {
            [unsupportedFiles addObject:filename];
        }
    }
    
    self.allFiles = allFiles;
    self.supportedFiles = supportedFiles;
    self.unsupportedFiles = unsupportedFiles;
    
    self.fileDictionary = fileDictionary;
    
    if (self.directoryMonitor.ignoreDirectoryContentChanges == NO)
    {
        if ([NSThread isMainThread])
        {
            [self.tableView reloadData];
        }
        else
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
    
    [self didRefreshCurrentDirectory];
}

- (void)directoryContentsChanged:(NSNotification *)notification
{
    if (self.refreshAutomatically)
    {
        [self refreshDirectory];
    }
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    __strong NSString *displayName = [self displayNameForIndexPath:indexPath];
    cell.textLabel.text = displayName;
    
    if (self.showFileExtensions)
    {
        cell.detailTextLabel.text = [self visibleFileExtensionForIndexPath:indexPath];
    }
    
    return cell;
}

#pragma mark Sections

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.directoryMonitor.ignoreDirectoryContentChanges)
    {
        // This is called every time you insert, delete or remove something. Even though we're ignoring directory content changes, we still need to be up to date in case of these cases.
        [self refreshDirectory];
    }
    
    NSInteger numberOfSections = self.sections.count;
    return numberOfSections > 0 ? numberOfSections : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionTitle = nil;
    if (self.sections.count)
    {
        NSInteger numberOfRows = [self tableView:tableView numberOfRowsInSection:section];
        if (numberOfRows > 0)
        {
            sectionTitle = [self.sections objectAtIndex:section];
        }
    }
    return sectionTitle;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if (!self.showSectionTitles)
    {
        return nil;
    }
    
    return self.sections;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return index;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = self.fileDictionary.count;
    if (self.sections.count)
    {
        numberOfRows = [[self.fileDictionary objectForKey:[self.sections objectAtIndex:section]] count];
    }
    return numberOfRows;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        [self deleteFileAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Subclass methods

- (void)didRefreshCurrentDirectory
{
    if ([self.delegate respondsToSelector:@selector(fileBrowserViewController:didRefreshDirectory:)])
    {
        [self.delegate fileBrowserViewController:self didRefreshDirectory:self.currentDirectory];
    }
    
    // Subclasses implement custom logic
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

#pragma mark - Getters/Setters

- (void)setCurrentDirectory:(NSString *)currentDirectory
{
    if ([_currentDirectory isEqualToString:currentDirectory])
    {
        return;
    }
    
    _currentDirectory = [currentDirectory copy];
    
    self.directoryMonitor = [[RSTDirectoryMonitor alloc] initWithDirectory:currentDirectory];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(directoryContentsChanged:) name:RSTDirectoryMonitorContentsDidChangeNotification object:nil];
        
    if (self.isViewLoaded) // Crash if subclass sets currentDirectory in init method, as self.tableView isn't loaded yet
    {
        [self refreshDirectory];
    }
}

- (void)setSupportedFileExtensions:(NSArray *)supportedFileExtensions
{
    if ([_supportedFileExtensions isEqualToArray:supportedFileExtensions])
    {
        return;
    }
    
    _supportedFileExtensions = [supportedFileExtensions copy];
    
    if (self.isViewLoaded) // Crash if subclass sets supportedFileExtensions in init method, as self.tableView isn't loaded yet
    {
        [self refreshDirectory];
    }
}

- (NSArray *)unavailableFiles
{
    return [self.directoryMonitor unavailableFiles];
}

- (void)setIgnoreDirectoryContentChanges:(BOOL)ignoreDirectoryContentChanges
{
    if (ignoreDirectoryContentChanges)
    {
        self.ignoreDirectoryContentChangesCount++;
        self.directoryMonitor.ignoreDirectoryContentChanges = YES;
    }
    else
    {
        self.ignoreDirectoryContentChangesCount--;
        
        if (self.ignoreDirectoryContentChangesCount <= 0)
        {
            self.directoryMonitor.ignoreDirectoryContentChanges = NO;
            [self refreshDirectory];
        }
    }
}

- (BOOL)isIgnoringDirectoryContentChanges
{
    return (self.ignoreDirectoryContentChangesCount > 0);
}

@end







