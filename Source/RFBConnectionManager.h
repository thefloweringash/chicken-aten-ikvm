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
#import "rfbproto.h"
#import "Profile.h"
@class ProfileManager;

/* Constants, generally used for userdefaults */
#define RFB_COLOR_MODEL		@"RFBColorModel"
#define RFB_GAMMA_CORRECTION	@"RFBGammaCorrection"
#define RFB_LAST_HOST		@"RFBLastHost"

#define RFB_HOST_INFO		@"HostPreferences"
#define RFB_LAST_DISPLAY	@"Display"
#define RFB_LAST_PROFILE	@"Profile"

@interface RFBConnectionManager : NSObject
{
    IBOutlet NSTextField *display;
    IBOutlet NSComboBox *hostName;
    IBOutlet NSSecureTextField *passWord;
    IBOutlet NSButton *shared;
    IBOutlet NSPanel *loginPanel;
    IBOutlet NSMatrix *colorModelMatrix;
    IBOutlet NSTextField *psThreshold;
    IBOutlet NSTextField *psMaxRects;
    IBOutlet NSTextField *gamma;
    IBOutlet NSPopUpButton *profilePopup;
    IBOutlet ProfileManager *profileManager;
    IBOutlet NSButton *rememberPwd;
	IBOutlet NSSlider *autoscrollIncrement;
	IBOutlet NSButton *fullscreenScrollbars;
	IBOutlet NSSlider *frontInverseCPUSlider;
	IBOutlet NSSlider *otherInverseCPUSlider;
    NSMutableArray*	connections;
}

+ (float)gammaCorrection;
+ (void)getLocalPixelFormat:(rfbPixelFormat*)pf;

- (void)updateProfileList:(id)notification;
- (void)updateLoginPanel;
- (void)removeConnection:(id)aConnection;
- (IBAction)connect:(id)sender;

- (void)selectedHostChanged: (NSString *) newHostName;

- (NSDictionary *) selectedHostDictionary;

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost;
- (void)setDisplayNameTranslation:(NSString*)translation forName:(NSString*)aName forHost:(NSString*)aHost;

- (void)createConnectionWithDictionary:(NSDictionary *) someDict profile:(Profile *) someProfile owner:(id) someOwner;

- (IBAction)preferencesChanged:(id)sender;
- (id)defaultFrameBufferClass;

//- (void)controlTextDidChange:(NSNotification *)aNotification; no needed?

- (void)makeAllConnectionsWindowed;

- (BOOL)haveMultipleConnections; // True if there is more than one connection open.
- (BOOL)haveAnyConnections;      // True if there are any connections open.

- (IBAction)frontInverseCPUSliderChanged: (NSSlider *)sender;
- (IBAction)otherInverseCPUSliderChanged: (NSSlider *)sender;
- (float)maxPossibleFrameBufferUpdateSeconds;

@end
