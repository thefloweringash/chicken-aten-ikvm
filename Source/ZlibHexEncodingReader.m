//
//  ZlibHexEncodingReader.m
//  Chicken of the VNC
//
//  Created by Helmut Maierhofer on Fri Nov 08 2002.
//  Copyright (c) 2002 Helmut Maierhofer. All rights reserved.
//

#import "ZlibHexEncodingReader.h"
#import "RFBConnection.h"
#import "CARD16Reader.h"
#import "ByteBlockReader.h"
#import "ZlibStreamReader.h"

@implementation ZlibHexEncodingReader

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
		int inflateResult;
	
		zLengthReader = [[CARD16Reader alloc] initTarget:self action:@selector(setZLength:)];
        rawStream = [[ZlibStreamReader alloc] initTarget:self
                                                  action:@selector(setZlibRawTile:)
                                              connection:connection];
		inflateResult = inflateInit(&encodedStream);
		if(inflateResult != Z_OK) {
            NSString *fmt = NSLocalizedString(@"ZlibInflateErr", nil);
			[connection terminateConnection:[NSString stringWithFormat:fmt, encodedStream.msg]];
		}
	}
    return self;
}

- (void)dealloc
{
	[zLengthReader release];
    [rawStream release];
	inflateEnd(&encodedStream);
	[super dealloc];
}

- (void)setSubEncoding:(NSNumber *)aNumber
{
    subEncodingMask = [aNumber unsignedCharValue];

    if (subEncodingMask & (rfbHextileZlibRaw | rfbHextileZlibHex))
        [connection setReader:zLengthReader];
    else
        [super setSubEncoding:aNumber];
}

- (void)inflateError
{
    NSString    *fmt = NSLocalizedString(@"ZlibHexInflateError", nil);
    NSString    *err = [NSString stringWithFormat: fmt, encodedStream.msg];

    [connection terminateConnection:err];
}

#define ZLIBHEX_MAX_RAW_TILE_SIZE 4096

/* Decompressed data for a ZlibRaw tile. */
- (void)setZlibRawTile:(NSData*)data
{
    [frameBuffer putRect:currentTile fromData:[data bytes]];
    [self nextTile];
}

/* Read the data for a tile. This may be zlib-compressed, in which case we
 * inflate, or it may be an actual raw tile, in which case we pass it along
 * super to interpret. */
- (void)drawRawTile:(NSData*)data
{
	int inflateResult, bpp;
	unsigned char* ptr;
	
	if(subEncodingMask & rfbHextileZlibHex) {
        unsigned bufferSz = ZLIBHEX_MAX_RAW_TILE_SIZE;
        unsigned char *buffer = (unsigned char *)malloc(bufferSz);
        
		encodedStream.next_in = (unsigned char*)[data bytes];
		encodedStream.avail_in = [data length];
		encodedStream.next_out = buffer;
		encodedStream.avail_out = bufferSz;
		encodedStream.data_type = Z_BINARY;
		inflateResult = inflate(&encodedStream, Z_SYNC_FLUSH);
		if(inflateResult < 0) {
            [self inflateError];
            free(buffer);
			return;
		}

        // parse Hextile header
		ptr = buffer;
		bpp = [frameBuffer bytesPerPixel];
		if(subEncodingMask & rfbHextileBackgroundSpecified) {
			[frameBuffer fillColor:&background fromPixel:ptr];
			ptr += bpp;
		}
        [frameBuffer fillRect:currentTile withFbColor:&background];
		if(subEncodingMask & rfbHextileForegroundSpecified) {
			subEncodingMask &= ~(rfbHextileSubrectsColoured);
			[frameBuffer fillColor:&foreground fromPixel:ptr];
			ptr += bpp;
		}
		if(subEncodingMask & rfbHextileAnySubrects) {
            numOfSubRects = *ptr++;
            unsigned coloured = subEncodingMask & rfbHextileSubrectsColoured;
            unsigned length = (coloured ? bpp + 2 : 2) * numOfSubRects;
            unsigned size = length + (ptr - buffer);

            if (size > bufferSz) {
                // buffer wasn't large enough
                buffer = realloc(buffer, size);
                encodedStream.next_out = buffer + bufferSz
                                                - encodedStream.avail_out;
                encodedStream.avail_out += size - bufferSz;
                bufferSz = size;
                ptr = buffer + (size - length);

                inflateResult = inflate(&encodedStream, Z_SYNC_FLUSH);
                if (inflateResult < 0) {
                    [self inflateError];
                    free(buffer);
                    return;
                }
            }

            if (size > bufferSz - encodedStream.avail_out) {
                NSString    *err = NSLocalizedString(@"ZlibHexDeflateTooSmall", nil);
                [connection terminateConnection:err];
                free(buffer);
                return;
            }

            // send uncompressed data to superclass
            NSData *data = [NSData dataWithBytesNoCopy:ptr length:length
                                          freeWhenDone:NO];
            if (coloured)
                [self drawSubColorRects:data];
            else
                [self drawSubRects:data];
		} else {
			[self nextTile];
		}
        free(buffer);
	} else
        [super drawRawTile:data];
}

- (void)setZLength:(NSNumber*)theLength
{
    if (subEncodingMask & rfbHextileZlibRaw) {
        [rawStream setCompressedSize:[theLength unsignedIntValue]
                     maxUncompressed:ZLIBHEX_MAX_RAW_TILE_SIZE];
        [connection setReader:rawStream];
    } else {
        // Note that here we're repurposing rawReader to read either a raw tile
        // or a Zlib tile
        [rawReader setBufferSize:[theLength unsignedIntValue]];
        [connection setReader:rawReader];
    }
}

@end
