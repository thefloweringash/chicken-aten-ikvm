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
#define RFB_GUID          @"Host_ID"
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

- (id)initWithHost:(NSString*)host preferenceDictionary:(NSDictionary*)prefDict
{
    if( self = [super init] )
	{
		//_prefDict = [[NSMutableDictionary dictionaryWithDictionary:prefDict] retain];
		
		if( nil == _name )
		{
			_name = [[NSString stringWithString:host] retain];
		}
		_host = host;
		_password =         [[NSString stringWithString:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name]] retain];
		_rememberPassword = [prefDict objectForKey:RFB_REMEMBER];
		_display =          [prefDict objectForKey:RFB_DISPLAY];
		_lastDisplay =      [prefDict objectForKey:RFB_LAST_DISPLAY];
		_lastProfile =      [prefDict objectForKey:RFB_LAST_PROFILE];
		_shared =           [prefDict objectForKey:RFB_SHARED];
		_fullscreen =       [prefDict objectForKey:RFB_FULLSCREEN];
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
		_rememberPassword = [[NSString alloc] init];
		_display =          [[NSString alloc] init];
		_lastDisplay =      [[NSString alloc] init];
		_lastProfile =      [[NSString alloc] init];
		_shared =           [[NSString alloc] init];
		_fullscreen =       [[NSString alloc] init];
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
	return [_rememberPassword intValue] == 0 ? NO : YES;
}

- (NSString*)display
{
	return _display;
}

- (NSString*)lastDisplay
{
	return _lastDisplay;
}

- (bool)shared
{
	return [_shared intValue] == 0 ? NO : YES;
}

- (bool)fullscreen
{
	return [_fullscreen intValue] == 0 ? NO : YES;
}

- (NSString*)lastProfile
{
	return _lastProfile;
}

- (void)setName: (NSString*)name
{
	// if the password is saved, destroy the one off the old name key
	if( 0 != [_rememberPassword intValue] )
	{
		[[KeyChain defaultKeyChain] removeGenericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name];
	}
	
	[_name release];
	_name = name;
	[_name retain];
	
	// if the password should be saved, save it with the new name key
	if( 0 != [_rememberPassword intValue] )
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
	[_rememberPassword release];
	_rememberPassword = [NSString stringWithFormat:@"%d", rememberPassword];
	[_rememberPassword retain];
	
	//[_prefDict setObject:_rememberPassword forKey:RFB_REMEMBER];
	
	// make sure that the saved password reflects the new remember password setting
	if( 0 != [_rememberPassword intValue] )
	{
		[[KeyChain defaultKeyChain] setGenericPassword:_password forService:KEYCHAIN_SERVICE_NAME account:_name];
	}
	else
	{
		[[KeyChain defaultKeyChain] removeGenericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name];
	}
}

- (void)setDisplay: (NSString*)display
{
	[_display release];
	_display = display;
	[_display retain];
	
	//[_prefDict setObject:_display forKey:RFB_DISPLAY];
}

- (void)setLastDisplay: (NSString*)lastDisplay
{
	[_lastDisplay release];
	_lastDisplay = lastDisplay;
	[_lastDisplay retain];
	
	//[_prefDict setObject:_lastDisplay forKey:RFB_LAST_DISPLAY];
}

- (void)setShared: (bool)shared
{
	[_shared release];
	_shared = [NSString stringWithFormat:@"%d", shared];
	[_shared retain];
	
	//[_prefDict setObject:_shared forKey:RFB_SHARED];
}

- (void)setFullscreen: (bool)fullscreen
{
	[_fullscreen release];
	_fullscreen =  [NSString stringWithFormat:@"%d", fullscreen];
	[_fullscreen retain];
	
	//[_prefDict setObject:_fullscreen forKey:RFB_FULLSCREEN];
}

- (void)setLastProfile: (NSString*)lastProfile
{
	[_lastProfile release];
	_lastProfile = lastProfile;
	[_lastProfile retain];
	
	//[_prefDict setObject:_lastProfile forKey:RFB_LAST_PROFILE];
}

@end
