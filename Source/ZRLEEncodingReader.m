//
//  ZRLEEncodingReader.m
//  Chicken of the VNC
//
//  Created by Helmut Maierhofer on Thu Nov 07 2002.
//  Copyright (c) 2002 Helmut Maierhofer. All rights reserved.
//

#import "ZRLEEncodingReader.h"
#import "RFBConnection.h"

#define TILE_WIDTH		64
#define TILE_HEIGHT		64

@implementation ZRLEEncodingReader

- (void)setUncompressedData:(unsigned char*)data length:(int)length
{
	int i, y, samples, samplesPerByte, shift;
	unsigned cPixelSize = [frameBuffer tightBytesPerPixel];
	unsigned char subEncoding, index, b;
	FrameBufferPaletteIndex tileBuffer[TILE_HEIGHT * TILE_WIDTH];
	FrameBufferPaletteIndex* current, *eol;

	for(tile.origin.y = frame.origin.y; tile.origin.y < frame.origin.y+frame.size.height; tile.origin.y += TILE_HEIGHT) {
		tile.size.height = MIN(TILE_HEIGHT, (frame.origin.y + frame.size.height - tile.origin.y));
		for(tile.origin.x = frame.origin.x; tile.origin.x < frame.origin.x+frame.size.width; tile.origin.x += TILE_WIDTH) {
			tile.size.width = MIN(TILE_WIDTH, (frame.origin.x + frame.size.width - tile.origin.x));
			subEncoding = *data++;
//			NSLog(@"Subencoding = %d\n", subEncoding);
			if(subEncoding == 0) {
				// raw pixels
				[frameBuffer putRect:tile fromTightData:data];
				data += (int)(cPixelSize * tile.size.width * tile.size.height);
				continue;
			}
			if(subEncoding == 1) {
				[frameBuffer fillRect:tile tightPixel:data];
				data += cPixelSize;
				continue;
			}
			if(subEncoding <= 16) {
				for(i=0; i<subEncoding; i++) {
					[frameBuffer fillColor:palette + i fromTightPixel:data];
					data += cPixelSize;
				}
				current = tileBuffer;
				y = tile.size.height;
				switch(subEncoding - 2) {
					case 0: samplesPerByte = 8; break;
					case 1:
					case 2: samplesPerByte = 4; break;
					default:samplesPerByte = 2; break;
				}
				shift = 8 / samplesPerByte;
				while(y--) {
					samples = 0;
					eol = current + (int)tile.size.width;
					while(current < eol) {
						if(samples == 0) {
							index = *data++;
							samples = samplesPerByte;
						}
						*current++ = index >> (8 - shift);
						index <<= shift;
						samples--;
					}
				}
				[frameBuffer putRect:tile withColors:tileBuffer fromPalette:palette];
				continue;
			}
			if(subEncoding == 128) {
				y = 0;
				while(y < (tile.size.width * tile.size.height)) {
					[frameBuffer fillColor:palette fromTightPixel:data];
					data += cPixelSize;
					i = 1;
					do {
						b = *data++;
						i += b;
					} while(b == 0xff);
					[frameBuffer putRun:palette ofLength:i at:tile pixelOffset:y];
					y += i;
				}
				continue;
			}
			if(subEncoding >= 130) {
				for(i=0; i<(subEncoding - 128); i++) {
					[frameBuffer fillColor:palette + i fromTightPixel:data];
					data += cPixelSize;
				}
				y = 0;
				while(y < (tile.size.width * tile.size.height)) {
					index = *data++;
					if(index < 128) {
						[frameBuffer putRun:palette + index ofLength:1 at:tile pixelOffset:y];
						y++;
						continue;
					}
					index &= 0x7f;
					i = 1;
					do {
						b = *data++;
						i += b;
					} while(b == 0xff);
					[frameBuffer putRun:palette + index ofLength:i at:tile pixelOffset:y];
					y += i;
				}
				continue;
			}
			[connection terminateConnection:[NSString stringWithFormat:@"ZlibHex unknown subencoding %d encountered\n", subEncoding]];
			return;
		}
	}
    [target performSelector:action withObject:self];	
}

@end
