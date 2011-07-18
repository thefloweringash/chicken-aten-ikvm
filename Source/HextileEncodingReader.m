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
#import "FrameBufferUpdateReader.h"

@implementation HextileEncodingReader

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
		subEncodingReader = [[CARD8Reader alloc] initTarget:self action:@selector(setSubEncoding:)];
		rawReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawRawTile:)];
        tileHeaderReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setTileHeader:)];
		subColorRectReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawSubColorRects:)];
		subRectReader = [[ByteBlockReader alloc] initTarget:self action:@selector(drawSubRects:)];
	}
	return self;
}

- (void)dealloc
{
    [rawReader release];
    [tileHeaderReader release];
    [subColorRectReader release];
    [subRectReader release];
    [subEncodingReader release];
    [super dealloc];
}

- (void)readEncoding
{
    currentTile.origin = frame.origin;
    currentTile.size.width = MIN(frame.size.width, TILE_SIZE);
    currentTile.size.height = MIN(frame.size.height, TILE_SIZE);
    [connection setReader:subEncodingReader];
}

/* Advances the data to the next tile. After reading the current tile, this
 * updates the currentTile variable. */
- (void)nextTile
{
    currentTile.origin.x += TILE_SIZE;
    if(currentTile.origin.x >= NSMaxX(frame)) {
        currentTile.origin.x = frame.origin.x;
        currentTile.origin.y += TILE_SIZE;
        if(currentTile.origin.y >= NSMaxY(frame)) {
            [updater didRect: self];
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
    [connection setReader:subEncodingReader];
}

- (void)setSubEncoding:(NSNumber*)aNumber
{
    subEncodingMask = [aNumber unsignedCharValue];

    if (subEncodingMask & rfbHextileRaw) {
        int s = [frameBuffer bytesPerPixel] * currentTile.size.width * currentTile.size.height;
        subEncodingMask = 0;
        [rawReader setBufferSize:s];
        [connection setReader:rawReader];
    } else {
        unsigned    headerSz = 0;

        if (subEncodingMask & rfbHextileBackgroundSpecified)
            headerSz += [frameBuffer bytesPerPixel];
        else {
            // use default background color: same as previous tile
            [frameBuffer fillRect:currentTile withFbColor:&background];
        }

        if (subEncodingMask & rfbHextileForegroundSpecified) {
            headerSz += [frameBuffer bytesPerPixel];
            subEncodingMask &= ~rfbHextileSubrectsColoured;
        }
        if (subEncodingMask & rfbHextileAnySubrects)
            headerSz += 1;

        if(headerSz > 0) {
            [tileHeaderReader setBufferSize:headerSz];
            [connection setReader:tileHeaderReader];
        } else
            [self nextTile];
    }
}

- (void)drawRawTile:(NSData*)data
{
    [frameBuffer putRect:currentTile fromData:(unsigned char*)[data bytes]];
    [self nextTile];
}

- (void)setTileHeader:(NSData *)data
{
    const unsigned char *bytes = [data bytes];

    if (subEncodingMask & rfbHextileBackgroundSpecified) {
        [frameBuffer fillColor:&background fromPixel:bytes];
        [frameBuffer fillRect:currentTile withFbColor:&background];
        bytes += [frameBuffer bytesPerPixel];
    }
    
    if (subEncodingMask & rfbHextileForegroundSpecified) {
        [frameBuffer fillColor:&foreground fromPixel:bytes];
        bytes += [frameBuffer bytesPerPixel];
    }

    if (subEncodingMask & rfbHextileAnySubrects) {
        numOfSubRects = *bytes;

        if(subEncodingMask & rfbHextileSubrectsColoured) {
            unsigned sz = ([frameBuffer bytesPerPixel] + 2) * numOfSubRects;
            [subColorRectReader setBufferSize:sz];
            [connection setReader:subColorRectReader];
        } else {
            [subRectReader setBufferSize:numOfSubRects * 2];
            [connection setReader:subRectReader];
        }
    } else
        [self nextTile];
}

- (void)drawSubColorRects:(NSData*)data
{
    NSRect  r;
    unsigned char* bytes = (unsigned char*)[data bytes];
    unsigned char* pixptr;
    unsigned int bpp = [frameBuffer bytesPerPixel];

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
