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

@end
