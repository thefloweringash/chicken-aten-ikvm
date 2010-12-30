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
#import "ZlibStreamReader.h"


@implementation ZlibEncodingReader

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
		numBytesReader = [[CARD32Reader alloc] initTarget:self action:@selector(setNumBytes:)];
        zlibReader = [[ZlibStreamReader alloc] initTarget:self
                                       action:@selector(setUncompressedData:)
                                   connection:aConnection];
	}
    return self;
}

- (void)dealloc
{
	[numBytesReader release];
    [zlibReader release];
    [super dealloc];
}

- (void)readEncoding
{
    [connection setReader:numBytesReader];
}

- (void)setNumBytes:(NSNumber*)numBytes
{
    [zlibReader setCompressedSize:[numBytes unsignedIntValue]
                  maxUncompressed:[self maximumUncompressedSize]];
    [connection setReader:zlibReader];
}

/* Maximum possible size for uncompressed data from this rectangle. */
- (unsigned)maximumUncompressedSize
{
    return [frameBuffer bytesPerPixel] * frame.size.width * frame.size.height;
}

- (void)setUncompressedData:(NSData *)data
{
    int expectedLen = frame.size.width * frame.size.height
                                    * [frameBuffer bytesPerPixel];

    if ([data length] == expectedLen)
        [frameBuffer putRect:frame fromData:[data bytes]];
    else
        NSLog(@"Uncompressed Zlib data was not of expected length");
    [updater didRect:self];
}

@end
