//
//  ZRLEEncodingReader.h
//  Chicken of the VNC
//
//  Created by Helmut Maierhofer on Thu Nov 07 2002.
//  Copyright (c) 2002 Helmut Maierhofer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZlibEncodingreader.h"

@interface ZRLEEncodingReader : ZlibEncodingReader
{
	NSRect tile;
	FrameBufferColor	palette[128];
}

- (void)setUncompressedData:(unsigned char*)data length:(int)length;

@end
