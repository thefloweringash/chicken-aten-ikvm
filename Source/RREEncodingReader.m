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
#import "RectangleList.h"

#define PS_THRESHOLD	0x10000
#define PS_MAXRECT	128

@implementation RREEncodingReader

- (void)setPSThreshold:(unsigned int)anInt
{
    psThreshold = anInt;
}

- (void)setMaximumPSRectangles:(unsigned int)anInt
{
    maxPsRects = anInt;
}

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    [super initTarget:aTarget action:anAction];
    [self setPSThreshold:PS_THRESHOLD];
    [self setMaximumPSRectangles:PS_MAXRECT];
    numOfReader = [[CARD32Reader alloc] initTarget:self action:@selector(setNumOfRects:)];
    backPixReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setBackground:)];
    subRectReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawRectangles:)];
    rectList = [[RectangleList alloc] initElements:psThreshold];
    return self;
}

- (void)dealloc
{
    [numOfReader release];
    [backPixReader release];
    [subRectReader release];
    [rectList release];
    [super dealloc];
}

- (void)setFrameBuffer:(id)aBuffer
{
    [super setFrameBuffer:aBuffer];
    [backPixReader setBufferSize:[aBuffer bytesPerPixel]];
}

- (void)resetReader
{
#ifdef COLLECT_STATS
    bytesTransferred = 4 + [frameBuffer bytesPerPixel];
#endif
    [target setReader:numOfReader];
}

- (void)setNumOfRects:(NSNumber*)aNumber
{
    unsigned int totalSize = frame.size.width * frame.size.height;
    unsigned int avgSize;

    numOfSubRects = [aNumber unsignedIntValue];
    avgSize = totalSize / (numOfSubRects + 1);

    if((numOfSubRects < maxPsRects) || (avgSize > psThreshold)) {
        useList = YES;
        [rectList startWithNumber:numOfSubRects + 1];
    } else {
        useList = NO;
    }
    [target setReader:backPixReader];
}

- (id)rectangleList
{
    return (useList) ? rectList : nil;
}

- (void)setBackground:(NSData*)data
{
    [frameBuffer fillRect:frame withPixel:(unsigned char*)[data bytes]];
    if(useList) {
        float	rgb[3];
        [frameBuffer getRGB:rgb fromPixel:(unsigned char*)[data bytes]];
        [rectList putRectangle:frame withColor:rgb];
    }
    if(numOfSubRects) {
        int size = ([frameBuffer bytesPerPixel] + 8) * numOfSubRects;
#ifdef COLLECT_STATS
	bytesTransferred += size;
#endif
        [subRectReader setBufferSize:size];
        [target setReader:subRectReader];
    } else {
        [target performSelector:action withObject:self];
    }
}

- (void)drawRectangles:(NSData*)data
{
    unsigned char*	bytes = (unsigned char*)[data bytes];
    unsigned char*	pixptr;
    float		rgb[3];
    rfbRectangle	subRect;
    NSRect		r;
    unsigned int	bpp = [frameBuffer bytesPerPixel];

    while(numOfSubRects--) {
        if(useList) {
            [frameBuffer getRGB:rgb fromPixel:bytes];
        }
        pixptr = bytes;
        bytes += bpp;
        memcpy(&subRect, bytes, sizeof(subRect));
        bytes += sizeof(subRect);
        r.origin.x = ntohs(subRect.x) + frame.origin.x;
        r.origin.y = ntohs(subRect.y) + frame.origin.y;
        r.size.width = ntohs(subRect.w);
        r.size.height = ntohs(subRect.h);
        [frameBuffer fillRect:r withPixel:pixptr];
        if(useList) {
            [rectList putRectangle:r withColor:rgb];
        }
    }
    [target performSelector:action withObject:self];
}

@end
