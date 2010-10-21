//
//  CursorPseudoEncodingReader.h
//  Chicken of the VNC
//
//  Created by Alex Wray on 9/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//


#import <AppKit/AppKit.h>
#import "EncodingReader.h"
#import <Cocoa/Cocoa.h>
#import "ByteBlockReader.h"

@interface CursorPseudoEncodingReader : EncodingReader {
	ByteBlockReader *cursorReader;
        // number of bytes per row of the mask
    unsigned int    bytesPerRow;
        // number of bytes of pixels in the cursor data
    unsigned int    bytesPixels;
}

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater
		   connection: (RFBConnection *)aConnection;

- (void)readEncoding;
- (void)setCursor:(NSData*)pixel;
- (NSImage *)imageFromCursorData: (NSData *)pixels;

@end
