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
#import "PrefController.h"
#import "ServerFromPrefs.h"
#import "ServerFromRendezvous.h"
#import <AppKit/AppKit.h>

#define RFB_PREFS_LOCATION  @"Library/Preferences/cotvnc.prefs"
#define RFB_SERVER_LIST     @"ServerList"
#define RFB_GROUP_LIST		@"GroupList"
#define RFB_SAVED_SERVERS   @"SavedServers"

@implementation ServerDataManager

static ServerDataManager* gInstance = nil;

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
													 name:NSApplicationWillTerminateNotification object:NSApp];
		
		mServers                 = [[NSMutableDictionary alloc] init];
		mGroups                  = [[NSMutableDictionary alloc] init];
		mRendezvousNameToServer  = [[NSMutableDictionary alloc] init];
		
		[mGroups setObject:mServers forKey:@"All"];
		[mGroups setObject:[NSMutableDictionary dictionaryWithCapacity:1] forKey:@"Standard"];
		[mGroups setObject:[NSMutableDictionary dictionaryWithCapacity:1] forKey:@"Rendezvous"];
		
		assert( nil != [mGroups objectForKey:@"All"] );
		assert( mServers == [mGroups objectForKey:@"All"] );
		assert( nil != [mGroups objectForKey:@"Standard"] );
		assert( nil != [mGroups objectForKey:@"Rendezvous"] );
		
		mServiceBrowser = nil;
	}
	
	return self;
}

- (id)initWithOriginalPrefs
{
	if( self = [self init] )
	{
		NSDictionary *hostInfo = [[PrefController sharedController] hostInfo];
		NSEnumerator* hostEnumerator = [hostInfo keyEnumerator];
		NSEnumerator* objEnumerator = [hostInfo objectEnumerator];
		NSString* host;
		NSDictionary* obj;
		while( host = [hostEnumerator nextObject] )
		{
			obj = [objEnumerator nextObject];
			id<IServerData> server = [ServerFromPrefs createWithHost:host preferenceDictionary:obj];
			if( nil != server )
			{
				[server setDelegate:self];
				[mServers setObject:server forKey:[server name]];
			}
		}
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self save];
		
    [mServers release];
	[mGroups release];
	if( nil != mServiceBrowser )
	{
		[mServiceBrowser release];
	}
	
    [super dealloc];
}

- (void)save
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject: gInstance];
	[[NSUserDefaults standardUserDefaults] setObject: data forKey: RFB_SAVED_SERVERS];
}

+ (ServerDataManager*) sharedInstance
{
	if( nil == gInstance )
	{
		NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:RFB_SAVED_SERVERS];
		if ( data )
		{
			gInstance = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			[gInstance retain];
		}
		
		if( nil == gInstance )
		{
			NSString *storePath = [NSHomeDirectory() stringByAppendingPathComponent:RFB_PREFS_LOCATION];
			
			gInstance = [NSKeyedUnarchiver unarchiveObjectWithFile:storePath];
			[gInstance retain];
			if( nil == gInstance )
			{
				// Didn't find any preferences under the new serialization system,
				// load based on the old system
				gInstance = [[ServerDataManager alloc] initWithOriginalPrefs];
				
				[gInstance save];
			}
		}
		
		if( nil == [gInstance getServerAtIndex:0] )
		{
			[gInstance createServerByName:NSLocalizedString(@"RFBDefaultServerName", nil)];
		}
	}
	
	return gInstance;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSParameterAssert( [coder allowsKeyedCoding] );

	[coder encodeObject:mServers forKey:RFB_SERVER_LIST];
	[coder encodeObject:mGroups forKey:RFB_GROUP_LIST];
}

