/* TightEncodingReader.m created by helmut on 31-Oct-2000 */

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

#import "TightEncodingReader.h"
#import "ZipLengthReader.h"
#import "CopyFilter.h"
#import "PaletteFilter.h"
#import "GradientFilter.h"
#import "CARD8Reader.h"
#import "ByteBlockReader.h"
#import "RFBConnection.h"

@implementation TightEncodingReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    [super initTarget:aTarget action:anAction];
    controlReader = [[CARD8Reader alloc] initTarget:self action:@selector(setControl:)];
    backPixReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setBackground:)];
    filterIdReader = [[CARD8Reader alloc] initTarget:self action:@selector(setFilterId:)];
    unzippedDataReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setUnzippedData:)];
    zippedDataReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setZippedData:)];
    zipLengthReader = [[ZipLengthReader alloc] initTarget:self action:@selector(setZipLength:)];
    copyFilter = [[CopyFilter alloc] initTarget:self action:@selector(filterInitDone:)];
    paletteFilter = [[PaletteFilter alloc] initTarget:self action:@selector(filterInitDone:)];
    gradientFilter = [[GradientFilter alloc] initTarget:self action:@selector(filterInitDone:)];
    zBuffer = [[NSMutableData alloc] initWithLength:Z_BUFSIZE];
    connection = [aTarget topTarget];
    return self;
}

- (void)dealloc
{
    [controlReader release];
    [backPixReader release];
    [filterIdReader release];
    [unzippedDataReader release];
    [zippedDataReader release];
    [zipLengthReader release];
    [copyFilter release];
    [paletteFilter release];
    [gradientFilter release];
    [zBuffer release];
    [super dealloc];
}

- (void)setFrameBuffer:(id)aBuffer
{
    [super setFrameBuffer:aBuffer];
    [backPixReader setBufferSize:[aBuffer tightBytesPerPixel]];
    [copyFilter setFrameBuffer:aBuffer];
    [paletteFilter setFrameBuffer:aBuffer];
    [gradientFilter setFrameBuffer:aBuffer];
}

- (void)resetReader
{
#ifdef COLLECT_STATS
     bytesTransferred = 1;
#endif
    [target setReader:controlReader];
}

- (void)setControl:(NSNumber*)cntlByte
{
    int streamId;
    
    cntl = [cntlByte unsignedCharValue];
    for(streamId=0; streamId<NUM_ZSTREAMS; streamId++) {
        if((cntl & 0x01) && zStreamActive[streamId]) {
            if((inflateEnd(&zStream[streamId]) != Z_OK) && (zStream[streamId].msg != NULL)) {
                NSLog(@"inflateEnd: %s\n", zStream[streamId].msg); // jason - correct spelling from 'infalte'
				zStreamActive[streamId] = NO;
            }
        }
		cntl >>= 1;
    }
    if(cntl == rfbTightFill) {
        [target setReader:backPixReader];
        return;
    }
    if(cntl > rfbTightMaxSubencoding) {
	[connection terminateConnection:@"Tight encoding: bad subencoding value received.\n"];
        return;
    }
    if(cntl & rfbTightExplicitFilter) {
        [target setReader:filterIdReader];
        return;
    }
    currentFilter = copyFilter;
    [target setReader:currentFilter];
}

- (void)setBackground:(NSData*)data
{
#ifdef COLLECT_STATS
        bytesTransferred += [data length];
#endif
    [frameBuffer fillRect:frame tightPixel:(unsigned char*)[data bytes]];
    [target performSelector:action withObject:self];
}

- (void)setFilterId:(NSNumber*)aByte
{
#ifdef COLLECT_STATS
        bytesTransferred += 1;
#endif
    switch([aByte unsignedCharValue]) {
        case rfbTightFilterCopy:
            currentFilter = copyFilter;
            break;
        case rfbTightFilterPalette:
            currentFilter = paletteFilter;
            break;
        case rfbTightFilterGradient:
            currentFilter = gradientFilter;
            break;
        default:
            currentFilter = nil;
	    [connection terminateConnection:[NSString stringWithFormat:@"Tight encoding: unknown filter code %@ received.\n", aByte]];
            return;
    }
    [target setReader:currentFilter];
}

