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

#import <poll.h>
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
    int             causeErr = 0;
    NSString        *errMsg = nil;
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
            causeErr = errno;
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
            /* Socket connected successfully: Now wait for data from server. For
             * example, if we're tunnelling over SSH, SSH will accept the
             * connection right away, but we want to wait for the handshake from
             * the VNC server, before we represent to the user that a connection
             * ha been made. */
            struct pollfd   pfd;

            freeaddrinfo(res0);

            pfd.fd = sock;
            pfd.events = POLLERR | POLLHUP | POLLIN;
            poll(&pfd, 1, -1);
            if (pfd.revents & (POLLERR | POLLHUP)) {
                [self performSelectorOnMainThread:@selector(serverClosed)
                           withObject:nil waitUntilDone:NO];
                return;
            }

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
                if (errno == ECONNREFUSED) {
                    errMsg = @"ConnectRefused";
                } else if (errno == ETIMEDOUT) {
                    errMsg = @"ConnectTimedOut";
                } else {
                    cause = @"connect()";
                    causeErr = errno;
                }
                close(sock);
                currentSock = -1;
                [lock unlock];
            }
        }
    }

    freeaddrinfo(res0);
    // exhausted all possible addresses -> failure
    pool = [[NSAutoreleasePool alloc] init];
    if (errMsg == nil) {
        errMsg = [NSString stringWithFormat:@"%s: %@", strerror(causeErr),
                                        cause];
    }
    [self performSelectorOnMainThread: @selector(connectionFailed:)
                           withObject: errMsg waitUntilDone: NO];
    [pool release];
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
    int      errNum = [error intValue];
    NSString *actionStr = NSLocalizedString( @"NoNamedServer", nil );
    NSString *message;
    NSString *title = [NSString stringWithFormat:actionStr, [self host]];

    if (errNum == EAI_NONAME)
        message = @"";
    else
        message = [NSString stringWithFormat:@"%s: getaddrinfo()",
                                gai_strerror(errNum)];

    [self error:title message:message];
}

/* Connection attempt has failed. Executed in main thread. */
- (void)connectionFailed: (NSString *)cause
{
    NSString *actionStr;

    actionStr = NSLocalizedString( @"NoConnection", nil );
    actionStr = [NSString stringWithFormat:actionStr, [self host], [server port]];
        // cause can be either a localized string tag or the error string
        // itself, in which case NSLocalizedString just returns cause
    cause = NSLocalizedString(cause, nil);
    [self error:actionStr message:cause];
}

- (void)serverClosed
{
    NSString    *templ = NSLocalizedString(@"NoConnection", nil);
    NSString    *actionStr;

    actionStr = [NSString stringWithFormat:templ, [self host], [server port]];
    [self error:actionStr message:NSLocalizedString(@"ServerClosed", nil)];
}

/* Creates error sheet or panel */
- (void)error:(NSString*)theAction message:(NSString*)message
{
    if (delegate == nil) {
        // only show error if we haven't been canceled
        [self release];
        return;
    }

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
