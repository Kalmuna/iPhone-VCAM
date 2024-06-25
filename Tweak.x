#include <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
// #import "util.h"

static NSFileManager *g_fileManager = nil; // file manager
static UIPasteboard *g_pasteboard = nil; // clipboard manager
static BOOL g_canReleaseBuffer = YES;
static BOOL g_bufferReload = YES; // refresh video true/false
static AVSampleBufferDisplayLayer *g_previewLayer = nil; // native camera preview
static NSTimeInterval g_refreshPreviewByVideoDataOutputTime = 0; // show regular camera video if VideoDataOutput doesn't existnize the picture of VideoDataOutput, and if not, the video display will be read directly.
static BOOL g_cameraRunning = NO;
static NSString *g_cameraPosition = @"B"; // B = rear camera、F = front camera
static AVCaptureVideoOrientation g_photoOrientation = AVCaptureVideoOrientationPortrait; // video orientation

NSString *g_isMirroredMark = @"/var/mobile/Library/Caches/vcam_is_mirrored_mark";
NSString *g_tempFile = @"/var/mobile/Library/Caches/temp.mov"; // location for temp file


@interface GetFrame : NSObject
+ (CMSampleBufferRef _Nullable)getCurrentFrame:(CMSampleBufferRef) originSampleBuffer :(BOOL)forceReNew;
+ (UIWindow*)getKeyWindow;
@end

