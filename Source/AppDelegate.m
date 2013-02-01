//
//  AppDelegate.m
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "AppDelegate.h"
#import "KeyEquivalentManager.h"
#import "PrefController.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "ListenerController.h"
#import "ServerDataManager.h"
#import "DockConnection.h"

@implementation AppDelegate

- (id) init
{
    if (self = [super init])
        dockConnections = [[NSMutableArray alloc] init];

    return self;
}

/* This will copy the Chicken of the VNC preferences file to a Chicken file, if
 * the former exists and the latter doesn't. This allows us to inherit Chicken
 * of the VNC preferences the first time we're run. This has to be called before
 * any call to NSUserDefaults. */
- (void)copyCotvncPrefs
{
    NSArray         *libDirs;
    int             i;
    NSFileManager   *fileManager = [NSFileManager defaultManager];

    libDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                  NSUserDomainMask, YES);

    for (i = 0; i < [libDirs count]; i++) {
        NSString    *path = [libDirs objectAtIndex:i];
        NSString    *cotvncPref;
        NSString    *chickenPref;
        
        cotvncPref = [path stringByAppendingPathComponent:
                            @"Preferences/com.geekspiff.chickenofthevnc.plist"];
        chickenPref = [path stringByAppendingPathComponent:
                            @"Preferences/net.sourceforge.chicken.plist"];

        if ([fileManager fileExistsAtPath:cotvncPref]
                && ![fileManager fileExistsAtPath:chickenPref]) {
            BOOL    success;
            success = [fileManager copyPath:cotvncPref toPath:chickenPref
                                    handler:nil];
            if (!success) {
                NSLog(@"Failed to copy %@ to %@", cotvncPref, chickenPref);
            }
        }
    }
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    [self copyCotvncPrefs];
	// make sure our singleton key equivalent manager is initialized, otherwise, it won't watch the frontmost window
	[KeyEquivalentManager defaultManager];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	RFBConnectionManager *cm = [RFBConnectionManager sharedManager];

	if ( ! [cm runFromCommandLine] && ! [cm launchedByURL] )
		[cm runNormally];
	
	[mRendezvousMenuItem setState: [[PrefController sharedController] usesRendezvous] ? NSOnState : NSOffState];
	[mInfoVersionNumber setStringValue: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];
}


- (IBAction)showPreferences: (id)sender
{
	[[PrefController sharedController] showWindow];
}

- (BOOL) applicationShouldHandleReopen: (NSApplication *) app hasVisibleWindows: (BOOL) visibleWindows
{
	if(!visibleWindows)
	{
		[self showConnectionDialog:nil];
		return NO;
	}
	
	return YES;
}

- (IBAction)changeRendezvousUse:(id)sender
{
	PrefController *prefs = [PrefController sharedController];
	[prefs toggleUseRendezvous: sender];
	
	[mRendezvousMenuItem setState: [prefs usesRendezvous] ? NSOnState : NSOffState];
}


- (IBAction)showConnectionDialog: (id)sender
{  [[RFBConnectionManager sharedManager] showConnectionDialog: nil];  }

- (IBAction)showNewConnectionDialog:(id)sender
{  [[RFBConnectionManager sharedManager] showNewConnectionDialog: nil];  }

- (IBAction)showListenerDialog: (id)sender
{  [[ListenerController sharedController] showWindow: nil];  }


- (IBAction)showProfileManager: (id)sender
{  [[ProfileManager sharedManager] showWindow: nil];  }


- (IBAction)showHelp: (id)sender
{
	NSString *path = [[NSBundle mainBundle] pathForResource: @"index" ofType: @"html" inDirectory: @"help"];
	[[NSWorkspace sharedWorkspace] openFile: path];
}

- (NSMenuItem *)getFullScreenMenuItem
{
    return fullScreenMenuItem;
}

/* Dock menu-related selectors */

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	NSMenu              *dockMenu = [[[NSMenu alloc] init] autorelease];
    ServerDataManager   *serverManager = [ServerDataManager sharedInstance];
	NSEnumerator        *enumerator;
	NSString            *s;

	[dockMenu addItemWithTitle:NSLocalizedString(@"ConnectTo", nil)
			  action:nil
			  keyEquivalent:@""];

	enumerator = [[serverManager sortedServerNames] objectEnumerator];
	while (s = [enumerator nextObject]) {
		NSMenuItem	*item =  [dockMenu addItemWithTitle:s
										action:@selector(connectClicked:)
										keyEquivalent:@""];

		[item setTarget:self];
        [item setRepresentedObject:[serverManager getServerWithName:s]];
        [item setIndentationLevel:1];
	}

    if ([dockConnections count] > 0) {
        // Menu items for current dock-initiated connection attempts.
        [dockMenu addItem:[NSMenuItem separatorItem]];
        [dockConnections makeObjectsPerformSelector:@selector(addMenuItems:)
                withObject:dockMenu];
    }

    return dockMenu;
}	

- (void)connectClicked: (id)sender
{
    DockConnection      *conn;

    conn = [[DockConnection alloc] initWithServer:[sender representedObject]];
    [dockConnections addObject:conn];
    [conn release];
}

- (void)addDockConnection:(DockConnection *)conn
{
    [dockConnections addObject:conn];
}

- (void)removeDockConnection: (DockConnection *)conn
{
    /* This selector is called by the object conn itself. We want to make sure
     * that the object continues to exist, even though we're about to remove it
     * from our array. */
    [[conn retain] autorelease];
    [dockConnections removeObject:conn];
}

@end
