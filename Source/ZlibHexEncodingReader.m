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

@implementation ZlibHexEncodingReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    if (self = [super initTarget:aTarget action:anAction]) {
		int inflateResult;
	
		zLengthReader = [[CARD16Reader alloc] initTarget:self action:@selector(setZLength:)];
		connection = [aTarget topTarget];
		inflateResult = inflateInit(&rawStream);
		if(inflateResult != Z_OK) {
			[connection terminateConnection:[NSString stringWithFormat:@"Zlib encoding: inflateInit: %s.\n", rawStream.msg]];
		}
		inflateResult = inflateInit(&encodedStream);
		if(inflateResult != Z_OK) {
			[connection terminateConnection:[NSString stringWithFormat:@"Zlib encoding: inflateInit: %s.\n", encodedStream.msg]];
		}
	}
    return self;
}

- (void)dealloc
{
	[zLengthReader release];
	inflateEnd(&rawStream);
	inflateEnd(&encodedStream);
	[super dealloc];
}

- (void)checkSubEncoding
{
    if(subEncodingMask & rfbHextileRaw) {
        int s = [frameBuffer bytesPerPixel] * currentTile.size.width * currentTile.size.height;
        subEncodingMask = 0;
        [rawReader setBufferSize:s];
        [target setReader:rawReader];
	} else if(subEncodingMask & (rfbHextileZlibRaw | rfbHextileZlibHex)) {
		[target setReader:zLengthReader];
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

#define ZLIBHEX_MAX_RAW_TILE_SIZE 4096

- (void)drawRawTile:(NSData*)data
{
	int inflateResult, bpp;
	unsigned char buffer[ZLIBHEX_MAX_RAW_TILE_SIZE];
	unsigned char* ptr;
	
	if(subEncodingMask & rfbHextileZlibRaw) {
		rawStream.next_in = (char*)[data bytes];
		rawStream.avail_in = [data length];
		rawStream.next_out = buffer;
		rawStream.avail_out = ZLIBHEX_MAX_RAW_TILE_SIZE;
		rawStream.data_type = Z_BINARY;
		inflateResult = inflate(&rawStream, Z_SYNC_FLUSH);
		if(inflateResult < 0) {
			[connection terminateConnection:[NSString stringWithFormat:@"ZlibHex inflate error: %s", rawStream.msg]];
			return;
		}
#ifdef COLLECT_STATS
		bytesTransferred += [data length];
#endif
		[frameBuffer putRect:currentTile fromData:buffer];
		[self nextTile];
		return;
	}
	if(subEncodingMask & rfbHextileZlibHex) {
		encodedStream.next_in = (char*)[data bytes];
		encodedStream.avail_in = [data length];
		encodedStream.next_out = buffer;
		encodedStream.avail_out = ZLIBHEX_MAX_RAW_TILE_SIZE;
		encodedStream.data_type = Z_BINARY;
		inflateResult = inflate(&encodedStream, Z_SYNC_FLUSH);
		if(inflateResult < 0) {
			[connection terminateConnection:[NSString stringWithFormat:@"ZlibHex inflate error: %s", encodedStream.msg]];
			return;
		}
		ptr = buffer;
		bpp = [frameBuffer bytesPerPixel];
		if(subEncodingMask & rfbHextileBackgroundSpecified) {
			[frameBuffer fillColor:&background fromPixel:ptr];
			[frameBuffer fillRect:currentTile withFbColor:&background];
			ptr += bpp;
		}
		if(subEncodingMask & rfbHextileForegroundSpecified) {
			subEncodingMask &= ~(rfbHextileSubrectsColoured);
			[frameBuffer fillColor:&foreground fromPixel:ptr];
			ptr += bpp;
		}
		if(subEncodingMask & rfbHextileAnySubrects) {
			numOfSubRects = *ptr++;
			if(subEncodingMask & rfbHextileSubrectsColoured) {
				[self drawSubColorRects:[NSData dataWithBytes:ptr length:(bpp + 2) * numOfSubRects]];
			} else {
				[self drawSubRects:[NSData dataWithBytes:ptr length:2 * numOfSubRects]];
			}
		} else {
			[self nextTile];
		}
		return;
	}
	[super drawRawTile:data];
}

- (void)setZLength:(NSNumber*)theLength
{
#ifdef COLLECT_STATS
	bytesTransferred += 2;
#endif
	[rawReader setBufferSize:[theLength unsignedIntValue]];
	[target setReader:rawReader];
}

@end