@implementation GetFrame
+ (CMSampleBufferRef _Nullable)getCurrentFrame:(CMSampleBufferRef _Nullable) originSampleBuffer :(BOOL)forceReNew{
    static AVAssetReader *reader = nil;
    // static AVAssetReaderTrackOutput *trackout = nil;
    static AVAssetReaderTrackOutput *videoTrackout_32BGRA = nil;
    static AVAssetReaderTrackOutput *videoTrackout_420YpCbCr8BiPlanarVideoRange = nil;
    static AVAssetReaderTrackOutput *videoTrackout_420YpCbCr8BiPlanarFullRange = nil;
    // static AVAssetReaderTrackOutput *audioTrackout_pcm = nil;

    static CMSampleBufferRef sampleBuffer = nil;

    // origin buffer info
    CMFormatDescriptionRef formatDescription = nil;
    CMMediaType mediaType = -1;
    CMMediaType subMediaType = -1;
    CMVideoDimensions dimensions;
    if (originSampleBuffer != nil) {
        formatDescription = CMSampleBufferGetFormatDescription(originSampleBuffer);
        mediaType = CMFormatDescriptionGetMediaType(formatDescription);
        subMediaType = CMFormatDescriptionGetMediaSubType(formatDescription);
        dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
        if (mediaType != kCMMediaType_Video) {
            // if (mediaType == kCMMediaType_Audio && subMediaType == kAudioFormatLinearPCM) {
            //     if (reader != nil && audioTrackout_pcm != nil && [reader status] == AVAssetReaderStatusReading) {
            //         NSLog(@"ok");
                    
            //         static CMSampleBufferRef audioBuffer = nil;
            //         if (audioBuffer != nil) CFRelease(audioBuffer);
            //         audioBuffer = [audioTrackout_pcm copyNextSampleBuffer];
            //         NSLog(@"audioBuffer = %@", audioBuffer);
            //         // return audioBuffer;
            //     }
            // }
            // @see https://developer.apple.com/documentation/coremedia/cmmediatype?language=objc
            return originSampleBuffer;
        }
    }

    // Return null if no replacement video is chosen; uses camera normally
    if ([g_fileManager fileExistsAtPath:g_tempFile] == NO) return nil;
    if (sampleBuffer != nil && !g_canReleaseBuffer && CMSampleBufferIsValid(sampleBuffer) && forceReNew != YES) return sampleBuffer; // return previous buffer if cannot be released


    static NSTimeInterval renewTime = 0;
    // New replacement video selected
    if ([g_fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.new", g_tempFile]]) {
        NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
        if (nowTime - renewTime > 3) {
            renewTime = nowTime;
            g_bufferReload = YES;
        }
    }

    if (g_bufferReload) {
        g_bufferReload = NO;
        @try{
            // AVAsset *asset = [AVAsset assetWithURL: [NSURL URLWithString:downloadFilePath]];
            AVAsset *asset = [AVAsset assetWithURL: [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", g_tempFile]]];
            reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
            
            AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject]; // Getting the track
            // kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange  : YUV420 For SD video [420v]
            // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange   : YUV422 For HD video [420f] 
            // kCVPixelFormatType_32BGRA : BGRA format for OpenGL and CoreImage

            // OSType type = kCVPixelFormatType_32BGRA;
            // NSDictionary *readerOutputSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(type)}; // Decompresses video frames into 32-bit BGRA format
            // trackout = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:readerOutputSettings];

            videoTrackout_32BGRA = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
            videoTrackout_420YpCbCr8BiPlanarVideoRange = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)}];
            videoTrackout_420YpCbCr8BiPlanarFullRange = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)}];
            
            // AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject]; // Getting the track
            // audioTrackout_pcm = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:@{AVFormatIDKey : [NSNumber numberWithInt:kAudioFormatLinearPCM]}];
            
            
            [reader addOutput:videoTrackout_32BGRA];
            [reader addOutput:videoTrackout_420YpCbCr8BiPlanarVideoRange];
            [reader addOutput:videoTrackout_420YpCbCr8BiPlanarFullRange];

            // [reader addOutput:audioTrackout_pcm];

            [reader startReading];
            // NSLog(@"Staring videoo");
        }@catch(NSException *except) {
            NSLog(@"Error starting video:%@", except);
        }
    }
    // NSLog(@"Refreshed");

    CMSampleBufferRef videoTrackout_32BGRA_Buffer = [videoTrackout_32BGRA copyNextSampleBuffer];
    CMSampleBufferRef videoTrackout_420YpCbCr8BiPlanarVideoRange_Buffer = [videoTrackout_420YpCbCr8BiPlanarVideoRange copyNextSampleBuffer];
    CMSampleBufferRef videoTrackout_420YpCbCr8BiPlanarFullRange_Buffer = [videoTrackout_420YpCbCr8BiPlanarFullRange copyNextSampleBuffer];

    CMSampleBufferRef newsampleBuffer = nil;
    // Copy the corresponding type according to subMediaType
    switch(subMediaType) {
        case kCVPixelFormatType_32BGRA:
            // NSLog(@"--->kCVPixelFormatType_32BGRA");
            CMSampleBufferCreateCopy(kCFAllocatorDefault, videoTrackout_32BGRA_Buffer, &newsampleBuffer);
            break;
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            // NSLog(@"--->kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange");
            CMSampleBufferCreateCopy(kCFAllocatorDefault, videoTrackout_420YpCbCr8BiPlanarVideoRange_Buffer, &newsampleBuffer);
            break;
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            // NSLog(@"--->kCVPixelFormatType_420YpCbCr8BiPlanarFullRange");
            CMSampleBufferCreateCopy(kCFAllocatorDefault, videoTrackout_420YpCbCr8BiPlanarFullRange_Buffer, &newsampleBuffer);
            break;
        default:
            CMSampleBufferCreateCopy(kCFAllocatorDefault, videoTrackout_32BGRA_Buffer, &newsampleBuffer);
    }
    // Free up memory
    if (videoTrackout_32BGRA_Buffer != nil) CFRelease(videoTrackout_32BGRA_Buffer);
    if (videoTrackout_420YpCbCr8BiPlanarVideoRange_Buffer != nil) CFRelease(videoTrackout_420YpCbCr8BiPlanarVideoRange_Buffer);
    if (videoTrackout_420YpCbCr8BiPlanarFullRange_Buffer != nil) CFRelease(videoTrackout_420YpCbCr8BiPlanarFullRange_Buffer);

    if (newsampleBuffer == nil) {
        g_bufferReload = YES;
    }else {
        if (sampleBuffer != nil) CFRelease(sampleBuffer);
        if (originSampleBuffer != nil) {

            // NSLog(@"---->%@", originSampleBuffer);
            // NSLog(@"====>%@", formatDescription);

            CMSampleBufferRef copyBuffer = nil;
            
            CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(newsampleBuffer);

            // NSLog(@"width:%ld height:%ld", CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
            // NSLog(@"width:%d height:%d ===", dimensions.width, dimensions.height);

            // TODO:: filters

            CMSampleTimingInfo sampleTime = {
                .duration = CMSampleBufferGetDuration(originSampleBuffer),
                .presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(originSampleBuffer),
                .decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(originSampleBuffer)
            };

            CMVideoFormatDescriptionRef videoInfo = nil;
            CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &videoInfo);
            
            // If this buffer is passed it needs to be generated according to this buffer
            // CMSampleBufferSetOutputPresentationTimeStamp(sampleBuffer, [[NSDate date] timeIntervalSince1970] * 1000);

            // CVImage Buffer
            CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, nil, nil, videoInfo, &sampleTime, &copyBuffer);
            // NSLog(@"cvimagebuffer ->%@", copyBuffer);

            if (copyBuffer != nil) {
                CFDictionaryRef exifAttachments = CMGetAttachment(originSampleBuffer, (CFStringRef)@"{Exif}", NULL);
                CFDictionaryRef TIFFAttachments = CMGetAttachment(originSampleBuffer, (CFStringRef)@"{TIFF}", NULL);

                // Setting EXIF information
                if (exifAttachments != nil) CMSetAttachment(copyBuffer, (CFStringRef)@"{Exif}", exifAttachments, kCMAttachmentMode_ShouldPropagate);
                // Setting TIFF information
                if (exifAttachments != nil) CMSetAttachment(copyBuffer, (CFStringRef)@"{TIFF}", TIFFAttachments, kCMAttachmentMode_ShouldPropagate);
                
                // NSLog(@"Exit message is set %@", CMGetAttachment(copyBuffer, (CFStringRef)@"{TIFF}", NULL));
                sampleBuffer = copyBuffer;
                // NSLog(@"--->GetDataBuffer = %@", CMSampleBufferGetDataBuffer(copyBuffer));
            }
            CFRelease(newsampleBuffer);
            // sampleBuffer = newsampleBuffer;
        }else {
            // Read directly from kCVPixelFormatType_32BGRA
            sampleBuffer = newsampleBuffer;
        }
    }
    if (CMSampleBufferIsValid(sampleBuffer)) return sampleBuffer;
    return nil;
}
+(UIWindow*)getKeyWindow{
    // need using [GetFrame getKeyWindow].rootViewController
    UIWindow *keyWindow = nil;
    if (keyWindow == nil) {
        NSArray *windows = UIApplication.sharedApplication.windows;
        for(UIWindow *window in windows){
            if(window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
    }
    return keyWindow;
}
@end


CALayer *g_maskLayer = nil;
%hook AVCaptureVideoPreviewLayer
- (void)addSublayer:(CALayer *)layer{
    %orig;
    // self.opacity = 0;
    // self.borderColor = [UIColor blackColor].CGColor;

    static CADisplayLink *displayLink = nil;
    if (displayLink == nil) {
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
        [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }

    // Play Entries
    if (![[self sublayers] containsObject:g_previewLayer]) {
        g_previewLayer = [[AVSampleBufferDisplayLayer alloc] init];

        // black mask
        g_maskLayer = [CALayer new];
        g_maskLayer.backgroundColor = [UIColor blackColor].CGColor;
        [self insertSublayer:g_maskLayer above:layer];
        [self insertSublayer:g_previewLayer above:g_maskLayer];

        // layer size init
        dispatch_async(dispatch_get_main_queue(), ^{
            g_previewLayer.frame = [UIApplication sharedApplication].keyWindow.bounds;
            g_maskLayer.frame = [UIApplication sharedApplication].keyWindow.bounds;
        });
        // NSLog(@"Added %@", [self sublayers]);
    }
}
%new
-(void)step:(CADisplayLink *)sender{
    if ([g_fileManager fileExistsAtPath:g_tempFile]) {
        if (g_maskLayer != nil) g_maskLayer.opacity = 1;
        if (g_previewLayer != nil) {
            g_previewLayer.opacity = 1;
            [g_previewLayer setVideoGravity:[self videoGravity]];
        }
    }else {
        if (g_maskLayer != nil) g_maskLayer.opacity = 0;
        if (g_previewLayer != nil) g_previewLayer.opacity = 0;
    }

    if (g_cameraRunning && g_previewLayer != nil) {
        // NSLog(@"g_previewLayer=>%@", g_previewLayer);
        // NSLog(@"g_previewLayer.readyForMoreMediaData %@", g_previewLayer.readyForMoreMediaData?@"yes":@"no");
        g_previewLayer.frame = self.bounds;
        // NSLog(@"-->%@", NSStringFromCGSize(g_previewLayer.frame.size));

        switch(g_photoOrientation) {
            case AVCaptureVideoOrientationPortrait:
                // NSLog(@"AVCaptureVideoOrientationPortrait");
            case AVCaptureVideoOrientationPortraitUpsideDown:
                // NSLog(@"AVCaptureVideoOrientationPortraitUpsideDown");
                g_previewLayer.transform = CATransform3DMakeRotation(0 / 180.0 * M_PI, 0.0, 0.0, 1.0);break;
            case AVCaptureVideoOrientationLandscapeRight:
                // NSLog(@"AVCaptureVideoOrientationLandscapeRight");
                g_previewLayer.transform = CATransform3DMakeRotation(90 / 180.0 * M_PI, 0.0, 0.0, 1.0);break;
            case AVCaptureVideoOrientationLandscapeLeft:
                // NSLog(@"AVCaptureVideoOrientationLandscapeLeft");
                g_previewLayer.transform = CATransform3DMakeRotation(-90 / 180.0 * M_PI, 0.0, 0.0, 1.0);break;
            default:
                g_previewLayer.transform = self.transform;
        }

        // Prevents conflicts with VideoOutput
        static NSTimeInterval refreshTime = 0;
        NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970] * 1000;
        if (nowTime - g_refreshPreviewByVideoDataOutputTime > 1000) {
            // Framerate control
            static CMSampleBufferRef copyBuffer = nil;
            if (nowTime - refreshTime > 1000 / 33 && g_previewLayer.readyForMoreMediaData) {
                refreshTime = nowTime;
                g_photoOrientation = -1;
                // NSLog(@"-==-·Refreshed %f", nowTime);
                CMSampleBufferRef newBuffer = [GetFrame getCurrentFrame:nil :NO];
                if (newBuffer != nil) {
                    [g_previewLayer flush];
                    if (copyBuffer != nil) CFRelease(copyBuffer);
                    CMSampleBufferCreateCopy(kCFAllocatorDefault, newBuffer, &copyBuffer);
                    if (copyBuffer != nil) [g_previewLayer enqueueSampleBuffer:copyBuffer];

                    // camera info
                    NSDate *datenow = [NSDate date];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
                    CGSize dimensions = self.bounds.size;
                    NSString *str = [NSString stringWithFormat:@"%@\n%@ - %@\nW:%.0f  H:%.0f",
                        [formatter stringFromDate:datenow],
                        [NSProcessInfo processInfo].processName,
                        [NSString stringWithFormat:@"%@ - %@", g_cameraPosition, @"preview"],
                        dimensions.width, dimensions.height
                    ];
                    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
                    [g_pasteboard setString:[NSString stringWithFormat:@"CCVCAM%@", [data base64EncodedStringWithOptions:0]]];
                }
            }
        }
    }
}
%end


%hook AVCaptureSession
-(void) startRunning {
    g_cameraRunning = YES;
    g_bufferReload = YES;
    g_refreshPreviewByVideoDataOutputTime = [[NSDate date] timeIntervalSince1970] * 1000;
	NSLog(@"Camera starting, preset is %@", [self sessionPreset]);
	%orig;
}
-(void) stopRunning {
    g_cameraRunning = NO;
	NSLog(@"Stop using the camera");
	%orig;
}
- (void)addInput:(AVCaptureDeviceInput *)input {
    if ([[input device] position] > 0) {
        g_cameraPosition = [[input device] position] == 1 ? @"B" : @"F";
    }
 	// NSLog(@"input device added - %@", [[input device] activeFormat]);
	%orig;
}
- (void)addOutput:(AVCaptureOutput *)output{
	NSLog(@"output device added - %@", output);
	%orig;
}
%end


%hook AVCaptureStillImageOutput
- (void)captureStillImageAsynchronouslyFromConnection:(AVCaptureConnection *)connection completionHandler:(void (^)(CMSampleBufferRef imageDataSampleBuffer, NSError *error))handler{
    g_canReleaseBuffer = NO;
    NSLog(@"Picture taken %@", handler);
    void (^newHandler)(CMSampleBufferRef imageDataSampleBuffer, NSError *error) = ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        NSLog(@"Photo Call %@", handler);
        CMSampleBufferRef newBuffer = [GetFrame getCurrentFrame:imageDataSampleBuffer :YES];
        if (newBuffer != nil) {
            imageDataSampleBuffer = newBuffer;
        }
        handler(imageDataSampleBuffer, error);
        g_canReleaseBuffer = YES;
    };
    %orig(connection, [newHandler copy]);
}
// TODO:: block buffer not finished yet so need here
+ (NSData *)jpegStillImageNSDataRepresentation:(CMSampleBufferRef)jpegSampleBuffer{
    CMSampleBufferRef newBuffer = [GetFrame getCurrentFrame:nil :NO];
    if (newBuffer != nil) {
        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(newBuffer);

        CIImage *ciimage = [CIImage imageWithCVImageBuffer:pixelBuffer];
        if (@available(iOS 11.0, *)) { // 旋转问题
            switch(g_photoOrientation){
                case AVCaptureVideoOrientationPortrait:
                    ciimage = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationUp];break;
                case AVCaptureVideoOrientationPortraitUpsideDown:
                    ciimage = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationDown];break;
                case AVCaptureVideoOrientationLandscapeRight:
                    ciimage = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationRight];break;
                case AVCaptureVideoOrientationLandscapeLeft:
                    ciimage = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationLeft];break;
            }
        }
        UIImage *uiimage = [UIImage imageWithCIImage:ciimage scale:2.0f orientation:UIImageOrientationUp];
        if ([g_fileManager fileExistsAtPath:g_isMirroredMark]) {
            uiimage = [UIImage imageWithCIImage:ciimage scale:2.0f orientation:UIImageOrientationUpMirrored];
        }
        NSData *theNewPhoto = UIImageJPEGRepresentation(uiimage, 1);
        return theNewPhoto;
    }
    return %orig;
}
%end

