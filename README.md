
This library provides a UIActivity for exporting a UIImage (or local path to a JPEG file) into Adobe Lightroom via the Adobe Creative Cloud.

## Screenshots

<img src="https://s3.amazonaws.com/s3.iconocode.com/github/images/AdobeLightroomActivity-1.png" width="200"/> &nbsp; <img src="https://s3.amazonaws.com/s3.iconocode.com/github/images/AdobeLightroomActivity-2.png" width="200">

## Installation & Usage

### Setup

  1. Download the [Adobe Creative SDK](http://creativesdk.adobe.com).
  2. Create a [new application](https://creativesdk.adobe.com/myapps.html) in order to get issued a client ID and secret.
  3. To build the Example application you will need to place the `AdobeCreativeSDKFoundation.framework` in the `Example/CreativeSDK` folder.
  4. Be sure to init the `ICAdobeLightroomActivity` class with the Adobe supplied client ID and secret.

### Options

There are two ways to control the activity.

  1. Explicitly specify the Adobe Lightroom Collection to export into.
  2. Bring up a picker and choose an existing Adobe Lightroom (Mobile) Collection.

The included example shows the picker by default, but option 1 is in the code, commented out.

### Notifications

There are several NSNotifications emitted during the lifetime of the activity.

  * `AdobeLightroomActivityDidStartNotification` - sent when the activity starts processing.
  * `AdobeLightroomActivityDidStartUploadingFilesNotification` - sent when the activity starts uploading the files.
  * `AdobeLightroomActivityDidStartUploadingFileNotification` - sent when a specific file has begun to upload. Inspect the userInfo for the pertinent information (accessible via AdobeLightroomActivityUploaderFileNameKey and AdobeLightroomActivityUploaderFileURLKey).
  * `AdobeLightroomActivityDidGetProgressUpdateNotification` - sent every time there is an update of a file's upload progress. Inspect the userInfo using the AdobeLightroomActivityUploaderProgressKey. 
  * `AdobeLightroomActivityDidFinishUploadingFileNotification` - sent when a specific file has finished the upload. Inspect the userInfo for the pertinent information (accessible via AdobeLightroomActivityUploaderFileNameKey and AdobeLightroomActivityUploaderFileURLKey).
  * `AdobeLightroomActivityDidFinishUploadingFilesNotification` - sent when the activity finishes uploading the files.
  * `AdobeLightroomActivityDidFailNotification` - sent when there was an error during the process.

If you want to cancel the uploads currently in progress, dispatch `AdobeLightroomActivityCancelUploadsNotification`.

### Notes

Since a UIImage cannot specify a filename, we are looking at the `accessibilityIdentifier` property for the name.

### License

MIT. See the [LICENSE](LICENSE) file for all the information.

