/* SetColorMapEntriesReader.m created by helmut on Wed 17-Jun-1998 */

/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
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

#import "SetColorMapEntriesReader.h"
#import "ByteBlockReader.h"
#import "RFBProtocol.h"

@implementation SetColorMapEntriesReader

- (id)initWithProtocol: (RFBProtocol *)aProtocol
            connection:(RFBConnection *)aConnection
{
	if (self = [super init]) {
        protocol = aProtocol;
        connection = aConnection;
		headerReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setHeader:) size:5];
		colorReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setColors:)];
	}
    return self;
}

- (void)dealloc
{
    [headerReader release];
    [colorReader release];
    [super dealloc];
}

- (void)readMessage
{
    [connection setReader:headerReader];
}

- (void)setHeader:(NSData*)header
{
    rfbSetColourMapEntriesMsg msg;

    memcpy(&msg.pad, [header bytes], sizeof(msg) - 1);
    numberOfColors = ntohs(msg.nColours);
    [colorReader setBufferSize:numberOfColors * 3 * sizeof(CARD16)];
    [connection setReader:colorReader];
}

/* Dummy method: doesn't actually process the color map */
- (void)setColors:(NSData*)colors
{
    [protocol messageReaderDone];
}

@end
