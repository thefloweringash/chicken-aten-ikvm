/* SshWaiter.m
 * Copyright (C) 2011 Dustin Cartwright
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "SshWaiter.h"
#import "IServerData.h"
#import "RFBConnection.h"
#import "SshTunnel.h"

#import <sys/socket.h>
#import <unistd.h>

@implementation SshWaiter

- (id)initWithServer:(id<IServerData>)aServer profile:(Profile*)aProfile
    delegate:(id<ConnectionWaiterDelegate>)aDelegate window:(NSWindow *)aWind
{
    if (self = [super init]) {
        server = [aServer retain];
        profile = [aProfile retain];
        delegate = aDelegate;
        window = [aWind retain];

        tunnel = [[SshTunnel alloc] initWithServer:server delegate:self];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [tunnel close];
    [tunnel release];

    [super dealloc];
}

- (void)cancel
{
    [super cancel];
    [tunnel close];
}

- (NSWindow *)windowForSshAuth
{
    if ([delegate respondsToSelector:@selector(connectionPrepareForSheet)])
        [delegate connectionPrepareForSheet];
    return window;
}

- (void)tunnelEstablishedAtPort:(in_port_t)aPort
{
    host = @"localhost";
    port = aPort;
    lock = [[NSLock alloc] init];
    currentSock = -1;

    [NSThread detachNewThreadSelector: @selector(connect:) toTarget: self
                           withObject: nil];
}

- (void)finishConnection
{
    NSFileHandle    *fh;
    RFBConnection   *conn;
    
    if (delegate == nil)
        return;

    fh = [[NSFileHandle alloc] initWithFileDescriptor: currentSock
                                       closeOnDealloc: YES];
    conn = [[RFBConnection alloc] initWithFileHandle:fh server:server
                                             profile:profile];
    [conn setSshTunnel:tunnel];
    [delegate connectionSucceeded:conn];

    [fh release];
    [tunnel release];
    tunnel = nil;
    [conn release];
    currentSock = -1;
}

- (void)sshFailed
{
    [delegate connectionFailed];
}

@end
