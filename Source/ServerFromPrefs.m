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
#import "IServerData.h"
#import "ServerDataManager.h"

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
		[_name autorelease];
		[_host autorelease];
		[_password autorelease];
		[_lastProfile autorelease];
		
		_name =             [host copy];
		_host =             [host retain];
		_password =         [[NSString alloc] initWithString:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name]];
		_rememberPassword = [[prefDict objectForKey:RFB_REMEMBER] intValue] == 0 ? NO : YES;
		_display =          [[prefDict objectForKey:RFB_DISPLAY] intValue];
		_lastProfile =      [[prefDict objectForKey:RFB_LAST_PROFILE] retain];
		_shared =           [[prefDict objectForKey:RFB_SHARED] intValue] == 0 ? NO : YES;
		_fullscreen =       [[prefDict objectForKey:RFB_FULLSCREEN] intValue] == 0 ? NO : YES;
	}
	
	return self;
}

- (void)dealloc
{
	[_prefDict release];
	[super dealloc];
}

+ (id<IServerData>)createWithHost:(NSString*)hostName preferenceDictionary:(NSDictionary*)prefDict;
{
	return [[[ServerFromPrefs alloc] initWithHost:hostName preferenceDictionary:prefDict] autorelease];
}

+ (id<IServerData>)createWithName:(NSString*)name
{
	ServerFromPrefs* newServer = [[[ServerFromPrefs alloc] init] autorelease];
	[newServer setName:name];
	
	return newServer;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSParameterAssert( [coder allowsKeyedCoding] );

	[coder encodeObject:_name			 forKey:RFB_NAME];
	[coder encodeObject:_host			 forKey:RFB_HOST];
	[coder encodeBool:_rememberPassword  forKey:RFB_REMEMBER];
	[coder encodeInt:_display			 forKey:RFB_DISPLAY];
	[coder encodeObject:_lastProfile	 forKey:RFB_LAST_PROFILE];
	[coder encodeBool:_shared			 forKey:RFB_SHARED];
	[coder encodeBool:_fullscreen		 forKey:RFB_FULLSCREEN];
}

- (id)initWithCoder:(NSCoder *)coder
{
	[self autorelease];
	NSParameterAssert( [coder allowsKeyedCoding] );
	[self retain];
	
	if( self = [super init] )
	{
		[_name autorelease];
		[_host autorelease];
		[_password autorelease];
		[_lastProfile autorelease];
				
		// Can decode keys in any order
		_name =             [[coder decodeObjectForKey:RFB_NAME] retain];
		_host =             [[coder decodeObjectForKey:RFB_HOST] retain];
		_rememberPassword = [coder decodeBoolForKey:RFB_REMEMBER];
		_display =          [coder decodeIntForKey:RFB_DISPLAY];
		_lastProfile =      [[coder decodeObjectForKey:RFB_LAST_PROFILE] retain];
		_shared =           [coder decodeBoolForKey:RFB_SHARED];
		_fullscreen =       [coder decodeBoolForKey:RFB_FULLSCREEN];
			
		_password = [[NSString alloc] initWithString:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name]];
	}
	
    return self;
}

- (bool)doYouSupport: (SUPPORT_TYPE)type
{
	switch( type )
	{
		case EDIT_ADDRESS:
		case EDIT_PORT:
		case EDIT_NAME:
		case SAVE_PASSWORD:
		case CONNECT:
		case DELETE:
			return YES;
		default:
			// handle all cases
			assert(0);
	}
	
	return NO;
}

- (void)setName: (NSString*)name
{
	if( NSOrderedSame != [name compare:_name] )
	{
		NSMutableString *nameHelper = [NSMutableString stringWithString:name];
		
		[_delegate validateNameChange:nameHelper forServer:self];
		
		// if the password is saved, destroy the one off the old name key
		if( YES == _rememberPassword)
		{
			[[KeyChain defaultKeyChain] removeGenericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name];
		}
		
		[super setName:nameHelper];
		
		// if the password should be saved, save it with the new name key
		if( YES == _rememberPassword)
		{
			[[KeyChain defaultKeyChain] setGenericPassword:_password forService:KEYCHAIN_SERVICE_NAME account:_name];
		}
	}
}

- (void)setPassword: (NSString*)password
{
	[super setPassword:password];
	
	// only save if set to do so
	if( YES == _rememberPassword )
	{
		[[KeyChain defaultKeyChain] setGenericPassword:_password forService:KEYCHAIN_SERVICE_NAME account:_name];
	}
}

- (void)setRememberPassword: (bool)rememberPassword
{
	[super setRememberPassword:rememberPassword];
	
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

@end
