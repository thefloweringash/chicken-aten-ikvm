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

#import <Foundation/Foundation.h>

@implementation ServerBase

- (id)init
{
	if( self = [super init] )
	{
		// The order of remember password setting and password is critical, or we risk loosing
		// saved passwords.
		[self setName:            [NSString stringWithString:@"new server"]];
		[self setHostAndPort:     [NSString stringWithString:@"localhost"]];
		[self setRememberPassword:NO];
		[self setPassword:        [NSString stringWithString:@""]];
		[self setDisplay:         0];
		[self setPort:            5900];
		[self setLastProfile:     [NSString stringWithString:[[ProfileDataManager sharedInstance] defaultProfileName]]];
		[self setShared:          NO];
		[self setFullscreen:      NO];
		[self setViewOnly:      NO];

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
	[_hostAndPort release];
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

- (NSString *)hostAndPort
{
	return _hostAndPort;
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

- (bool)isPortSpecifiedInHost
{
    return _isPortSpecifiedInHost;
}

- (int)port
{
	return _port;
}

- (bool)shared
{
	return _shared;
}

- (bool)fullscreen
{
	return _fullscreen;
}

- (bool)viewOnly
{
	return _viewOnly;
}

- (NSString*)lastProfile
{
	return _lastProfile;
}

- (void)setName: (NSString*)name
{
	[_name release];
	if( nil != name )
	{
		_name = [name retain];
	}
	else
	{
		_name = [[NSString stringWithString:@"localhost"] retain];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setHost: (NSString*)host
{
	[_host release];
	if( nil != host )
	{
        _host = [host retain];
	}
	else
	{
		_host = [[NSString stringWithString:@"new server"] retain];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setHostAndPort: (NSString*)hostAndPort
{
	BOOL portWasSpecifiedInHost = [self isPortSpecifiedInHost];
    NSString *strippedHost = [hostAndPort stringByTrimmingCharactersInSet:
                                    [NSCharacterSet whitespaceCharacterSet]];
	
	[_hostAndPort release];
	if( nil != hostAndPort )
	{
		_hostAndPort = [hostAndPort retain];
		
        if ([hostAndPort hasPrefix: @"["]) {
            // IPv6 escaped notation, in which the host is surrounded by []
            NSRange endBracket = [strippedHost rangeOfString: @"]"];
            NSRange hostRange;

            hostRange.location = 1;
            if (endBracket.location == NSNotFound)
                hostRange.length = [strippedHost length] - 1;
            else
                hostRange.length = endBracket.location - 1;

            [self setHost: [strippedHost substringWithRange: hostRange]];
            
            if ([strippedHost length] > hostRange.length + 2
                    && [strippedHost characterAtIndex: hostRange.length + 2] == ':') {
                // port also specified in string
                NSString    *portStr;
                portStr = [strippedHost substringFromIndex: hostRange.length + 3];
                [self setPort: [portStr intValue]];
                _isPortSpecifiedInHost = YES;
            } else
                _isPortSpecifiedInHost = NO;
        } else {
            NSArray *items = [strippedHost componentsSeparatedByString:@":"];

            if ([items count] == 2) {
                // host:port format
                [self setHost: [items objectAtIndex: 0]];
                [self setPort: [[items objectAtIndex: 1] intValue]];
                _isPortSpecifiedInHost = YES;
            } else {
                // Either no colons or IPv6 notation
                [self setHost: strippedHost];
                _isPortSpecifiedInHost = NO;
            }
        }

        if (portWasSpecifiedInHost && !_isPortSpecifiedInHost)
            [self setDisplay: [self display]];
	}
	else
	{
		_hostAndPort = [_host copy];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setPassword: (NSString*)password
{
	[_password release];
	
	if( nil != password )
	{
		_password = [password retain];
	}
	else
	{
		_password = [[NSString stringWithString:@""] retain];
	}
	
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
    if (_display < DISPLAY_MAX)
        [self setPort: _display + PORT_BASE];
    else
        [self setPort: _display];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setShared: (bool)shared
{
	_shared = shared;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setPort: (int)port
{
	_port = port;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setFullscreen: (bool)fullscreen
{
	_fullscreen =  fullscreen;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setViewOnly: (bool)viewOnly
{
	_viewOnly = viewOnly;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

- (void)setLastProfile: (NSString*)lastProfile
{
	ProfileDataManager* profileManager = [ProfileDataManager sharedInstance];
	
	if( [profileManager profileWithNameExists: lastProfile] )
	{
		[_lastProfile autorelease];
		_lastProfile = [lastProfile retain];
	}
	else if( ![profileManager profileWithNameExists: _lastProfile] )
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
	if( !lastProfile || ![profileManager profileWithNameExists: lastProfile] )
	{
		[self setLastProfile:[NSString stringWithString:[profileManager defaultProfileName]]];
	}
}

- (void)copyServer: (id<IServerData>)server
{
	
	[self setHostAndPort:[server hostAndPort]];
	// remember password must come before setting the password (in case a root class
	// needs to do appropriate save logic
	[self setRememberPassword:[server rememberPassword]];
	[self setPassword:[server password]];
	[self setDisplay:[server display]];
	[self setPort:[server port]];
	[self setShared:[server shared]];
	[self setFullscreen:[server fullscreen]];
	[self setViewOnly:[server viewOnly]];
	[self setLastProfile:[server lastProfile]];
}

- (bool)addToServerListOnConnect
{
	return NO;
}

@end
