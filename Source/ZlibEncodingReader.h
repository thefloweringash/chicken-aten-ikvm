//
//  ZlibEncodingReader.h
//  Chicken of the VNC
//
//  Created by Helmut Maierhofer on Wed Nov 06 2002.
//  Copyright (c) 2002 Helmut Maierhofer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <zlib.h>
#import "EncodingReader.h"

@interface ZlibEncodingReader : EncodingReader
{
	unsigned char*	pixels;
	unsigned int	capacity;
	id				numBytesReader;
	id				pixelReader;
	id				connection;
	z_stream		stream;
}

- (void)setUncompressedData:(unsigned char*)data length:(int)length;

@end
