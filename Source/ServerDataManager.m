//
//  ServerManager.m
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sat Jan 24 2004.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "ServerDataManager.h"
#import "ServerFromPrefs.h"
#import <AppKit/AppKit.h>

#define RFB_PREFS_LOCATION  @"Library/Preferences/cotvnc.prefs"
#define RFB_HOST_INFO		@"HostPreferences"
#define RFB_SERVER_LIST     @"ServerList"

@implementation ServerDataManager

static ServerDataManager* instance = nil;

+ (void)initialize
{
	[ServerDataManager setVersion:1];
}

- (id)init
{
	if( self = [super init] )
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillTerminate:)
													 name:@"NSApplicationWillTerminateNotification" object:NSApp];
	}
	
	return self;
}

- (id)initWithOriginalPrefs
{
	if( self = [self init] )
	{
		servers = [[NSMutableDictionary alloc] init];
		NSEnumerator* hostEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:RFB_HOST_INFO] keyEnumerator];
		NSEnumerator* objEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:RFB_HOST_INFO] objectEnumerator];
		NSString* host;
		NSDictionary* obj;
		while( host = [hostEnumerator nextObject] )
		{
			obj = [objEnumerator nextObject];
			id<IServerData> server = [ServerFromPrefs createWithHost:host preferenceDictionary:obj];
			if( nil != server )
			{
				[servers setObject:server forKey:[server name]];
			}
		}
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self save];
		
    [servers release];
    [super dealloc];
}

- (void)save
{
	NSString *storePath = [NSHomeDirectory() stringByAppendingPathComponent:RFB_PREFS_LOCATION];
	
	[NSKeyedArchiver archiveRootObject:instance toFile:storePath];	
}

+ (ServerDataManager*) sharedInstance
{
	if( nil == instance )
	{
		NSString *storePath = [NSHomeDirectory() stringByAppendingPathComponent:RFB_PREFS_LOCATION];
		
		instance = [NSKeyedUnarchiver unarchiveObjectWithFile:storePath];
		if( nil == instance )
		{
			// Didn't find any preferences under the new serialization system,
			// load based on the old system
			instance = [[ServerDataManager alloc] initWithOriginalPrefs];
			
			[instance save];
			
			// Now that we've saved to the new format, remove from the old one
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:RFB_HOST_INFO];
		}
		else
		{
			[instance retain];
		}
	}
	
	return instance;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    assert( [coder allowsKeyedCoding] );

	[coder encodeObject:servers forKey:RFB_SERVER_LIST];
    
	return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [self init];
		
	if( nil != self )
	{
		assert( [coder allowsKeyedCoding] );
		
		servers = [[coder decodeObjectForKey:RFB_SERVER_LIST] retain];
	}
	
    return self;
}


- (void)applicationWillTerminate:(NSNotification *)notification
{
	if( nil != instance )
	{
		[instance release];
	}
}

- (NSEnumerator*) getServerEnumerator
{
	return [servers objectEnumerator];
}

- (id<IServerData>)getServerWithName:(NSString*)name
{
	return [servers objectForKey:name];
}

- (id<IServerData>)getServerAtIndex:(int)index
{
	return [[servers allValues] objectAtIndex:index];
}

- (void)removeServer:(id<IServerData>)server
{
	[servers removeObjectForKey:[server name]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
														object:self];
}

- (id<IServerData>)createServerByName:(NSString*)name
{
	if(nil != [servers objectForKey:name])
	{
		int numHelper = 0;
		NSString* newName;
		do
		{
			numHelper++;
			newName = [NSString stringWithFormat:@"%@_%d", name, numHelper];
		}while( nil != [servers objectForKey:newName] );
		name = newName;
	}
	
	ServerFromPrefs* newServer = [ServerFromPrefs createWithName:name];
	[servers setObject:newServer forKey:name];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
														object:self];
	
	return newServer;
}
@end
