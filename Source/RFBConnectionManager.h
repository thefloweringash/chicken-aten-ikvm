/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
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
#import "ServerDataViewController.h"
#import "ConnectionWaiter.h"

@class Profile, ProfileManager;
@class RFBConnection;
@class ServerDataViewController;
@protocol IServerData;


@interface RFBConnectionManager : NSWindowController<ConnectionWaiterDelegate>
{
	IBOutlet NSTableView *serverList;
	IBOutlet NSTableView *groupList;
	IBOutlet NSBox *serverDataBoxLocal;
	IBOutlet NSBox *serverListBox;
	IBOutlet NSBox *serverGroupBox;
	IBOutlet NSSplitView *splitView;
    IBOutlet NSButton *serverDeleteBtn;
    IBOutlet NSButton *serverAddBtn;
    NSMutableArray*	sessions;
	ServerDataViewController* mServerCtrler;
	BOOL mDisplayGroups;
	BOOL mRunningFromCommandLine;
	BOOL mLaunchedByURL;
	NSArray* mOrderedServerNames;

    ConnectionWaiter    *connectionWaiter;
    BOOL lockedSelection;
}

+ (id)sharedManager;

- (void)wakeup;
- (BOOL)runFromCommandLine;
- (void)runNormally;
- (void)connectionSucceeded:(RFBConnection *)conn;
- (void)connectionFailed;

- (void)showNewConnectionDialog: (id)sender;
- (void)showConnectionDialog: (id)sender;

- (void)removeConnection:(id)aConnection;
- (void)cmdlineUsage;

- (void)selectedHostChanged;

- (void)setControlsEnabled:(BOOL)enabled;
- (void)connectionDone;

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost;
- (void)setDisplayNameTranslation:(NSString*)translation forName:(NSString*)aName forHost:(NSString*)aHost;

- (BOOL)createConnectionWithFileHandle:(NSFileHandle*)file 
    server:(id<IServerData>) server;
- (void)successfulConnection: (RFBConnection *)theConnection;

- (IBAction)addServer:(id)sender;
- (IBAction)deleteSelectedServer:(id)sender;

- (void)makeAllConnectionsWindowed;

- (void)serverListDidChange:(NSNotification*)notification;

- (id<IServerData>)selectedServer;
- (BOOL)selectServerByName:(NSString *)aName;

- (void)useRendezvous:(BOOL)useRendezvous;

- (void)displayGroups:(bool)display;

- (void)setFrontWindowUpdateInterval: (NSTimeInterval)interval;
- (void)setOtherWindowUpdateInterval: (NSTimeInterval)interval;

- (BOOL)launchedByURL;
- (void)setLaunchedByURL:(bool)launchedByURL;

@end
