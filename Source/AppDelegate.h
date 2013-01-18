//
//  AppDelegate.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ConnectionWaiter.h"

@interface AppDelegate : NSObject<ConnectionWaiterDelegate> {
	IBOutlet NSMenuItem *mRendezvousMenuItem;
	IBOutlet NSTextField *mInfoVersionNumber;
    IBOutlet NSMenuItem *fullScreenMenuItem;
	
	ConnectionWaiter    *dockConnection;
}

- (IBAction)showPreferences: (id)sender;
- (IBAction)changeRendezvousUse:(id)sender;
- (IBAction)showNewConnectionDialog:(id)sender;
- (IBAction)showConnectionDialog: (id)sender;
- (IBAction)showListenerDialog: (id)sender;
- (IBAction)showProfileManager: (id)sender;
- (IBAction)showHelp: (id)sender;

- (NSMenuItem *)getFullScreenMenuItem;

- (NSMenu *)applicationDockMenu:(NSApplication *)sender;
- (void)connectionSucceeded: (RFBConnection *)theConnection;
- (void)connectionFailed;

@end
