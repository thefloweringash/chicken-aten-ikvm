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

#import <AppKit/AppKit.h>
#import <netinet/in.h>
#import "AuthPrompt.h"

@class SshWaiter;
@protocol IServerData;

@interface SshTunnel : NSObject <AuthPromptDelegate> {
    NSTask  *task;
    NSPipe  *sshIn;
    NSPipe  *sshOut;
    NSPipe  *sshErr;

    SshWaiter   *delegate;
    in_port_t   localPort;
    int         state;
}

- (id)initWithServer:(id<IServerData>)aServer delegate:(SshWaiter *)aDelegate;
- (void)dealloc;

- (void)close;

- (in_port_t)localPort;

@end
