/* ConnectionWaiter.m
 * Copyright (C) 2010 Dustin Cartwright
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

#import "ConnectionWaiter.h"
#import "IServerData.h"
#import "RFBConnection.h"
#import "RFBConnectionManager.h"

#import <unistd.h>

@implementation ConnectionWaiter

- (id)initWithServer:(id<IServerData>)aServer profile:(Profile*)aProfile
    delegate:(id<ConnectionWaiterDelegate>)aDelegate window:(NSWindow *)aWindow
{
    if (self = [super init]) {
        server = [aServer retain];
        profile = [aProfile retain];
        lock = [[NSLock alloc] init];
        currentSock = -1;
        window = [aWindow retain];

        delegate = aDelegate;

        [self retain]; // on behalf of new thread
        [NSThread detachNewThreadSelector: @selector(connect:) toTarget: self
                               withObject: nil];
            
    }
    return self;
}

- (void)dealloc
{
    [server release];
    [profile release];
    [lock release];
    [window release];
    [errorStr release];
    [super dealloc];
}

- (void)setErrorStr:(NSString *)str
{
    [errorStr release];
    errorStr = [str retain];
}

/* Cancels the connection attempt. This prevents any future messages to the
 * delegate. */
- (void)cancel
{
    [lock lock];
    delegate = nil;
    if (currentSock >= 0) {
        close(currentSock);
        currentSock = -1;
    }
    [lock unlock];
    [window release];
    window = nil;
}

- (NSString *)host
{
    NSString	*host = [server host];
    return host ? host : DEFAULT_HOST;
}

/* Attempts to connect to the server. Note that connect: has had a retain
 * performed for it by initWithServer, so before exiting it must ensure that
 * release gets called on the main thread. */
- (void)connect: (id)unused
{
    int             error;
    struct addrinfo hints;
    struct addrinfo *res, *res0;
    NSString        *cause = @"unknown";
    NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
    NSString    *host = [self host];
    NSString    *port = [NSString stringWithFormat:@"%d", [server port]];

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_ADDRCONFIG; // getaddrinfo will only do IPv6 lookup
                                    // if host has an IPv6 address
    hints.ai_flags = 0;
    hints.ai_protocol = IPPROTO_TCP;

    error = getaddrinfo([host UTF8String], [port UTF8String], &hints, &res0);
    [pool release];

    if (error) {
        NSNumber    *errnum = [[NSNumber alloc] initWithInt: error];
        [self performSelectorOnMainThread: @selector(lookupFailed:)
                               withObject: errnum waitUntilDone: NO];
        [errnum release];

        return;
    }

    // Try all available addresses for given host string
    for (res = res0; res; res = res->ai_next) {
        int     sock;
        if ((sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0) {
            cause = @"socket()";
            continue;
        }

        [lock lock];
        if (delegate == nil) {
            [lock unlock];
            break;
        }
        currentSock = sock;
        [lock unlock];

        if (connect(sock, res->ai_addr, res->ai_addrlen) == 0) {
            // socket connected successfully
            freeaddrinfo(res0);
            [self performSelectorOnMainThread:@selector(finishConnection)
                                   withObject:nil waitUntilDone:NO];
            return; 
        } else {
            [lock lock];
            if (delegate == nil) {
                // cancelled in middle of connect, so cancel message has already
                // closed the socket
                [lock unlock];
                break;
            } else {
                cause = @"connect()";
                close(sock);
                currentSock = -1;
                [lock unlock];
            }
        }
    }

    freeaddrinfo(res0);
    // exhausted all possible addresses -> failure
    [self performSelectorOnMainThread: @selector(connectionFailed:)
                           withObject: cause waitUntilDone: NO];
}

- (void)finishConnection
{
    if (delegate) {
        // only if we haven't been canceled
        NSFileHandle    *fh;
        RFBConnection   *theConnection;

        fh = [[NSFileHandle alloc] initWithFileDescriptor: currentSock
                                           closeOnDealloc: YES];
        theConnection = [[RFBConnection alloc] initWithFileHandle:fh
                server:server profile:profile];
        [delegate connectionSucceeded: theConnection];
        [fh release];
        [theConnection release];
        currentSock = -1;
    }
    [self release];
}

/* DNS lookup has failed. Executed in main thread. */
- (void)lookupFailed: (NSNumber *)error
{
    if (delegate) {
        // only if we haven't been canceled
        NSString *actionStr = NSLocalizedString( @"NoNamedServer", nil );
        NSString *message = [NSString stringWithFormat:@"%s: getaddrinfo()",
                                gai_strerror([error intValue])];
        NSString *title = [NSString stringWithFormat:actionStr, [self host]];

        [self error:title message:message];
    } else
        [self release];
}

/* Connection attempt has failed. Executed in main thread. */
- (void)connectionFailed: (NSString *)cause
{
    if (delegate) {
        // only if we haven't been canceled
        NSString *actionStr;
        NSString *message;

        actionStr = NSLocalizedString( @"NoConnection", nil );
        actionStr = [NSString stringWithFormat:actionStr, [self host], [server port]];
        message = [NSString stringWithFormat:@"%s: %@", strerror(errno), cause];
        [self error:actionStr message:message];
    } else
        [self release];
}

/* Creates error sheet or panel */
- (void)error:(NSString*)theAction message:(NSString*)message
{
    if ([delegate respondsToSelector:@selector(connectionPrepareForSheet)])
        [delegate connectionPrepareForSheet];

    if (errorStr)
        theAction = errorStr;

	NSString *ok = NSLocalizedString( @"Okay", nil );
    if (window)
        NSBeginAlertSheet(theAction, ok, nil, nil, window, self,
                @selector(errorDidEnd:returnCode:contextInfo:), NULL, NULL,
                message);
    else
        NSRunAlertPanel(theAction, message, ok, NULL, NULL, NULL);
}

- (void)errorDidEnd:(NSWindow *)sheet returnCode:(int)returnCode
        contextInfo:(void *)info
{
    [delegate connectionFailed];
    [self release];
}

@end
