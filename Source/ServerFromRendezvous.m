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

@implementation ServerFromRendezvous

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
		[service_ resolve];
		
		// Set the initial name. If will have to be validated with the
		// delegate if one is set
		[super setName:[service_ name]];
	}
	
	return self;
}

- (void)dealloc
{
	[service_ release];
}

- (bool)doYouSupport: (SUPPORT_TYPE)type
{
	switch( type )
	{
		case EDIT_ADDRESS:
		case EDIT_PORT:
		case EDIT_NAME:
		case SAVE_PASSWORD:
		case DELETE:
		case SERVER_SAVE:
			return NO;
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
		assert( [[service_ addresses] count] > 0 );
		
		NSData* data = [[service_ addresses] objectAtIndex:0];
		return [NSString stringWithCString:inet_ntoa(((struct sockaddr_in*)[data bytes])->sin_addr)];
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

- (bool)rememberPassword
{
	return false;
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
}

@end
