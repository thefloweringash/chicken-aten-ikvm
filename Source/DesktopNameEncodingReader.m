/* DesktopNameEncodingReader.m
 * Copyright (C) 2010 Dustin Cartwright
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

#import "DesktopNameEncodingReader.h"
#import "FrameBufferUpdateReader.h"
#import "RFBConnection.h"
#import "RFBStringReader.h"

/* Pseudo-encoding to support renaming the desktop. */
@implementation DesktopNameEncodingReader

- (void)dealloc
{
    [nameReader release];
    [super dealloc];
}

- (void)readEncoding
{
    if (!nameReader)
        nameReader = [[RFBStringReader alloc] initTarget:self
                                                  action:@selector(nameRead:)
                                              connection:connection];
    [nameReader readString];
}

- (void)nameRead:(NSString *)newName
{
    [connection setDisplayName:newName];
    [updater didRect:self];
}

@end
