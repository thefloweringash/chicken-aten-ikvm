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

@class ZlibStreamReader;

@interface ZlibEncodingReader : EncodingReader
{
	id				numBytesReader;
    ZlibStreamReader    *zlibReader;
}

- (unsigned)maximumUncompressedSize;
- (void)setUncompressedData:(NSData *)data;

@end
