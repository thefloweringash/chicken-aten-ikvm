//
//  ProfileDataManager.m
//  Chicken of the VNC
//
//  Created by Jared McIntyre on 8/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "ProfileDataManager.h"

#define PROFILES			@"ConnectProfiles"

@implementation ProfileDataManager

static ProfileDataManager* gInstance = nil;

- (id)init
{
	if( self = [super init] )
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillTerminate:)
													 name:NSApplicationWillTerminateNotification object:NSApp];
													 
		NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
		if((profiles = [[ud objectForKey:PROFILES] mutableCopy]) != nil) {
			NSString* key;
			NSEnumerator* keys = [profiles keyEnumerator];

			while((key = [keys nextObject]) != nil) {
				NSMutableDictionary* d = [[[profiles objectForKey:key] mutableCopy] autorelease];
				[profiles setObject:d forKey:key];
			}
		}
	}
	
	return self;
}

+ (ProfileDataManager*) sharedInstance
{
	if( nil == gInstance )
	{
		gInstance = [[ProfileDataManager alloc] init];
	}
	
	return gInstance;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[gInstance release];
}

- (NSMutableDictionary*)profileForKey:(id)key
{
	return (NSMutableDictionary*)[profiles objectForKey:key];
}

- (void)setProfile:(NSMutableDictionary*)profile forKey:(id) key
{
	[profiles setObject:profile forKey:key];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ProfileListChangeMsg
														object:self];
}

- (void)removeProfileForKey:(id) key
{
	[profiles removeObjectForKey:key];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ProfileListChangeMsg
														object:self];
}

- (int)count
{
	return [profiles count];
}

- (void)save
{
	[[NSUserDefaults standardUserDefaults] setObject:profiles forKey:PROFILES];
}

- (NSArray*)sortedKeyArray
{
	return [[profiles allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

@end
