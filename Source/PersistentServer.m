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
#import "ServerDataManager.h"

@implementation PersistentServer

- (id)init
{
    if (self = [super init]) {
        _name = @"new server";
    }
    return self;
}

- (void)dealloc
{
    [_name release];
    [super dealloc];
}

- (NSString*)name
{
	return _name;
}

- (NSString *)password
{
    if (_rememberPassword) {
        NSString    *service = [self keychainServiceName];
        return [[KeyChain defaultKeyChain] genericPasswordForService:service
                                                account:[self keychainAccount]];
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
		[[KeyChain defaultKeyChain] setGenericPassword:password
                                        forService:[self keychainServiceName]
                                           account:[self keychainAccount]];
    } else
        [super setPassword:password];
}

- (void)setRememberPassword: (BOOL)rememberPassword
{
	if (rememberPassword && !_rememberPassword) {
        [[KeyChain defaultKeyChain] setGenericPassword:_password
                                        forService:[self keychainServiceName]
                                           account:[self keychainAccount]];
        [_password release];
        _password = nil;
        _rememberPassword = YES;
	} else if (!rememberPassword && _rememberPassword) {
        _password = [[self password] retain];
		[[KeyChain defaultKeyChain] removeGenericPasswordForService:[self keychainServiceName]
                            account:[self keychainAccount]];
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

- (NSString *)keychainAccount
{
    return _name;
}

@end
