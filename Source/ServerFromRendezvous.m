//
//  ServerFromRendezvous.m
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

#import "ServerFromRendezvous.h"
#import "sys/socket.h"
#import "netinet/in.h"
#import "arpa/inet.h"
#import "KeyChain.h"

#define RFB_SAVED_RENDEZVOUS_SERVERS @"RFB_SAVED_RENDEZVOUS_SERVERS"

@implementation ServerFromRendezvous

#define KEYCHAIN_ZEROCONF_SERVICE_NAME	@"cotvnc-zeroconf"

+ (id<IServerData>)createWithNetService:(NSNetService*)service
{
	return [[[ServerFromRendezvous alloc] initWithNetService:service] autorelease];
}

- (id)initWithNetService:(NSNetService*)service
{
	if( self = [super init] )
	{
		bHasResolved      = NO;
		bResloveSucceeded = NO;
		
		[service retain];
		service_ = service;
		[service_ setDelegate:self];
		if ( [service respondsToSelector: @selector(resolveWithTimeout:)] )
			[service_ resolveWithTimeout: 5.0]; // Tiger only API
		else
			[service_ resolve];
		
		// Set the initial name. It will have to be validated with the
		// delegate if one is set
		[super setName:[service_ name]];
		
		NSMutableDictionary* rendServerDict = [[NSUserDefaults standardUserDefaults] objectForKey:RFB_SAVED_RENDEZVOUS_SERVERS];
		NSMutableDictionary* propertyDict = [rendServerDict objectForKey:[service_ name]];
		if ( propertyDict )
		{
			[self setRememberPassword: [[propertyDict objectForKey:@"rememberPassword"] boolValue]];
			[self setDisplay:          [[propertyDict objectForKey:@"display"] intValue]];
			[self setShared:           [[propertyDict objectForKey:@"shared"] boolValue]];
			[self setFullscreen:       [[propertyDict objectForKey:@"fullscreen"] boolValue]];
			[self setListenOnly:       [[propertyDict objectForKey:@"listenOnly"] boolValue]];
			[self setLastProfile:       [propertyDict objectForKey:@"lastProfile"]];
		}
	}
	
	return self;
}

- (void)dealloc
{
	[self save];
	[service_ release];
	[super dealloc];
}

- (void)save
{
	// This code is extremely inefficient since we are rebuilding the dictionary of rendezvous servers
	// for each rendezvous server saved.
	
	NSMutableDictionary* propertyDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:_rememberPassword],	[NSString stringWithString:@"rememberPassword"],
		[NSNumber numberWithInt:_display],				[NSString stringWithString:@"display"],
		[NSNumber numberWithBool:_shared],				[NSString stringWithString:@"shared"],
		[NSNumber numberWithBool:_fullscreen],			[NSString stringWithString:@"fullscreen"],
		[NSNumber numberWithBool:_listenOnly],          [NSString stringWithString:@"listenOnly"], 
		_lastProfile,									[NSString stringWithString:@"lastProfile"],
		nil,											nil];

	NSDictionary* defaultServerDict = [[NSUserDefaults standardUserDefaults] objectForKey:RFB_SAVED_RENDEZVOUS_SERVERS];
	NSMutableDictionary* rendServerDict = [NSMutableDictionary dictionaryWithDictionary:defaultServerDict];
	
	if( nil == rendServerDict )
	{
		[[NSUserDefaults standardUserDefaults] setObject:[NSMutableDictionary dictionary] forKey:RFB_SAVED_RENDEZVOUS_SERVERS];
		
		defaultServerDict = [[NSUserDefaults standardUserDefaults] objectForKey:RFB_SAVED_RENDEZVOUS_SERVERS];
		assert( nil != defaultServerDict );
		rendServerDict = [NSMutableDictionary dictionaryWithDictionary:defaultServerDict];
	}
	
	[rendServerDict setObject:propertyDict forKey:[service_ name]];
	[[NSUserDefaults standardUserDefaults] setObject:rendServerDict forKey:RFB_SAVED_RENDEZVOUS_SERVERS];
}

- (bool)doYouSupport: (SUPPORT_TYPE)type
{
	switch( type )
	{
		case EDIT_ADDRESS:
		case EDIT_PORT:
		case EDIT_NAME:
		case DELETE:
		case SERVER_SAVE:
		case ADD_SERVER_ON_CONNECT:
			return NO;
		case EDIT_PASSWORD:
		case SAVE_PASSWORD:
		case CONNECT:
			return (bHasResolved && bResloveSucceeded);
		default:
			// handle all cases
			assert(0);
	}
	
	return NO;
}

- (NSString*)host
{
	if( bHasResolved && bResloveSucceeded )
	{
		int i;
		
		for (i=0;i<[[service_ addresses] count];i++) {
			struct in_addr sinAddr = ((struct sockaddr_in*)[[[service_ addresses] objectAtIndex:i] bytes])->sin_addr;
			if (sinAddr.s_addr != 0)
				return [NSString stringWithCString:inet_ntoa(sinAddr)];
		}
		return NSLocalizedString( @"AddressResolveFailed", nil );
	}
	else if( bHasResolved && !bResloveSucceeded )
	{
		return NSLocalizedString( @"AddressResolveFailed", nil );
	}
	else
	{
		return NSLocalizedString( @"Resolving", nil );
	}
}

- (int)display
{
	if( bHasResolved )
	{
		assert( [[service_ addresses] count] > 0 );
		
		NSData* data = [[service_ addresses] objectAtIndex:0];
		return ((struct sockaddr_in*)[data bytes])->sin_port;
	}
	else
	{
		return 0;
	}
}

- (void)setDelegate: (id<IServerDataDelegate>)delegate;
{
	[super setDelegate:delegate];
	
	// Now that we have a delegate, make sure the name is to the delegates liking
	
	NSMutableString *nameHelper = [NSMutableString stringWithString:[service_ name]];
	
	[_delegate validateNameChange:nameHelper forServer:self];
	
	[super setName:nameHelper];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
	bHasResolved = YES;
	bResloveSucceeded = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
	bHasResolved = YES;
	bResloveSucceeded = YES;
	
	[service_ stop];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
														
	// Finally, load the password
	if( YES == _rememberPassword )
	{
		[self setPassword:[NSString stringWithString:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_ZEROCONF_SERVICE_NAME account:[service_ name]]]];
	}
}

- (void)setPassword: (NSString*)password
{
	[super setPassword:password];
	
	// only save if set to do so
	if( YES == _rememberPassword && YES == bHasResolved && YES == bResloveSucceeded)
	{
		[[KeyChain defaultKeyChain] setGenericPassword:_password forService:KEYCHAIN_ZEROCONF_SERVICE_NAME account:[service_ name]];
	}
}

- (void)setRememberPassword: (bool)rememberPassword
{
	[super setRememberPassword:rememberPassword];
	
	// make sure that the saved password reflects the new remember password setting
	if( YES == bHasResolved && YES == bResloveSucceeded)
	{
		if( YES == _rememberPassword )
		{
			[[KeyChain defaultKeyChain] setGenericPassword:_password forService:KEYCHAIN_ZEROCONF_SERVICE_NAME account:[service_ name]];
		}
		else
		{
			[[KeyChain defaultKeyChain] removeGenericPasswordForService:KEYCHAIN_ZEROCONF_SERVICE_NAME account:[service_ name]];
		}
	}
}

@end
