//
//  ZlibHexEncodingReader.h
//  Chicken of the VNC
//
//  Created by Helmut Maierhofer on Fri Nov 08 2002.
//  Copyright (c) 2002 Helmut Maierhofer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HextileEncodingReader.h"
#import <zlib.h>

@class CARD16Reader;
@class ZlibStreamReader;

@interface ZlibHexEncodingReader : HextileEncodingReader
{
	CARD16Reader        *zLengthReader;
    ZlibStreamReader    *rawStream;
	z_stream		encodedStream;
}

@end
