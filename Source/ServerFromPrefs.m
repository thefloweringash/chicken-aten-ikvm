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
#import "KeyChain.h"

#define RFB_NAME          @"Name"
#define RFB_HOST		  @"Host"
#define RFB_PASSWORD	  @"Password"
#define RFB_REMEMBER	  @"RememberPassword"
#define RFB_DISPLAY		  @"Display"
#define RFB_SHARED		  @"Shared"
#define RFB_FULLSCREEN    @"Fullscreen"
#define RFB_LAST_DISPLAY  @"Display"
#define RFB_LAST_PROFILE  @"Profile"
#define RFB_PORT		  5900

#define KEYCHAIN_SERVICE_NAME	@"cotvnc" // This should really be the appname, but I'm too lame to know how to find that - kjw

@implementation ServerFromPrefs

+ (void)initialize
{
	[ServerFromPrefs setVersion:1];
}

- (id)initWithHost:(NSString*)host preferenceDictionary:(NSDictionary*)prefDict
{
    if( self = [super init] )
	{
		_name =             [[NSString stringWithString:host] retain];
		_host =             [host retain];
		_password =         [[NSString stringWithString:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name]] retain];
		_rememberPassword = [[prefDict objectForKey:RFB_REMEMBER] intValue] == 0 ? NO : YES;
		_display =          [[prefDict objectForKey:RFB_DISPLAY] intValue];
		_lastDisplay =      [[prefDict objectForKey:RFB_LAST_DISPLAY] intValue];
		_lastProfile =      [prefDict objectForKey:RFB_LAST_PROFILE];
		_shared =           [[prefDict objectForKey:RFB_SHARED] intValue] == 0 ? NO : YES;
		_fullscreen =       [[prefDict objectForKey:RFB_FULLSCREEN] intValue] == 0 ? NO : YES;
	}
	
	return self;
}

- (id)initWithDefaults
{
	if( self = [super init] )
	{
		_name =             [[NSString stringWithString:@"new server"] retain];
		_host =             [[NSString stringWithString:@"localhost"] retain];
		_password =         [[NSString alloc] init];
		_rememberPassword = NO;
		_display =          0;
		_lastDisplay =      0;
		_lastProfile =      [[NSString alloc] init];
		_shared =           NO;
		_fullscreen =       NO;
	}
	
	return self;
}

- (void)dealloc
{
	[_prefDict release];
	[_name release];
	[_password release];
}

+ (id<IServerData>)createWithHost:(NSString*)hostName preferenceDictionary:(NSDictionary*)prefDict;
{
	return [[[ServerFromPrefs alloc] initWithHost:hostName preferenceDictionary:prefDict] autorelease];
}

+ (id<IServerData>)createWithName:(NSString*)name
{
	ServerFromPrefs* newServer = [[ServerFromPrefs alloc] initWithDefaults];
	[newServer setName:name];
	
	return newServer;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    assert( [coder allowsKeyedCoding] );

	[coder encodeObject:_name			 forKey:RFB_NAME];
	[coder encodeObject:_host			 forKey:RFB_HOST];
	[coder encodeBool:_rememberPassword  forKey:RFB_REMEMBER];
	[coder encodeInt:_display			 forKey:RFB_DISPLAY];
	[coder encodeInt:_lastDisplay		 forKey:RFB_LAST_DISPLAY];
	[coder encodeObject:_lastProfile	 forKey:RFB_LAST_PROFILE];
	[coder encodeBool:_shared			 forKey:RFB_SHARED];
	[coder encodeBool:_fullscreen		 forKey:RFB_FULLSCREEN];
   	
    return;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
	if( nil != self )
	{
		assert( [coder allowsKeyedCoding] );

		// Can decode keys in any order
		_name =             [[coder decodeObjectForKey:RFB_NAME] retain];
		_host =             [[coder decodeObjectForKey:RFB_HOST] retain];
		_rememberPassword = [coder decodeBoolForKey:RFB_REMEMBER];
		_display =          [coder decodeIntForKey:RFB_DISPLAY];
		_lastDisplay =      [coder decodeIntForKey:RFB_LAST_DISPLAY];
		_lastProfile =      [[coder decodeObjectForKey:RFB_LAST_PROFILE] retain];
		_shared =           [coder decodeBoolForKey:RFB_SHARED];
		_fullscreen =       [coder decodeBoolForKey:RFB_FULLSCREEN];
			
		_password = [[NSString stringWithString:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name]] retain];
	}
	
    return self;
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

- (int)lastDisplay
{
	return _lastDisplay;
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
	// if the password is saved, destroy the one off the old name key
	if( YES == _rememberPassword)
	{
		[[KeyChain defaultKeyChain] removeGenericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name];
	}
	
	[_name release];
	_name = name;
	[_name retain];
	
	// if the password should be saved, save it with the new name key
	if( YES == _rememberPassword)
	{
		[[KeyChain defaultKeyChain] setGenericPassword:_password forService:KEYCHAIN_SERVICE_NAME account:_name];
	}
}

- (void)setHost: (NSString*)host
{
	[_host release];
	_host = host;
	[_host retain];
}

- (void)setPassword: (NSString*)password
{
	[_password release];
	_password = password;
	[_password retain];
	
	// only save if set to do so
	if( _rememberPassword )
	{
		[[KeyChain defaultKeyChain] setGenericPassword:_password forService:KEYCHAIN_SERVICE_NAME account:_name];
	}
}

- (void)setRememberPassword: (bool)rememberPassword
{
	_rememberPassword = rememberPassword;
	
	// make sure that the saved password reflects the new remember password setting
	if( YES == _rememberPassword )
	{
		[[KeyChain defaultKeyChain] setGenericPassword:_password forService:KEYCHAIN_SERVICE_NAME account:_name];
	}
	else
	{
		[[KeyChain defaultKeyChain] removeGenericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name];
	}
}

- (void)setDisplay: (int)display
{
	_display = display;
}

- (void)setLastDisplay: (int)lastDisplay
{
	_lastDisplay = lastDisplay;
}

- (void)setShared: (bool)shared
{
	_shared = shared;
}

- (void)setFullscreen: (bool)fullscreen
{
	_fullscreen =  fullscreen;
}

- (void)setLastProfile: (NSString*)lastProfile
{
	[_lastProfile release];
	_lastProfile = lastProfile;
	[_lastProfile retain];
}

@end
