/* RawEncodingReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "RawEncodingReader.h"
#import "ByteBlockReader.h"
#import "FrameBufferUpdateReader.h"

@implementation RawEncodingReader

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
		pixelReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setPixels:)];
	}
    return self;
}

- (void)dealloc
{
    [pixelReader release];
    [super dealloc];
}

- (void)readEncoding
{
    unsigned s = [frameBuffer bytesPerPixel] * frame.size.width * frame.size.height;

    [pixelReader setBufferSize:s];
    [connection setReader:pixelReader];
}

- (void)setPixels:(NSData*)pixel
{
    [frameBuffer putRect:frame fromData:(unsigned char*)[pixel bytes]];
    [updater didRect:self];
}

@end
