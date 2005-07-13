//
//  PrefController_private.m
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "PrefController_private.h"
#import "NSObject_Chicken.h"
#import "ProfileManager.h"


// --- Preference Keys --- //
NSString *kPrefs_FullscreenWarning_Key = @"DisplayFullscreenWarning";
NSString *kPrefs_AutoscrollIncrement_Key = @"FullscreenAutoscrollIncrement";
NSString *kPrefs_FullscreenScrollbars_Key = @"FullscreenScrollbars";
NSString *kPrefs_PSMaxRect_Key = @"PS_MAXRECTS";
NSString *kPrefs_PSThreshold_Key = @"PS_THRESHOLD";
NSString *kPrefs_UseRendezvous_Key = @"Rendezvous Setting";
NSString *kPrefs_ConnectionProfiles_Key = @"ConnectProfiles";
NSString *kPrefs_FrontFrameBufferUpdateSeconds_Key = @"FrontFrameBufferUpdateSeconds";
NSString *kPrefs_OtherFrameBufferUpdateSeconds_Key = @"OtherFrameBufferUpdateSeconds";
NSString *kPrefs_HostInfo_Key = @"HostPreferences";
NSString *kPrefs_LastHost_Key = @"RFBLastHost";
NSString *kPrefs_Version_Key = @"Version";
NSString *kPrefs_AutoReconnect_Key = @"AutoReconnect";
NSString *kPrefs_IntervalBeforeReconnect_Key = @"IntervalBeforeReconnect";


// Note: Preference Keys that start with "Listener"
// are defined and used in ListenerController


@implementation PrefController (Private)

#pragma mark Preference Updating


- (void)_updatePrefs_20b2
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *profiles = [defaults objectForKey: kPrefs_ConnectionProfiles_Key];
	if ( profiles )
	{
		profiles = [profiles deepMutableCopy];
		NSEnumerator *profileNameEnumerator = [profiles keyEnumerator];
		NSString *profileName;
		while ( profileName = [profileNameEnumerator nextObject] )
		{
			NSMutableDictionary *profile = [profiles objectForKey: profileName];
			
			int enableMask = [[profile objectForKey: @"EnabledEncodings"] intValue];
			NSArray *encodings = [profile objectForKey: kProfile_Encodings_Key];
			if ( ! encodings )
			{
				[profiles removeObjectForKey: profileName];
				continue;
			}
			
			NSMutableArray *newEncodings = [NSMutableArray array];
			NSEnumerator *encodingEnumerator = [encodings objectEnumerator];
			NSDictionary *encoding;
			while ( encoding = [encodingEnumerator nextObject] )
			{
				if ( ! [encoding isKindOfClass: [NSDictionary class]] )
				{
					int encValue = [(NSString *)encoding intValue];
					NSParameterAssert( encValue >= 0 && encValue < NUMENCODINGS );
					BOOL enabled = (enableMask & (1 << encValue)) ? YES : NO;
					
					switch (encValue)
					{
						case 0:		encValue = 1;		break;
						case 1:		encValue = 2;		break;
						case 2:		encValue = 0;		break;
						case 5:		encValue = 6;		break;
						case 6:		encValue = 5;		break;
					}
					
					encoding = [NSMutableDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithInt: gEncodingValues[encValue]],	kProfile_EncodingValue_Key, 
						[NSNumber numberWithBool: enabled],						kProfile_EncodingEnabled_Key, 
						nil,													nil];
				}
				[newEncodings addObject: encoding];
			}
			[profile setObject: newEncodings forKey: kProfile_Encodings_Key];

			NSNumber *value;
			value = [profile objectForKey: kProfile_PixelFormat_Key];
			if ( ! value )
				[profile setObject: [NSNumber numberWithInt: 0] forKey: kProfile_PixelFormat_Key];
			value = [profile objectForKey: kProfile_EnableCopyrect_Key];
			if ( ! value || ! [value isKindOfClass: [NSNumber class]] )
				[profile setObject: [NSNumber numberWithBool: YES] forKey: kProfile_EnableCopyrect_Key];

			[profile removeObjectForKey: @"EnabledEncodings"];
		}
		
		id defaultProfile = [profiles objectForKey: @"default"];
		if ( defaultProfile )
		{
			[defaultProfile setObject: [NSNumber numberWithBool: YES] forKey: kProfile_IsDefault_Key];
			NSString *name = NSLocalizedString(@"defaultProfileName", nil);
			[profiles setObject: defaultProfile forKey: name];
			[profiles removeObjectForKey: @"default"];
		}
		[defaults setObject: profiles forKey: kPrefs_ConnectionProfiles_Key];
	}

}


#pragma mark -
#pragma mark Preferences Window


- (void)_setupWindow
{
	if ( mWindow )
		return;
	[NSBundle loadNibNamed: @"Preferences" owner: self];
	
	// set our controls' default values
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[mAutoscrollIncrement setFloatValue: [defaults floatForKey: kPrefs_AutoscrollIncrement_Key]];
    [mFullscreenScrollbars setState: [defaults boolForKey: kPrefs_FullscreenScrollbars_Key] ? NSOnState : NSOffState];
    
	float updateDelay;
    updateDelay = [defaults floatForKey: kPrefs_FrontFrameBufferUpdateSeconds_Key];
    updateDelay = (float)[mFrontInverseCPUSlider maxValue] - updateDelay;
    [mFrontInverseCPUSlider setFloatValue: updateDelay];
    updateDelay = [defaults floatForKey: kPrefs_OtherFrameBufferUpdateSeconds_Key];
    updateDelay = (float)[mOtherInverseCPUSlider maxValue] - updateDelay;
    [mOtherInverseCPUSlider setFloatValue: updateDelay];
	[mDisplayFullscreenWarning setState: [defaults boolForKey: kPrefs_FullscreenWarning_Key]];
}

@end
