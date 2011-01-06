//
//  ServerFromConnection.m
//  Chicken of the VNC
//
//  Created by Mark Lentczner on Sun Oct 24 2004.
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

#import "ServerFromConnection.h"


@implementation ServerFromConnection

- (id)initFromConnection:(NSFileHandle*)file
{
    self = [super init];
    
    if (self) {
        //we should really extract the info from the socket and set port and address
        //but at present, nothing uses this information once the server is connected
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
		case CONNECT:
			return NO;
	}
	
    // shouldn't ever get here
	return NO;
}

@end
