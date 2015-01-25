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

#import "ICAdobeLightroomUploader.h"
#import "ICAdobeLightroomUploadJob.h"
#import "ICAdobeLightroomActivity.h"
#import "ICAdobeLightroomUtilities.h"

#import <AdobeCreativeSDKFoundation/AdobeCreativeSDKFoundation.h>

@interface ICAdobeLightroomUploader()

@property (nonatomic, strong) ICAdobeLightroomUploadJob *currentJob;
@property (nonatomic, strong) NSMutableArray *uploadQueue;
@property (nonatomic, strong) NSMutableArray *assetsInCollection;
@property (nonatomic, assign) BOOL listedAssetsInCollection;

@end

@implementation ICAdobeLightroomUploader

+ (ICAdobeLightroomUploader *)sharedUploader
{
    static dispatch_once_t once;
    static ICAdobeLightroomUploader *sharedUploader = nil;
    
    dispatch_once( &once, ^{
        sharedUploader = [[ICAdobeLightroomUploader alloc] init];
    });
    
    return sharedUploader;
}

- (id)init
{
    self = [super init];
    
    if ( self )
    {
        self.uploadQueue = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCancellation:)
                                                     name:AdobeLightroomActivityCancelUploadsNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AdobeLightroomActivityCancelUploadsNotification
                                                  object:nil];
}

- (void)uploadImage:(UIImage *)image
           withName:(NSString *)name
       toCollection:(AdobePhotoCollection *)collection
{
    NSData *data = UIImageJPEGRepresentation(image, 1.0f);
    
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:@"alr"] URLByAppendingPathExtension:@"jpg"];
    
    [data writeToFile:fileURL.path atomically:YES];

    [self uploadFromPath:fileURL withName:name toCollection:collection removeFileOnCompletion:YES];
}

- (void)uploadFromPath:(NSURL *)path
              withName:(NSString *)name
          toCollection:(AdobePhotoCollection *)collection
removeFileOnCompletion:(BOOL)removeOnCompletion
{
    NSString *extension = [[path.path pathExtension] lowercaseString];
    if ( ![extension isEqualToString:@"jpg"] && ![extension isEqualToString:@"jpeg"] )
    {
        NSLog( @"Warning: the image %@ may not be a JPEG which is a requirement for this service.", name );
    }
    
    [self.uploadQueue addObject:[ICAdobeLightroomUploadJob uploadJobWithPath:path
                                                                    withName:name
                                                                toCollection:collection
                                                      removeFileOnCompletion:removeOnCompletion]];
    [self updateQueue];
}

- (void)updateQueue
{
    if ( [self.uploadQueue count] > 0 )
    {
        if ( !self.currentJob )
        {
            @synchronized( self )
            {
                self.currentJob = [self.uploadQueue firstObject];
                [self.uploadQueue removeObjectAtIndex:0];
                
                if ( [self.uploadQueue count] == 0 )
                {
                    self.listedAssetsInCollection = NO;
                    [self.assetsInCollection removeAllObjects];
                }
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidStartUploadingFileNotification
                                                                object:self
                                                              userInfo:@{ AdobeLightroomActivityUploaderFileURLKey:self.currentJob.fileURL }];
            
            if ( !self.listedAssetsInCollection )
            {
                [self listAssestInCollection:self.currentJob.collection
                                      onPage:nil
                                onCompletion:^( NSArray *assets )
                 {
                     // iterate the array to see if the current job is already there
                     [assets enumerateObjectsUsingBlock:^( id obj, NSUInteger idx, BOOL *stop )
                     {
                         AdobePhotoAsset *asset = obj;
                     
                         if ( [asset.name isEqualToString:self.currentJob.name] )
                         {
                             self.currentJob.asset = asset;
                             *stop = YES;
                         }
                     }];
                     
                     [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidStartUploadingFilesNotification object:nil];
                     
                     [self uploadAsset];
                 }
                                     onError:^( NSError *error )
                 {
                     NSLog(@"There was a problem listing assets in the collection: %@", error);
                 }];
            }
            else
            {
                // iterate the array to see if the current job is already there
                [self.assetsInCollection enumerateObjectsUsingBlock:^( id obj, NSUInteger idx, BOOL *stop )
                 {
                    AdobePhotoAsset *asset = obj;
                    if ( [asset.name isEqualToString:self.currentJob.name])
                    {
                        self.currentJob.asset = asset;
                        *stop = YES;
                    }
                }];
                
                [self uploadAsset];
            }
        }
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidFinishUploadingFilesNotification
                                                            object:nil];
    }
}

- (void)listAssestInCollection:(AdobePhotoCollection *)collection
                        onPage:(AdobePhotoPage *)page
                  onCompletion:(void (^)(AdobePhotoAssets* assets))completionBlock
                       onError:(void (^)(NSError* error))errorBlock
{
    if ( !self.assetsInCollection )
    {
        self.assetsInCollection = [NSMutableArray new];
    }
    
    [collection listAssetsOnPage:page
                    withSortType:AdobePhotoCollectionSortByCustomOrder
                       withLimit:500
                        withFlag:AdobePhotoCollectionFlagAll
                    onCompletion:^( NSArray *assets, AdobePhotoPage *previousPage, AdobePhotoPage *nextPage )
     {
         if ( assets )
         {
             [self.assetsInCollection addObjectsFromArray:assets];
         }
         
         if ( nextPage )
         {
             [self listAssestInCollection:collection
                                   onPage:nextPage
                             onCompletion:completionBlock
                                  onError:errorBlock];
         }
         else
         {
             self.listedAssetsInCollection = YES;
             
             if ( completionBlock )
             {
                 completionBlock( self.assetsInCollection );
             }
         }
     }
                         onError:^( NSError *error )
     {
         if ( errorBlock )
         {
             errorBlock( error );
         }
     }];
}

