//
//  AppDelegate.h
//  Chicken of the VNC
//
//  Created by Bob Newhart on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppDelegate : NSObject {
	IBOutlet NSMenuItem *mRendezvousMenuItem;
	IBOutlet NSTextField *mInfoVersionNumber;
}

- (IBAction)showPreferences: (id)sender;
- (IBAction)changeRendezvousUse:(id)sender;
- (IBAction)showConnectionDialog: (id)sender;
- (IBAction)showProfileManager: (id)sender;

@end
