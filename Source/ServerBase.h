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

#define PORT_BASE 5900

@class Profile;

// This represents all the data and settings needed to connect to a VNC server.
@interface ServerBase : NSObject <IServerData> {
	NSString* _host;
	NSString* _password;
	int       _port;
	bool      _shared;
	bool      _fullscreen;
	bool      _viewOnly;	
    Profile   *_profile;

    NSString  *_sshHost;
    int       _sshPort; // 0 means use default port
    NSString  *_sshUser;
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
- (NSString*)password;
- (BOOL)rememberPassword;
- (int)port;
- (bool)shared;
- (bool)fullscreen;
- (bool)viewOnly;
- (Profile *)profile;
- (bool)addToServerListOnConnect;

- (NSString *)sshHost;
- (int)sshPort;
- (NSString *)sshUser;
- (NSString *)sshString;

- (void)setHost: (NSString*)host;
- (BOOL)setHostAndPort: (NSString*)host;
- (void)setPassword: (NSString*)password;
- (void)setDisplay: (int)display;
- (void)setShared: (bool)shared;
- (void)setPort: (int)port;
- (void)setFullscreen: (bool)fullscreen;
- (void)setViewOnly: (bool)viewOnly;
- (void)setProfile: (Profile *)profile;
- (void)setProfileName: (NSString *)profileName;
- (void)setSshString:(NSString *)str;
- (void)setSshTunnel:(BOOL)enable;

- (void)copyServer: (id<IServerData>)server;

//@}

@end
