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

#import "ICAdobeLightroomActivity.h"
#import "ICAdobeLightroomUploader.h"
#import "ICAdobeLightroomAuthenticationViewController.h"
#import "ICAdobeLightroomCollectionPickerViewController.h"
#import "ICAdobeLightroomUtilities.h"

#import <AdobeCreativeSDKFoundation/AdobeCreativeSDKFoundation.h>

NSString *const AdobeLightroomActivityDidStartNotification = @"AdobeLightroomActivityDidStartNotification";
NSString *const AdobeLightroomActivityDidStartUploadingFilesNotification = @"AdobeLightroomActivityDidStartUploadingFilesNotification";
NSString *const AdobeLightroomActivityDidStartUploadingFileNotification = @"AdobeLightroomActivityDidStartUploadingFileNotification";
NSString *const AdobeLightroomActivityDidFinishUploadingFileNotification = @"AdobeLightroomActivityDidFinishUploadingFileNotification";
NSString *const AdobeLightroomActivityDidFinishUploadingFilesNotification = @"AdobeLightroomActivityDidFinishUploadingFilesNotification";
NSString *const AdobeLightroomActivityDidGetProgressUpdateNotification = @"AdobeLightroomActivityDidGetProgressUpdateNotification";
NSString *const AdobeLightroomActivityDidFailNotification = @"AdobeLightroomActivityDidFailNotification";

NSString *const AdobeLightroomActivityCancelUploadsNotification = @"AdobeLightroomActivityCancelUploadsNotification";

NSString *const AdobeLightroomActivityUploaderFileNameKey = @"AdobeLightroomActivityUploaderFileNameKey";
NSString *const AdobeLightroomActivityUploaderFileURLKey = @"AdobeLightroomActivityUploaderFileURLKey";
NSString *const AdobeLightroomActivityUploaderProgressKey = @"AdobeLightroomActivityUploaderProgressKey";

@interface ICAdobeLightroomActivity() < ICAdobeLightroomAuthenticationDelegate,
                                        ICAdobeLightroomCollectionChooserDelegate >

@property (nonatomic, copy) NSArray *activityItems;
@property (nonatomic, strong) AdobePhotoCollection *collection;
@property (nonatomic, strong) UINavigationController *navController;
@property (nonatomic, strong) ICAdobeLightroomCollectionPickerViewController *collectionPicker;

@property (nonatomic, strong) NSString *clientID;
@property (nonatomic, strong) NSString *clientSecret;

@end

@implementation ICAdobeLightroomActivity

- (id)initWithClientID:(NSString *)clientID
      withClientSecret:(NSString *)clientSecret
{
    if ( self = [super init] )
    {
        _clientID = clientID;
        _clientSecret = clientSecret;
    }
    
    return self;
}

- (NSString *)activityType
{
    return @"com.iconocode.activity.AdobeLightroomActivity";
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
- (UIActivityCategory)activityCategory
{
    return UIActivityCategoryShare;
}
#endif

- (NSString *)activityTitle
{
    return @"Adobe Lightroom";
}

- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"AdobeLightroomActivityIcon"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    __block BOOL result = NO;
    
    [activityItems enumerateObjectsUsingBlock:^( id obj, NSUInteger idx, BOOL *stop )
    {
        if ( [obj isKindOfClass:[NSURL class]] )
        {
            result = YES;
            *stop = YES;
        }
        else if ( [obj isKindOfClass:[UIImage class]] )
        {
            result = YES;
            *stop = YES;
        }
    }];

    return result;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[activityItems count]];

    [activityItems enumerateObjectsUsingBlock:^( id obj, NSUInteger idx, BOOL *stop )
     {
         if ( [obj isKindOfClass:[NSURL class]] )
         {
             [items addObject:obj];
         }
         else if ( [obj isKindOfClass:[UIImage class]] )
         {
             [items addObject:obj];
         }
     }];
    
    self.activityItems = [NSArray arrayWithArray:items];
}

- (UIViewController *)activityViewController
{
    UIViewController* vc = nil;
    
    [ICAdobeLightroomUtilities initializeAdobeCreativeCloudWithClientID:self.clientID
                                                        andClientSecret:self.clientSecret];
    
    if ( ![[AdobeUXAuthManager sharedManager] isAuthenticated] )
    {
        ICAdobeLightroomAuthenticationViewController* lc = [[ICAdobeLightroomAuthenticationViewController alloc] init];
        [lc setDelegate:self];
        
        self.navController = [[UINavigationController alloc] initWithRootViewController:lc];
        vc = self.navController;
    }
    else if ( !self.collectionName )
    {
        self.collectionPicker = [[ICAdobeLightroomCollectionPickerViewController alloc] init];
        [self.collectionPicker setDelegate:self];
        
        vc = [[UINavigationController alloc] initWithRootViewController:self.collectionPicker];
    }
    
    return vc;
}

