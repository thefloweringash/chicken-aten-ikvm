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
		// The order of remember password setting and password is critical, or we risk loosing
		// saved passwords.
		[self setName:            [NSString stringWithString:@"new server"]];
		[self setHost:            [NSString stringWithString:@"localhost"]];
		[self setRememberPassword:NO];
		[self setPassword:        [NSString stringWithString:@""]];
		[self setDisplay:         0];
		[self setLastProfile:     [NSString stringWithString:[[ProfileDataManager sharedInstance] defaultProfileName]]];
		[self setShared:          NO];
		[self setFullscreen:      NO];

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
	// subclasses are fully responsible for implementing this
	assert(0);
	
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
	ProfileDataManager* profileManager = [ProfileDataManager sharedInstance];
	
	if( nil != [profileManager profileForKey: lastProfile] )
	{
		[_lastProfile autorelease];
		_lastProfile = [lastProfile retain];
	}
	else if( nil == [profileManager profileForKey: _lastProfile] )
	{
		// This can actually happen at load, and this is a good place to catch it
		[_lastProfile autorelease];
		[self setLastProfile:[NSString stringWithString:[profileManager defaultProfileName]]];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setDelegate: (id<IServerDataDelegate>)delegate
{
	_delegate = delegate;
}

- (void)profileListUpdate:(id)notification
{
	ProfileDataManager* profileManager = [ProfileDataManager sharedInstance];
	
	NSString *lastProfile = [self lastProfile];
	if( !lastProfile || (nil == [profileManager profileForKey: lastProfile]) )
	{
		[self setLastProfile:[NSString stringWithString:[profileManager defaultProfileName]]];
	}
}

@end
