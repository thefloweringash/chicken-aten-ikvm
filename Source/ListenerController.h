//
//  ListenerController.h
//  Chicken of the VNC
//
//  Created by Mark Lentczner on Sat Oct 23 2004.
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
#import "Profile.h"

@interface ListenerController : NSWindowController
{
    IBOutlet NSTextField *portText;
    IBOutlet NSButton *localOnlyBtn;
    IBOutlet NSPopUpButton *profilePopup;
    IBOutlet NSButton *fullscreen;

	IBOutlet NSButton *actionBtn;
	IBOutlet NSTextField *statusText;

    NSFileHandle* listeningSockets[2]; // listening socket: IPv4 and IPv6
    Profile* listeningProfile;
}

+ (ListenerController*)sharedController;

- (IBAction)actionPressed:(id)sender;
- (IBAction)valueChanged:(id)sender;
- (void)setDisplaysFullscreen:(BOOL)aFullscreen;

- (BOOL)startListenerOnPort:(int)port withProfile:(Profile*)profile localOnly:(BOOL)local;
- (void)stopListener;

- (void)setProfilePopupToProfile: (NSString *)profileName;
- (void)changeProfileTo:(Profile *)profile;

@end
