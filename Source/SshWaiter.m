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
    [fh closeFile];
    [fh release];

    [super dealloc];
}

- (void)cancel
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                    name:NSFileHandleDataAvailableNotification
                                  object:fh];
    [fh closeFile];
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
    struct sockaddr_in  addr;
    int                 sock = socket(AF_INET, SOCK_STREAM, 0);
    
    if (sock < 0) {
        NSString *msg = [NSString stringWithFormat:@"socket() - %d", errno];
        [tunnel close];
        [self error:@"Couldn't connect to tunnel" message:msg];
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(aPort);

    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) == 0) {
        fh = [[NSFileHandle alloc] initWithFileDescriptor:sock
                                           closeOnDealloc:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                 selector:@selector(dataAvailable:)
                                     name:NSFileHandleDataAvailableNotification
                                   object:fh];
        [fh waitForDataInBackgroundAndNotify];
    } else {
        NSString *msg = [NSString stringWithFormat:@"connect() - %d", errno];
        [tunnel close];
        [self error:@"Couldn't connect to tunnel" message:msg];
    }
}

- (void)dataAvailable:(NSNotification *)notif
{
    RFBConnection   *conn;

    conn = [[RFBConnection alloc] initWithFileHandle:fh server:server
                                             profile:profile];
    [conn setSshTunnel:tunnel];

    [fh release];
    fh = nil;
    [tunnel release];
    tunnel = nil;

    [delegate connectionSucceeded:conn];
    [conn release];
}

- (void)sshFailed
{
    [delegate connectionFailed];
}

@end
