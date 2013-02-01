/* CommandLineConnection.m
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

#import <Cocoa/Cocoa.h>
#import "CommandLineConnection.h"

/* This object represents a connection which was begun by a command-line
 * argument. This connection behaves much like a dock-initiated connection in
 * that it's listed in the dock menu and can be cancelled there. The one
 * difference is that Chicken will quit if the connection fails, like a
 * traditional command-line application. */

@implementation CommandLineConnection

- (void)connectionFailed
{
    [NSApp terminate:self];
    [super connectionFailed];
}

@end
