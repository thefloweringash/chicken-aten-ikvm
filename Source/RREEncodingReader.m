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
//#import "RectangleList.h"
#import "RFBConnection.h"
#import "FrameBufferUpdateReader.h"

#define PS_THRESHOLD	0x10000
#define PS_MAXRECT	128

@implementation RREEncodingReader

#if 0
- (void)setPSThreshold:(unsigned int)anInt
{
    psThreshold = anInt;
}

- (void)setMaximumPSRectangles:(unsigned int)anInt
{
    maxPsRects = anInt;
}
#endif

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
#if 0
		[self setPSThreshold:PS_THRESHOLD];
		[self setMaximumPSRectangles:PS_MAXRECT];
#endif
		numOfReader = [[CARD32Reader alloc] initTarget:self action:@selector(setNumOfRects:)];
		backPixReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setBackground:)];
		subRectReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawRectangles:)];
#if 0
		rectList = [[RectangleList alloc] initElements:psThreshold];
#endif
	}
    return self;
}

- (void)dealloc
{
    [numOfReader release];
    [backPixReader release];
    [subRectReader release];
    //[rectList release];
    [super dealloc];
}

- (void)setFrameBuffer:(id)aBuffer
{
    [super setFrameBuffer:aBuffer];
    [backPixReader setBufferSize:[aBuffer bytesPerPixel]];
}

- (void)readEncoding
{
#ifdef COLLECT_STATS
    bytesTransferred = 4 + [frameBuffer bytesPerPixel];
#endif
    [connection setReader:numOfReader];
}

- (void)setNumOfRects:(NSNumber*)aNumber
{
    unsigned int totalSize = frame.size.width * frame.size.height;
    unsigned int avgSize;

    numOfSubRects = [aNumber unsignedIntValue];
    avgSize = totalSize / (numOfSubRects + 1);

#if 0
    if((numOfSubRects < maxPsRects) || (avgSize > psThreshold)) {
        useList = YES;
        [rectList startWithNumber:numOfSubRects + 1];
    } else {
        useList = NO;
    }
#endif
    [connection setReader:backPixReader];
}

#if 0
/* This used to return the list of rectangles for immediate drawing. These were
 * then drawn using a fill primitive and not a copy from the framebuffer.
 * However, we now draw only once the frame buffer update is complete, and not
 * as each rectangle comes in. Thus, the non-nil return value only serves to
 * indicate that we've already marked our rectangles as dirty by calling
 * connection drawRect: directly. This code and the related stuff in
 * RectangleList.m and CoRREEncodingReader.m should be cleaned up. */
- (id)rectangleList
{
    return (useList) ? rectList : nil;
}
#endif

- (void)setBackground:(NSData*)data
{
    [frameBuffer fillRect:frame withPixel:(unsigned char*)[data bytes]];
#if 0
    if(useList) {
        float	rgb[3];
        [frameBuffer getRGB:rgb fromPixel:(unsigned char*)[data bytes]];
        [rectList putRectangle:frame withColor:rgb];
    }
#endif
    if(numOfSubRects) {
        int size = ([frameBuffer bytesPerPixel] + 8) * numOfSubRects;
#ifdef COLLECT_STATS
	bytesTransferred += size;
#endif
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
    //float		rgb[3];
    rfbRectangle	subRect;
    NSRect		r;
    unsigned int	bpp = [frameBuffer bytesPerPixel];

    while(numOfSubRects--) {
#if 0
        if(useList) {
            [frameBuffer getRGB:rgb fromPixel:bytes];
        }
#endif
        pixptr = bytes;
        bytes += bpp;
        memcpy(&subRect, bytes, sizeof(subRect));
        bytes += sizeof(subRect);
        r.origin.x = ntohs(subRect.x) + frame.origin.x;
        r.origin.y = ntohs(subRect.y) + frame.origin.y;
        r.size.width = ntohs(subRect.w);
        r.size.height = ntohs(subRect.h);
        [frameBuffer fillRect:r withPixel:pixptr];
#if 0
        if(useList) {
 //           [rectList putRectangle:r withColor:rgb];
            r.origin.x -= frame.origin.x;
            r.origin.y -= frame.origin.y;
            [connection drawRectFromBuffer:r];
        }
#endif
    }
    [updater didRect:self];
}

@end
