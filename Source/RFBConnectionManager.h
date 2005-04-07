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
@class Profile, ProfileManager;
@class ServerDataViewController;
@protocol ConnectionDelegate, IServerData;


@interface RFBConnectionManager : NSWindowController<ConnectionDelegate>
{
	IBOutlet NSTableView *serverList;
	IBOutlet NSTableView *groupList;
	IBOutlet NSBox *serverDataBoxLocal;
	IBOutlet NSBox *serverListBox;
	IBOutlet NSBox *serverGroupBox;
	IBOutlet NSSplitView *splitView;
    IBOutlet NSButton *serverDeleteBtn;
    NSMutableArray*	connections;
	ServerDataViewController* mServerCtrler;
	BOOL mDisplayGroups;
	BOOL mRunningFromCommandLine;
	NSMutableArray* mOrderedServerNames;
}

+ (id)sharedManager;

- (void)wakeup;
- (BOOL)runFromCommandLine;
- (void)runNormally;

- (void)showConnectionDialog: (id)sender;

- (void)removeConnection:(id)aConnection;
- (bool)connect:(id<IServerData>)server;
- (void)cmdlineUsage;

- (void)selectedHostChanged;

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost;
- (void)setDisplayNameTranslation:(NSString*)translation forName:(NSString*)aName forHost:(NSString*)aHost;

- (BOOL)createConnectionWithServer:(id<IServerData>) server profile:(Profile *) someProfile owner:(id) someOwner;
- (BOOL)createConnectionWithFileHandle:(NSFileHandle*)file 
    server:(id<IServerData>) server profile:(Profile *) someProfile owner:(id) someOwner;

- (IBAction)addServer:(id)sender;
- (IBAction)deleteSelectedServer:(id)sender;

- (void)makeAllConnectionsWindowed;

- (BOOL)haveMultipleConnections; // True if there is more than one connection open.
- (BOOL)haveAnyConnections;      // True if there are any connections open.

- (void)serverListDidChange:(NSNotification*)notification;

- (id<IServerData>)selectedServer;

- (void)useRendezvous:(BOOL)useRendezvous;

- (void)displayGroups:(bool)display;

- (void)setFrontWindowUpdateInterval: (NSTimeInterval)interval;
- (void)setOtherWindowUpdateInterval: (NSTimeInterval)interval;

@end
