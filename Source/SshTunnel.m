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

#define SSH_STATE_OPENING 0 /* ssh process has been started */
#define SSH_STATE_PROMPT 1  /* ssh process is waiting for us to provide some
                               kind of response. */
#define SSH_STATE_TUNNELING 2 /* ssh connection established: at this point we
                                 still have a delegate to send errors to */
#define SSH_STATE_OPEN 3    /* ssh tunnel established: no more delegate */
#define SSH_STATE_CLOSING 4 /* ssh in proces of shutting down, either due to
                               errror, or because we requested it. */

/* SshTunnel operates on a state machine as follows. The state transitions can
   by messages to SshTunnel, by the ssh program or both. In the latter case,
   these trigger callbacks to the delegate as shown below.

              [SshTunnel acceptKey:]
              [SshTunnel usePassword:]
       +-------------------<----------------------+
       V                                          |
   OPENING -----------------------------------> PROMPT
      |      [delegate firstTimeConnectiong:]
      |      [delegate getPassword]
      |
      | [delegate tunnelEstablishedAtPort:]
      V
  TUNNELING------------------------------+
      |                                  |
      | [SshTunnel tunnelConnected]      |
      V                                  | [SshTunnel close]
     OPEN                                | [delegate tunnelFailed:]
      |                                  |
      | [SshTunnel close]                |
      |                                  |
      |  +-------------------------------+
      V  V
   CLOSING <---------------------------OPENING or PROMPT
               [SshTunnel close]
               [delegate sshFailedWithError:]
 */

#define TUNNEL_PORT_START 5910
#define TUNNEL_PORT_END 5950

static BOOL portUsed[TUNNEL_PORT_END - TUNNEL_PORT_START];

@interface SshTunnel (Private)

- (void)findPortForTunnel;
- (BOOL)setupFifos;
- (void)cleanupFifos;

- (void)processString:(NSString *)str fromFileHandle:(NSFileHandle *)fh;
- (void)firstTimeConnecting:(NSString *)str;
- (void)tunnelError:(NSStrign *)str;
- (void)sshFailed:(NSString *)err;

- (void)writeToHelper:(NSString *)str;

@end

@implementation SshTunnel