- (id)initWithCoder:(NSCoder *)coder
{
	[self autorelease];
	NSParameterAssert( [coder allowsKeyedCoding] );
	[self retain];
			
	if( self = [self init] )
	{
		[mServers release];
		mServers = [[coder decodeObjectForKey:RFB_SERVER_LIST] retain];
		
		[mGroups release];
		mGroups = [[coder decodeObjectForKey:RFB_GROUP_LIST] retain];
		
		if( nil == mGroups )
		{
			mGroups                  = [[NSMutableDictionary alloc] init];
			[mGroups setObject:[NSMutableDictionary dictionaryWithCapacity:1] forKey:@"Standard"];
			[mGroups setObject:[NSMutableDictionary dictionaryWithCapacity:1] forKey:@"Rendezvous"];
		}

		[mGroups setObject:mServers forKey:@"All"];
		
		assert( nil != [mGroups objectForKey:@"All"] );
		assert( mServers == [mGroups objectForKey:@"All"] );
		assert( nil != [mGroups objectForKey:@"Standard"] );
		assert( nil != [mGroups objectForKey:@"Rendezvous"] );

		
		// This next bit will fix issues where the key and the name
		// didn't always match due to a bug in the name change code.
		// Eventually this should be deleted since the bug was never
		// in a public release.
		BOOL bContinueOuter = YES;
		NSString* key;
		do
		{
			BOOL bContinueInner = YES;
			NSEnumerator* keyEnumerator = [mServers keyEnumerator];
			while( (key = [keyEnumerator nextObject]) && bContinueInner )
			{
				id<IServerData> server = [mServers objectForKey:key];
				if(  NSOrderedSame != [[server name] compare: key] )
				{
					[mServers removeObjectForKey:key];
					[mServers setObject:server forKey:[server name]];
					bContinueInner = NO;
				}
			}
			
			if( nil == key )
			{
				bContinueOuter = NO;
			}
		}while( bContinueOuter );
		
		id<IServerData> server;
		NSEnumerator* objEnumerator = [mServers objectEnumerator];
		while( server = [objEnumerator nextObject] )
		{
			[server setDelegate:self];
		}
	}
	
    return self;
}


- (void)applicationWillTerminate:(NSNotification *)notification
{
	[gInstance release];
}

- (unsigned) serverCount
{
	return [mServers count];
}

- (NSEnumerator*) getServerEnumerator
{
	return [mServers objectEnumerator];
}

- (unsigned) groupCount
{
	return [mGroups count];
}

- (NSEnumerator*) getGroupNameEnumerator
{
	return [mGroups keyEnumerator];
}

- (NSEnumerator*) getServerEnumeratorForGroupName:(NSString*)group;
{
	if( [group compare:@"Standard"] )
	{
		return [mServers objectEnumerator];
	}
	else if( [group compare:@"Rendezvous"] )
	{
		return nil;
	}
	
	return nil;
}

- (id<IServerData>)getServerWithName:(NSString*)name
{
	return [mServers objectForKey:name];
}

- (id<IServerData>)getServerAtIndex:(int)index
{
	if( 0 > index || 0 == [mServers count] )
	{
		return nil;
	}
	
	return [[mServers allValues] objectAtIndex:index];
}

- (void)removeServer:(id<IServerData>)server
{	
	NSString* name;
	NSEnumerator* groupKeys = [mGroups keyEnumerator];
	while( name = [groupKeys nextObject] )
	{
		[[mGroups objectForKey:name] removeObjectForKey:[server name]];
	}
	
	assert( nil == [mServers objectForKey:[server name]] );
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
														object:self];
}

- (void)makeNameUnique:(NSMutableString*)name
{
	if(nil != [mServers objectForKey:name])
	{
		int numHelper = 0;
		NSString* newName;
		do
		{
			numHelper++;
			newName = [NSString stringWithFormat:@"%@_%d", name, numHelper];
		}while( nil != [mServers objectForKey:newName] );
		
		[name setString: newName];
	}
}

- (id<IServerData>)createServerByName:(NSString*)name
{
	NSMutableString *nameHelper = [NSMutableString stringWithString:name];
	
	[self makeNameUnique:nameHelper];
	
	ServerFromPrefs* newServer = [ServerFromPrefs createWithName:nameHelper];
	[mServers setObject:newServer forKey:[newServer name]];
	[[mGroups objectForKey:@"Standard"] setObject:newServer forKey:[newServer name]];
	
	NSParameterAssert( nil != [mServers objectForKey:nameHelper] );
	NSParameterAssert( newServer == [mServers objectForKey:nameHelper] );
	
	[newServer setDelegate:self];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
														object:self];
	
	return newServer;
}

