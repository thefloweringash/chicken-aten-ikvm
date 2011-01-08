/* PersistentServer.h
 * Copyright (C) 2011 Dustin Cartwright
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "PersistentServer.h"
#import "KeyChain.h"
#import "Profile.h"
#import "ProfileDataManager.h"
#import "ServerDataManager.h"

@implementation PersistentServer

- (id)init
{
    if (self = [super init]) {
        _name = @"new server";
    }
    return self;
}

- (id)initFromDictionary: (NSDictionary *)dict
{
    if (self = [super init]) {
        _rememberPassword = [[dict objectForKey:@"rememberPassword"] boolValue];
        _shared = [[dict objectForKey:@"shared"] boolValue];
        _fullscreen = [[dict objectForKey:@"fullscreen"] boolValue];
        _viewOnly = [[dict objectForKey:@"viewOnly"] boolValue];
        [_profile autorelease];
        _profile = [[ProfileDataManager sharedInstance]
                            profileForKey:[dict objectForKey:@"lastProfile"]];
        [_profile retain];
    }
    return self;
}

- (void)dealloc
{
    [_name release];
    [super dealloc];
}

- (NSMutableDictionary *)propertyDict
{
	NSMutableDictionary* propertyDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:_rememberPassword],	[NSString stringWithString:@"rememberPassword"],
		[NSNumber numberWithBool:_shared],				[NSString stringWithString:@"shared"],
		[NSNumber numberWithBool:_fullscreen],			[NSString stringWithString:@"fullscreen"],
		[NSNumber numberWithBool:_viewOnly],            [NSString stringWithString:@"viewOnly"], 
		[_profile profileName],							[NSString stringWithString:@"lastProfile"],
		nil,											nil];
    
    return propertyDict;
}

- (NSString*)name
{
	return _name;
}

- (NSString *)password
{
    if (_rememberPassword) {
        NSString    *service = [self keychainServiceName];
        NSString    *pass;
        pass = [[KeyChain defaultKeyChain] genericPasswordForService:service
                                                account:[self saveName]];
        if (pass)
            return pass
        else {
            _rememberPassword = NO;
            [super setPassword:nil];
            return [super password];
        }
    } else
        return [super password];
}


- (BOOL)rememberPassword
{
	return _rememberPassword;
}

- (void)setName: (NSString*)name
{
    if ([name isEqualToString:_name])
        return;

    // we do this so that the password gets deleted from the old name and
    // created at the new name
    BOOL    rememberPassword = _rememberPassword;
    [self setRememberPassword:NO];

	[_name autorelease];

	if (name) {
		NSMutableString *nameHelper = [NSMutableString stringWithString:name];
		
		[[ServerDataManager sharedInstance] validateNameChange:nameHelper
                                                     forServer:self];
		
		_name = [nameHelper retain];
	} else {
		_name = @"localhost";
	}

    [self setRememberPassword:rememberPassword];
}
- (void)setPassword: (NSString*)password
{
	if (_rememberPassword) {
        BOOL    saved;

		saved = [[KeyChain defaultKeyChain] setGenericPassword:password
                                        forService:[self keychainServiceName]
                                           account:[self saveName]];
        if (!saved) {
            _rememberPassword = NO;
            [super setPassword:password];
        }
    } else
        [super setPassword:password];
}

- (void)setRememberPassword: (BOOL)rememberPassword
{
	if (rememberPassword && !_rememberPassword) {
        if ([[KeyChain defaultKeyChain] setGenericPassword:_password
                                        forService:[self keychainServiceName]
                                           account:[self saveName]]) {
            [_password release];
            _password = nil;
            _rememberPassword = YES;
        }
	} else if (!rememberPassword && _rememberPassword) {
        _password = [[self password] retain];
		[[KeyChain defaultKeyChain] removeGenericPasswordForService:[self keychainServiceName]
                            account:[self saveName]];
        _rememberPassword = NO;
	}
}

- (void)copyServer:(PersistentServer *)server
{
	// remember password must come after setting the password so that the
    // appropriate save logic works
    [super copyServer:server];
	[self setRememberPassword:[server rememberPassword]];
}

- (NSString *)keychainServiceName
{
    return @"Chicken";
}

/* Name under which the keychain password and the server settings are stored. */
- (NSString *)saveName
{
    return _name;
}

@end
