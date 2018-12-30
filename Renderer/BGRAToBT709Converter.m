//
//  BGRAToBT709Converter.m
//
//  Created by Mo DeJong on 11/25/18.
//

#import "BGRAToBT709Converter.h"

#import "CGFrameBuffer.h"

#import "BT709.h"

@import Accelerate;

static inline uint32_t byte_to_grayscale24(uint32_t byteVal)
{
  return ((0xFF << 24) | (byteVal << 16) | (byteVal << 8) | byteVal);
}

@interface BGRAToBT709Converter ()

@end

@implementation BGRAToBT709Converter

- (void) deallocate
{
}

// BGRA -> BT709

+ (BOOL) convert:(uint32_t*)inBGRAPixels
  outBT709Pixels:(uint32_t*)outBT709Pixels
           width:(int)width
          height:(int)height
            type:(BGRAToBT709ConverterTypeEnum)type
{
  // width and height must be even for subsampling to work
  
  if ((width % 2) != 0) {
    return FALSE;
  }
  if ((height % 2) != 0) {
    return FALSE;
  }
  
  if (type == BGRAToBT709ConverterSoftware) @autoreleasepool {
    return [self.class convertSoftware:inBGRAPixels outBT709Pixels:outBT709Pixels width:width height:height];
  } else if (type == BGRAToBT709ConverterVImage) @autoreleasepool {
    return [self.class convertVimage:inBGRAPixels outBT709Pixels:outBT709Pixels width:width height:height];
  } else {
    return FALSE;
  }
  
  return TRUE;
}

// BT709 -> BGRA

+ (BOOL) unconvert:(uint32_t*)inBT709Pixels
     outBGRAPixels:(uint32_t*)outBGRAPixels
             width:(int)width
            height:(int)height
              type:(BGRAToBT709ConverterTypeEnum)type
{
  // width and height must be even for subsampling to work
  
  if ((width % 2) != 0) {
    return FALSE;
  }
  if ((height % 2) != 0) {
    return FALSE;
  }
    
  if (type == BGRAToBT709ConverterSoftware) @autoreleasepool {
    [self.class unconvertSoftware:inBT709Pixels outBGRAPixels:outBGRAPixels width:width height:height];
  } else if (type == BGRAToBT709ConverterVImage) @autoreleasepool {
    return [self.class unconvertVimage:inBT709Pixels outBGRAPixels:outBGRAPixels width:width height:height];
  } else {
    return FALSE;
  }
  
  return TRUE;
}

// BT709 module impl

+ (BOOL) convertSoftware:(uint32_t*)inBGRAPixels
  outBT709Pixels:(uint32_t*)outBT709Pixels
           width:(int)width
          height:(int)height
{
  
  for (int row = 0; row < height; row++) {
    for (int col = 0; col < width; col++) {
      int offset = (row * width) + col;
      uint32_t inPixel = inBGRAPixels[offset];
      
      uint32_t B = (inPixel & 0xFF);
      uint32_t G = ((inPixel >> 8) & 0xFF);
      uint32_t R = ((inPixel >> 16) & 0xFF);
      
      int Y, Cb, Cr;
      
      int result = BT709_from_sRGB_convertRGBToYCbCr(
                                          R,
                                          G,
                                          B,
                                          &Y,
                                          &Cb,
                                          &Cr,
                                          1);
      assert(result == 0);
      
      uint32_t Yu = Y;
      uint32_t Cbu = Cb;
      uint32_t Cru = Cr;
      
      uint32_t outPixel = (Cru << 16) | (Cbu << 8) | Yu;
      
      outBT709Pixels[offset] = outPixel;
    }
  }
  
  return TRUE;
}

+ (BOOL) unconvertSoftware:(uint32_t*)inBT709Pixels
             outBGRAPixels:(uint32_t*)outBGRAPixels
                     width:(int)width
                    height:(int)height
{
  
  for (int row = 0; row < height; row++) {
    for (int col = 0; col < width; col++) {
      int offset = (row * width) + col;
      uint32_t inPixel = inBT709Pixels[offset];
      
      uint32_t Y = (inPixel & 0xFF);
      uint32_t Cb = ((inPixel >> 8) & 0xFF);
      uint32_t Cr = ((inPixel >> 16) & 0xFF);
      
      int Ri, Gi, Bi;
      
      int result = BT709_to_sRGB_convertYCbCrToRGB(
                                                   Y,
                                                   Cb,
                                                   Cr,
                                                   &Ri,
                                                   &Gi,
                                                   &Bi,
                                                   1);
      assert(result == 0);
      
      uint32_t Ru = Ri;
      uint32_t Gu = Gi;
      uint32_t Bu = Bi;
      
      uint32_t outPixel = (Ru << 16) | (Gu << 8) | Bu;
      
      outBGRAPixels[offset] = outPixel;
    }
  }
  
  return TRUE;
}

