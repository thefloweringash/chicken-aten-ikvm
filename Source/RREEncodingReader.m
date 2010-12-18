/* RREEncodingReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "RREEncodingReader.h"
#import "CARD32Reader.h"
#import "ByteBlockReader.h"
#import "RFBConnection.h"
#import "FrameBufferUpdateReader.h"

@implementation RREEncodingReader

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
		numOfReader = [[CARD32Reader alloc] initTarget:self action:@selector(setNumOfRects:)];
		backPixReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setBackground:)];
		subRectReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawRectangles:)];
	}
    return self;
}

- (void)dealloc
{
    [numOfReader release];
    [backPixReader release];
    [subRectReader release];
    [super dealloc];
}

- (void)setFrameBuffer:(id)aBuffer
{
    [super setFrameBuffer:aBuffer];
    [backPixReader setBufferSize:[aBuffer bytesPerPixel]];
}

- (void)readEncoding
{
    [connection setReader:numOfReader];
}

- (void)setNumOfRects:(NSNumber*)aNumber
{
    numOfSubRects = [aNumber unsignedIntValue];
    [connection setReader:backPixReader];
}

- (void)setBackground:(NSData*)data
{
    [frameBuffer fillRect:frame withPixel:(unsigned char*)[data bytes]];
    if(numOfSubRects) {
        int size = ([frameBuffer bytesPerPixel] + 8) * numOfSubRects;
        [subRectReader setBufferSize:size];
        [connection setReader:subRectReader];
    } else {
        [updater didRect:self];
    }
}

- (void)drawRectangles:(NSData*)data
{
    unsigned char*	bytes = (unsigned char*)[data bytes];
    unsigned char*	pixptr;
    rfbRectangle	subRect;
    NSRect		r;
    unsigned int	bpp = [frameBuffer bytesPerPixel];

    while(numOfSubRects--) {
        pixptr = bytes;
        bytes += bpp;
        memcpy(&subRect, bytes, sizeof(subRect));
        bytes += sizeof(subRect);
        r.origin.x = ntohs(subRect.x) + frame.origin.x;
        r.origin.y = ntohs(subRect.y) + frame.origin.y;
        r.size.width = ntohs(subRect.w);
        r.size.height = ntohs(subRect.h);
        [frameBuffer fillRect:r withPixel:pixptr];
    }
    [updater didRect:self];
}

@end
