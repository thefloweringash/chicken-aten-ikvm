/* DockConnection.m
 * Copyright (C) 2013 Dustin Cartwright
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
 */

#import "DockConnection.h"
#import "AppDelegate.h"
#import "RFBConnectionManager.h"
#import "ServerBase.h"

/* This class manages a single dock-initiated connection while it's waiting to
 * complete. */

@implementation DockConnection

- (id)initWithServer:(id<IServerData>)server
{
    if (self = [super init]) {
        waiter = [ConnectionWaiter waiterForServer:server delegate:self
                    window:nil];
        [waiter retain];
    }

    return self;
}

- (void)dealloc
{
    [waiter release];
    [super dealloc];
}

- (void)connectionSucceeded:(RFBConnection *)conn
{
	[[RFBConnectionManager sharedManager] successfulConnection:conn];
    [[NSApp delegate] removeDockConnection:self];
}

- (void)connectionFailed
{
    [[NSApp delegate] removeDockConnection:self];
}

- (void)cancelConnection:(id)sender
{
    [waiter cancel];
    [[NSApp delegate] removeDockConnection:self];
}

- (void)addMenuItems:(NSMenu *)dockMenu
{
    NSString    *template = NSLocalizedString(@"ConnectingTo", nil);
    NSString    *name = [[waiter server] name];
    NSString    *title = [NSString stringWithFormat: template, name];
    NSMenuItem  *item;

    item = [dockMenu addItemWithTitle:title action:NULL
                        keyEquivalent:@""];
    [item setEnabled:NO];

    item = [dockMenu addItemWithTitle:NSLocalizedString(@"Cancel", nil)
                        action:@selector(cancelConnection:)
                        keyEquivalent:@""];
    [item setTarget:self];
    [item setIndentationLevel:1];
}

@end