// vImage based implementation, this implementation makes
// use of CoreGraphics to implement reading of sRGB pixels
// and writing of BT.709 formatted CoreVideo pixel buffers.

+ (BOOL) convertVimage:(uint32_t*)inBGRAPixels
          outBT709Pixels:(uint32_t*)outBT709Pixels
                   width:(int)width
                  height:(int)height
{
  CGImageRef inputImageRef;
  
  CGFrameBuffer *inputFB = [CGFrameBuffer cGFrameBufferWithBppDimensions:24 width:width height:height];
  
  memcpy(inputFB.pixels, inBGRAPixels, width*height*sizeof(uint32_t));
  
  inputImageRef = [inputFB createCGImageRef];
  
  inputFB = nil;
  
  // Copy data into a CoreVideo buffer which will be wrapped into a CGImageRef
  
  CVPixelBufferRef cvPixelBuffer = [self createYCbCrFromCGImage:inputImageRef];
  
  CGImageRelease(inputImageRef);
  
  // Copy (Y Cb Cr) as (c0 c1 c2) in (c3 c2 c1 c0)
  
  NSMutableData *Y = [NSMutableData data];
  NSMutableData *Cb = [NSMutableData data];
  NSMutableData *Cr = [NSMutableData data];
  
  const BOOL dump = FALSE;

  [self copyYCBCr:cvPixelBuffer Y:Y Cb:Cb Cr:Cr dump:dump];

  // Dump (Y Cb Cr) of first pixel
  
  uint8_t *yPtr = (uint8_t *) Y.bytes;
  uint8_t *cbPtr = (uint8_t *) Cb.bytes;
  uint8_t *crPtr = (uint8_t *) Cr.bytes;
  
  if ((0)) {
    int Y = yPtr[0];
    int Cb = cbPtr[0];
    int Cr = crPtr[0];
    printf("first pixel (Y Cb Cr) (%3d %3d %3d)\n", Y, Cb, Cr);
  }
  
  // Copy (Y Cb Cr) to output BGRA buffer and undo subsampling
  
  if (1) {
    const int yRowBytes = (int) width;
    const int cbRowBytes = (int) width / 2;
    const int crRowBytes = (int) width / 2;
    
    const int debug = 0;
    
    if (debug) {
    printf("destYBuffer %d x %d : YCbCr\n", width, height);
    }
    
    for (int row = 0; row < height; row++) {
      uint8_t *rowYPtr = yPtr + (row * yRowBytes);
      uint8_t *rowCbPtr = cbPtr + (row/2 * cbRowBytes);
      uint8_t *rowCrPtr = crPtr + (row/2 * crRowBytes);
      
      uint32_t *outRowPtr = outBT709Pixels + (row * width);
      
      for (int col = 0; col < width; col++) {
        uint32_t Y = rowYPtr[col];
        uint32_t Cb = rowCbPtr[col / 2];
        uint32_t Cr = rowCrPtr[col / 2];
        
        if (debug) {
          printf("Y Cb Cr (%3d %3d %3d)\n", Y, Cb, Cr);
        }
        
        uint32_t outPixel = (Cr << 16) | (Cb << 8) | Y;
        outRowPtr[col] = outPixel;
      }
    }
  }
  
  CVPixelBufferRelease(cvPixelBuffer);
  
  return TRUE;
}