%hook AVCapturePhotoOutput
// TODO:: block buffer not finished yet so need here
+ (NSData *)JPEGPhotoDataRepresentationForJPEGSampleBuffer:(CMSampleBufferRef)JPEGSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer{
    CMSampleBufferRef newBuffer = [GetFrame getCurrentFrame:nil :NO];
    if (newBuffer != nil) {
        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(newBuffer);
        CIImage *ciimage = [CIImage imageWithCVImageBuffer:pixelBuffer];
        if (@available(iOS 11.0, *)) { // orientation 
            switch(g_photoOrientation){
                case AVCaptureVideoOrientationPortrait:
                    ciimage = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationUp];break;
                case AVCaptureVideoOrientationPortraitUpsideDown:
                    ciimage = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationDown];break;
                case AVCaptureVideoOrientationLandscapeRight:
                    ciimage = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationRight];break;
                case AVCaptureVideoOrientationLandscapeLeft:
                    ciimage = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationLeft];break;
            }
        }
        UIImage *uiimage = [UIImage imageWithCIImage:ciimage scale:2.0f orientation:UIImageOrientationUp];
        if ([g_fileManager fileExistsAtPath:g_isMirroredMark]) {
            uiimage = [UIImage imageWithCIImage:ciimage scale:2.0f orientation:UIImageOrientationUpMirrored];
        }
        NSData *theNewPhoto = UIImageJPEGRepresentation(uiimage, 1);
        return theNewPhoto;
    }
    return %orig;
}

