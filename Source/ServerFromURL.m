//
//  ServerFromURL.m
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

#import "ServerFromURL.h"

@implementation ServerFromURL

- (id)init
{
	if (self = [super init])
	{
		mAddToServerListOnConnect = NO;
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
		case DELETE:
		case SERVER_SAVE:
		case EDIT_PASSWORD:
		case CONNECT:
		case ADD_SERVER_ON_CONNECT:
			return YES;
		case SAVE_PASSWORD:
			return mAddToServerListOnConnect;
		default:
			// handle all cases
			assert(0);
	}
	
	return NO;
}

- (bool)addToServerListOnConnect
{
	return mAddToServerListOnConnect;
}

- (void)setAddToServerListOnConnect: (bool)addToServerListOnConnect
{
	mAddToServerListOnConnect = addToServerListOnConnect;
	
	if( NO == addToServerListOnConnect )
	{
		[self setRememberPassword:NO];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
														object:self];
}

@end
