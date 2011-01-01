//
//  PrefController.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "rfbproto.h"


@interface PrefController : NSObject {
	IBOutlet NSWindow *mWindow;
	IBOutlet NSSlider *mAutoscrollIncrement;
	IBOutlet NSButton *mFullscreenScrollbars;
	IBOutlet NSButton *mDisplayFullscreenWarning;
	IBOutlet NSSlider *mFrontInverseCPUSlider;
	IBOutlet NSSlider *mOtherInverseCPUSlider;
}

	// Creation
+ (id)sharedController;

	// Settings
- (BOOL)displayFullScreenWarning;
- (void)setDisplayFullScreenWarning:(BOOL)warn;
- (float)fullscreenAutoscrollIncrement;
- (BOOL)fullscreenHasScrollbars;
- (float)frontFrameBufferUpdateSeconds;
- (float)otherFrameBufferUpdateSeconds;
- (float)gammaCorrection;
- (void)getLocalPixelFormat:(rfbPixelFormat*)pf;
- (id)defaultFrameBufferClass;
- (float)maxPossibleFrameBufferUpdateSeconds;
- (BOOL)usesRendezvous;
- (NSDictionary *)hostInfo;
- (void)setHostInfo: (NSDictionary *)hostInfo;
- (NSDictionary *)profileDict;
- (NSDictionary *)defaultProfileDict;
- (void)setProfileDict: (NSDictionary *)dict;
- (BOOL)autoReconnect;
- (NSTimeInterval)intervalBeforeReconnect;

	// Preferences Window
- (void)showWindow;

	// Action Methods
- (IBAction)frontInverseCPUSliderChanged: (NSSlider *)sender;
- (IBAction)otherInverseCPUSliderChanged: (NSSlider *)sender;
- (IBAction)autoscrollSpeedChanged: (NSSlider *)sender;
- (IBAction)toggleFullscreenScrollbars: (NSButton *)sender;
- (IBAction)toggleFullscreenWarning: (NSButton *)sender;
- (IBAction)toggleUseRendezvous: (id)sender;

@end
