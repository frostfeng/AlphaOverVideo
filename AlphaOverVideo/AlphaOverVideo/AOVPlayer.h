//
//  AOVPlayer.h
//
//  Created by Mo DeJong on 2/22/19.
//
//  See license.txt for license terms.
//
//  This object is initialized with a specific constructor
//  to indicate if a video is 24 BPP or 32 BPP (alpha channel)
//  video.

@import Foundation;
@import AVFoundation;
@import CoreVideo;
@import CoreImage;
@import CoreMedia;
@import VideoToolbox;

#import "AOVGamma.h"

NS_ASSUME_NONNULL_BEGIN

// AOVFrame class

@interface AOVPlayer : NSObject

// This property is set automatically by the type
// of asset clips passed into the player.

@property (nonatomic, readonly) BOOL hasAlphaChannel;

// The gamma setting to use when decoding the gamma curve used
// by the YCbCr encoding in the H.264 file. This property defaults
// to MetalBT709GammaSRGB, if the H.264 file is not encoded with
// sRGB gamma then this property should be set to either
// MetalBT709GammaApple or MetalBT709GammaLinear.

@property (nonatomic, assign) AOVGamma decodeGamma;

// This block will be invoked on the main thread when the
// dimensions of the video become available.

@property (nonatomic, copy, nullable) void (^videoSizeReadyBlock)(CGSize pixelSize, CGSize pointSize);

// This block will be invoked on the main thread when video playback
// is finished. For a single video, this is at the end of the video.
// For a set of clips, the finished callback is invoked after all
// clips are finished (including a set number of loops)

@property (nonatomic, copy, nullable) void (^videoPlaybackFinishedBlock)(void);

// Create player with a single asset, at the
// end of the clip, playback is stopped.
// This method accepts either a NSURL*
// or a NSArray tuple that contains two NSURLs.

+ (AOVPlayer* _Nullable) playerWithClip:(id _Nonnull)assetURLOrPair;

// Create player with multiple assets, the clips
// are played one after another with seamless transtions
// between each clip. Playback is stopped after each
// clip has been played.

+ (AOVPlayer* _Nullable) playerWithClips:(NSArray* _Nonnull)assetURLs;

// Create player with a single asset that is looped
// over and over.

+ (AOVPlayer* _Nullable) playerWithLoopedClip:(id _Nonnull)assetURLOrPair;

// Create player with multiple assets, seamless looping
// is used from clip to clip and the entire set of
// clips is looped at the end.

+ (AOVPlayer* _Nullable) playerWithLoopedClips:(NSArray* _Nonnull)assetURLs;

// Create player with a single asset, at the
// end of the clip playback is stopped.

- (NSString* _Nonnull) description;

// Create NSURL given an asset filename.

+ (NSURL* _Nullable) urlFromAsset:(NSString* _Nonnull)resFilename;

@end

NS_ASSUME_NONNULL_END

