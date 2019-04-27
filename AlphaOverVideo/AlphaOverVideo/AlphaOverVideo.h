//
//  AlphaOverVideo.h
//  AlphaOverVideo
//
//  Created by Mo DeJong on 4/4/19.
//  Copyright © 2019 Apple. All rights reserved.
//

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
#if TARGET_OS_SIMULATOR
#error No simulator support for Metal API. Must build for a device
#endif
#endif

@import MetalKit;

//! Project version number for AlphaOverVideo.
FOUNDATION_EXPORT double AlphaOverVideoVersionNumber;

//! Project version string for AlphaOverVideo.
FOUNDATION_EXPORT const unsigned char AlphaOverVideoVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <AlphaOverVideo/PublicHeader.h>

#import <AlphaOverVideo/AOVFrame.h>
#import <AlphaOverVideo/AOVPlayer.h>
#import <AlphaOverVideo/AOVMTKView.h>
#import <AlphaOverVideo/AOVDisplayLink.h>
#import <AlphaOverVideo/H264Encoder.h>
