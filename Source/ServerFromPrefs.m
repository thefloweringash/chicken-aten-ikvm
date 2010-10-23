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
#define RFB_HOSTANDPORT   @"HostAndPort"
#define RFB_PASSWORD	  @"Password"
#define RFB_REMEMBER	  @"RememberPassword"
#define RFB_DISPLAY		  @"Display"
#define RFB_DISPLAYMAX    @"DisplayMax"
#define RFB_SHARED		  @"Shared"
#define RFB_FULLSCREEN    @"Fullscreen"
#define RFB_VIEWONLY      @"ViewOnly"
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
		[self setName:             [NSString stringWithString:host]];
		[self setHostAndPort:      [NSString stringWithString:host]];
		[self setPassword:         [NSString stringWithString:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name]]];
		/* super instead of self here because we don't need to save the
		 * password. Moreover, if we couldn't get access to the keychain, then
		 * we don't want to clobber the keychain password. */
		[super setRememberPassword:[[prefDict objectForKey:RFB_REMEMBER] intValue] == 0 ? NO : YES];
		[self setDisplay:         [[prefDict objectForKey:RFB_DISPLAY] intValue]];
		[self setLastProfile:      [prefDict objectForKey:RFB_LAST_PROFILE]];
		[self setShared:          [[prefDict objectForKey:RFB_SHARED] intValue] == 0 ? NO : YES];
		[self setFullscreen:      [[prefDict objectForKey:RFB_FULLSCREEN] intValue] == 0 ? NO : YES];
		[self setViewOnly:        [[prefDict objectForKey:RFB_VIEWONLY] intValue] == 0 ? NO : YES];
	}
	
	return self;
}

- (void)dealloc
{
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
	[coder encodeObject:_hostAndPort     forKey:RFB_HOSTANDPORT];
	[coder encodeBool:_rememberPassword  forKey:RFB_REMEMBER];
    [coder encodeInt:DISPLAY_MAX         forKey:RFB_DISPLAYMAX];
	[coder encodeInt:_display			 forKey:RFB_DISPLAY];
	[coder encodeObject:_lastProfile	 forKey:RFB_LAST_PROFILE];
	[coder encodeBool:_shared			 forKey:RFB_SHARED];
	[coder encodeBool:_fullscreen		 forKey:RFB_FULLSCREEN];
	[coder encodeBool:_viewOnly          forKey:RFB_VIEWONLY];
}

- (id)initWithCoder:(NSCoder *)coder
{
	[self autorelease];
	NSParameterAssert( [coder allowsKeyedCoding] );
	[self retain];
	
	if( self = [super init] )
	{				
		[self setName:            [coder decodeObjectForKey:RFB_NAME]];
		[self setHost:            [coder decodeObjectForKey:RFB_HOST]];
		[self setPassword:        [NSString stringWithString:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_SERVICE_NAME account:_name]]];
        // Note the super instead of self here. See comment in initWithHost.
		[super setRememberPassword:[coder decodeBoolForKey:RFB_REMEMBER]];

		int displayMax; // what DISPLAY_MAX was used by whoever encoded this
		if ([coder containsValueForKey: RFB_DISPLAYMAX])
			displayMax = [coder decodeIntForKey:RFB_DISPLAYMAX];
		else
			displayMax = INT_MAX; // COTV version 2.0b4 and earlier

		int display = [coder decodeIntForKey:RFB_DISPLAY];
		if (display >= displayMax || display < DISPLAY_MAX)
			[self setDisplay: display];
		else
			[self setDisplay: display + PORT_BASE];

		[self setLastProfile:     [coder decodeObjectForKey:RFB_LAST_PROFILE]];
		[self setShared:          [coder decodeBoolForKey:RFB_SHARED]];
		[self setFullscreen:      [coder decodeBoolForKey:RFB_FULLSCREEN]];
		[self setViewOnly:  	  [coder decodeBoolForKey:RFB_VIEWONLY]];
		[self setHostAndPort:     [coder decodeObjectForKey:RFB_HOSTANDPORT]]; // might not be present
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
		case EDIT_PASSWORD:
		case SAVE_PASSWORD:
		case CONNECT:
		//case DELETE:
		//case SERVER_SAVE:
			return YES;
		//case ADD_SERVER_ON_CONNECT:
			//return NO;
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