- (void)capturePhotoWithSettings:(AVCapturePhotoSettings *)settings delegate:(id<AVCapturePhotoCaptureDelegate>)delegate{
    if (settings == nil || delegate == nil) return %orig;
    static NSMutableArray *hooked;
    if (hooked == nil) hooked = [NSMutableArray new];
    NSString *className = NSStringFromClass([delegate class]);
    if ([hooked containsObject:className] == NO) {
        [hooked addObject:className];

        if (@available(iOS 10.0, *)) {
            __block void (*original_method)(id self, SEL _cmd, AVCapturePhotoOutput *output, CMSampleBufferRef photoSampleBuffer, CMSampleBufferRef previewPhotoSampleBuffer, AVCaptureResolvedPhotoSettings *resolvedSettings, AVCaptureBracketedStillImageSettings *bracketSettings, NSError *error) = nil;
            MSHookMessageEx(
                [delegate class], @selector(captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:),
                imp_implementationWithBlock(^(id self, AVCapturePhotoOutput *output, CMSampleBufferRef photoSampleBuffer, CMSampleBufferRef previewPhotoSampleBuffer, AVCaptureResolvedPhotoSettings *resolvedSettings, AVCaptureBracketedStillImageSettings *bracketSettings, NSError *error){
                    g_canReleaseBuffer = NO;
                    CMSampleBufferRef newBuffer = [GetFrame getCurrentFrame:photoSampleBuffer :NO];
                    if (newBuffer != nil) {
                        photoSampleBuffer = newBuffer;
                        // NSLog(@"New buffer = %@", newBuffer);
                        // NSLog(@"Old buffer = %@", photoSampleBuffer);
                        // NSLog(@"Old previewPhotoSampleBuffer = %@", previewPhotoSampleBuffer);
                    }
                    NSLog(@"captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:");
                    // photoSampleBuffer = newPhotoBuffer;
                    // previewPhotoSampleBuffer = newPhotoBuffer;
                    @try{
                        original_method(self, @selector(captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:), output, photoSampleBuffer, previewPhotoSampleBuffer, resolvedSettings, bracketSettings, error);
                        g_canReleaseBuffer = YES;
                    }@catch(NSException *except) {
                        NSLog(@"Error %@", except);
                    }
                }), (IMP*)&original_method
            );
            __block void (*original_method2)(id self, SEL _cmd, AVCapturePhotoOutput *output, CMSampleBufferRef rawSampleBuffer, CMSampleBufferRef previewPhotoSampleBuffer, AVCaptureResolvedPhotoSettings *resolvedSettings, AVCaptureBracketedStillImageSettings *bracketSettings, NSError *error) = nil;
            MSHookMessageEx(
                [delegate class], @selector(captureOutput:didFinishProcessingRawPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:),
                imp_implementationWithBlock(^(id self, AVCapturePhotoOutput *output, CMSampleBufferRef rawSampleBuffer, CMSampleBufferRef previewPhotoSampleBuffer, AVCaptureResolvedPhotoSettings *resolvedSettings, AVCaptureBracketedStillImageSettings *bracketSettings, NSError *error){
                    NSLog(@"---raw->captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:");
                    // rawSampleBuffer = newPhotoBuffer;
                    // previewPhotoSampleBuffer = newPhotoBuffer;
                    return original_method2(self, @selector(captureOutput:didFinishProcessingRawPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:), output, rawSampleBuffer, previewPhotoSampleBuffer, resolvedSettings, bracketSettings, error);
                }), (IMP*)&original_method2
            );
        }

        if (@available(iOS 11.0, *)){ // iOS 11
            __block void (*original_method)(id self, SEL _cmd, AVCapturePhotoOutput *captureOutput, AVCapturePhoto *photo, NSError *error) = nil;
            MSHookMessageEx(
                [delegate class], @selector(captureOutput:didFinishProcessingPhoto:error:),
                imp_implementationWithBlock(^(id self, AVCapturePhotoOutput *captureOutput, AVCapturePhoto *photo, NSError *error){
                    if (![g_fileManager fileExistsAtPath:g_tempFile]) {
                        return original_method(self, @selector(captureOutput:didFinishProcessingPhoto:error:), captureOutput, photo, error);
                    }

                    g_canReleaseBuffer = NO;
                    static CMSampleBufferRef copyBuffer = nil;

                    // There's no buffer, create temporary one
                    // NSLog(@"photo.pixelBuffer= %@", photo.pixelBuffer);
                    CMSampleBufferRef tempBuffer = nil;
                    CVPixelBufferRef tempPixelBuffer = photo.pixelBuffer;
                    CMSampleTimingInfo sampleTime = {0,};
                    CMVideoFormatDescriptionRef videoInfo = nil;
                    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, tempPixelBuffer, &videoInfo);
                    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, tempPixelBuffer, true, nil, nil, videoInfo, &sampleTime, &tempBuffer);

                    // New data
                    NSLog(@"tempbuffer = %@, photo.pixelBuffer = %@, photo.CGImageRepresentation=%@", tempBuffer, photo.pixelBuffer, photo.CGImageRepresentation);
                    CMSampleBufferRef newBuffer = [GetFrame getCurrentFrame:tempBuffer :YES];
                    if (tempBuffer != nil) CFRelease(tempBuffer); // Release temporary buffer

                    if (newBuffer != nil) { // Hook attribute if new replacement data exists
                        if (copyBuffer != nil) CFRelease(copyBuffer);
                        CMSampleBufferCreateCopy(kCFAllocatorDefault, newBuffer, &copyBuffer);

                        __block CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(copyBuffer);
                        CIImage *ciimage = [CIImage imageWithCVImageBuffer:imageBuffer];

                        CIImage *ciimageRotate = [ciimage imageByApplyingCGOrientation:kCGImagePropertyOrientationLeft];
                        CIContext *cicontext = [CIContext new]; // Rotatioon problems here? Translation error? (此处旋转问题)
                        __block CGImageRef _Nullable cgimage = [cicontext createCGImage:ciimageRotate fromRect:ciimageRotate.extent];

                        UIImage *uiimage = [UIImage imageWithCIImage:ciimage];
                        __block NSData *theNewPhoto = UIImageJPEGRepresentation(uiimage, 1);

                        // After getting the new buffer start hooking the properties
                        __block NSData *(*fileDataRepresentationWithCustomizer)(id self, SEL _cmd, id<AVCapturePhotoFileDataRepresentationCustomizer> customizer);
                        MSHookMessageEx(
                            [photo class], @selector(fileDataRepresentationWithCustomizer:),
                            imp_implementationWithBlock(^(id self, id<AVCapturePhotoFileDataRepresentationCustomizer> customizer){
                                NSLog(@"fileDataRepresentationWithCustomizer");
                                if ([g_fileManager fileExistsAtPath:g_tempFile]) return theNewPhoto;
                                return fileDataRepresentationWithCustomizer(self, @selector(fileDataRepresentationWithCustomizer:), customizer);
                            }), (IMP*)&fileDataRepresentationWithCustomizer
                        );

                        __block NSData *(*fileDataRepresentation)(id self, SEL _cmd);
                        MSHookMessageEx(
                            [photo class], @selector(fileDataRepresentation),
                            imp_implementationWithBlock(^(id self, SEL _cmd){
                                NSLog(@"fileDataRepresentation");
                                if ([g_fileManager fileExistsAtPath:g_tempFile]) return theNewPhoto;
                                return fileDataRepresentation(self, @selector(fileDataRepresentation));
                            }), (IMP*)&fileDataRepresentation
                        );

                        __block CVPixelBufferRef *(*previewPixelBuffer)(id self, SEL _cmd);
                        MSHookMessageEx(
                            [photo class], @selector(previewPixelBuffer),
                            imp_implementationWithBlock(^(id self, SEL _cmd){
                                NSLog(@"previewPixelBuffer");
                                // RotatePixelBufferToAngle(imageBuffer, radians(-90));
                                return nil;
                            }), (IMP*)&previewPixelBuffer
                        );

                        __block CVImageBufferRef (*pixelBuffer)(id self, SEL _cmd);
                        MSHookMessageEx(
                            [photo class], @selector(pixelBuffer),
                            imp_implementationWithBlock(^(id self, SEL _cmd){
                                NSLog(@"pixelBuffer");
                                if ([g_fileManager fileExistsAtPath:g_tempFile]) return imageBuffer;
                                return pixelBuffer(self, @selector(pixelBuffer));
                            }), (IMP*)&pixelBuffer
                        );

                        __block CGImageRef _Nullable(*CGImageRepresentation)(id self, SEL _cmd);
                        MSHookMessageEx(
                            [photo class], @selector(CGImageRepresentation),
                            imp_implementationWithBlock(^(id self, SEL _cmd){
                                NSLog(@"CGImageRepresentation");
                                if ([g_fileManager fileExistsAtPath:g_tempFile]) return cgimage;
                                return CGImageRepresentation(self, @selector(CGImageRepresentation));
                            }), (IMP*)&CGImageRepresentation
                        );

                        __block CGImageRef _Nullable(*previewCGImageRepresentation)(id self, SEL _cmd);
                        MSHookMessageEx(
                            [photo class], @selector(previewCGImageRepresentation),
                            imp_implementationWithBlock(^(id self, SEL _cmd){
                                NSLog(@"previewCGImageRepresentation");
                                if ([g_fileManager fileExistsAtPath:g_tempFile]) return cgimage;
                                return previewCGImageRepresentation(self, @selector(previewCGImageRepresentation));
                            }), (IMP*)&previewCGImageRepresentation
                        );
                    }
                    g_canReleaseBuffer = YES;
                    
                    // NSLog(@"Native photo previewPixelBuffer = %@", photo.previewPixelBuffer );
                    // NSLog(@"Native photo fileDataRepresentation = %@", [photo fileDataRepresentation]);

                    return original_method(self, @selector(captureOutput:didFinishProcessingPhoto:error:), captureOutput, photo, error);
                }), (IMP*)&original_method
            );
        }
    }
    
    NSLog(@"capturePhotoWithSettings--->[%@]   [%@]", settings, delegate);
    %orig;
}
%end