+ (BOOL) unconvertVimage:(uint32_t*)inBT709Pixels
             outBGRAPixels:(uint32_t*)outBGRAPixels
                     width:(int)width
                    height:(int)height
{
  const int debug = 0;
  
  // Copy (Y Cb Cr) from c0 c1 c2 and then subsample into CoreVideo buffer
  
  CGSize size = CGSizeMake(width, height);
  
  // FIXME: pixel buffer pool here?
  
  CVPixelBufferRef cvPixelBuffer = [self createCoreVideoYCbCrBuffer:size];
  
  BOOL worked = [self setBT709Attributes:cvPixelBuffer];
  NSAssert(worked, @"worked");

  // Write input YCBCr pixels as subsampled planes in the CoreVideo buffer
  
  [self copyBT709ToCoreVideo:inBT709Pixels cvPixelBuffer:cvPixelBuffer];

  // Convert from YCbCr and write as sRGB pixels
  
  vImage_Buffer dstBuffer;
  
  worked = [self convertFromCoreVideoBuffer:cvPixelBuffer bufferPtr:&dstBuffer];
  NSAssert(worked, @"worked");
  
  CVPixelBufferRelease(cvPixelBuffer);

  // Copy BGRA pixels from dstBuffer to outBGRAPixels
  
  const int dstRowBytes = (int) dstBuffer.rowBytes;
  
  if (0) {
    printf("destBuffer %d x %d : R G B A\n", width, height);
    
    for (int row = 0; row < height; row++) {
      uint32_t *inRowPtr = (uint32_t*) (((uint8_t*)dstBuffer.data) + (row * dstRowBytes));
      
      for (int col = 0; col < width; col++) {
        uint32_t inPixel = inRowPtr[col];
        
        uint32_t B = (inPixel & 0xFF);
        uint32_t G = ((inPixel >> 8) & 0xFF);
        uint32_t R = ((inPixel >> 16) & 0xFF);
        uint32_t A = ((inPixel >> 24) & 0xFF);
        
        printf("R G B A (%3d %3d %3d %3d)\n", R, G, B, A);
      }
    }
  }
  
  // Copy from conversion buffer to output pixels
  
  for (int row = 0; row < height; row++) {
    uint8_t *outPtr = (((uint8_t*)outBGRAPixels) + (row * width * sizeof(uint32_t)));
    uint8_t *inPtr = (((uint8_t*)dstBuffer.data) + (row * dstRowBytes));
    memcpy(outPtr, inPtr, width * sizeof(uint32_t));
  }

  // Free allocated bufers
  
  free(dstBuffer.data);
  
  return TRUE;
}

// Set the proper attributes on a CVPixelBufferRef so that vImage
// is able to render directly into BT.709 formatted YCbCr planes.

+ (BOOL) setBT709Attributes:(CVPixelBufferRef)cvPixelBuffer
{
  // FIXME: UHDTV : HEVC uses kCGColorSpaceITUR_2020
  
  CGColorSpaceRef yuvColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
  
  // Attach BT.709 info to pixel buffer
  
  //CFDataRef colorProfileData = CGColorSpaceCopyICCProfile(yuvColorSpace); // deprecated
  CFDataRef colorProfileData = CGColorSpaceCopyICCData(yuvColorSpace);
  
  // FIXME: "CVImageBufferChromaSubsampling" read from attached H.264 (.m4v) is "TopLeft"
  // kCVImageBufferChromaLocationTopFieldKey = kCVImageBufferChromaLocation_TopLeft
  
  NSDictionary *pbAttachments = @{
                                  (__bridge NSString*)kCVImageBufferChromaLocationTopFieldKey: (__bridge NSString*)kCVImageBufferChromaLocation_Center,
                                  (__bridge NSString*)kCVImageBufferAlphaChannelIsOpaque: (id)kCFBooleanTrue,
                                  
                                  (__bridge NSString*)kCVImageBufferYCbCrMatrixKey: (__bridge NSString*)kCVImageBufferYCbCrMatrix_ITU_R_709_2,
                                  (__bridge NSString*)kCVImageBufferColorPrimariesKey: (__bridge NSString*)kCVImageBufferColorPrimaries_ITU_R_709_2,
                                  (__bridge NSString*)kCVImageBufferTransferFunctionKey: (__bridge NSString*)kCVImageBufferTransferFunction_ITU_R_709_2,
                                  // Note that icc profile is required to enable gamma mapping
                                  (__bridge NSString*)kCVImageBufferICCProfileKey: (__bridge NSData *)colorProfileData,
                                  };
  
  CVBufferRef pixelBuffer = cvPixelBuffer;
  
  CVBufferSetAttachments(pixelBuffer, (__bridge CFDictionaryRef)pbAttachments, kCVAttachmentMode_ShouldPropagate);
  
  // Drop ref to NSDictionary to enable explicit checking of ref count of colorProfileData, after the
  // release below the colorProfileData must be 1.
  pbAttachments = nil;
  CFRelease(colorProfileData);
  
  CGColorSpaceRelease(yuvColorSpace);
  
  return TRUE;
}

