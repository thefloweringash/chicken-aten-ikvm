/* HextileEncodingReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "HextileEncodingReader.h"
#import "CARD8Reader.h"
#import "ByteBlockReader.h"

@implementation HextileEncodingReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    if (self = [super initTarget:aTarget action:anAction]) {
		subEncodingReader = [[CARD8Reader alloc] initTarget:self action:@selector(setSubEncoding:)];
		rawReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawRawTile:)];
		backGroundReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setBackground:)];
		foreGroundReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setForeground:)];
		subColorRectReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawSubColorRects:)];
		numOfSubRectReader = [[CARD8Reader alloc] initTarget:self action:@selector(setSubrects:)];
		subRectReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawSubRects:)];
	}
	return self;
}

- (void)dealloc
{
    [rawReader release];
    [backGroundReader release];
    [foreGroundReader release];
    [subColorRectReader release];
    [numOfSubRectReader release];
    [subRectReader release];
    [subEncodingReader release];
    [super dealloc];
}

- (void)setFrameBuffer:(id)aBuffer
{
    [super setFrameBuffer:aBuffer];
    [backGroundReader setBufferSize:[aBuffer bytesPerPixel]];
    [foreGroundReader setBufferSize:[aBuffer bytesPerPixel]];
}

- (void)resetReader
{
#ifdef COLLECT_STATS
    bytesTransferred = 0;
#endif
    currentTile.origin = frame.origin;
    currentTile.size.width = MIN(frame.size.width, TILE_SIZE);
    currentTile.size.height = MIN(frame.size.height, TILE_SIZE);
    [target setReader:subEncodingReader];
}

- (void)nextTile
{
    currentTile.origin.x += TILE_SIZE;
    if(currentTile.origin.x >= NSMaxX(frame)) {
        currentTile.origin.x = frame.origin.x;
        currentTile.origin.y += TILE_SIZE;
        if(currentTile.origin.y >= NSMaxY(frame)) {
            [target performSelector:action withObject:self];
            return;
        }
    }
    currentTile.size.width = TILE_SIZE;
    if(NSMaxX(currentTile) > NSMaxX(frame)) {
        currentTile.size.width -= NSMaxX(currentTile) - NSMaxX(frame);
    }
    currentTile.size.height = TILE_SIZE;
    if(NSMaxY(currentTile) > NSMaxY(frame)) {
        currentTile.size.height -= NSMaxY(currentTile) - NSMaxY(frame);
    }
    [frameBuffer fillRect:currentTile withFbColor:&background];
    [target setReader:subEncodingReader];
}

- (void)checkSubEncoding
{
    if(subEncodingMask & rfbHextileRaw) {
        int s = [frameBuffer bytesPerPixel] * currentTile.size.width * currentTile.size.height;
        subEncodingMask = 0;
        [rawReader setBufferSize:s];
        [target setReader:rawReader];
    } else if(subEncodingMask & rfbHextileBackgroundSpecified) {
        subEncodingMask &= ~rfbHextileBackgroundSpecified;
        [target setReader:backGroundReader];
    } else if(subEncodingMask & rfbHextileForegroundSpecified) {
        subEncodingMask &= ~(rfbHextileForegroundSpecified | rfbHextileSubrectsColoured);
        [target setReader:foreGroundReader];
    } else if(subEncodingMask & rfbHextileAnySubrects) {
        [target setReader:numOfSubRectReader];
    } else {
        [self nextTile];
    }
}

- (void)setSubEncoding:(NSNumber*)aNumber
{
#ifdef COLLECT_STATS
    bytesTransferred += 1;
#endif
    if((subEncodingMask = [aNumber unsignedCharValue]) == 0) {
        [self nextTile];
    } else {
        [self checkSubEncoding];
    }
}

- (void)drawRawTile:(NSData*)data
{
#ifdef COLLECT_STATS
	bytesTransferred += [data length];
#endif
    [frameBuffer putRect:currentTile fromData:(unsigned char*)[data bytes]];
    [self nextTile];
}

- (void)setBackground:(NSData*)data
{
#ifdef COLLECT_STATS
        bytesTransferred += [data length];
#endif
    [frameBuffer fillColor:&background fromPixel:(unsigned char*)[data bytes]];
    [frameBuffer fillRect:currentTile withFbColor:&background];
    [self checkSubEncoding];
}

- (void)setForeground:(NSData*)data
{
#ifdef COLLECT_STATS
        bytesTransferred += [data length];
#endif
    [frameBuffer fillColor:&foreground fromPixel:(unsigned char*)[data bytes]];
    [self checkSubEncoding];
}

- (void)setSubrects:(NSNumber*)aNumber
{
#ifdef COLLECT_STATS
        bytesTransferred += 1;
#endif
    numOfSubRects = [aNumber unsignedCharValue];
    if(subEncodingMask & rfbHextileSubrectsColoured) {
        [subColorRectReader setBufferSize:([frameBuffer bytesPerPixel] + 2) * numOfSubRects];
        [target setReader:subColorRectReader];
    } else {
        [subRectReader setBufferSize:numOfSubRects * 2];
        [target setReader:subRectReader];
    }
}

- (void)drawSubColorRects:(NSData*)data
{
    NSRect  r;
    unsigned char* bytes = (unsigned char*)[data bytes];
    unsigned char* pixptr;
    unsigned int bpp = [frameBuffer bytesPerPixel];

#ifdef COLLECT_STATS
        bytesTransferred += [data length];
#endif
    while(numOfSubRects--) {
        pixptr = bytes;
        bytes += bpp;
        r.origin.x = rfbHextileExtractX(*bytes) + currentTile.origin.x;
        r.origin.y = rfbHextileExtractY(*bytes) + currentTile.origin.y;
        bytes++;
        r.size.width = rfbHextileExtractW(*bytes);
        r.size.height = rfbHextileExtractH(*bytes);
        bytes++;
        [frameBuffer fillRect:r withPixel:pixptr];
    }
    [self nextTile];
}

- (void)drawSubRects:(NSData*)data
{
    NSRect  r;
    unsigned char* bytes = (unsigned char*)[data bytes];

#ifdef COLLECT_STATS
        bytesTransferred += [data length];
#endif
    while(numOfSubRects--) {
        r.origin.x = rfbHextileExtractX(*bytes) + currentTile.origin.x;
        r.origin.y = rfbHextileExtractY(*bytes) + currentTile.origin.y;
        bytes++;
        r.size.width = rfbHextileExtractW(*bytes);
        r.size.height = rfbHextileExtractH(*bytes);
        bytes++;
        [frameBuffer fillRect:r withFbColor:&foreground];
    }
    [self nextTile];
}

@end
