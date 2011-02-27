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
#import <sys/stat.h>
#import <sys/types.h>
#import <unistd.h>

#define SSH_STATE_OPENING 0
#define SSH_STATE_PROMPT 1
#define SSH_STATE_PASSWORD_ENTERED 2
#define SSH_STATE_OPEN 3
#define SSH_STATE_CLOSING 4

#define TUNNEL_PORT_START 5910
#define TUNNEL_PORT_END 5950

static BOOL portUsed[TUNNEL_PORT_END - TUNNEL_PORT_START];

@interface SshTunnel (Private)

- (void)findPortForTunnel;
- (BOOL)setupFifos;
- (void)cleanupFifos;

- (void)processString:(NSString *)str fromFileHandle:(NSFileHandle *)fh;

- (void)getPassword;
- (void)writeToHelper:(NSString *)str;

- (void)firstTimeConnecting;

@end

@implementation SshTunnel

- (id)initWithServer:(id<IServerData>)aServer delegate:(SshWaiter *)aDelegate
{
    if (self = [super init]) {
        NSMutableArray  *args;
        NSString        *tunnel;
        NSString        *sshHost = [aServer sshHost];
        NSString        *tunnelledHost = [aServer host];
        NSNotificationCenter    *notifs = [NSNotificationCenter defaultCenter];
        NSMutableDictionary     *env;

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
            [self dealloc];
            return nil;
        }

        if (![self setupFifos]) {
            [self dealloc];
            return nil;
        }

        if ([sshHost isEqualToString:sshHost])
            tunnelledHost = @"localhost";
        tunnel = [NSString stringWithFormat:@"%d/%@/%d", localPort,
                                                tunnelledHost, [aServer port]];

        args = [[NSMutableArray alloc] init];
        [args addObject:@"-L"];
        [args addObject:tunnel];
        [args addObject:sshHost];
        [args addObject:@"echo;cat"];
        [task setArguments:args];

        env = [NSMutableDictionary dictionaryWithDictionary:
                                    [[NSProcessInfo processInfo] environment]];
        [env setObject:[[NSBundle mainBundle] pathForResource:@"ssh-helper"
                                                       ofType:@"sh"]
                forKey:@"SSH_ASKPASS"];
        [env setObject:@"dummy" forKey:@"DISPLAY"];
        [env setObject:fifo forKey:@"CHICKEN_NAMED"];
        [task setEnvironment:env];

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

        [notifs addObserver:self selector:@selector(applicationTerminating:)
                       name:NSApplicationWillTerminateNotification
                     object:NSApp];

        [args release];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self cleanupFifos];
    [task release];
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
    [self cleanupFifos];
    state = SSH_STATE_CLOSING;

    [self retain]; // we want to wait for ssh to terminate cleanly even if
                   // no one else cares.
    delegate = nil;
}

- (void)applicationTerminating:(NSNotification *)notif
{
    // make sure that the FIFOs and the ssh instance get cleaned up
    [self cleanupFifos];
    [task terminate];
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

        if(portUsed[port - TUNNEL_PORT_START])
            continue;

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
            portUsed[port - TUNNEL_PORT_START] = YES;
            return;
        } else {
            NSLog(@"Couldn't bind: %s", strerror(errno));
            close(fd);
        }
    }
}

// Create FIFOs which we'll use to communicate the password to our helper script
- (BOOL)setupFifos
{
    fifo = [[NSString stringWithFormat:@"/tmp/chicken-%d-%d", getpid(),
                                       localPort] retain];
    if (mkfifo([fifo fileSystemRepresentation], S_IRUSR | S_IWUSR) != 0) {
        NSLog(@"Couldn't make fifo: %d", errno);
        return NO;
    }

    return YES;
}

- (void)cleanupFifos
{
    if (fifo) {
        if (state == SSH_STATE_PROMPT)
            [self writeToHelper:@""];
        if (unlink([fifo fileSystemRepresentation]) != 0)
            NSLog(@"Error unlinking %@: %d", fifo, errno);
        [fifo release];
        fifo = nil;
    }
}