// Allocate a CoreVideo buffer for use with BT.709 format YCBCr 2 plane data

+ (CVPixelBufferRef) createCoreVideoYCbCrBuffer:(CGSize)size
{
  int width = (int) size.width;
  int height = (int) size.height;
  
  NSDictionary *pixelAttributes = @{
                                    (__bridge NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
                                    (__bridge NSString*)kCVPixelFormatOpenGLESCompatibility : @(YES),
                                    (__bridge NSString*)kCVPixelBufferCGImageCompatibilityKey : @(YES),
                                    (__bridge NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @(YES),
                                    };
  
  CVPixelBufferRef cvPixelBuffer = NULL;
  
  uint32_t yuvImageFormatType;
  //yuvImageFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange; // luma (0, 255)
  yuvImageFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange; // luma (16, 235)
  
  CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                        width,
                                        height,
                                        yuvImageFormatType,
                                        (__bridge CFDictionaryRef)(pixelAttributes),
                                        &cvPixelBuffer);
  
  NSAssert(result == kCVReturnSuccess, @"CVPixelBufferCreate failed");
  
  return cvPixelBuffer;
}

// Copy pixel data from CoreGraphics source into vImage buffer for processing.
// Note that data is copied as original pixel values, for example if the input
// is in linear RGB then linear RGB values are copied over.

+ (BOOL) convertIntoCoreVideoBuffer:(CGImageRef)inputImageRef
                      cvPixelBuffer:(CVPixelBufferRef)cvPixelBuffer
                          bufferPtr:(vImage_Buffer*)bufferPtr
{
  vImageCVImageFormatRef cvImgFormatRef;
  cvImgFormatRef = vImageCVImageFormat_CreateWithCVPixelBuffer(cvPixelBuffer);
  
  // Default to sRGB on both MacOSX and iOS
  //CGColorSpaceRef inputColorspaceRef = NULL;
  CGColorSpaceRef inputColorspaceRef = CGImageGetColorSpace(inputImageRef);
  
  vImage_CGImageFormat rgbCGImgFormat = {
    .bitsPerComponent = 8,
    .bitsPerPixel = 32,
    .bitmapInfo = (CGBitmapInfo)(kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst),
    .colorSpace = inputColorspaceRef,
  };
  
  const CGFloat backgroundColor = 0.0f;
  
  vImage_Flags flags = 0;
  flags = kvImagePrintDiagnosticsToConsole;
  
  vImage_Error err;
  
  // Copy input CoreGraphic image data into vImage buffer and then copy into CoreVideo buffer
  
  err = vImageBuffer_InitWithCGImage(bufferPtr, &rgbCGImgFormat, &backgroundColor, inputImageRef, flags);
  
  NSAssert(err == kvImageNoError, @"vImageBuffer_InitWithCGImage failed");
  
  err = vImageBuffer_CopyToCVPixelBuffer(bufferPtr, &rgbCGImgFormat, cvPixelBuffer, cvImgFormatRef, &backgroundColor, flags);
  
  NSAssert(err == kvImageNoError, @"error in vImageBuffer_CopyToCVPixelBuffer %d", (int)err);
  
  vImageCVImageFormat_Release(cvImgFormatRef);
  
  return TRUE;
}

// Convert the contents of a CoreVideo pixel buffer and write the results
// into the indicated destination vImage buffer.

+ (BOOL) convertFromCoreVideoBuffer:(CVPixelBufferRef)cvPixelBuffer
                          bufferPtr:(vImage_Buffer*)bufferPtr
{
//  int width = (int) CVPixelBufferGetWidth(cvPixelBuffer);
//  int height = (int) CVPixelBufferGetHeight(cvPixelBuffer);
  
  // Default to sRGB on both MacOSX and iOS
  CGColorSpaceRef outputColorspaceRef = NULL;
  
  vImage_CGImageFormat rgbCGImgFormat = {
    .bitsPerComponent = 8,
    .bitsPerPixel = 32,
    .bitmapInfo = (CGBitmapInfo)(kCGBitmapByteOrder32Host | kCGImageAlphaNoneSkipFirst),
    .colorSpace = outputColorspaceRef,
  };

//  const uint32_t bitsPerPixel = 32;
  const CGFloat backgroundColor = 0.0f;
  
  vImage_Flags flags = 0;
  flags = kvImagePrintDiagnosticsToConsole;
  
  vImage_Error err;
  
  vImageCVImageFormatRef cvImgFormatRef = vImageCVImageFormat_CreateWithCVPixelBuffer(cvPixelBuffer);

  NSAssert(cvImgFormatRef, @"vImageCVImageFormat_CreateWithCVPixelBuffer failed");
  
  err = vImageBuffer_InitWithCVPixelBuffer(bufferPtr, &rgbCGImgFormat, cvPixelBuffer, cvImgFormatRef, &backgroundColor, flags);
  
  NSAssert(err == kvImageNoError, @"vImageBuffer_InitWithCVPixelBuffer failed");
  
  vImageCVImageFormat_Release(cvImgFormatRef);
  
  if (err != kvImageNoError) {
    return FALSE;
  }
  
  return TRUE;
}

// Copy Y Cb Cr pixel data from the planes of a CoreVideo pixel buffer.
// Writes Y Cb Cr values to grayscale PNG if dump flag is TRUE.

+ (BOOL) copyYCBCr:(CVPixelBufferRef)cvPixelBuffer
                 Y:(NSMutableData*)Y
                Cb:(NSMutableData*)Cb
                Cr:(NSMutableData*)Cr
              dump:(BOOL)dump
{
  int width = (int) CVPixelBufferGetWidth(cvPixelBuffer);
  int height = (int) CVPixelBufferGetHeight(cvPixelBuffer);

  NSAssert((width % 2) == 0, @"width must be even : got %d", width);
  NSAssert((height % 2) == 0, @"height must be even : got %d", height);
  
  int hw = width / 2;
  int hh = height / 2;

  [Y setLength:width*height];
  [Cb setLength:hw*hh];
  [Cr setLength:hw*hh];
  
  {
    int status = CVPixelBufferLockBaseAddress(cvPixelBuffer, 0);
    assert(status == kCVReturnSuccess);
  }
  
  uint8_t *yOutPtr = (uint8_t *) Y.bytes;
  uint8_t *CbOutPtr = (uint8_t *) Cb.bytes;
  uint8_t *CrOutPtr = (uint8_t *) Cr.bytes;
  
  uint8_t *yPlane = (uint8_t *) CVPixelBufferGetBaseAddressOfPlane(cvPixelBuffer, 0);
  const size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(cvPixelBuffer, 0);
  
  for (int row = 0; row < height; row++) {
    uint8_t *rowPtr = yPlane + (row * yBytesPerRow);
    for (int col = 0; col < width; col++) {
      uint8_t bVal = rowPtr[col];
      
      int offset = (row * width) + col;
      yOutPtr[offset] = bVal;
    }
  }
  
  uint16_t *uvPlane = (uint16_t *) CVPixelBufferGetBaseAddressOfPlane(cvPixelBuffer, 1);
  const size_t cbcrBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(cvPixelBuffer, 1);
  const size_t cbcrPixelsPerRow = cbcrBytesPerRow / sizeof(uint16_t);
  
  for (int row = 0; row < hh; row++) {
    uint16_t *rowPtr = uvPlane + (row * cbcrPixelsPerRow);
    
    for (int col = 0; col < hw; col++) {
      uint16_t bPairs = rowPtr[col];
      uint8_t cbByte = bPairs & 0xFF; // uvPair[0]
      uint8_t crByte = (bPairs >> 8) & 0xFF; // uvPair[1]

      int offset = (row * hw) + col;
      CbOutPtr[offset] = cbByte;
      CrOutPtr[offset] = crByte;
    }
  }
  
  {
    int status = CVPixelBufferUnlockBaseAddress(cvPixelBuffer, 0);
    assert(status == kCVReturnSuccess);
  }
  
#if defined(DEBUG)
  if (dump) {
    NSString *filename = [NSString stringWithFormat:@"dump_Y.png"];
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *path = [tmpDir stringByAppendingPathComponent:filename];
    [self dumpArrayOfGrayscale:(uint8_t*)Y.bytes width:width height:height filename:path];
    NSLog(@"wrote %@ : %d x %d", path, width, height);
  }
  
  if (dump) {
    NSString *filename = [NSString stringWithFormat:@"dump_Cb.png"];
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *path = [tmpDir stringByAppendingPathComponent:filename];
    [self dumpArrayOfGrayscale:(uint8_t*)Cb.bytes width:hw height:hh filename:path];
    NSLog(@"wrote %@ : %d x %d", path, hw, hh);
  }
  
  if (dump) {
    NSString *filename = [NSString stringWithFormat:@"dump_Cr.png"];
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *path = [tmpDir stringByAppendingPathComponent:filename];
    [self dumpArrayOfGrayscale:(uint8_t*)Cr.bytes width:hw height:hh filename:path];
    NSLog(@"wrote %@ : %d x %d", path, hw, hh);
  }
#endif // DEBUG
  
  return TRUE;
}

// Dump the Y Cb Cr elements of a CoreVideo pixel buffer to PNG images
// in the tmp directory.

+ (BOOL) dumpYCBCr:(CVPixelBufferRef)cvPixelBuffer
{
  NSMutableData *Y = [NSMutableData data];
  NSMutableData *Cb = [NSMutableData data];
  NSMutableData *Cr = [NSMutableData data];
  
  [self copyYCBCr:cvPixelBuffer Y:Y Cb:Cb Cr:Cr dump:TRUE];
  
  return TRUE;
}

// Dump grayscale pixels as 24 BPP PNG image

+ (void) dumpArrayOfGrayscale:(uint8_t*)inGrayscalePtr
                        width:(int)width
                       height:(int)height
                     filename:(NSString*)filename
{
  CGFrameBuffer *fb = [CGFrameBuffer cGFrameBufferWithBppDimensions:24 width:width height:height];
  uint32_t *pixelsPtr = (uint32_t *) fb.pixels;
  
  for ( int i = 0; i < (width*height); i++) {
    uint8_t gray = inGrayscalePtr[i];
    uint32_t pixel = byte_to_grayscale24(gray);
    *pixelsPtr++ = pixel;
  }
  
#if TARGET_OS_IPHONE
  // No-op
#else
  CGColorSpaceRef colorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  fb.colorspace = colorspace;
  CGColorSpaceRelease(colorspace);
#endif // TARGET_OS_IPHONE
  
  NSData *pngData = [fb formatAsPNG];
  BOOL worked = [pngData writeToFile:filename atomically:TRUE];
  assert(worked);
  return;
}

// Given a CGImageRef, create a CVPixelBufferRef and render into it,
// format input BGRA data into BT.709 formatted YCbCr at 4:2:0 subsampling.
// This method returns a new CoreVideo buffer on success, otherwise failure.

+ (CVPixelBufferRef) createYCbCrFromCGImage:(CGImageRef)inputImageRef
{
  int width = (int) CGImageGetWidth(inputImageRef);
  int height = (int) CGImageGetHeight(inputImageRef);
  
  CGSize size = CGSizeMake(width, height);

  // FIXME: pixel buffer pool here?
  
  CVPixelBufferRef cvPixelBuffer = [self createCoreVideoYCbCrBuffer:size];

  BOOL worked = [self setBT709Attributes:cvPixelBuffer];
  NSAssert(worked, @"worked");
  
  vImage_Buffer sourceBuffer;
  
  worked = [self convertIntoCoreVideoBuffer:inputImageRef cvPixelBuffer:cvPixelBuffer bufferPtr:&sourceBuffer];
  NSAssert(worked, @"worked");

  if ((0)) {
    uint32_t *pixelPtr = (uint32_t *) sourceBuffer.data;
    uint32_t pixel = pixelPtr[0];
    
    int B = pixel & 0xFF;
    int G = (pixel >> 8) & 0xFF;
    int R = (pixel >> 16) & 0xFF;
    
    printf("first pixel (R G B) : %3d %3d %3d\n", R, G, B);
  }
  
  if ((0)) {
    printf("sourceBuffer %d x %d : R G B\n", width, height);
    
    const int srcRowBytes = sourceBuffer.rowBytes;
    
    for (int row = 0; row < height; row++) {
      uint32_t *rowPtr = (uint32_t*) (((uint8_t*)sourceBuffer.data) + (row * srcRowBytes));
      
      for (int col = 0; col < width; col++) {
        uint32_t inPixel = rowPtr[col];
        
        uint32_t B = (inPixel & 0xFF);
        uint32_t G = ((inPixel >> 8) & 0xFF);
        uint32_t R = ((inPixel >> 16) & 0xFF);
        
        printf("R G B (%3d %3d %3d)\n", R, G, B);
      }
    }
  }
  
  // Manually free() the allocated buffer for sourceBuffer
  
  free(sourceBuffer.data);
  
  // Copy data from CoreVideo pixel buffer planes into flat buffers
  
  if ((0)) {
    NSMutableData *Y = [NSMutableData data];
    NSMutableData *Cb = [NSMutableData data];
    NSMutableData *Cr = [NSMutableData data];
    
    const BOOL dump = TRUE;
    
    [self copyYCBCr:cvPixelBuffer Y:Y Cb:Cb Cr:Cr dump:dump];
    
    if ((1)) {
      // Dump YUV of first pixel
      
      uint8_t *yPtr = (uint8_t *) Y.bytes;
      uint8_t *cbPtr = (uint8_t *) Cb.bytes;
      uint8_t *crPtr = (uint8_t *) Cr.bytes;
      
      int Y = yPtr[0];
      int Cb = cbPtr[0];
      int Cr = crPtr[0];
      printf("first pixel (Y Cb Cr) (%3d %3d %3d)\n", Y, Cb, Cr);
    }
  }
  
  /*
  
  if (1) {
    // Convert the generated Y pixels back to RGB pixels
    // using CoreVideo and capture the results into a PNG.
    
    CGFrameBuffer *fb = [self processYUVTosRGB:cvPixelBuffer];
    
    {
      NSString *filename = [NSString stringWithFormat:@"dump_RGB_from_YUV.png"];
      NSString *tmpDir = NSTemporaryDirectory();
      NSString *path = [tmpDir stringByAppendingPathComponent:filename];
      NSData *pngData = [fb formatAsPNG];
      
      BOOL worked = [pngData writeToFile:path atomically:TRUE];
      assert(worked);
    }
    
    if ((1)) {
      // Dump RGB of first pixel
      uint32_t *pixelPtr = (uint32_t*) fb.pixels;
      uint32_t pixel = pixelPtr[0];
      int B = pixel & 0xFF;
      int G = (pixel >> 8) & 0xFF;
      int R = (pixel >> 16) & 0xFF;
      printf("YUV -> BGRA : first pixel (R G B) (%3d %3d %3d)\n", R, G, B);
    }
  }
   
  */
  
  return cvPixelBuffer;
}

// Copy YCbCr data stored in BGRA pixels into Y CbCr planes in CoreVideo
// pixel buffer.

+ (BOOL) copyBT709ToCoreVideo:(uint32_t*)inBT709Pixels
                cvPixelBuffer:(CVPixelBufferRef)cvPixelBuffer
{
  const int debug = 0;
  
  int width = (int) CVPixelBufferGetWidth(cvPixelBuffer);
  int height = (int) CVPixelBufferGetHeight(cvPixelBuffer);
  
  {
    {
      int status = CVPixelBufferLockBaseAddress(cvPixelBuffer, 0);
      assert(status == kCVReturnSuccess);
    }
    
    uint8_t *yPlane = (uint8_t *) CVPixelBufferGetBaseAddressOfPlane(cvPixelBuffer, 0);
    const size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(cvPixelBuffer, 0);
    
    uint16_t *cbcrPlane = (uint16_t *) CVPixelBufferGetBaseAddressOfPlane(cvPixelBuffer, 1);
    const size_t cbcrBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(cvPixelBuffer, 1);
    const size_t cbcrPixelsPerRow = cbcrBytesPerRow / sizeof(uint16_t);
    
    for (int row = 0; row < height; row++) {
      uint8_t *yRowPtr = yPlane + (row * yBytesPerRow);
      uint16_t *cbcrRowPtr = cbcrPlane + (row/2 * cbcrPixelsPerRow);
      
      for (int col = 0; col < width; col++) {
        int offset = (row * width) + col;
        uint32_t inPixel = inBT709Pixels[offset];
        
        uint32_t Y = inPixel & 0xFF;
        uint32_t Cb = (inPixel >> 8) & 0xFF;
        uint32_t Cr = (inPixel >> 16) & 0xFF;
        
        yRowPtr[col] = Y;
        
        if (debug) {
          printf("Y %3d\n", Y);
        }
        
        if ((col % 2) == 0) {
          int hcol = col / 2;
          cbcrRowPtr[hcol] = (Cr << 8) | (Cb);
          
          if (debug) {
            printf("Cb Cr (%3d %3d)\n", Cb, Cr);
          }
        }
      }
    }
    
    {
      int status = CVPixelBufferUnlockBaseAddress(cvPixelBuffer, 0);
      assert(status == kCVReturnSuccess);
    }
  }
  
  return TRUE;
}

@end
