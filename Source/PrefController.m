//
//  PrefController.m
//  Chicken of the VNC
//
//  Created by Bob Newhart on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "PrefController.h"
#import "PrefController_private.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"

#import "GrayScaleFrameBuffer.h"
#import "LowColorFrameBuffer.h"
#import "HighColorFrameBuffer.h"
#import "TrueColorFrameBuffer.h"


// --- Preferences Version --- //
static int const kPrefsVersion = 0x00000001;


@implementation PrefController

#pragma mark Creation and Deletion


+ (void)initialize
{
	NSUserDefaults *defaults;
	NSMutableDictionary *defaultDict;
	NSMutableArray *encodings;
	NSMutableDictionary *encoding;
	NSDictionary *profiles;
	int i;
	
	defaults = [NSUserDefaults standardUserDefaults];
	defaultDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool: YES],			kPrefs_FullscreenWarning_Key,
		[NSNumber numberWithFloat: 26.0],		kPrefs_AutoscrollIncrement_Key,
		[NSNumber numberWithBool: NO],			kPrefs_FullscreenScrollbars_Key,
		[NSNumber numberWithInt: 128],			kPrefs_PSMaxRect_Key,
		[NSNumber numberWithInt: 10000],		kPrefs_PSThreshold_Key,
		[NSNumber numberWithBool: YES],			kPrefs_UseRendezvous_Key,
		[NSNumber numberWithFloat: 0],			kPrefs_FrontFrameBufferUpdateSeconds_Key,
		[NSNumber numberWithFloat: 0.9],		kPrefs_OtherFrameBufferUpdateSeconds_Key, 
		nil,									nil];
	
	// create the encodings for the default profile
	encodings = [NSMutableArray array];
	encoding = [NSMutableDictionary dictionaryWithObject: [NSNumber numberWithBool: YES] 
												  forKey: kProfile_EncodingEnabled_Key];
	for ( i = 0; i < NUMENCODINGS; ++i )
	{
		[encoding setObject: [NSNumber numberWithInt: gEncodingValues[i]] forKey: kProfile_EncodingValue_Key];
		[encodings addObject: [[encoding copy] autorelease]];
	}
		
	// create the default profile
	NSString *profileName = NSLocalizedString(@"defaultProfileName", nil);;
	NSDictionary *profile = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: 0],						kProfile_PixelFormat_Key,
		[NSNumber numberWithInt: 50],						kProfile_E3BTimeout_Key,
		[NSNumber numberWithInt: 250],						kProfile_EmulateKeyDown_Key,
		[NSNumber numberWithInt: 5],						kProfile_EmulateKeyboard_Key,
		[NSNumber numberWithBool: YES],						kProfile_EnableCopyrect_Key,
		encodings,											kProfile_Encodings_Key,
		[NSNumber numberWithShort: kRemoteMetaModifier],	kProfile_LocalAltModifier_Key,
		[NSNumber numberWithShort: kRemoteAltModifier],		kProfile_LocalCommandModifier_Key,
		[NSNumber numberWithShort: kRemoteControlModifier],	kProfile_LocalControlModifier_Key,
		[NSNumber numberWithShort: kRemoteShiftModifier],	kProfile_LocalShiftModifier_Key,
		[NSNumber numberWithBool: YES],						kProfile_IsDefault_Key,
		nil,												nil];
	profiles = [NSDictionary dictionaryWithObject: profile forKey: profileName];
	[defaultDict setObject: profiles forKey: kPrefs_ConnectionProfiles_Key];
	
	[defaults registerDefaults: defaultDict];
}


+ (id)sharedController
{
	static id sInstance = nil;
	if ( ! sInstance )
	{
		sInstance = [[self alloc] init];
		NSParameterAssert( sInstance != nil );
	}
	return sInstance;
}


- (id)init
{
	if ( self = [super init] )
	{
		[self autorelease];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		int prefsVersion = [[defaults objectForKey: kPrefs_Version_Key] intValue];
		BOOL badPrefsVersion = (kPrefsVersion > prefsVersion);
		if ( 0x00000000 == prefsVersion )
		{
			// update for 2.0b2
			[self _updatePrefs_20b2];
			prefsVersion = 0x00000001;
		}
		
		if ( badPrefsVersion )
			[defaults setObject: [NSNumber numberWithInt: kPrefsVersion] forKey: kPrefs_Version_Key];
		
		[self retain];
	}
	return self;
}


#pragma mark -
#pragma mark Settings


- (BOOL)displayFullScreenWarning
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_FullscreenWarning_Key] boolValue];  }
	

- (float)fullscreenAutoscrollIncrement
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_AutoscrollIncrement_Key] floatValue];  }


