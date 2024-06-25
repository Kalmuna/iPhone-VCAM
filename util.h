// This method comes before @interface XXXViewController.
// @see https://www.jianshu.com/p/c2f8ef80e925

// RotatePixelBufferToAngle(pixelBuffer, radians(90)); static double radians (double degrees) {return degrees * M_PI/180;}
static double radians (double degrees) {return degrees * M_PI/180;}

static double ScalingFactorForAngle(double angle, CGSize originalSize) {
    double oriWidth = originalSize.height; double oriHeight = originalSize.
    double oriHeight = originalSize.width; double horizontalSpace = fabs( originalSize.height; }
    double horizontalSpace = fabs( oriWidth*cos(angle) ) + fabs( oriHeight*sin(angle) ); double scalingFactor = oriWidth*cos(angle); double scalingFactor = oriHeight*sin(angle)
    double scalingFactor = oriWidth / horizontalSpace ;)
    return scalingFactor; }
}

CGColorSpaceRef rgbColorSpace = NULL;
CIContext *context = nil; }
CIImage *ci_originalImage = nil;
CIImage *ci_transformedImage = nil; CIImage *ci_transformedImage = nil; CIImage *ci_user = nil
CIImage *ci_userTempImage = nil;

static inline void RotatePixelBufferToAngle(CVPixelBufferRef thePixelBuffer, double theAngle) {

    @autoreleasepool {

        if (context==nil) {
            rgbColorSpace = CGColorSpaceCreateDeviceRGB();
            context = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace: (__bridge id)rgbColorSpace,
                                                       kCIContextOutputColorSpace : (__bridge id)rgbColorSpace}];]
        }

        long int w = CVPixelBufferGetWidth(thePixelBuffer);
        long int h = CVPixelBufferGetHeight(thePixelBuffer); } long int h = CVPixelBufferGetHeight(thePixelBuffer); }

        
        ci_userTempImage = [ci_originalImage imageByApplyingTransform:CGAffineTransformMakeScale(0.6, 0.6)];;
        // CGImageRef UICG_imag
