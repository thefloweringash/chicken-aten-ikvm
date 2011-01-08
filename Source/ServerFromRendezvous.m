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
#import "Profile.h"

@implementation ServerFromRendezvous

+ (id<IServerData>)createWithNetService:(NSNetService*)service
{
	return [[[ServerFromRendezvous alloc] initWithNetService:service] autorelease];
}

- (id)initWithNetService:(NSNetService*)service
{
    NSDictionary* rendServerDict = [[NSUserDefaults standardUserDefaults] objectForKey:RFB_SAVED_RENDEZVOUS_SERVERS];
    NSDictionary* propertyDict = [rendServerDict objectForKey:[service name]];

    if (propertyDict)
        self = [super initFromDictionary:propertyDict];
    else
        self = [super init];

	if (self)
	{
		bHasResolved      = NO;
		bResloveSucceeded = NO;
        [_host autorelease];
        _host = [NSLocalizedString(@"Resolving", nil) retain];
		
		service_ = [service retain];
		[service_ setDelegate:self];
		if ( [service_ respondsToSelector: @selector(resolveWithTimeout:)] )
			[service_ resolveWithTimeout: 5.0]; // Tiger only API
		else
			[service_ resolve];
		
        [_name release];
        _name = [[service_ name] retain];
	}
	
	return self;
}

- (void)dealloc
{
	[service_ release];
	[super dealloc];
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

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
	bHasResolved = YES;
	bResloveSucceeded = NO;
    [_host autorelease];
	_host = [NSLocalizedString(@"AddressResolveFailed", nil) retain];
	
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
}

- (NSString *)keychainServiceName
{
    return @"Chicken-zeroconf";
}

- (NSString *)saveName
{
    return [service_ name];
}

@end
