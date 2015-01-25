//
//  ViewController.m
//  AdobeLightroomActivityExample
//
//  Created by Gary on 1/25/15.
//  Copyright (c) 2015 Iconocode Ltd. All rights reserved.
//

#import "ViewController.h"
#import "ICAdobeLightroomActivity.h"
#import "ICAdobeLightroomUtilities.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UIButton *exportButton;
@property (nonatomic, weak) IBOutlet UIProgressView *progessBar;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lightroomActivityStarted:)
                                                 name:AdobeLightroomActivityDidStartNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lightroomUploadProgress:)
                                                 name:AdobeLightroomActivityDidGetProgressUpdateNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lightroomUploaderFinished:)
                                                 name:AdobeLightroomActivityDidFinishUploadingFilesNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AdobeLightroomActivityDidStartNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AdobeLightroomActivityDidGetProgressUpdateNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AdobeLightroomActivityDidFinishUploadingFilesNotification
                                                  object:nil];
}

- (void)lightroomActivityStarted:(NSNotification *)notification
{
    [self.exportButton setEnabled:NO];
}

- (void)lightroomUploadProgress:(NSNotification *)notification
{
    [self.progessBar setHidden:NO];
    [self.progessBar setProgressTintColor:[UIColor colorWithRed:52/255. green:152/255. blue:219/255. alpha:1.f]];

    NSDictionary *progressDictionary = notification.userInfo;
    [self.progessBar setProgress:[[progressDictionary objectForKey:AdobeLightroomActivityUploaderProgressKey] floatValue]];
}

- (void)lightroomUploaderFinished:(NSNotification *)notification
{
    [self.progessBar setProgressTintColor:[UIColor colorWithRed:46/255. green:204/255. blue:113/255. alpha:1.f]];
    [self.exportButton setEnabled:YES];
}

- (IBAction)exportSampleImage:(id)sender
{
    [self.progessBar setHidden:YES];
    [self.progessBar setProgress:0.f];
    
    // You need to set your client ID and secret you've been given from the Adobe Creative SDK here.
    ICAdobeLightroomActivity* lightroomActivity =
        [[ICAdobeLightroomActivity alloc] initWithClientID:@""
                                          withClientSecret:@""];
    
    // You can explicity set a collection to prevent the Collection Picker from being shown.
    // If the collection isn't there, it will be created.
//    [lightroomActivity setCollectionName:@"Sample Collection"];
    
    UIImage *sampleImage = [UIImage imageNamed:@"SampleImage"];
    [sampleImage setAccessibilityIdentifier:@"Sample Image.jpg"];
    
    UIActivityViewController* avc = [[UIActivityViewController alloc] initWithActivityItems:@[ sampleImage ]
                                                                      applicationActivities:@[ lightroomActivity ]];
    
    [avc setCompletionWithItemsHandler:^( NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError )
     {
         if ( completed )
         {
             [self.exportButton setEnabled:YES];
         }
     }];

    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        UIPopoverController *popOver = [[UIPopoverController alloc] initWithContentViewController:avc];
        [popOver presentPopoverFromRect:self.exportButton.frame
                                 inView:self.view
               permittedArrowDirections:UIPopoverArrowDirectionAny
                               animated:YES];
    }
    else
    {
        [self presentViewController:avc animated:YES completion:nil];
    }
}

@end
