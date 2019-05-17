//
//  AOVMTKView.h
//
//  Created by Mo DeJong on 2/22/19.
//
//  See license.txt for license terms.
//
//  This object provides a base class for functionaity required
//  on top of a plain MTKView. This view adds support for
//  rendering from a CoreVideo pixel buffer. A regular RGB (24 BPP)
//  or a special purpose RGBA (32 BPP alpha channel) source can
//  be rendered into this Metal view.

@import Foundation;
@import AVFoundation;
@import CoreVideo;
@import CoreImage;
@import CoreMedia;
@import VideoToolbox;
@import MetalKit;

#import <MetalKit/MTKView.h>

#import "AOVFrame.h"
#import "AOVPlayer.h"

// AOVMTKView extends MTKView

@interface AOVMTKView : MTKView <MTKViewDelegate>

// This method is invoked when the next frame of video is available.

- (void) nextFrameReady:(AOVFrame*)nextFrame;

// Attaching a player to a view will configure the view so that it
// is able to play content generated by the given player.

- (BOOL) attachPlayer:(AOVPlayer*)player;

// Detaching a player disconnects the player output so that it is
// no longer displayed in the view.
// Returns TRUE on success, otherwise FALSE is something went wrong.

- (BOOL) detachPlayer:(AOVPlayer*)player;

@end