- (void)lightroomCollection:(void (^)(AdobePhotoCollection *collection))completionHandler
{
    [ICAdobeLightroomUtilities lightroomCatalog:^( AdobePhotoCatalog *catalog )
     {
         if ( catalog )
         {
             [self listCollectionForCatalog:catalog
                                  afterName:nil
                               onCompletion:completionHandler];
         }
         else if ( completionHandler )
         {
             completionHandler( nil );
         }
     }];
}

- (void)listCollectionForCatalog:(AdobePhotoCatalog *)catalog
                       afterName:(NSString *)name
                    onCompletion:(void (^)(AdobePhotoCollection *collection))completionHandler
{
    NSInteger listLimit = 100;
    [catalog listCollectionsAfterName:name
                            withLimit:listLimit
            includeDeletedCollections:NO
                         onCompletion:^( NSArray *collections )
     {
         if ( collections )
         {
             __block AdobePhotoCollection *foundCollection = nil;
             
             if ( self.collectionName )
             {
                 [collections enumerateObjectsUsingBlock:^( id obj, NSUInteger idx, BOOL *stop )
                  {
                      AdobePhotoCollection *collection = obj;
                      if ( [collection.name isEqualToString:self.collectionName] )
                      {
                          foundCollection = collection;
                          *stop = YES;
                      }
                  }];
             }
             
             if ( foundCollection )
             {
                 if ( completionHandler )
                 {
                     completionHandler( foundCollection );
                 }
             }
             else if ( collections.count == listLimit )
             {
                 AdobePhotoCollection *lastCollection = [collections lastObject];
                 [self listCollectionForCatalog:catalog
                                      afterName:lastCollection.name
                                   onCompletion:completionHandler];
             }
             else
             {
                 [AdobePhotoCollection create:self.collectionName
                                    inCatalog:catalog
                                 onCompletion:^( AdobePhotoCollection *collection )
                  {
                      if ( completionHandler )
                      {
                          completionHandler( collection );
                      }
                  }
                                      onError:^( NSError *error )
                  {
                      if ( completionHandler )
                      {
                          completionHandler( nil );
                      }
                  }];
             }
         }
         else if ( completionHandler )
         {
             completionHandler( nil );
         }
     }
                              onError:^( NSError *error )
     {
         if ( completionHandler )
         {
             completionHandler( nil );
         }
     }];
}

- (void)authenticationSucceeded
{
    if ( ![[AdobeUXAuthManager sharedManager] isAuthenticated] )
    {
        self.activityItems = nil;
    }

    [self performSelector:@selector(performActivity) withObject:nil afterDelay:1.0];
}

- (void)authenticationFailed
{
    self.activityItems = nil;
    [self activityDidFinish:YES];
}

- (void)performActivity
{
    [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidStartNotification object:nil];

    if ( self.collection )
    {
        [self activityDidFinish:NO];
        [self performActivityIntl:self.collection];
    }
    else if ( self.collectionName )
    {
        [self activityDidFinish:NO];

        [self lightroomCollection:^( AdobePhotoCollection *collection )
         {
             if ( collection == nil )
             {
                 self.activityItems = nil;
             }
             else
             {
                 self.collection = collection;
             }
             
             [self performActivityIntl:collection];
         }];
    }
    else
    {
        [self showCollectionPicker];
    }
}

- (void)performActivityIntl:(AdobePhotoCollection *)collection
{
    [self.activityItems enumerateObjectsUsingBlock:^( id obj, NSUInteger idx, BOOL *stop )
     {
         if ( [obj isKindOfClass:[NSURL class]] )
         {
             NSURL *url = obj;
             NSArray *pathComponents = [obj pathComponents];
             
             [[ICAdobeLightroomUploader sharedUploader] uploadFromPath:url
                                                              withName:[pathComponents lastObject]
                                                          toCollection:collection
                                                removeFileOnCompletion:NO];
         }
         else if ( [obj isKindOfClass:[UIImage class]] )
         {
             UIImage *image = obj;
             
             if ( !image.accessibilityIdentifier )
             {
                 NSLog( @"Warning: UIImage is unnamed: set name using accessibilityIdentifier property." );
                 image.accessibilityIdentifier = @"";
             }
             
             [[ICAdobeLightroomUploader sharedUploader] uploadImage:image
                                                           withName:image.accessibilityIdentifier
                                                       toCollection:collection];
         }
     }];
}

- (void)showCollectionPicker
{
    self.collectionPicker = [[ICAdobeLightroomCollectionPickerViewController alloc] init];
    [self.collectionPicker setDelegate:self];

    [self.navController pushViewController:self.collectionPicker animated:YES];
}

- (void)collectionSelected:(AdobePhotoCollection *)collection
{
    [self activityDidFinish:NO];
    self.collection = collection;
    [self performActivityIntl:self.collection];
}

- (void)selectionCancelled
{
    [self activityDidFinish:YES];
    self.activityItems = nil;
}

@end
