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
#import "Profile.h"

#define RFB_SAVED_RENDEZVOUS_SERVERS @"RFB_SAVED_RENDEZVOUS_SERVERS"

@implementation ServerFromRendezvous

#define KEYCHAIN_ZEROCONF_SERVICE_NAME	@"Chicken-zeroconf"

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
        [self setHost: NSLocalizedString( @"Resolving", nil )];
		
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
			[self setShared:           [[propertyDict objectForKey:@"shared"] boolValue]];
			[self setFullscreen:       [[propertyDict objectForKey:@"fullscreen"] boolValue]];
			[self setViewOnly:         [[propertyDict objectForKey:@"viewOnly"] boolValue]];
            [self setProfileName:       [propertyDict objectForKey:@"lastProfile"]];
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
		[NSNumber numberWithInt:_port - PORT_BASE],		[NSString stringWithString:@"display"],
		[NSNumber numberWithBool:_shared],				[NSString stringWithString:@"shared"],
		[NSNumber numberWithBool:_fullscreen],			[NSString stringWithString:@"fullscreen"],
		[NSNumber numberWithBool:_viewOnly],            [NSString stringWithString:@"viewOnly"], 
		[_profile profileName],							[NSString stringWithString:@"lastProfile"],
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
			return NO;
		case EDIT_PASSWORD:
		case CONNECT:
			return (bHasResolved && bResloveSucceeded);
	}
	
    // shouldn't get here, but just in case...
	return NO;
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
	[self setHost: NSLocalizedString( @"AddressResolveFailed", nil )];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)extractAddress
{
    int i;
    
    for (i=0;i<[[service_ addresses] count];i++) {
        struct sockaddr_in *sockAddr = (struct sockaddr_in*)[[[service_ addresses] objectAtIndex:i] bytes];
        struct in_addr sinAddr = sockAddr->sin_addr;
        if (sinAddr.s_addr != 0)
        {
            _port = ntohs(sockAddr->sin_port);
            [self setHost:[NSString stringWithUTF8String:inet_ntoa(sinAddr)]];
            return;
        }
    }
    [self setHost: NSLocalizedString( @"AddressResolveFailed", nil )];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
	bHasResolved = YES;
	bResloveSucceeded = YES;
    [self extractAddress];
	
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
