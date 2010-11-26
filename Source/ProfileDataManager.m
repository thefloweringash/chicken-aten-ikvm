//
//  ProfileDataManager.m
//  Chicken of the VNC
//
//  Created by Jared McIntyre on 8/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "ProfileDataManager.h"
#import "NSObject_Chicken.h"
#import "ProfileManager.h"
#import "PrefController.h"


@implementation ProfileDataManager

- (id)init
{
	if( self = [super init] )
	{
		NSDictionary *dict = [[PrefController sharedController] profileDict];
        mProfileDicts = [[NSMutableDictionary alloc] initWithDictionary:dict];

        mProfiles = [[NSMutableDictionary alloc] init];
		NSString* key;
		NSEnumerator* keys = [mProfileDicts keyEnumerator];

		while((key = [keys nextObject]) != nil) {
			NSMutableDictionary* d = [mProfileDicts objectForKey:key];
            Profile *p = [[Profile alloc] initWithDictionary:d name:key];
            [mProfiles setObject:p forKey:key];
            [p release];
		}

		//[self updateAllProfiles]; // for the new EventFilter stuff
	}
	
	return self;
}

- (void)dealloc
{
	[mProfiles release];
    [mProfileDicts release];
	[super dealloc];
}

+ (ProfileDataManager*) sharedInstance
{
	static id sInstance = nil;
	if( nil == sInstance )
	{
		sInstance = [[ProfileDataManager alloc] init];
	}
	
	return sInstance;
}

- (Profile *)defaultProfile
{
	return [mProfiles objectForKey: [self defaultProfileName]];
}

- (NSString *)defaultProfileName
{
	NSEnumerator *profileNameEnumerator = [mProfiles keyEnumerator];
	NSString *profileName;
	
	while ( profileName = [profileNameEnumerator nextObject] )
	{
		Profile *profile = [mProfiles objectForKey: profileName];
		if ( [profile isDefault] )
			return profileName;
	}
	[NSException raise: NSInternalInconsistencyException format: @"No default profile could be found"];
	return nil; // never executed
}

- (Profile*)profileForKey:(id)key
{
	return [mProfiles objectForKey:key];
}

- (BOOL)profileWithNameExists:(NSString *)name
{
    Profile* p = [mProfiles objectForKey: name];
	
    return nil != p;
}

- (void)setProfile:(Profile*)profile forKey:(id) key
{
	[mProfiles setObject:profile forKey:key];
    [mProfileDicts setObject:[profile dictionary] forKey:key];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ProfileListChangeMsg
														object:self];
	[[PrefController sharedController] setProfileDict: mProfileDicts];
}

- (void)removeProfileForKey:(id) key
{
	[mProfiles removeObjectForKey:key];
    [mProfileDicts removeObjectForKey:key];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ProfileListChangeMsg
														object:self];
	[[PrefController sharedController] setProfileDict: mProfileDicts];
}

- (int)count
{
	return [mProfiles count];
}

/* Invoked when profile has changed, so that it can be saved to preferences. */
- (void)saveProfile: (Profile *)profile
{
    [mProfileDicts setObject:[profile dictionary] forKey:[profile profileName]];
	[[PrefController sharedController] setProfileDict: mProfileDicts];
}

- (NSArray*)sortedKeyArray
{
	return [[mProfiles allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

#if 0
- (void)updateAllProfiles
{
	NSString* key;
	NSEnumerator* keys = [mProfiles keyEnumerator];
	NSDictionary *defaultProfile = [[PrefController sharedController] defaultProfileDict];
	
	while( key = [keys nextObject] )
	{
		NSMutableDictionary* d = [mProfiles objectForKey:key];
		id button2EmulationScenario = [d objectForKey: kProfile_Button2EmulationScenario_Key];
		if ( ! button2EmulationScenario )
		{
			NSString *entryName;

			entryName = kProfile_Button2EmulationScenario_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_Button3EmulationScenario_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_ClickWhileHoldingModifierForButton2_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_MultiTapModifierForButton2_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_MultiTapDelayForButton2_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_MultiTapCountForButton2_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_TapAndClickModifierForButton2_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_TapAndClickButtonSpeedForButton2_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_TapAndClickTimeoutForButton2_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_ClickWhileHoldingModifierForButton3_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_MultiTapModifierForButton3_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_MultiTapDelayForButton3_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_MultiTapCountForButton3_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_TapAndClickModifierForButton3_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_TapAndClickButtonSpeedForButton3_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
			entryName = kProfile_TapAndClickTimeoutForButton3_Key;
			[d setObject: [[[defaultProfile objectForKey: entryName] copy] autorelease] forKey: entryName];
		}
	}
}
#endif

@end
