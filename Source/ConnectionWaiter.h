//
//  ConnectionWaiter.m
//  Chicken of the VNC
//
//  Created by Dustin Cartwright on 7/9/2010.
//

/* Copyright (C) 2010 Dustin Cartwright
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

#import <Cocoa/Cocoa.h>
#import "SshTunnel.h"

@protocol IServerData;
@class Profile;
@class RFBConnection;

@protocol ConnectionWaiterDelegate <NSObject>

- (void)connectionSucceeded: (RFBConnection *)conn;
- (void)connectionFailed;

@optional
- (void)connectionPrepareForSheet;

@end

/* This class allows the asynchronous connection to servers. Upon
 * initialization, it begins connection to the server in another thread. When
 * the connection succeeds it sends connectionSucceeded: to its delegate.
 *
 * Note that it maintains a retain for the connecting thread. Thus, the
 * initializing object need not even maintain a pointer to the ConnectionWaiter
 * instance. */
@interface ConnectionWaiter : NSObject {
        // variables used for initializing RFBConnection
    id<IServerData>     server;
    NSString            *host;
    in_port_t           port;
    Profile             *profile;

    NSLock              *lock; // protects currentSock and delegate
    int                 currentSock; // socket for current connect() attempt
                                     // when current sock is non-negative, then
                                     // cancel is responsible for closing
                                     // currentSock during cancellation
    NSWindow            *window; // for displaying error panels

    id<ConnectionWaiterDelegate>    delegate;
    NSString            *errorStr; // error header, if not the default
};

+ (ConnectionWaiter *)waiterForServer:(id<IServerData>)aServer
                              profile:(Profile*)aProfile
                             delegate:(id<ConnectionWaiterDelegate>)aDelegate
                               window:(NSWindow *)aWind;
- (id)initWithServer:(id<IServerData>)aServer profile:(Profile*)aProfile
    delegate:(id<ConnectionWaiterDelegate>)aDelegate window:(NSWindow *)aWind;
- (void)dealloc;

- (void)setErrorStr:(NSString *)str;

- (void)cancel;

- (void)connect: (id)unused;
- (void)finishConnection;
- (void)connectionFailed: (NSString *)cause;
- (void)serverClosed;

- (void)error:(NSString*)theAction message:(NSString*)theFunction;

@end
