/* PaletteFilter.m created by helmut on 01-Nov-2000 */

/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "PaletteFilter.h"
#import "rfbproto.h"
#import "CARD8Reader.h"
#import "ByteBlockReader.h"
#import "EncodingReader.h"
#import "FrameBuffer.h"

@implementation PaletteFilter

- (id)initWithTarget:(TightEncodingReader*)aTarget
          andConnection: (RFBConnection *)aConnection
{
    if (self = [super initWithTarget:aTarget andConnection:aConnection]) {
		numColorReader = [[CARD8Reader alloc] initTarget:self action:@selector(setColors:)];
		paletteReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setPalette:)];
		filterData = [[NSMutableData alloc] init];
	}
    return self;
}

- (void)dealloc
{
    [numColorReader release];
    [paletteReader release];
    [filterData release];
    if(src) {
		free(src);
    }
    [super dealloc];
}

- (void)resetFilterForRect:(NSRect)rect
{
    rowSize = rect.size.width;
    if(rowSize > rowCapacity) {
        rowCapacity = rowSize;
		if(src) {
			free(src);
		}
        src = malloc(3 * rowSize * sizeof(int));
    }
    [connection setReader:numColorReader];
}

/* Just read the number of colors */
- (void)setColors:(NSNumber*)n
{
    numColors = [n unsignedCharValue] + 1;
    [paletteReader setBufferSize:numColors * bytesPerPixel];
#ifdef COLLECT_STATS
    bytesTransferred = 1 + numColors * bytesPerPixel;
#endif
    [connection setReader:paletteReader];
}

/* Just read the palette */
- (void)setPalette:(NSData*)data
{
/*   {
        int i;
        unsigned short* sp = (unsigned short*)[data bytes];
        printf("palette: ");
        for(i=0; i<numColors; i++) {
            printf("%04x ", sp[i]);
        }
        printf("\n");
    }
*/
    [frameBuffer splitRGB:(unsigned char*)[data bytes] pixels:numColors into:palette];
    [target filterInitDone];
}

- (NSData*)filter:(NSData*)data rows:(unsigned)numRows
{
    int b, w, x, y, rowBytes, val;
    unsigned char* fd;
    int* dst;
    unsigned char* bytes = (unsigned char*)[data bytes];

    rowBytes = rowSize * bytesPerPixel;
    [filterData setLength:numRows * rowBytes];
    fd = [filterData mutableBytes];
    if(numColors == 2) {
        w = (rowSize + 7) / 8;
        for(y=0; y<numRows; y++) {
            dst = src;
            for(x=0; x<rowSize/8; x++) {
                for(b=7; b>=0; b--) {
                    val = ((int)((bytes[y*w+x] >> b) & 1)) * 3;
                    *dst++ = palette[val];
                    *dst++ = palette[val+1];
                    *dst++ = palette[val+2];
                }
            }
            for(b=7; b>=8 - (rowSize & 7); b--) {
                val = ((int)((bytes[y*w+x] >> b) & 1)) * 3;
                *dst++ = palette[val];
                *dst++ = palette[val+1];
                *dst++ = palette[val+2];
            }
            [frameBuffer combineRGB:src pixels:rowSize into:fd];
            fd += rowBytes;
        }
    } else {
//        printf("palettedata: ");
        for(y=0; y<numRows; y++) {
            dst = src;
            for(x=0; x<rowSize; x++) {
//                printf("%02x ", bytes[y*rowSize+x] & 0xff);
                val = ((int)bytes[y*rowSize+x]) * 3;                
                *dst++ = palette[val];
                *dst++ = palette[val+1];
                *dst++ = palette[val+2];
            }
            [frameBuffer combineRGB:src pixels:rowSize into:fd];
            fd += rowBytes;
        }
//        printf("\n");
    }
    return filterData;
}

- (unsigned)bitsPerPixel
{
    return (numColors == 2) ? 1 : 8;
}

@end
