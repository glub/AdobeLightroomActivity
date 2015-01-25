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

#import "ICAdobeLightroomUtilities.h"
#import "ICAdobeLightroomActivity.h"

@implementation ICAdobeLightroomUtilities

+ (void)initializeAdobeCreativeCloudWithClientID:(NSString *)clientID
                                 andClientSecret:(NSString *)clientSecret
{
    NSParameterAssert( clientID && [clientID length] > 0 );
    NSParameterAssert( clientSecret && [clientSecret length] > 0 );
    
    [[AdobeUXAuthManager sharedManager] setAuthenticationParametersWithClientID:clientID
                                                               withClientSecret:clientSecret];
}

+ (void)lightroomCatalog:(void (^)(AdobePhotoCatalog *catalog))completionHandler
{
    [AdobePhotoCatalog listOfType:AdobePhotoCatalogTypeLightroom onCompletion:^( NSArray *catalogs )
     {
         if ( completionHandler )
         {
             completionHandler( [catalogs firstObject] );
         }
     }
                          onError:^( NSError *error )
     {
         NSLog( @"There was a problem listing the Lightroom catalogs: %@", error );
         if ( completionHandler )
         {
             completionHandler( nil );
         }
     }];
}

+ (void)listCollectionsForCatalog:(AdobePhotoCatalog *)catalog
                        afterName:(NSString *)name
                        withLimit:(NSUInteger)limit
                     onCompletion:(void (^)(AdobePhotoCollections *collections))completionHandler
{
    [catalog listCollectionsAfterName:name
                            withLimit:limit
            includeDeletedCollections:NO
                         onCompletion:completionHandler
                              onError:^( NSError *error )
    {
        NSLog( @"There was a problem listing the Lightroom collections: %@", error );
        if ( completionHandler )
        {
            completionHandler( nil );
        }
    }];
}

+ (UIViewController*)topMostController
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while ( topController.presentedViewController )
    {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

@end