%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(dispatch_queue_t)sampleBufferCallbackQueue{
    // NSLog(@"sampleBufferDelegate--->%@", [sampleBufferDelegate class]); // TODO:: The same software may have different proxy objects that need to be replaced once per object
    if (sampleBufferDelegate == nil || sampleBufferCallbackQueue == nil) return %orig;
    static NSMutableArray *hooked;
    if (hooked == nil) hooked = [NSMutableArray new];
    NSString *className = NSStringFromClass([sampleBufferDelegate class]);
    if ([hooked containsObject:className] == NO) {
        [hooked addObject:className];
        __block void (*original_method)(id self, SEL _cmd, AVCaptureOutput *output, CMSampleBufferRef sampleBuffer, AVCaptureConnection *connection) = nil;
        // NSLog(@"Preparing to hook-->%@ %p", [sampleBufferDelegate class], original_method);

        // NSLog(@"---------> AVCaptureVideoDataOutput -> videoSettings = %@", [self videoSettings]);
        // Dynamically hook and then call the original method to use the queue.
        MSHookMessageEx(
            [sampleBufferDelegate class], @selector(captureOutput:didOutputSampleBuffer:fromConnection:),
            imp_implementationWithBlock(^(id self, AVCaptureOutput *output, CMSampleBufferRef sampleBuffer, AVCaptureConnection *connection){
                // NSLog(@"Please, show up! 【self = %@】 params = %p", self, original_method);
                g_refreshPreviewByVideoDataOutputTime = ([[NSDate date] timeIntervalSince1970]) * 1000;

                CMSampleBufferRef newBuffer = [GetFrame getCurrentFrame:sampleBuffer :NO];

                // Refreshing preview with buffer
                NSString *previewType = @"buffer";
                g_photoOrientation = [connection videoOrientation];
                if (newBuffer != nil && g_previewLayer != nil && g_previewLayer.readyForMoreMediaData) {
                    [g_previewLayer flush];
                    [g_previewLayer enqueueSampleBuffer:newBuffer];
                    previewType = @"buffer - preview";
                }

                static NSTimeInterval oldTime = 0;
                NSTimeInterval nowTime = g_refreshPreviewByVideoDataOutputTime;
                if (nowTime - oldTime > 3000) { // Refresh every 3 seconds
                    oldTime = nowTime;
                    // camera info
                    // NSLog(@"set camera info");
                    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
                    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
                    NSDate *datenow = [NSDate date];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
                    NSString *str = [NSString stringWithFormat:@"%@\n%@ - %@\nW:%d  H:%d",
                        [formatter stringFromDate:datenow],
                        [NSProcessInfo processInfo].processName,
                        [NSString stringWithFormat:@"%@ - %@", g_cameraPosition, previewType],
                        dimensions.width, dimensions.height
                    ];
                    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
                    [g_pasteboard setString:[NSString stringWithFormat:@"CCVCAM%@", [data base64EncodedStringWithOptions:0]]];
                }
                
                return original_method(self, @selector(captureOutput:didOutputSampleBuffer:fromConnection:), output, newBuffer != nil? newBuffer: sampleBuffer, connection);
            }), (IMP*)&original_method
        );
    }
	// NSLog(@"AVCaptureVideoDataOutput -> setSampleBufferDelegate [%@] [%@]", sampleBufferDelegate, sampleBufferCallbackQueue);
	%orig;
}
%end