- (void)readFromSsh:(NSNotification *)notif
{
    NSData		    *data;
	NSString	    *str;
    NSEnumerator    *en;
    NSString        *line;

    data = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([data length] == 0) {
        return;
    }

    str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    en = [[str componentsSeparatedByString:@"\n"] objectEnumerator];

    while (line = [en nextObject]) {
        [self processString:line fromFileHandle:[notif object]];
    }

    [str release];
    [[notif object] readInBackgroundAndNotify];
}

- (void)processString:(NSString *)str fromFileHandle:(NSFileHandle *)fh
{
    if (fh == [sshOut fileHandleForReading]) {
        // data from ssh's standard out
        if ([str isEqualToString:@""]) {
            // blank lines means that we've connected
            state = SSH_STATE_OPEN;
            [self cleanupFifos];
            [delegate tunnelEstablishedAtPort:localPort];
            delegate = nil;
        } else
            NSLog(@"Unknown message from ssh stdout: %@", str);
    } else if (fh == [sshErr fileHandleForReading]) {
        // data from ssh's standard error: messages sent via our helper. These
        // require a response.
        if ([str hasPrefix:@"Chicken ssh-helper: Password:"]) {
            if (state != SSH_STATE_CLOSING) {
                state = SSH_STATE_PROMPT;
                [self getPassword];
            }
        } else if ([str hasPrefix:@"Chicken ssh-helper: The authenticity of host "]) {

            if (state == SSH_STATE_CLOSING)
                [self writeToHelper:@"no"];
            else {
                state = SSH_STATE_PROMPT;
                [self firstTimeConnecting];
            }
        // messages sent by ssh itself.
        } else if ([str isEqualToString:@"Password:"]) {
            // this probably won't ever happen
            NSLog(@"Password prompt: how did this happen?");
            state = SSH_STATE_PROMPT;
            [self getPassword];
        } else if ([str hasPrefix:@"Identity added:"]) {
            NSLog(@"Added identity");
        } else if ([str hasPrefix:@"cat: "]) {
            NSLog(@"Error with cat: %@", str);
        } else if ([str hasPrefix:@"Permission denied"]) {
            NSLog(@"permission denied");
            [delegate sshFailed];
            [self close];
        } else if ([str hasPrefix:@"channel "])
            NSLog(@"probably open failure: %@", str);
        else if ([str hasPrefix:@"Warning: Permanently added"])
            NSLog(@"Added key to known hosts");
        else if ([str length] > 0)
            NSLog(@"Unknown message from ssh error: %@", str);
    } else
        NSLog(@"Read notification from unknown object");
}

- (void)sshTerminated:(NSNotification *)notif
{
    portUsed[localPort - TUNNEL_PORT_START] = NO;

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
    [self close];
}

- (void)authPasswordEntered:(NSString *)password
{
    [self writeToHelper:password];

    state = SSH_STATE_PASSWORD_ENTERED;
}

- (void)writeToHelper:(NSString *)str
{
    NSFileHandle    *fh = [NSFileHandle fileHandleForWritingAtPath:fifo];

    [fh writeData: [str dataUsingEncoding:NSUTF8StringEncoding]];
    [fh writeData: [NSData dataWithBytes: "\n" length:1]];
    [fh closeFile];
}

- (void)firstTimeConnecting
{
    /* This is ssh's first time connecting to this server. We want to verify
     * that the user wants to add the unauthenticated server key to the hosts
     * file. */

    NSWindow    *wind = [delegate windowForSshAuth];
    NSAlert     *alert = [[NSAlert alloc] init];

    [alert setMessageText:NSLocalizedString(@"FirstTimeHeader", nil)];
    [alert setInformativeText:NSLocalizedString(@"FirstTimeMessage", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Connect", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert beginSheetModalForWindow:wind modalDelegate:self
                     didEndSelector:@selector(firstTime:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (void)firstTime:(NSAlert *)sheet returnCode:(int)retCode
      contextInfo:(void *)info
{
    NSString    *resp = retCode == NSAlertFirstButtonReturn ? @"yes" : @"no";
    [self writeToHelper:resp];
}

@end
