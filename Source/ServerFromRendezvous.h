//
//  ServerFromRendezvous.h
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
#import "PersistentServer.h"
#import "IServerData.h"

#define RFB_SAVED_RENDEZVOUS_SERVERS @"RFB_SAVED_RENDEZVOUS_SERVERS"

@interface ServerFromRendezvous : PersistentServer {
	NSNetService* service_;
	bool bHasResolved;
	bool bResloveSucceeded;
}

+ (id<IServerData>)createWithNetService:(NSNetService*)service;

- (id)initWithNetService:(NSNetService*)service;
- (void)dealloc;

- (bool)doYouSupport: (SUPPORT_TYPE)type;

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict;
- (void)netServiceDidResolveAddress:(NSNetService *)sender;

@end
