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
#import "Profile.h"
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

@implementation ServerFromPrefs

+ (void)initialize
{
	[ServerFromPrefs setVersion:1];
}

/* This is used for loading the servers under some old preference scheme (before
 * 2.0b4. */
- (id)initWithHost:(NSString*)host preferenceDictionary:(NSDictionary*)prefDict
{
    if( self = [super init] )
	{
        _name = [host retain];
        [self setHost: host];
        _rememberPassword =       [[prefDict objectForKey:RFB_REMEMBER] boolValue];
		[self setDisplay:         [[prefDict objectForKey:RFB_DISPLAY] intValue]];
		[self setProfileName:      [prefDict objectForKey:RFB_LAST_PROFILE]];
		[self setShared:          [[prefDict objectForKey:RFB_SHARED] intValue]];
		[self setFullscreen:      [[prefDict objectForKey:RFB_FULLSCREEN] intValue]];
		[self setViewOnly:        [[prefDict objectForKey:RFB_VIEWONLY] intValue]];
	}
	
	return self;
}

/* Loading from preferences in 2.2 and later. */
- (id)initWithName: (NSString *)name andDictionary:(NSDictionary *)dict
{
    if (self = [super initFromDictionary:dict]) {
        [_name autorelease];
        _name = [name retain];
        [_host release];
        _host = [[dict objectForKey:@"host"] retain];
        _port = [[dict objectForKey:@"port"] intValue];
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

- (id)initWithCoder:(NSCoder *)coder
{
	[self autorelease];
	NSParameterAssert( [coder allowsKeyedCoding] );
	[self retain];
	
	if( self = [super init] )
	{
        BOOL    havePort; // port's been specified in hostAndPort
        _name =                  [[coder decodeObjectForKey:RFB_NAME] retain];
        NSString *host =          [coder decodeObjectForKey:RFB_HOST];
		havePort = [self setHostAndPort:[coder decodeObjectForKey:RFB_HOSTANDPORT]];
        [self setHost: host];
        _rememberPassword =       [coder decodeBoolForKey:RFB_REMEMBER];

		int displayMax; // what DISPLAY_MAX was used by whoever encoded this
		if ([coder containsValueForKey: RFB_DISPLAYMAX])
			displayMax = [coder decodeIntForKey:RFB_DISPLAYMAX];
		else
			displayMax = INT_MAX; // COTV version 2.0b4 and earlier

		int display = [coder decodeIntForKey:RFB_DISPLAY];
        if (!havePort) {
            if (display >= displayMax)
                [self setPort: display];
            else
                [self setPort: display + PORT_BASE];
        }

        [self setProfileName:     [coder decodeObjectForKey:RFB_LAST_PROFILE]];
		[self setShared:          [coder decodeBoolForKey:RFB_SHARED]];
		[self setFullscreen:      [coder decodeBoolForKey:RFB_FULLSCREEN]];
		[self setViewOnly:  	  [coder decodeBoolForKey:RFB_VIEWONLY]];
	}
	
    return self;
}

- (NSMutableDictionary *)propertyDict
{
    NSMutableDictionary *dict = [super propertyDict];

    [dict setObject:[NSNumber numberWithInt:_port] forKey:@"port"];
    [dict setObject:_host forKey:@"host"];
    return dict;
}

- (bool)doYouSupport: (SUPPORT_TYPE)type
{
	switch( type )
	{
		case EDIT_ADDRESS:
		case EDIT_PORT:
		case EDIT_NAME:
		case EDIT_PASSWORD:
		case CONNECT:
			return YES;
	}
	
    // shouldn't ever get here
	return NO;
}

@end