// metadata
// %hook AVCaptureMetadataOutput
// - (void)setMetadataObjectsDelegate:(id<AVCaptureMetadataOutputObjectsDelegate>)objectsDelegate queue:(dispatch_queue_t)objectsCallbackQueue{
//     if (objectsDelegate == nil || objectsCallbackQueue == nil) {
//         NSLog(@"AVCaptureMetadataOutput is empty!");
//         return %orig;
//     }
//     static void *(*original_method)(id self, SEL _cmd, AVCaptureOutput *output, NSArray<__kindof AVMetadataObject *> *metadataObjects, AVCaptureConnection *connection) = NULL;
//     if (original_method == NULL) {
//         NSLog(@"Hooking setMetadataObjectsDelegate");
//         MSHookMessageEx(
//             [objectsDelegate class], @selector(captureOutput:didOutputMetadataObjects:fromConnection:),
//             imp_implementationWithBlock(^(id self, AVCaptureOutput *output, NSArray<__kindof AVMetadataObject *> *metadataObjects, AVCaptureConnection *connection){
//                 // NSLog(@"Capturing metadata %@", metadataObjects);

//                 original_method(self, @selector(captureOutput:didOutputMetadataObjects:fromConnection:), output, metadataObjects, connection);
//             }), (IMP*)&original_method
//         );
//     }
// 	NSLog(@"AVCaptureMetadataOutput -> setMetadataObjectsDelegate [%@]   [%@]", objectsDelegate, objectsCallbackQueue);
// 	%orig;
// }
// %end