- (id)initWithServer:(id<IServerData>)aServer delegate:(SshWaiter *)aDelegate
{
    if (self = [super init]) {
        NSMutableArray  *args;
        NSString        *tunnel;
        NSString        *tunnelledHost = [aServer host];
        in_port_t       sshPort = [aServer sshPort];
        NSString        *sshUser = [aServer sshUser];
        NSNotificationCenter    *notifs = [NSNotificationCenter defaultCenter];
        NSMutableDictionary     *env;

        delegate = aDelegate;
        sshHost = [[aServer sshHost] retain];

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

        if ([sshHost isEqualToString:[aServer host]])
            tunnelledHost = @"localhost";
        tunnel = [NSString stringWithFormat:@"%d/%@/%d", localPort,
                                                tunnelledHost, [aServer port]];

        args = [[NSMutableArray alloc] init];
        [args addObject:@"-L"];
        [args addObject:tunnel];
        if (sshPort) {
            [args addObject:@"-p"];
            [args addObject:[NSString stringWithFormat:@"%d", sshPort]];
        }
        if (sshUser) {
            [args addObject:@"-l"];
            [args addObject:sshUser];
        }
        [args addObject:@"-x"]; // make sure that ssh doesn't forward our dummy
                                // display
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
        [self retain]; // this retain lasts as long as ssh is running

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
    [sshHost release];
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
    switch (state) {
        case SSH_STATE_OPENING:
        case SSH_STATE_PROMPT:
            [task terminate];
            // fall through
        case SSH_STATE_OPEN:
            /* Shut down the connection gently by closing the channel */
            [[sshIn fileHandleForWriting] closeFile];
    }

    state = SSH_STATE_CLOSING;
    delegate = nil;
}

- (void)applicationTerminating:(NSNotification *)notif
{
    // make sure that the FIFOs and the ssh instance get cleaned up
    [task terminate];
    [self cleanupFifos];
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

    if (state == SSH_STATE_CLOSING)
        return;

    data = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([data length] == 0) {
        /* end of stream */
        if ([notif object] == [sshErr fileHandleForReading] &&
                state != SSH_STATE_CLOSING) {
            /* Program quit without giving us an error message that we
             * recognized. */
            [self sshFailed:NSLocalizedString(@"SshQuit", nil)];
        }
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

/* Process one line of output from ssh */
- (void)processString:(NSString *)str fromFileHandle:(NSFileHandle *)fh
{
    if (fh == [sshOut fileHandleForReading]) {
        // data from ssh's standard out
        if ([str isEqualToString:@""]) {
            // blank lines means that we've connected
            state = SSH_STATE_TUNNELING;
            [self cleanupFifos];
            [delegate tunnelEstablishedAtPort:localPort];
        } else
            NSLog(@"Unknown message from ssh stdout: %@", str);
    } else if (fh == [sshErr fileHandleForReading]) {
        // data from ssh's standard error: messages sent via our helper. These
        // require a response.
        if ([str hasPrefix:@"Chicken ssh-helper: Password:"]) {
            if (state == SSH_STATE_OPENING) {
                state = SSH_STATE_PROMPT;
                [delegate getPassword];
            }
        } else if ([str hasPrefix:@"Chicken ssh-helper: The authenticity of host "]) {
            if (state == SSH_STATE_OPENING) {
                [self firstTimeConnecting:str];
            }

        // messages sent by ssh itself.
        } else if ([str hasPrefix:@"ssh: Could not resolve hostname"]) {
            NSString *fmt = NSLocalizedString(@"NoNamedServer", nil);
            NSString *str = [NSString stringWithFormat:fmt, sshHost];
            [self sshFailed:str];
        } else if ([str hasPrefix:@"ssh: connect to host"]) {
            if ([str hasSuffix:@"Connection refused\r"]) {
                [self sshFailed:NSLocalizedString(@"ConnectRefused", nil)];
            } else if ([str hasSuffix:@"Operation timed out\r"]) {
                [self sshFailed:NSLocalizedString(@"ConnectTimedOut", nil)];
            } else {
                [self sshFailed:[[str componentsSeparatedByString:@": "]
                                    lastObject]];
            }
        } else if ([str hasPrefix:@"@@@@@@@@"]) {
            [self sshFailed:NSLocalizedString(@"SshKeyMismatch", nil)];
        } else if ([str hasPrefix:@"Permission denied"])
            [self sshFailed:NSLocalizedString(@"SshPermissionDenied", nil)];
        else if ([str hasPrefix:@"Connection closed by "])
            [self sshFailed:NSLocalizedString(@"SshConnectionClosed", nil)];
        else if ([str hasPrefix:@"Identity added:"]) {
            NSLog(@"Added identity");
        } else if ([str hasPrefix:@"channel "])
            [self tunnelError:str];
        else if ([str hasPrefix:@"Warning: Permanently added"])
            NSLog(@"Added key to known hosts");

        // messages sent by shell, cat, etc.
        else if ([str hasPrefix:@"/bin/cat: "]) {
           [self sshFailed:NSLocalizedString(@"CatError", nil)];
        } else if ([str hasPrefix:@"ssh_askpass: exec("]) {
           [self sshFailed:NSLocalizedString(@"SshScriptError", nil)];
        } else if ([str length] > 0)
            NSLog(@"Unknown message from ssh error: %@", str);
    } else
        NSLog(@"Read notification from unknown object");
}

/* This is our first time connecting and the ssh program has given us a prompt
 * about accepting the host key. We extract the fingerprint and pass this along
 * to the delegate. */
- (void)firstTimeConnecting:(NSString *)str
{
    NSRange     intro = [str rangeOfString:@" key fingerprint is "];
    NSString    *fingerprint = @"<unknown>";

    if (intro.location != NSNotFound) {
        NSRange     after, end, sub;

        after.location = intro.location + intro.length;
        after.length = [str length] - after.location;
        end = [str rangeOfString:@". " options:0 range:after];

        if (end.location != NSNotFound) {
            sub.location = after.location;
            sub.length = end.location - sub.location;
            fingerprint = [str substringWithRange:sub];
        }
    }

    state = SSH_STATE_PROMPT;
    [delegate firstTimeConnecting:fingerprint];
}

- (void)tunnelError:(NSString *)err
{
    int         i;
    NSString    dict[2][] = {
        {@"connect failed: Connection refused", @"ConnectRefused"},
        {@"administratively prohibited", @"SshTunnelAdminProhibited"}};

    state = SSH_STATE_CLOSING;

    for (i = 0; i < sizeof(dict) / sizeof(*dict); i++) {
        if ([str containsSubstring:dict[i][0]]) {
            [delegate tunnelFailed:NSLocalizedString(dict[i][1], nil)];
            return;
        }
    }

    [delegate tunnelFailed:NSLocalizedString(@"SshTunnelOther", nil)];
}

- (void)sshFailed:(NSString *)err
{
    state = SSH_STATE_CLOSING;
    [delegate sshFailedWithError:err];
}

- (void)sshTerminated:(NSNotification *)notif
{
    portUsed[localPort - TUNNEL_PORT_START] = NO;
    [self cleanupFifos];

    /* The termination notification can come before the end of the error stream,
     * so we clean up here, but we wait to see if we get an explanation on
     * sshErr before we tell the delegate that we've failed. */
    [self release];
}

- (void)acceptKey:(BOOL)accept
{
    NSString    *resp = accept ? @"yes" : @"no";
    [self writeToHelper:resp];
    if (!accept)
        state = SSH_STATE_CLOSING;
}

- (void)usePassword:(NSString*)password
{
    [self writeToHelper:password];
}

- (void)sshTunnelConnected
{
    state = SSH_STATE_OPEN;
    delegate = nil;
}

/* Write a messsage to our helper script. This is how we feed replies to ssh's
 * interactive questions. */
- (void)writeToHelper:(NSString *)str
{
    int     fd;

    if (state != SSH_STATE_PROMPT)
        return;

    /* Even though we believe that our helper is waiting for input, something
     * may have happened, so we open non-blocking. This also precludes Cocoa
     * wrappers. */
    fd = open([fifo fileSystemRepresentation], O_WRONLY | O_NONBLOCK);
    if (fd == -1) {
        NSLog(@"Couldn't open FIFO to ssh helper: %s", strerror(errno));
        errno = 0;
    } else {
        const char  *cStr = [str UTF8String];
        int         len = strlen(cStr);
        char        *buf = malloc(len + 1);

        memcpy(buf, cStr, len);
        buf[len] = '\n';
        if (write(fd, buf, len + 1) <= 0) {
            NSLog(@"Couldn't write to ssh helper: %s", strerror(errno));
            errno = 0;
        }
        free(buf);
        close(fd);
    }
    state = SSH_STATE_OPENING;
}

@end