- (void)uploadAsset
{
    if ( self.currentJob.asset == nil )
    {
        self.currentJob.asset = [AdobePhotoAsset create:self.currentJob.name
                                           inCollection:self.currentJob.collection
                                           withDataPath:self.currentJob.fileURL
                                        withContentType:@"image/jpeg"
                                             onProgress:^( double fractionCompleted )
         {
             if ( self.currentJob )
             {
                 NSDictionary *userInfo = @{
                                            AdobeLightroomActivityUploaderFileNameKey : self.currentJob.name,
                                            AdobeLightroomActivityUploaderFileURLKey : self.currentJob.fileURL,
                                            AdobeLightroomActivityUploaderProgressKey : @(fractionCompleted),
                                            };
                 
//                 ICLogDebug( @"Image progress: %@ (%f%%)", self.currentJob.name, fractionCompleted );
                 
                 [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidGetProgressUpdateNotification
                                                                     object:self
                                                                   userInfo:userInfo];
             }
         }
                   onCompletion:^( AdobePhotoAsset *asset )
        {
            ICLogDebug( @"Image %@ uploaded to Adobe Lightroom.", asset.name );
            
            if ( self.currentJob.removeFileOnCompletion )
            {
                NSError *err = nil;
                [[NSFileManager defaultManager] removeItemAtURL:self.currentJob.fileURL error:&err];
                if ( err )
                {
                    NSLog( @"Failed to remove temporary file: %@.", err );
                }
            }
                
            NSDictionary *info = nil;
            if ( self.currentJob )
            {
                info = @{ AdobeLightroomActivityUploaderFileURLKey : self.currentJob.fileURL };
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidFinishUploadingFileNotification
                                                                object:self
                                                              userInfo:info];
            self.currentJob = nil;
            [self updateQueue];
        }
                 onCancellation:^
        {
            ICLogDebug( @"Image %@ cancelled from uploading to Adobe Lightroom.", self.currentJob.name );

            if ( self.currentJob.removeFileOnCompletion )
            {
                NSError *err = nil;
                [[NSFileManager defaultManager] removeItemAtURL:self.currentJob.fileURL error:&err];
                if ( err )
                {
                    NSLog( @"Failed to remove temporary file: %@.", err );
                }
            }

            NSDictionary *info = nil;
            if ( self.currentJob )
            {
                info = @{ AdobeLightroomActivityUploaderFileURLKey : self.currentJob.fileURL };
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidFinishUploadingFileNotification
                                                                object:self
                                                              userInfo:info];
            self.currentJob = nil;
            [self updateQueue];
        }
                        onError:^( NSError *error )
         {
             if ( self.currentJob.removeFileOnCompletion )
             {
                 NSError *err = nil;
                 [[NSFileManager defaultManager] removeItemAtURL:self.currentJob.fileURL error:&err];
                 if ( err )
                 {
                     NSLog( @"Failed to remove temporary file: %@.", err );
                 }
             }

             NSDictionary *info = nil;
             if ( self.currentJob )
             {
                 info = @{ AdobeLightroomActivityUploaderFileURLKey : self.currentJob.fileURL };
             }
             
             [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidFailNotification
                                                                 object:self
                                                               userInfo:info];
             NSLog( @"Failed to upload image %@ to Adobe Lightroom: %@", self.currentJob.name, error );
             self.currentJob = nil;
             [self updateQueue];
         }];
    }
    else
    {
        long long remoteFileSize = [self.currentJob.asset size];
        
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.currentJob.fileURL.path error:NULL];
        NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
        long long localFileSize = [fileSizeNumber longLongValue];
        
        // if we don't have the same size, update the master data
        if ( remoteFileSize != localFileSize )
        {
            ICLogDebug( @"File exists, but is different... removing existing file." );
            
            [self.currentJob.asset delete:^
            {
                self.currentJob.asset = nil;
                [self uploadAsset];
            }
                                  onError:^( NSError *error )
            {
                NSDictionary *info = nil;
                if ( self.currentJob )
                {
                    info = @{ AdobeLightroomActivityUploaderFileURLKey : self.currentJob.fileURL };
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidFailNotification
                                                                    object:self
                                                                  userInfo:info];
                NSLog( @"Failed to update image %@ to Adobe Lightroom: %@", self.currentJob.name, error );
                self.currentJob = nil;
                [self updateQueue];
            }];
        }
        else
        {
            ICLogDebug( @"Same file exists... skipping." );
            
            if ( self.currentJob.removeFileOnCompletion )
            {
                NSError *err = nil;
                [[NSFileManager defaultManager] removeItemAtURL:self.currentJob.fileURL error:&err];
                if ( err )
                {
                    NSLog( @"Failed to remove temporary file: %@.", err );
                }
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:AdobeLightroomActivityDidFinishUploadingFileNotification
                                                                object:self
                                                              userInfo:@{ AdobeLightroomActivityUploaderFileURLKey : self.currentJob.fileURL }];

            self.currentJob = nil;
            [self updateQueue];
        }
    }
}

- (NSUInteger)pendingUploadCount
{
    return [self.uploadQueue count];
}

- (void)handleCancellation:(NSNotification *)notification
{
    [self cancelUploads];
}

- (void)cancelUploads
{
    [self.uploadQueue removeAllObjects];
    [self.currentJob.asset cancelUploadRequest];
}

@end
