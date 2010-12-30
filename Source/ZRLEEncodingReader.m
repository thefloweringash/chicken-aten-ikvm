//
//  ZRLEEncodingReader.m
//  Chicken of the VNC
//
//  Created by Helmut Maierhofer on Thu Nov 07 2002.
//  Copyright (c) 2002 Helmut Maierhofer. All rights reserved.
//

#import "ZRLEEncodingReader.h"
#import "RFBConnection.h"
#import "FrameBufferUpdateReader.h"

#define TILE_WIDTH		64
#define TILE_HEIGHT		64

@implementation ZRLEEncodingReader

- (unsigned)maximumUncompressedSize
{
    /* The worst case is using all plain RLE subencodings, but all runs having
     * length one. Thus every pixel is a CPIXEL followed by a single length
     * byte. In addition, there is a subencoding byte for each tile.
     *
     * Admittedly, it's rather silly for the server to choose such a wasteful
     * encoding, but we might as well prepare for it. */
    unsigned    tilesWide = (frame.size.width + TILE_WIDTH - 1) / TILE_WIDTH;
    unsigned    tilesHigh = (frame.size.height + TILE_HEIGHT - 1) / TILE_HEIGHT;
    return tilesWide * tilesHigh
        + ([frameBuffer bytesPerPixel] + 1) * frame.size.width * frame.size.height;
}

- (void)setUncompressedData:(NSData *)nsData
{
	int i, y, samples, samplesPerByte, shift;
	unsigned cPixelSize = [frameBuffer tightBytesPerPixel];
    const char  *data = [nsData bytes];
    int         length = [nsData length];
	
	// hack around UltraVN‚ 1.0.1, Chicken Bug #1351494
	if ( 4 == cPixelSize )
	{
		[frameBuffer setTightBytesPerPixelOverride: 3];
		cPixelSize = 3;
	}
	
	unsigned char subEncoding, b;
	FrameBufferPaletteIndex tileBuffer[TILE_HEIGHT * TILE_WIDTH];
	FrameBufferPaletteIndex* current, *eol;

	for(tile.origin.y = frame.origin.y; tile.origin.y < frame.origin.y+frame.size.height; tile.origin.y += TILE_HEIGHT) {
		tile.size.height = MIN(TILE_HEIGHT, (frame.origin.y + frame.size.height - tile.origin.y));
		for(tile.origin.x = frame.origin.x; tile.origin.x < frame.origin.x+frame.size.width; tile.origin.x += TILE_WIDTH) {
			tile.size.width = MIN(TILE_WIDTH, (frame.origin.x + frame.size.width - tile.origin.x));
            if (--length <= 0) {
                [connection terminateConnection:NSLocalizedString(@"ZrleTooSmall", nil)];
                return;
            }
			subEncoding = *data++;
//			NSLog(@"Subencoding = %d\n", subEncoding);
			if(subEncoding == 0) {
				// raw pixels
                int size = cPixelSize * tile.size.width * tile.size.height;
                if (length < size) {
                    [connection terminateConnection:NSLocalizedString(@"ZrleTooSmall", nil)];
                    return;
                }
				[frameBuffer putRect:tile fromTightData:data];
				data += size;
                length -= size;
			} else if(subEncoding == 1) {
                // solid color
                if (length < cPixelSize) {
                    [connection terminateConnection:NSLocalizedString(@"ZrleTooSmall", nil)];
                    return;
                }
				[frameBuffer fillRect:tile tightPixel:data];
				data += cPixelSize;
                length -= cPixelSize;
			} else if(subEncoding <= 16) {
                // packed palette types
				unsigned char index = 0;
				switch(subEncoding - 2) {
					case 0: samplesPerByte = 8; break;
					case 1:
					case 2: samplesPerByte = 4; break;
					default:samplesPerByte = 2; break;
				}
				shift = 8 / samplesPerByte;
                int bytesPerRow = (tile.size.width + samplesPerByte - 1)/samplesPerByte;

                if (length < subEncoding * cPixelSize + tile.size.height * bytesPerRow) {
                    [connection terminateConnection:NSLocalizedString(@"ZrleTooSmall", nil)];
                    return;
                }
				for(i=0; i<subEncoding; i++) {
					[frameBuffer fillColor:palette + i fromTightPixel:data];
					data += cPixelSize;
                    length -= cPixelSize;
				}
				current = tileBuffer;
				y = tile.size.height;
				while(y--) {
					samples = 0;
					eol = current + (int)tile.size.width;
					while(current < eol) {
						if(samples == 0) {
							index = *data++;
                            length--;
							samples = samplesPerByte;
						}
						*current++ = index >> (8 - shift);
						index <<= shift;
						samples--;
					}
				}
				[frameBuffer putRect:tile withColors:tileBuffer fromPalette:palette];
			} else if(subEncoding == 128) {
                // plain RLE
				y = 0;
				while(y < (tile.size.width * tile.size.height)) {
                    if (length < cPixelSize) {
                        [connection terminateConnection:NSLocalizedString(@"ZrleTooSmall",
                                                                          nil)];
                        return;
                    }
					[frameBuffer fillColor:palette fromTightPixel:data];
					data += cPixelSize;
                    length -= cPixelSize;
					i = 1;
					do {
                        if (--length < 0) {
                            [connection terminateConnection:
                                NSLocalizedString(@"ZrleTooSmall", nil)];
                            return;
                        }
						b = *data++;
						i += b;
					} while(b == 0xff);
					[frameBuffer putRun:palette ofLength:i at:tile pixelOffset:y];
					y += i;
				}
			} else if(subEncoding >= 130) {
                // palette RLE
                if (length < (subEncoding - 128) * cPixelSize) {
                    [connection terminateConnection:NSLocalizedString(@"ZrleTooSmall", nil)];
                    return;
                }
				for(i=0; i<(subEncoding - 128); i++) {
					[frameBuffer fillColor:palette + i fromTightPixel:data];
					data += cPixelSize;
                    length -= cPixelSize;
				}
				y = 0;
				while(y < (tile.size.width * tile.size.height)) {
					unsigned char index = *data++;
					if(index < 128) {
						[frameBuffer putRun:palette + index ofLength:1 at:tile pixelOffset:y];
						y++;
						continue;
					}
					index &= 0x7f;
					i = 1;
					do {
                        if (--length < 0) {
                            [connection terminateConnection:
                                NSLocalizedString(@"ZrleTooSmall", nil)];
                            return;
                        }
						b = *data++;
						i += b;
					} while(b == 0xff);
					[frameBuffer putRun:palette + index ofLength:i at:tile pixelOffset:y];
					y += i;
				}
			} else {
                NSString    *format;
                NSString    *err;

                format = NSLocalizedString(@"ZrleUnknownSubencoding", nil);
                err = [NSString stringWithFormat:format, subEncoding];
                [connection terminateConnection:err];
                return;
            }
		}
	}

    [updater didRect:self];
}

@end
