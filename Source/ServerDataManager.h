//
//  ServerManager.h
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
#import "IServerData.h"

@class ServerFromPrefs;

/**
 *  ServerDataManager manages all known accessible servers in Chicken of the VNC
 *  including saved server from preferences, rendezvous servers, etc. Servers will
 *  be accessible through the IServerData protocol. Users should not attempt to access
 *  the servers as their specific class type since those classes may change in ways
 *  incompatible to your code (including adding new server classes), but the protocol
 *  should not.
 *  <BR><BR>
 *  This is a singleton class. Always access the class through the sharedInstance
 *  function. Do not create an instance yourself.
 */
@interface ServerDataManager : NSObject {
	
	NSMutableDictionary* mServers;
	NSMutableDictionary* mGroups;
	NSMutableDictionary* mRendezvousNameToServer;
	
	bool mPostMessages;
	
	// Keeps track of search status
	NSNetServiceBrowser *mServiceBrowser_VNC;
	NSNetServiceBrowser *mServiceBrowser_RFB;
	BOOL mSearching;
	bool mUsingRendezvous;
}

#define ServerListChangeMsg @"ServerListChangeMsg"

/**
 *  Accessor method to fetch the singleton instance for this class. Use this method
 *  instead of creating an instance of your own.
 *  @return Shared singleton instance of the ServerDataManager class. */
+ (ServerDataManager*) sharedInstance;

/**
 *  Saves the current server settings.
 */
- (void)save;

/**
 *  Sets whether or not rendezvous server searching should be on
 */
- (void)useRendezvous:(bool)use;

/**
 * @return Whether or not rendezvous server searching is on
 */
- (bool)getUseRendezvous;

/*
 *  Provides the number of servers managed by ServerDataManager.
 *  @return The number of servers.
 */
- (unsigned) serverCount;

- (unsigned)saveableCount;

/*
 *  Allows access to all servers managed by ServerDataManager.
 *  @return The enumerator that can be used to enumerate through all servers. 
 */
//- (NSEnumerator*) getServerEnumerator;

- (NSArray *)sortedServerNames;

/*
 *  Provides the number of groups managed by ServerDataManager.
 *  @return The number of groups.
 */
- (unsigned) groupCount;

	/*
 *  Allows access to the names of all the groups servers managed by ServerDataManager.
 *  @return The enumerator that can be used to enumerate through all group names. 
 */
- (NSEnumerator*) getGroupNameEnumerator;

/*
 *  Allows access to all the servers in a particular group.
 *  @return The enumerator that can be used to enumerate through all servers in a group. 
 */
- (NSEnumerator*) getServerEnumeratorForGroupName:(NSString*)group;

/*
 *  Retrieves a server by its name. The retrieval process is case sensative.
 *  @param name The name of the server you want to retrieve.
 *  @return The server whose name matches the requested one or nil if the server
 *  was not found.
 */
- (id<IServerData>)getServerWithName:(NSString*)name;

/*
 *  Deletes the specified server
 *  @param server The server to be deleted.
 */
- (void)removeServer:(id<IServerData>)server;

/*
 *  Adds a new server to the server list. The name passed in becomes the name of the
 *  server unless that name is already in use. If the name is in use, an underscore
 *  followed by a number will be added to the name so that it is unique.
 *  @param name The name to create the server as.
 *  @return The created server.
 */
- (ServerFromPrefs *)createServerByName:(NSString*)name;

/*
 *  Adds an existing server to the server list. A new server will be created in the
 *  ServerDataManager. If the server's name is in use, an underscore followed by a number
 *  will be added to the name in the new instance of the server so that it is unique.
 *  @param server The server to add.
 *  @return The new server (the one that is stored).
 */
- (ServerFromPrefs *)addServer:(id<IServerData>)server;

/* @name Archiving and Unarchiving
 * Implements the NSCoding protocol for serialization
 */
//@{
- (id)initWithCoder:(NSCoder*)coder;
//@}

/** 
 *	The primary goal of this function is to force servers to have unique names
 */
- (void)validateNameChange:(NSMutableString *)name forServer:(id<IServerData>)server;

// NSNetServiceBrowser delegate methods for service browsing
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser;
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser;
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
			 didNotSearch:(NSDictionary *)errorDict;
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
		   didFindService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing;
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
		 didRemoveService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing;

@end
