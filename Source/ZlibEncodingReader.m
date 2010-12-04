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
#import "FrameBufferUpdateReader.h"
#import "RFBConnection.h"


@implementation ZlibEncodingReader

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
		int inflateResult;
	
		capacity = 0;
		pixels = NULL;
		numBytesReader = [[CARD32Reader alloc] initTarget:self action:@selector(setNumBytes:)];
		pixelReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setCompressedData:)];
		inflateResult = inflateInit(&stream);
		if (inflateResult != Z_OK) {
            NSString *err = NSLocalizedString(@"ZlibInflateInitErr", nil);
			[connection terminateConnection:[NSString stringWithFormat:err, stream.msg]];
		}
	}
    return self;
}

- (void)dealloc
{
    if (pixels)
        free(pixels);
	[numBytesReader release];
    [pixelReader release];
	inflateEnd(&stream);
    [super dealloc];
}

- (void)readEncoding
{
    [connection setReader:numBytesReader];
}

- (void)setNumBytes:(NSNumber*)numBytes
{
#ifdef COLLECT_STATS
	bytesTransferred = 4 + [numBytes unsignedIntValue];
#endif
	[pixelReader setBufferSize:[numBytes unsignedIntValue]];
	[connection setReader:pixelReader];
}

/* Maximum possible size for uncompressed data from this rectangle. */
- (unsigned)maximumUncompressedSize
{
    return [frameBuffer bytesPerPixel] * frame.size.width * frame.size.height;
}

- (void)setCompressedData:(NSData*)data
{
	int inflateResult;
	unsigned s = [self maximumUncompressedSize];
	if(s > capacity) {
		free(pixels);
		pixels = malloc(s);
		NSParameterAssert( pixels != NULL );
		capacity = s;
	}
	stream.next_in   = (unsigned char*)[data bytes];
	stream.avail_in  = [data length];
	stream.next_out  = pixels;
	stream.avail_out = capacity;
	stream.data_type = Z_BINARY;
	inflateResult = inflate(&stream, Z_SYNC_FLUSH);
    if(inflateResult == Z_NEED_DICT ) {
        NSString    *err = NSLocalizedString(@"ZlibNeedsDict", nil);
		[connection terminateConnection:err];
		return;
    }
    if(inflateResult < 0) {
        NSString *fmt = NSLocalizedString(@"ZlibInflateError", nil);
        NSString *err = [NSString stringWithFormat:fmt, stream.msg];
		[connection terminateConnection:err];
		return;
    }
	[self setUncompressedData:pixels length:capacity - stream.avail_out];
    [updater didRect:self];
}

- (void)setUncompressedData:(unsigned char*)data length:(int)length
{
    int expectedLen = frame.size.width * frame.size.height
                                    * [frameBuffer bytesPerPixel];

    if (length == expectedLen)
        [frameBuffer putRect:frame fromData:pixels];
    else
        NSLog(@"Uncompressed Zlib data was not of expected length");
}

@end
