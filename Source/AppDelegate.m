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


@implementation AppDelegate

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

@end
