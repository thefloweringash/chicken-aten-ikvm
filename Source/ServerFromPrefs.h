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

@interface ServerFromPrefs : NSObject <IServerData> {
	NSString* _name;
	NSString* _host;
	NSString* _password;
	bool      _rememberPassword;
	int       _display;
	int       _lastDisplay;
	bool      _shared;
	bool      _fullscreen;
	NSString* _lastProfile;
	
	NSMutableDictionary* _prefDict;
}

+ (id<IServerData>)createWithName:(NSString*)name;
+ (id<IServerData>)createWithHost:(NSString*)hostName preferenceDictionary:(NSDictionary*)prefDict;

- (id)initWithDefaults;
- (id)initWithHost:(NSString*)host preferenceDictionary:(NSDictionary*)prefDict;

/* @name Archiving and Unarchiving
 * Implements the NSCoding protocol for serialization
 */
//@{
- (void)encodeWithCoder:(NSCoder*)coder;
- (id)initWithCoder:(NSCoder*)coder;
//@}

// IServerData
- (NSString*)name;
- (NSString*)host;
- (NSString*)password;
- (bool)rememberPassword;
- (int)display;
- (int)lastDisplay;
- (bool)shared;
- (bool)fullscreen;
- (NSString*)lastProfile;

- (void)setName: (NSString*)name;
- (void)setHost: (NSString*)host;
- (void)setPassword: (NSString*)password;
- (void)setRememberPassword: (bool)rememberPassword;
- (void)setDisplay: (int)display;
- (void)setLastDisplay: (int)lastDisplay;
- (void)setShared: (bool)shared;
- (void)setFullscreen: (bool)fullscreen;
- (void)setLastProfile: (NSString*)lastProfile;

@end
