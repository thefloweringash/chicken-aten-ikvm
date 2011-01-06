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

- (BOOL)rememberPassword
{
	return _rememberPassword;
}

- (void)setName: (NSString*)name
{
	[_name autorelease];
	if( nil != name )
	{
		_name = [name retain];
	}
	else
	{
		_name = @"localhost";
	}
}

- (void)setRememberPassword: (BOOL)rememberPassword
{
	_rememberPassword = rememberPassword;
}

- (void)copyServer:(PersistentServer *)server
{
	// remember password must come before setting the password so that the
    // appropriate save logic works
	[self setRememberPassword:[server rememberPassword]];
    [super copyServer:server];
}

@end
