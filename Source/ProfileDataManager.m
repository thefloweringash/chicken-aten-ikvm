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
		mProfiles = (NSMutableDictionary *)[[PrefController sharedController] profileDict];
		NSParameterAssert( mProfiles != nil );
		mProfiles = [[mProfiles deepMutableCopy] retain];
		NSString* key;
		NSEnumerator* keys = [mProfiles keyEnumerator];

		while((key = [keys nextObject]) != nil) {
			NSMutableDictionary* d = [[[mProfiles objectForKey:key] mutableCopy] autorelease];
			[mProfiles setObject:d forKey:key];
		}
		
		[self updateAllProfiles]; // for the new EventFilter stuff
	}
	
	return self;
}

- (void)dealloc
{
	[mProfiles release];
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

- (NSMutableDictionary *)defaultProfile
{
	return [mProfiles objectForKey: [self defaultProfileName]];
}

- (NSString *)defaultProfileName
{
	NSEnumerator *profileNameEnumerator = [mProfiles keyEnumerator];
	NSString *profileName;
	
	while ( profileName = [profileNameEnumerator nextObject] )
	{
		NSDictionary *profile = [mProfiles objectForKey: profileName];
		if ( [profile objectForKey: kProfile_IsDefault_Key] )
			return profileName;
	}
	[NSException raise: NSInternalInconsistencyException format: @"No default profile could be found"];
	return nil; // never executed
}

- (NSMutableDictionary*)profileForKey:(id)key
{
	return [mProfiles objectForKey:key];
}

- (void)setProfile:(NSMutableDictionary*)profile forKey:(id) key
{
	[mProfiles setObject:profile forKey:key];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ProfileListChangeMsg
														object:self];
}

- (void)removeProfileForKey:(id) key
{
	[mProfiles removeObjectForKey:key];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ProfileListChangeMsg
														object:self];
}

- (int)count
{
	return [mProfiles count];
}

- (void)save
{
	[[PrefController sharedController] setProfileDict: mProfiles];
}

- (NSArray*)sortedKeyArray
{
	return [[mProfiles allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

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

@end
