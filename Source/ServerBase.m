//
//  ServerFromPrefs.m
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

#import "ServerFromPrefs.h"
#import "IServerData.h"
#import "ProfileManager.h"
#import "ProfileDataManager.h"

@implementation ServerBase

- (id)init
{
	if( self = [super init] )
	{
		_name =             [[NSString alloc] initWithString:@"new server"];
		_host =             [[NSString alloc] initWithString:@"localhost"];
		_password =         [[NSString alloc] init];
		_rememberPassword = NO;
		_display =          0;
		_lastProfile =      nil;
		_shared =           NO;
		_fullscreen =       NO;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(profileListUpdate:)
													 name:ProfileListChangeMsg
												   object:(id)[ProfileDataManager sharedInstance]];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:ProfileListChangeMsg
												  object:(id)[ProfileDataManager sharedInstance]];
												  
	[_name release];
	[_host release];
	[_password release];
	[_lastProfile release];
	[super dealloc];
}

- (bool)doYouSupport: (SUPPORT_TYPE)type
{
	switch( type )
	{
		case EDIT_ADDRESS:
		case EDIT_PORT:
		case EDIT_NAME:
		case CONNECT:
			return YES;
		case SAVE_PASSWORD:
			return NO;
		default:
			// handle all cases
			assert(0);
	}
	
	return NO;
}

- (NSString*)name
{
	return _name;
}

- (NSString*)host
{
	return _host;
}

- (NSString*)password
{
	return _password;
}

- (bool)rememberPassword
{
	return _rememberPassword;
}

- (int)display
{
	return _display;
}

- (bool)shared
{
	return _shared;
}

- (bool)fullscreen
{
	return _fullscreen;
}

- (NSString*)lastProfile
{
	return _lastProfile;
}

- (void)setName: (NSString*)name
{
	[_name autorelease];
	_name = [name retain];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setHost: (NSString*)host
{
	[_host autorelease];
	_host = [host retain];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setPassword: (NSString*)password
{
	[_password autorelease];
	_password = [password retain];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setRememberPassword: (bool)rememberPassword
{
	_rememberPassword = rememberPassword;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setDisplay: (int)display
{
	_display = display;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setShared: (bool)shared
{
	_shared = shared;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setFullscreen: (bool)fullscreen
{
	_fullscreen =  fullscreen;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setLastProfile: (NSString*)lastProfile
{
	[_lastProfile autorelease];
	_lastProfile = nil;
	
	if( nil != [[ProfileDataManager sharedInstance] profileForKey: lastProfile] )
		_lastProfile = [lastProfile retain];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setDelegate: (id<IServerDataDelegate>)delegate
{
	_delegate = delegate;
}

- (void)profileListUpdate:(id)notification
{
	NSString *lastProfile = [self lastProfile];
	if( !lastProfile || (nil == [[ProfileDataManager sharedInstance] profileForKey: lastProfile]) )
	{
		[self setLastProfile:nil];
	}
}

@end