- (void)validateNameChange:(NSMutableString *)name forServer:(id<IServerData>)server;
{
	[(NSObject *)server retain];

	BOOL insertServer = NO;
	NSMutableArray *groupsWithServer = [[[NSMutableArray alloc] init] autorelease];

	// Remove original server/key pair
	//
	// It is possible that the server hasn't been inserted yet, and
	// we are validating a name for a server that will be inserted.
	// If that is the case, the server we find searching on [server name]
	// will not be the same as the server.  In this case, we won't remove
	// the server from the list (because it isn't in the list yet). However,
	// if they are the same, then we are validating a name change and
	// the server needs to be removed before being added.
	if( server == [mServers objectForKey:[server name]] )
	{
		NSString* groupName;
		NSEnumerator* groupKeys = [mGroups keyEnumerator];
		while( groupName = [groupKeys nextObject] )
		{
			NSMutableDictionary *group = [mGroups objectForKey:groupName];
			if( nil != [group objectForKey:[server name]] )
			{
				[group removeObjectForKey:[server name]];
				[groupsWithServer addObject:groupName];
			}
		}

		[mServers removeObjectForKey:[server name]];
		
		insertServer = YES;
	}

	// Check to see if new name is valid and update if it isn't
	if( nil != [mServers objectForKey:name] )
	{
		NSParameterAssert( server != [mServers objectForKey:name] );
		
		[self makeNameUnique:name];
	}
	
	// Insert updated server/key pair
	if( insertServer )
	{
		NSString* groupName;
		NSEnumerator* groupNames = [groupsWithServer objectEnumerator];
		while( groupName = [groupNames nextObject] )
		{
			[[mGroups objectForKey:groupName] setObject:server forKey:name];
		}
		[mServers setObject:server forKey:name];
	}
		
	[(NSObject *)server release];
}

- (void)useRendezvous:(bool)use
{
	if( use != mUsingRendezvous )
	{
		mUsingRendezvous = use;
		
		if( mUsingRendezvous )
		{
			NSParameterAssert( nil == mServiceBrowser );
			
			mServiceBrowser = [[NSNetServiceBrowser alloc] init];
			[mServiceBrowser setDelegate:self];
			[mServiceBrowser searchForServicesOfType:@"_vnc._tcp" inDomain:@""];
		}
		else
		{
			[mServiceBrowser release];
			mServiceBrowser = nil;
			
			NSMutableDictionary *rendezvousDict = [mGroups objectForKey:@"Rendezvous"];
			NSEnumerator *rendEnum = [rendezvousDict keyEnumerator];
			NSString* host;
			while( host = [rendEnum nextObject] )
			{
				[mServers removeObjectForKey:host];
			}
			
			[rendezvousDict removeAllObjects];
			[mRendezvousNameToServer removeAllObjects];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
																object:self];
		}
	}
}

- (bool)getUseRendezvous
{
	return mUsingRendezvous;
}

// Sent when browsing begins
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
    mSearching = YES;	
    //[self updateUI];
}

// Sent when browsing stops
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
    mSearching = NO;
    //[self updateUI];	
}

// Sent if browsing fails
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
			 didNotSearch:(NSDictionary *)errorDict
{
    mSearching = NO;
    //[self handleError:[errorDict objectForKey:NSNetServicesErrorCode]];	
}

// Sent when a service appears
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
		   didFindService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing
{
	ServerFromRendezvous* newServer = [ServerFromRendezvous createWithNetService:aNetService];
	
	// store a quick lookup list that connects the rendezvous name to the server class
	// because the server name will not necessarily match that of the service published
	[mRendezvousNameToServer setObject:newServer forKey:[aNetService name]];
	
	// Set delegate before adding to the server lists so that the server has a chance
	// to appropriately validate the name as defined by the service
	[newServer setDelegate:self];
	
	[mServers setObject:newServer forKey:[newServer name]];
	[[mGroups objectForKey:@"Rendezvous"] setObject:newServer forKey:[newServer name]];
	
	NSParameterAssert( nil != [mServers objectForKey:[newServer name]] );
	NSParameterAssert( nil != [mGroups objectForKey:@"Rendezvous"] );
	NSParameterAssert( nil != [[mGroups objectForKey:@"Rendezvous"] objectForKey:[newServer name]] );
	NSParameterAssert( newServer == [mServers objectForKey:[newServer name]] );
	NSParameterAssert( newServer == [[mGroups objectForKey:@"Rendezvous"] objectForKey:[newServer name]] );
	
    if(!moreComing)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
															object:self];
	}
}

// Sent when a service disappears
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
		 didRemoveService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing
{
	ServerFromRendezvous* serverToRemove = [mRendezvousNameToServer objectForKey:[aNetService name]];
	
	NSParameterAssert( nil != serverToRemove );
	
	[serverToRemove retain];
	
	[[mGroups objectForKey:@"Rendezvous"] removeObjectForKey:[serverToRemove name]];
    [mServers removeObjectForKey:[serverToRemove name]];
	
	[serverToRemove release];
    
    if(!moreComing)
    {		
        [[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
															object:self];
    }	
}

@end