// UI
@interface CCUIImagePickerDelegate : NSObject <UINavigationControllerDelegate,UIImagePickerControllerDelegate>
@end
@implementation CCUIImagePickerDelegate
// This method is called on the success of selecting an image
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [[GetFrame getKeyWindow].rootViewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"%@", info);
    // NSString *result = @"Application Failure!";
    // Information about the selected image is stored in the info dictionary
    NSString *selectFile = info[@"UIImagePickerControllerMediaURL"];
    if ([g_fileManager fileExistsAtPath:g_tempFile]) [g_fileManager removeItemAtPath:g_tempFile error:nil];

    if ([g_fileManager copyItemAtPath:selectFile toPath:g_tempFile error:nil]) {
        [g_fileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@.new", g_tempFile] withIntermediateDirectories:YES attributes:nil error:nil];
        // result = @"Application Success!";
        sleep(1);
        [g_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@.new", g_tempFile] error:nil];  
    }
    // UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"VCAM" message:result preferredStyle:UIAlertControllerStyleAlert];
    // UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"oj8k" style:UIAlertActionStyleDefault handler:nil];
    // [alertController addAction:cancel];
    // [[GetFrame getKeyWindow].rootViewController presentViewController:alertController animated:YES completion:nil];

}
// Call this method to deselect the image
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [[GetFrame getKeyWindow].rootViewController dismissViewControllerAnimated:YES completion:nil];
    // selectFile = nil;
}
@end


// UI
static NSTimeInterval g_volume_up_time = 0;
static NSTimeInterval g_volume_down_time = 0;
static NSString *g_downloadAddress = @""; // Download address
static BOOL g_downloadRunning = NO; // Is download in progress?

void ui_selectVideo(){
    static CCUIImagePickerDelegate *delegate = nil;
    if (delegate == nil) delegate = [CCUIImagePickerDelegate new];
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = [NSArray arrayWithObjects:@"public.movie",/* @"public.image",*/ nil];
    picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
    if (@available(iOS 11.0, *)) picker.videoExportPreset = AVAssetExportPresetPassthrough;
    picker.allowsEditing = YES;
    picker.delegate = delegate;
    [[GetFrame getKeyWindow].rootViewController presentViewController:picker animated:YES completion:nil];
}

@interface AVSystemController : NSObject
+ (id)sharedAVSystemController;
- (BOOL)getVolume:(float*)arg1 forCategory:(id)arg2;
- (BOOL)setVolumeTo:(float)arg1 forCategory:(id)arg2;
@end

/**
 * Download video
 * @param bool quick Whether it's a convenient download, in which case minimize pop-ups
 */
