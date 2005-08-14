//
//  ServerStandAlone.h
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

#import <Foundation/Foundation.h>
#import "ServerBase.h"
#import "IServerData.h"

@interface ServerStandAlone : ServerBase {
	bool mAddToServerListOnConnect;
}

- (NSString *)name;
- (bool)addToServerListOnConnect;
- (void)setAddToServerListOnConnect: (bool)addToServerListOnConnect;

- (bool)doYouSupport: (SUPPORT_TYPE)type;

@end
