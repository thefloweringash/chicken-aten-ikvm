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

#import <AppKit/AppKit.h>
#import "ConnectionWaiter.h"
#import "AuthPrompt.h"

@protocol IServerData;

@class Profile;
@class ServerBase;
@class SshTunnel;

/* This class waits for ssh to connect to a remote host and for a connection to
 * be made through the remote tunnel. */
@interface SshWaiter : ConnectionWaiter <AuthPromptDelegate>
{
    SshTunnel       *tunnel;
    AuthPrompt      *auth;
    NSTimer         *tunnelClosedTimer;
    BOOL            tunnelHasFailed;
}

- (id)initWithServer:(id<IServerData>)aServer
    delegate:(id<ConnectionWaiterDelegate>)aDelegate window:(NSWindow *)aWind;
- (id)initWithServer:(id<IServerData>)aServer
            delegate:(id<ConnectionWaiterDelegate>)aDelegate
              window:(NSWindow *)aWind sshTunnel:(SshTunnel *)aTunnel;
- (void)dealloc;

- (void)cancel;

// messages from SshTunnel
- (void)firstTimeConnecting:(NSString *)fingerprint;
- (void)getPassword;
- (void)tunnelEstablishedAtPort:(in_port_t)aPort;
- (void)sshFailedWithError:(NSString *)err;
- (void)tunnelFailed:(NSString *)err;

// implementation of AuthPromptDelegate
- (void)authCancelled;
- (void)authPasswordEntered:(NSString *)password;

@end
