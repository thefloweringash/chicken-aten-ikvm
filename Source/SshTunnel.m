/* SshTunnel.m
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

#import "SshTunnel.h"
#import "IServerData.h"
#import "SshWaiter.h"

#import <sys/socket.h>
#import <unistd.h>

#define SSH_STATE_OPENING 0
#define SSH_STATE_PASSWORD_PROMPT 1
#define SSH_STATE_PASSWORD_ENTERED 2
#define SSH_STATE_OPEN 3
#define SSH_STATE_CLOSING 4

#define TUNNEL_PORT_START 5910
#define TUNNEL_PORT_END 5950

@interface SshTunnel (Private)

- (void)findPortForTunnel;
- (void)getPassword;

@end

@implementation SshTunnel

- (id)initWithServer:(id<IServerData>)aServer delegate:(SshWaiter *)aDelegate
{
    if (self = [super init]) {
        NSMutableArray  *args = [[NSMutableArray alloc] init];
        NSString        *tunnel;
        NSString        *sshHost = [aServer sshHost];
        NSString        *tunnelledHost = [aServer host];
        NSNotificationCenter    *notifs = [NSNotificationCenter defaultCenter];

        delegate = aDelegate;

        task = [[NSTask alloc] init];
        sshIn = [[NSPipe alloc] init];
        sshOut = [[NSPipe alloc] init];
        sshErr = [[NSPipe alloc] init];

        [task setLaunchPath:@"/usr/bin/ssh"];
        [task setStandardInput:sshIn];
        [task setStandardOutput:sshOut];
        [task setStandardError:sshErr];

        [self findPortForTunnel];
        if (localPort == 0) {
            NSLog(@"Couldn't find port for tunnelling");
            [args release];
            [self dealloc];
            return nil;
        }

        if ([sshHost isEqualToString:sshHost])
            tunnelledHost = @"localhost";
        tunnel = [NSString stringWithFormat:@"%d/%@/%d", localPort, sshHost,
                                                [aServer port]];

        [args addObject:@"-L"];
        [args addObject:tunnel];
        [args addObject:sshHost];
        [args addObject:@"echo;sleep 10;cat"];
        [task setArguments:args];

        [notifs addObserver:self selector:@selector(sshTerminated:)
                name:NSTaskDidTerminateNotification object:task];
        [task launch];

        [notifs addObserver:self selector:@selector(readFromSsh:)
                       name:NSFileHandleReadCompletionNotification
                     object:[sshOut fileHandleForReading]];
        [notifs addObserver:self selector:@selector(readFromSsh:)
                       name:NSFileHandleReadCompletionNotification
                     object:[sshErr fileHandleForReading]];
        [[sshOut fileHandleForReading] readInBackgroundAndNotify];
        [[sshErr fileHandleForReading] readInBackgroundAndNotify];

        [args release];
    }

    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [task release];
    [[sshIn fileHandleForReading] closeFile];
    [[sshOut fileHandleForWriting] closeFile];
    [[sshErr fileHandleForWriting] closeFile];
    [sshIn release];
    [sshOut release];
    [sshErr release];

    [super dealloc];
}

- (void)close
{
    if (state == SSH_STATE_CLOSING)
        return;

    [[sshIn fileHandleForWriting] closeFile];
    state = SSH_STATE_CLOSING;
    [self retain]; // we want to wait for ssh to terminate cleanly even if
                   // no one else cates.
    delegate = nil;
}

- (in_port_t)localPort
{
    return localPort;
}

- (void)findPortForTunnel
{
    // initializes localPort to an unused port by finding a port we can bind to

    in_port_t   port;

    for (port = TUNNEL_PORT_START; port < TUNNEL_PORT_END; port++) {
        struct sockaddr_in  addr;
        int                 fd;
        int                 reuse = 1;

        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        addr.sin_port = htons(port);

        fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) {
            NSLog(@"Couldn't create socket: %s", strerror(errno));
            continue;
        }
        if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse)) !=
            0) {
            NSLog(@"Couldn't setsockopt: %s", strerror(errno));
            continue;
        }
        if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) == 0) {
            close(fd);
            localPort = port;
            return;
        } else {
            NSLog(@"Couldn't bind: %s", strerror(errno));
            close(fd);
        }
    }
}

- (void)readFromSsh:(NSNotification *)notif
{
    NSData		*data;
	NSString	*str;

    data = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([data length] == 0) {
        return;
    }

    str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    if ([notif object] == [sshOut fileHandleForReading]) {
        // data from ssh's standard out
        if ([str isEqualToString:@"\n"]) {
            state = SSH_STATE_OPEN;
            [delegate tunnelEstablishedAtPort:localPort];
            delegate = nil;
        } else
            NSLog(@"Unknown message from ssh stdout: %@", str);
    } else if ([notif object] == [sshErr fileHandleForReading]) {
        // data from ssh's standard error
        if ([str isEqualToString:@"Password:"]) {
            state = SSH_STATE_PASSWORD_PROMPT;
            [self getPassword];
        } else
            NSLog(@"Unknown message from ssh error: %@", str);
    } else {
        NSLog(@"Read notification from unknown object");
        [str release];
        return;
    }

    [str release];
    [[notif object] readInBackgroundAndNotify];
}

- (void)sshTerminated:(NSNotification *)notif
{
    if (state != SSH_STATE_OPEN)
        [delegate sshFailed];
    else if (state == SSH_STATE_CLOSING) {
        [[sshOut fileHandleForReading] closeFile];
        [[sshErr fileHandleForReading] closeFile];
        [self release]; // balances the retain in the close method
    }
}

- (void)getPassword
{
    AuthPrompt  *auth = [[AuthPrompt alloc] initWithDelegate:self];
    NSWindow    *wind = [delegate windowForSshAuth];

    [auth runSheetOnWindow:wind]; 
}

- (void)authCancelled
{
    [delegate sshFailed];
}

- (void)authPasswordEntered:(NSString *)password
{
    NSFileHandle    *fh = [sshIn fileHandleForWriting];

    [fh writeData: [password dataUsingEncoding:NSUTF8StringEncoding]];
    [fh writeData: [NSData dataWithBytes: "\n" length:1]];
    state = SSH_STATE_PASSWORD_ENTERED;
}

@end