void ui_downloadVideo(){
    if (g_downloadRunning) return;

    void (^startDownload)(void) = ^{
        g_downloadRunning = YES;
        
        NSString *tempPath = [NSString stringWithFormat:@"%@.downloading.mov", g_tempFile];

        NSData *urlData = [NSData dataWithContentsOfURL:[NSURL URLWithString:g_downloadAddress]];
        if ([urlData writeToFile:tempPath atomically:YES]) {
            AVAsset *asset = [AVAsset assetWithURL: [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", tempPath]]];
            if (asset.playable) {
                // File saved
                if ([g_fileManager fileExistsAtPath:g_tempFile]) [g_fileManager removeItemAtPath:g_tempFile error:nil];
                [g_fileManager moveItemAtPath:tempPath toPath:g_tempFile error:nil];
                [[%c(AVSystemController) sharedAVSystemController] setVolumeTo:0 forCategory:@"Ringtone"];
                // The video has changed
                [g_fileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@.new", g_tempFile] withIntermediateDirectories:YES attributes:nil error:nil];
                sleep(1);
                [g_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@.new", g_tempFile] error:nil];
            }else {
                if ([g_fileManager fileExistsAtPath:tempPath]) [g_fileManager removeItemAtPath:tempPath error:nil];
            }
        }else {
            if ([g_fileManager fileExistsAtPath:g_tempFile]) [g_fileManager removeItemAtPath:g_tempFile error:nil];
        }
        [[%c(AVSystemController) sharedAVSystemController] setVolumeTo:0 forCategory:@"Ringtone"];
        g_downloadRunning = NO;
    };
    dispatch_async(dispatch_queue_create("download", nil), startDownload);
}

%hook VolumeControl
-(void)increaseVolume {
    NSTimeInterval nowtime = [[NSDate date] timeIntervalSince1970];
    if (g_volume_down_time != 0 && nowtime - g_volume_down_time < 1) {
        if ([g_downloadAddress isEqual:@""]) {
            ui_selectVideo();
        }else {
            ui_downloadVideo();
        }
    }
    g_volume_up_time = nowtime;
    %orig;
}
-(void)decreaseVolume {
    static CCUIImagePickerDelegate *delegate = nil;
    if (delegate == nil) delegate = [CCUIImagePickerDelegate new];

    NSTimeInterval nowtime = [[NSDate date] timeIntervalSince1970];
    if (g_volume_up_time != 0 && nowtime - g_volume_up_time < 1) {

        // Resolution information on the clipboard
        NSString *str = g_pasteboard.string;
        NSString *infoStr = @"Information will be recorded when the lens is used";
        if (str != nil && [str hasPrefix:@"CCVCAM"]) {
            str = [str substringFromIndex:6]; //Intercept the string after subscript 3
            // NSLog(@"The obtained string is:%@", str);
            NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:str options:0];
            NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
            infoStr = decodedString;
            // NSLog(@"-----=-=-=-=--=-=-%@", decodedString);
        }
        
        // Tips for video quality
        NSString *title = @"iOS-VCAM";
        if ([g_fileManager fileExistsAtPath:g_tempFile]) title = @"iOS-VCAM ✅";
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:infoStr preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *next = [UIAlertAction actionWithTitle:@"Select video" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            ui_selectVideo();
        }];
        UIAlertAction *download = [UIAlertAction actionWithTitle:@"Save video" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            // Set the download address
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Save video" message:@"Try to use MOV format video\nMP4 can also be, other types have not yet been tested" preferredStyle:UIAlertControllerStyleAlert];
            [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                if ([g_downloadAddress isEqual:@""]) {
                    textField.placeholder = @"Remote video address";
                }else {
                    textField.text = g_downloadAddress;
                }
                textField.keyboardType = UIKeyboardTypeURL;
            }];
            UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                //Respond to events and get text messages
                g_downloadAddress = alert.textFields[0].text;
                NSString *resultStr = @"Convenient mode has been changed to download from remote\n\nIt needs to be guaranteed to be an accessible video address\n\nAfter completion, there will be a mute prompt of the system\nDownload failure to disable replacement";
                if ([g_downloadAddress isEqual:@""]) {
                    resultStr = @"The convenient mode has been changed to choose from the album.";
                }
                UIAlertController* resultAlert = [UIAlertController alertControllerWithTitle:@"Convenient mode change" message:resultStr preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Help" style:UIAlertActionStyleDefault handler:nil];
                [resultAlert addAction:ok];
                [[GetFrame getKeyWindow].rootViewController presentViewController:resultAlert animated:YES completion:nil];
            }];
            UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:okAction];
            [alert addAction:cancel];
            [[GetFrame getKeyWindow].rootViewController presentViewController:alert animated:YES completion:nil];
        }];
        UIAlertAction *cancelReplace = [UIAlertAction actionWithTitle:@"Disable replacement" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
            if ([g_fileManager fileExistsAtPath:g_tempFile]) [g_fileManager removeItemAtPath:g_tempFile error:nil];
        }];

        NSString *isMirroredText = @"Trying to Fix Photo Flip";
        if ([g_fileManager fileExistsAtPath:g_isMirroredMark]) isMirroredText = @"Trying to Fix Photo Flip ✅";
        UIAlertAction *isMirrored = [UIAlertAction actionWithTitle:isMirroredText style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            if ([g_fileManager fileExistsAtPath:g_isMirroredMark]) {
                [g_fileManager removeItemAtPath:g_isMirroredMark error:nil];
            }else {
                [g_fileManager createDirectoryAtPath:g_isMirroredMark withIntermediateDirectories:YES attributes:nil error:nil];
            }
        }];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel the operation" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *showHelp = [UIAlertAction actionWithTitle:@"- Check the help -" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            NSURL *URL = [NSURL URLWithString:@"https://github.com/trizau/iOS-VCAM"];
            [[UIApplication sharedApplication]openURL:URL];
        }];

        [alertController addAction:next];
        [alertController addAction:download];
        [alertController addAction:cancelReplace];
        [alertController addAction:cancel];
        [alertController addAction:showHelp];
        [alertController addAction:isMirrored];
        [[GetFrame getKeyWindow].rootViewController presentViewController:alertController animated:YES completion:nil];
    }
    g_volume_down_time = nowtime;
    %orig;

    // NSLog(@"Reduce the volume?%@ %@", [NSProcessInfo processInfo].processName, [NSProcessInfo processInfo].hostName);
    // %orig;
}
%end


%ctor {
	NSLog(@"Loaded");
    if([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){13, 0, 0}]) {
        %init(VolumeControl = NSClassFromString(@"SBVolumeControl"));
    }
    // if ([[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"] isEqual:@"com.apple.springboard"]) {
    // NSLog(@"Where am i? %@ %@", [NSProcessInfo processInfo].processName, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]);
    // }
    g_fileManager = [NSFileManager defaultManager];
    g_pasteboard = [UIPasteboard generalPasteboard];
}

%dtor{
    g_fileManager = nil;
    g_pasteboard = nil;
    g_canReleaseBuffer = YES;
    g_bufferReload = YES;
    g_previewLayer = nil;
    g_refreshPreviewByVideoDataOutputTime = 0;
    g_cameraRunning = NO;
    NSLog(@"Uninstall completed");
}
