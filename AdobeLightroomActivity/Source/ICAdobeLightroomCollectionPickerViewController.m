/*
 * Copyright (c) 2015 Iconocode Ltd. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#import "ICAdobeLightroomCollectionPickerViewController.h"
#import "ICAdobeLightroomUtilities.h"
#import <AdobeCreativeSDKFoundation/AdobeCreativeSDKFoundation.h>

@interface ICAdobeLightroomCollectionPickerViewController ()

@property (nonatomic, strong) AdobePhotoCatalog *catalog;
@property (nonatomic, strong) NSMutableArray *collections;
@property (nonatomic, strong) UIView *spinnerView;
@property (nonatomic, strong) UIBarButtonItem *saveButton;
@property (nonatomic, strong) AdobePhotoCollection *selectedCollection;

@end

@implementation ICAdobeLightroomCollectionPickerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:NSLocalizedString(@"Choose Destination", @"Choose destination title")];
    
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    [self.navigationController setNavigationBarHidden:NO];
    [self.navigationController setToolbarHidden:YES];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor whiteColor];
    self.refreshControl.tintColor = [UIColor lightGrayColor];
    [self.refreshControl addTarget:self
                            action:@selector(listCatalogFromStart)
                  forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"button-close"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(handleClose:)];

    self.saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(handleDone:)];
    [self.saveButton setEnabled:NO];
    
    [self.navigationItem setLeftBarButtonItem:closeButton];
    [self.navigationItem setRightBarButtonItem:self.saveButton];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationItem setHidesBackButton:YES];
    
    [self showSpinnerView];
    
    [self listCatalogFromStart];
}

- (void)showSpinnerView
{
    CGSize viewSize = CGSizeMake(80, 50);
    CGSize spinnerSize = CGSizeMake(30, 30);
    UIActivityIndicatorViewStyle spinnerStyle = UIActivityIndicatorViewStyleWhite;
    
    self.spinnerView = [[UIView alloc] initWithFrame:CGRectMake(viewSize.width/2, 0, viewSize.width, viewSize.height)];
    self.spinnerView.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.5f];
    self.spinnerView.layer.cornerRadius = 12.0f;
    self.spinnerView.layer.masksToBounds = YES;
    
    UIActivityIndicatorView *progressIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake( 0, 0, spinnerSize.width, spinnerSize.height )];
    [progressIndicator setActivityIndicatorViewStyle:spinnerStyle];
    progressIndicator.center = CGPointMake( viewSize.width/2, viewSize.height/2 );
    [progressIndicator startAnimating];
    [self.spinnerView addSubview:progressIndicator];
    
    self.spinnerView.center = self.view.center;
    
    [[ICAdobeLightroomUtilities topMostController].view addSubview:self.spinnerView];
}

- (void)hideSpinnerView
{
    if (self.spinnerView)
    {
        [UIView animateWithDuration:0.5 animations:^
         {
             [self.spinnerView setAlpha:0.f];
         }
                         completion:^(BOOL finished)
         {
             [self.spinnerView removeFromSuperview];
             self.spinnerView = nil;
         }];
    }
    
    [self.refreshControl endRefreshing];
}

- (void)listCatalogFromStart
{
    [ICAdobeLightroomUtilities lightroomCatalog:^( AdobePhotoCatalog *catalog )
     {
         NSUInteger limit = 100;
         self.catalog = catalog;
         [ICAdobeLightroomUtilities listCollectionsForCatalog:catalog
                                                    afterName:nil
                                                    withLimit:limit
                                                 onCompletion:^( NSArray *collections )
          {
              [self hideSpinnerView];
              self.collections = [collections mutableCopy];
              [self.tableView reloadData];
              
              if ( collections.count == limit )
              {
                  AdobePhotoCollection *lastCollection = [collections lastObject];
                  [self listCatalogAfterName:lastCollection.name
                                onCompletion:^
                  {
                      [self.tableView reloadData];
                  }];
              }
          }];
     }];
}

- (void)listCatalogAfterName:(NSString *)name
           onCompletion:(void (^)(void))completionHandler
{
    NSUInteger limit = 250;
    [ICAdobeLightroomUtilities listCollectionsForCatalog:self.catalog
                                               afterName:name
                                               withLimit:limit
                                            onCompletion:^( NSArray *collections )
     {
         [self.collections addObjectsFromArray:collections];
         if ( collections.count == limit )
         {
             AdobePhotoCollection *lastCollection = [collections lastObject];
             [self listCatalogAfterName:lastCollection.name onCompletion:completionHandler];
         }
     }];
}

- (void)handleDone:(id)sender
{
    if ( self.delegate )
    {
        [self.delegate collectionSelected:self.selectedCollection];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleClose:(id)sender
{
    if ( self.delegate )
    {
        [self.delegate selectionCancelled];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.collections count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50.f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    
    AdobePhotoCollection *collection = [self.collections objectAtIndex:indexPath.row];
    
    UIFont* font = [UIFont fontWithName:@"Helvetica Neue" size:14.0];
    [cell.textLabel setFont:font];
    [cell.textLabel setText:collection.name];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.saveButton setEnabled:YES];
    self.selectedCollection = [self.collections objectAtIndex:indexPath.row];
}

@end
