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

@interface SshWaiter(Private)

- (void)waitForData;
- (void)tunnelledConnFailed: (NSString *)err;

@end

@implementation SshWaiter

- (id)initWithServer:(id<IServerData>)aServer
    delegate:(id<ConnectionWaiterDelegate>)aDelegate window:(NSWindow *)aWind
{
    if (self = [super init]) {
        server = [aServer retain];
        delegate = aDelegate;
        window = [aWind retain];
        currentSock = -1;

        tunnel = [[SshTunnel alloc] initWithServer:server delegate:self];
    }

    return self;
}

/* Starts a connection attempt, reusing an existing tunnel. */
- (id)initWithServer:(id<IServerData>)aServer
            delegate:(id<ConnectionWaiterDelegate>)aDelegate
              window:(NSWindow *)aWind sshTunnel:(SshTunnel *)aTunnel
{
    if (self = [super init]) {
        server = [aServer retain];
        delegate = aDelegate;
        window = [aWind retain];
        tunnel = [aTunnel retain];

        [self tunnelEstablishedAtPort:[tunnel localPort]];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [tunnel close];
    [tunnel release];
    [auth release];

    [super dealloc];
}

- (void)cancel
{
    [super cancel];
    [tunnel close];
}

- (void)firstTimeConnecting:(NSString *)fingerprint
{
    /* This is ssh's first time connecting to this server. We want to verify
     * that the user wants to add the unauthenticated server key to the hosts
     * file. */

    NSAlert     *alert = [[NSAlert alloc] init];
    NSString    *msg = NSLocalizedString(@"FirstTimeMessage", nil);

    if ([delegate respondsToSelector:@selector(connectionPrepareForSheet)])
        [delegate connectionPrepareForSheet];

    [alert setMessageText:NSLocalizedString(@"FirstTimeHeader", nil)];
    [alert setInformativeText:[NSString stringWithFormat:msg, fingerprint]];
    [alert addButtonWithTitle:NSLocalizedString(@"Connect", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert beginSheetModalForWindow:window modalDelegate:self
                     didEndSelector:@selector(firstTime:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (void)firstTime:(NSAlert *)sheet returnCode:(int)retCode
      contextInfo:(void *)info
{
    BOOL    accept = retCode == NSAlertFirstButtonReturn;
    [tunnel acceptKey:accept];
    if ([delegate respondsToSelector:@selector(connectionSheetOver)])
        [delegate connectionSheetOver];
    if (!accept)
        [delegate connectionFailed];
}

- (void)getPassword
{
    auth = [[AuthPrompt alloc] initWithDelegate:self];

    if ([delegate respondsToSelector:@selector(connectionPrepareForSheet)])
        [delegate connectionPrepareForSheet];
    [auth runSheetOnWindow:window]; 
}

- (void)tunnelEstablishedAtPort:(in_port_t)aPort
{
    struct sockaddr_in  addr;

    if ((currentSock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        NSString *fmt = NSLocalizedString(@"TunnelSocketErr", nil);
        [self tunnelledConnFailed:[NSString stringWithFormat:fmt,strerror(errno)]];
        errno = 0;
        return;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(aPort);
    if (connect(currentSock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        NSString *fmt = NSLocalizedString(@"TunnelConnectErr", nil);
        [self tunnelledConnFailed:[NSString stringWithFormat:fmt, strerror(errno)]];
        errno = 0;
        return;
    }

    [NSThread detachNewThreadSelector:@selector(waitForData)
                             toTarget:self
                           withObject:nil];
}

- (void)tunnelledConnFailed: (NSString *)err
{
    [self error:NSLocalizedString(@"TunnelErr", nil) message:err];
}

- (void)waitForData
{
    [self waitForDataOn:currentSock];
}

- (void)finishConnection
{
    NSFileHandle    *fh;
    RFBConnection   *conn;
    
    if (delegate == nil)
        return;

    fh = [[NSFileHandle alloc] initWithFileDescriptor: currentSock
                                       closeOnDealloc: YES];
    conn = [[RFBConnection alloc] initWithFileHandle:fh server:server];
    [conn setSshTunnel:tunnel];
    [delegate connectionSucceeded:conn];

    [fh release];
    [tunnel release];
    tunnel = nil;
    [conn release];
    currentSock = -1;
}

- (void)serverClosed
{
    [self tunnelledConnFailed:NSLocalizedString(@"ServerClosed", nil)];
}

- (void)sshFailedWithError:(NSString *)err
{
    NSString    *fmt = NSLocalizedString(@"SshError", nil);
    NSString    *header = [NSString stringWithFormat:fmt, [server sshHost]];

    if (auth) {
        [auth stopSheet];
        [auth release];
        auth = nil;
    }
    [self error:header message:err];
}

- (void)authCancelled
{
    [auth release];
    auth = nil;
    [tunnel close];
    [delegate connectionFailed];
}

- (void)authPasswordEntered:(NSString *)password
{
    [auth release];
    auth = nil;
    [tunnel usePassword:password];
    if ([delegate respondsToSelector:@selector(connectionSheetOver)])
        [delegate connectionSheetOver];
}

@end