- (void)filterInitDone:(FilterReader*)theFilter
{
    int size;

#ifdef COLLECT_STATS
    bytesTransferred += [theFilter bytesTransferred];
#endif
    if((pixelBits = [theFilter bitsPerPixel]) == 0) {
        [connection terminateConnection:@"Tight encoding: palette with length 0 received\n"];
        return;
    }
    rowSize = (frame.size.width * pixelBits + 7) / 8;
    size = rowSize * frame.size.height;
    if(size < TIGHT_MIN_TO_COMPRESS) {
        [unzippedDataReader setBufferSize:size];
        [target setReader:unzippedDataReader];
        return;
    }
    [target setReader:zipLengthReader];
}

- (void)setUnzippedData:(NSData*)data
{
#ifdef COLLECT_STATS
    bytesTransferred += [data length];
#endif
    data = [currentFilter filter:data rows:frame.size.height];
    [frameBuffer putRect:frame fromTightData:(unsigned char*)[data bytes]];
    [target performSelector:action withObject:self];
}

- (void)setZipLength:(NSNumber*)zl
{
    int 	streamId, error;
    z_stream*	stream;

#ifdef COLLECT_STATS
    unsigned l = [zl unsignedIntValue];
    if(l < 0x80) {
	bytesTransferred += 1;
    } else if(l < 0x4000) {
	bytesTransferred += 2;
    } else {
	bytesTransferred += 3;
    }
#endif
    streamId = cntl & 0x03;
    stream = zStream + streamId;
    if(!zStreamActive[streamId]) {
        stream->zalloc = Z_NULL;
        stream->zfree = Z_NULL;
        stream->opaque = Z_NULL;
        error = inflateInit(stream);
        if(error != Z_OK) {
            if(stream->msg != NULL) {
                [connection terminateConnection:[NSString stringWithFormat:@"InflateInit error: %s.\n", stream->msg]];
            } else {
                [connection terminateConnection:@"InflateInit error\n"];
            }
            return;
        }
        zStreamActive[streamId] = YES;
    }
    compressedLength = [zl unsignedIntValue];
    zBufPos = 0;
    rowsDone = 0;
    [zippedDataReader setBufferSize:MIN(compressedLength, Z_BUFSIZE)];
    [target setReader:zippedDataReader];
}

- (void)setZippedData:(NSData*)data
{
    NSData* filtered;
    int numRows, error;
    z_stream* stream;
    NSRect r;

#ifdef COLLECT_STATS
    bytesTransferred += [data length];
#endif
    stream = zStream + (cntl & 0x03);
    stream->next_in = (char*)[data bytes];
    stream->avail_in = [data length];
    do {
        stream->next_out = [zBuffer mutableBytes] + zBufPos;
        stream->avail_out = Z_BUFSIZE - zBufPos;
        error = inflate(stream, Z_SYNC_FLUSH);
        if((error != Z_OK) && (error != Z_STREAM_END)) {
            if(stream->msg != NULL) {
                [connection terminateConnection:[NSString stringWithFormat:@"Inflate error: %s.\n", stream->msg]];
            } else {
                [connection terminateConnection:@"Inflate error\n"];
            }
            return;
        }
        numRows = (Z_BUFSIZE - stream->avail_out) / rowSize;
        filtered = [currentFilter filter:zBuffer rows:numRows];
        r = frame;
        r.origin.y += rowsDone;
        r.size.height = numRows;
        [frameBuffer putRect:r fromTightData:(unsigned char*)[filtered bytes]];
        rowsDone += numRows;
        zBufPos = Z_BUFSIZE - stream->avail_out - numRows * rowSize;
        if(zBufPos > 0) {
            char* z = [zBuffer mutableBytes];
            memcpy(z, z + numRows * rowSize, zBufPos);
        }
    } while(stream->avail_out == 0 && (rowsDone < frame.size.height));
    if((compressedLength -= [data length]) > 0) {
        [zippedDataReader setBufferSize:MIN(compressedLength, Z_BUFSIZE)];
        [target setReader:zippedDataReader];
    } else {
        [target performSelector:action withObject:self];
    }
}

@end

