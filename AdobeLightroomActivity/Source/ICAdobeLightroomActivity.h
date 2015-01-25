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

#import <UIKit/UIKit.h>

// Sent when the activity starts processing.
extern NSString *const AdobeLightroomActivityDidStartNotification;

// Sent when the activity starts sending files.
extern NSString *const AdobeLightroomActivityDidStartUploadingFilesNotification;

// Sent at the start of upload for each file.
extern NSString *const AdobeLightroomActivityDidStartUploadingFileNotification;

// Sent at the end of upload for each file.
extern NSString *const AdobeLightroomActivityDidFinishUploadingFileNotification;

// Sent whtn the activity stops sending files.
extern NSString *const AdobeLightroomActivityDidFinishUploadingFilesNotification;

// Sent during the upload. Use AdobeLightroomActivityUploaderProgressKey to look at the userInfo.
extern NSString *const AdobeLightroomActivityDidGetProgressUpdateNotification;

// Sent on event of an upload failure.
extern NSString *const AdobeLightroomActivityDidFailNotification;

// Post this notification to cancel the uploads.
extern NSString *const AdobeLightroomActivityCancelUploadsNotification;

// userInfo keys
extern NSString *const AdobeLightroomActivityUploaderFileNameKey;
extern NSString *const AdobeLightroomActivityUploaderFileURLKey;
extern NSString *const AdobeLightroomActivityUploaderProgressKey;

@interface ICAdobeLightroomActivity : UIActivity

// If you do not set the collection name, you will be prompted for one at runtime.
@property (nonatomic, strong) NSString *collectionName;

// Get your Adobe Creative SDK client id/secret from: http://creativesdk.adobe.com
- (id)initWithClientID:(NSString *)clientID
      withClientSecret:(NSString *)clientSecret;

@end
