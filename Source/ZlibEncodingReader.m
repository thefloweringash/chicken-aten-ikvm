//
//  ZlibEncodingReader.m
//  Chicken of the VNC
//
//  Created by Helmut Maierhofer on Wed Nov 06 2002.
//  Copyright (c) 2002 Helmut Maierhofer. All rights reserved.
//

#import "ZlibEncodingReader.h"
#import "CARD32Reader.h"
#import "ByteBlockReader.h"
#import "RFBConnection.h"


@implementation ZlibEncodingReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    if (self = [super initTarget:aTarget action:anAction]) {
		int inflateResult;
	
		capacity = 4096;
		pixels = malloc(capacity);
		numBytesReader = [[CARD32Reader alloc] initTarget:self action:@selector(setNumBytes:)];
		pixelReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setCompressedData:)];
		connection = [aTarget topTarget];
		inflateResult = inflateInit(&stream);
		if (inflateResult != Z_OK) {
			[connection terminateConnection:[NSString stringWithFormat:@"Zlib encoding: inflateInit: %s.\n", stream.msg]];
		}
	}
    return self;
}

- (void)dealloc
{
	free(pixels);
	[numBytesReader release];
    [pixelReader release];
	inflateEnd(&stream);
    [super dealloc];
}

- (void)resetReader
{
    [target setReader:numBytesReader];
}

- (void)setNumBytes:(NSNumber*)numBytes
{
#ifdef COLLECT_STATS
	bytesTransferred = 4 + [numBytes unsignedIntValue];
#endif
	[pixelReader setBufferSize:[numBytes unsignedIntValue]];
	[target setReader:pixelReader];
}

- (void)setCompressedData:(NSData*)data
{
	int inflateResult;
	unsigned s = [frameBuffer bytesPerPixel] * frame.size.width * frame.size.height;
	if(s > capacity) {
		free(pixels);
		pixels = malloc(s);
		NSParameterAssert( pixels != NULL );
		capacity = s;
	}
	stream.next_in   = (char*)[data bytes];
	stream.avail_in  = [data length];
	stream.next_out  = pixels;
	stream.avail_out = capacity;
	stream.data_type = Z_BINARY;
	inflateResult = inflate(&stream, Z_SYNC_FLUSH);
    if(inflateResult == Z_NEED_DICT ) {
		[connection terminateConnection:@"Zlib inflate needs a dictionary.\n"];
		return;
    }
    if(inflateResult < 0) {
		[connection terminateConnection:[NSString stringWithFormat:@"Zlib inflate error: %s\n", stream.msg]];
		return;
    }
	[self setUncompressedData:pixels length:capacity - stream.avail_out];
}

- (void)setUncompressedData:(unsigned char*)data length:(int)length
{
	[frameBuffer putRect:frame fromData:pixels];
    [target performSelector:action withObject:self];
}

@end
