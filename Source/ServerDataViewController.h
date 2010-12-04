//
//  ServerFromPrefs.h
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sun May 1 2004.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//


#import <Cocoa/Cocoa.h>
#import "ConnectionWaiter.h"

@protocol IServerData;
@protocol ConnectionDelegate;
@class RFBConnection;
@class RFBConnectionManager;

@interface ServerDataViewController : NSWindowController
                                            <ConnectionWaiterDelegate>
{
    IBOutlet NSTextField *display;
    IBOutlet NSTextField *displayDescription;
    IBOutlet NSTextField *hostName;
    IBOutlet NSTextField *password;
    IBOutlet NSPopUpButton *profilePopup;
    IBOutlet NSButton *rememberPwd;
	IBOutlet NSButton *fullscreen;
    IBOutlet NSButton *shared;
	IBOutlet NSButton *viewOnly;
	IBOutlet NSButton *save;
	IBOutlet NSBox *box;
	IBOutlet NSButton *connectBtn;
	
	IBOutlet NSProgressIndicator *connectIndicator;
	IBOutlet NSTextField *connectIndicatorText;
	
	id<IServerData> mServer;
	
	bool selfTerminate;
	bool removedSaveCheckbox;

    ConnectionWaiter    *connectionWaiter;
    BOOL saveCheckboxWasVisible;
    RFBConnectionManager *superController;
}

- (id)initWithReleaseOnCloseOrConnect;

- (void)setServer:(id<IServerData>)server;
- (id<IServerData>)server;

- (IBAction)rememberPwdChanged:(id)sender;
- (IBAction)profileSelectionChanged:(id)sender;
- (IBAction)fullscreenChanged:(id)sender;
- (IBAction)sharedChanged:(id)sender;
- (IBAction)viewOnlyChanged:(id)sender;
- (IBAction)connectToServer:(id)sender;
- (IBAction)addServerChanged:(id)sender;

- (IBAction)showProfileManager:(id)sender;

- (IBAction)connectToServer:(id)sender;
- (IBAction)cancelConnect: (id)sender;

- (void)connectionSucceeded: (RFBConnection *)theConnection;
- (void)connectionFailed;
- (void)connectionAttemptEnded;

- (void)disableControls;

- (NSBox*)box;

- (void)updateView:(id)notification;
- (void)updateProfileView:(id)notification;
- (void)setProfilePopupToProfile: (NSString *)profileName;

- (void)loadProfileIntoView;

- (void)setSaveCheckboxIsVisible:(BOOL)visible;
- (void)setSuperController:(RFBConnectionManager *)aSuperController;

@end

#if 0
@protocol ConnectionDelegate

- (void)successfulConnection: (RFBConnection *)connection
                    toServer:(id<IServerData>)server;

@end
#endif
