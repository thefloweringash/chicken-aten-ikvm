//
//  ServerFromPrefs.h
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sat Jan 24 2004.
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

#import <Foundation/Foundation.h>
#import "IServerData.h"

@interface ServerBase : NSObject <IServerData> {
	NSString* _name;
	NSString* _host;
	NSString* _hostAndPort;
	NSString* _password;
	bool      _rememberPassword;
	int       _display;
	int       _port;
	bool      _shared;
	bool      _fullscreen;
	bool      _viewOnly;	
	NSString* _lastProfile;
	id<IServerDataDelegate> _delegate;
}

- (id)init;
- (void)dealloc;

/** @name IServerData
 *  Implements the IServerData protocol
 */
//@{
- (bool)doYouSupport: (SUPPORT_TYPE)type;

- (NSString*)name;
- (NSString*)host;
- (NSString*)hostAndPort;
- (NSString*)password;
- (bool)rememberPassword;
- (int)display;
- (bool)isPortSpecifiedInHost;
- (int)port;
- (bool)shared;
- (bool)fullscreen;
- (bool)viewOnly;
- (NSString*)lastProfile;
- (bool)addToServerListOnConnect;

- (void)setName: (NSString*)name;
- (void)setHost: (NSString*)host;
- (void)setHostAndPort: (NSString*)host;
- (void)setPassword: (NSString*)password;
- (void)setRememberPassword: (bool)rememberPassword;
- (void)setDisplay: (int)display;
- (void)setShared: (bool)shared;
- (void)setPort: (int)port;
- (void)setFullscreen: (bool)fullscreen;
- (void)setViewOnly: (bool)viewOnly;
- (void)setLastProfile: (NSString*)lastProfile;
- (void)setAddToServerListOnConnect: (bool)addToServerListOnConnect;

- (void)setDelegate: (id<IServerDataDelegate>)delegate;

- (void)profileListUpdate:(id)notification;
//@}

@end
