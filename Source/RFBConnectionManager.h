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

@interface RFBConnectionManager : NSObject
{
    id connect;
    id display;
    id hostName;
    id passWord;
    id shared;
    NSPanel *loginPanel;
    NSMutableArray*	connections;
        
    id colorModelMatrix;
    id psThreshold;
    id psMaxRects;
    id gamma;
    id profilePopup;
    id profileManager;
    id rememberPwd;
	id autoscrollIncrement; // jason added
	id fullscreenScrollbars; // jason added
}

+ (float)gammaCorrection;
+ (void)getLocalPixelFormat:(rfbPixelFormat*)pf;

- (id)init;
- (void)awakeFromNib;
- (void)dealloc;
- (void)removeConnection:(id)aConnection;
- (void)connect:(id)sender;

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost;
- (void)setDisplayNameTranslation:(NSString*)translation forName:(NSString*)aName forHost:(NSString*)aHost;

- (void)createConnectionWithDictionary:(NSDictionary *) someDict profile:(Profile *) someProfile owner:(id) someOwner;

- (void)preferencesChanged:(id)sender;
- (id)defaultFrameBufferClass;
//- (void)applicationWillTerminate:(NSNotification *)aNotification;

- (void)controlTextDidChange:(NSNotification *)aNotification;

// Jason added the following for full-screen windows
- (void)makeAllConnectionsWindowed;

- (BOOL)haveMultipleConnections; // True if there is more than one connection open.
- (BOOL)haveAnyConnections;      // True if there are any connections open.

@end