- (BOOL)fullscreenHasScrollbars
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_FullscreenScrollbars_Key] boolValue];  }


- (int)PS_THRESHOLD
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_PSThreshold_Key] intValue];  }


- (int)PS_MAXRECTS
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_PSMaxRect_Key] intValue];  }


- (float)frontFrameBufferUpdateSeconds
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_FrontFrameBufferUpdateSeconds_Key] floatValue];  }


- (float)otherFrameBufferUpdateSeconds
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_OtherFrameBufferUpdateSeconds_Key] floatValue];  }


- (void)getLocalPixelFormat:(rfbPixelFormat*)pf
{
    id fbc = [self defaultFrameBufferClass];
    [fbc getPixelFormat:pf];
}

- (float)gammaCorrection
{
	// we won't need this method once we move to a sane way of drawing into our local buffer
	return 1.1;
}


- (id)defaultFrameBufferClass
{
	// we won't need this method once we move to a sane way of drawing into our local buffer
	NSWindowDepth windowDepth = [[NSScreen deepestScreen] depth];
	if( 1 == NSNumberOfColorComponents(NSColorSpaceFromDepth(windowDepth)) )
		return [GrayScaleFrameBuffer class];

	int bpp = NSBitsPerPixelFromDepth( windowDepth );
	if ( bpp <= 8 )
		return [LowColorFrameBuffer class];
	if ( bpp <= 16 )
		return [HighColorFrameBuffer class];
	return [TrueColorFrameBuffer class];
}

- (float)maxPossibleFrameBufferUpdateSeconds;
{
	// this is a bit ugly - our window might not be loaded yet, so if it's not, hardcode the value, yick
	if ( mWindow )
		return [mFrontInverseCPUSlider maxValue];
	return 1;
}


- (BOOL)usesRendezvous
{  return [[[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_UseRendezvous_Key] boolValue];  }


- (NSDictionary *)hostInfo
{  return [[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_HostInfo_Key];  }


- (void)setHostInfo: (NSDictionary *)dict
{  [[NSUserDefaults standardUserDefaults] setObject: dict forKey: kPrefs_HostInfo_Key];  }


- (NSString *)lastHostName
{  return [[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_LastHost_Key];  }


- (NSDictionary *)profileDict
{  return [[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_ConnectionProfiles_Key];  }


- (void)setProfileDict: (NSDictionary *)dict
{  [[NSUserDefaults standardUserDefaults] setObject: dict forKey: kPrefs_ConnectionProfiles_Key];  }


#pragma mark -
#pragma mark Preferences Window


- (void)showWindow
{
	[self _setupWindow];
	[mWindow makeKeyAndOrderFront: nil];
}


#pragma mark -
#pragma mark Action Methods


- (IBAction)frontInverseCPUSliderChanged: (NSSlider *)sender
{
	float updateDelay = [sender floatValue];
	updateDelay = (float)[sender maxValue] - updateDelay;
	[[NSUserDefaults standardUserDefaults] setFloat: updateDelay forKey: kPrefs_FrontFrameBufferUpdateSeconds_Key];
	[[RFBConnectionManager sharedManager] setFrontWindowUpdateInterval: updateDelay];
}

- (IBAction)otherInverseCPUSliderChanged: (NSSlider *)sender
{
	float updateDelay = [sender floatValue];
	updateDelay = (float)[sender maxValue] - updateDelay;
	[[NSUserDefaults standardUserDefaults] setFloat: updateDelay forKey: kPrefs_OtherFrameBufferUpdateSeconds_Key];
	[[RFBConnectionManager sharedManager] setOtherWindowUpdateInterval: updateDelay];
}


- (IBAction)autoscrollSpeedChanged: (NSSlider *)sender
{
	float value = floor([sender floatValue] + 0.5);
	[[NSUserDefaults standardUserDefaults] setFloat: value forKey: kPrefs_AutoscrollIncrement_Key];
}


- (IBAction)toggleFullscreenScrollbars: (NSButton *)sender
{
	BOOL value = ([sender state] == NSOnState) ? YES : NO;
	[[NSUserDefaults standardUserDefaults] setBool: value forKey: kPrefs_FullscreenScrollbars_Key];
}


- (IBAction)toggleFullscreenWarning: (NSButton *)sender
{
	BOOL value = ([sender state] == NSOnState) ? YES : NO;
	[[NSUserDefaults standardUserDefaults] setBool: value forKey: kPrefs_FullscreenWarning_Key];
}


- (IBAction)toggleUseRendezvous: (id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL use = ! [[defaults objectForKey: kPrefs_UseRendezvous_Key] boolValue];
	[defaults setBool: use forKey: kPrefs_UseRendezvous_Key];

	[[RFBConnectionManager sharedManager] useRendezvous: use];
}

@end
