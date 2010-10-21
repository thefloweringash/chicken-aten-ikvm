/* GradientFilter.m created by helmut on 01-Nov-2000 */

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

#import "GradientFilter.h"
#import "FrameBuffer.h"
#import "EncodingReader.h"

@implementation GradientFilter

- (id)initWithTarget:(TightEncodingReader *)aTarget
          andConnection:(RFBConnection *)aConnection
{
    if (self = [super initWithTarget: aTarget andConnection: aConnection]) {
		filterData = [[NSMutableData alloc] init];
		prevRow = thisRow = src = NULL;
	}
    return self;
}

static void _free(void* p) {
    if(p != NULL) {
	free(p);
    }
}

- (void)dealloc
{
    [filterData release];
    _free(prevRow);
    _free(thisRow);
    _free(src);
    [super dealloc];
}

- (void)resetFilterForRect:(NSRect)rect
{
    rowSize = rect.size.width;
    rowBytes = rowSize * bytesPerPixel;
    if(rowSize > rowCapacity) {
        rowCapacity = rowSize;
        _free(prevRow);
        _free(thisRow);
        _free(src);
        prevRow = malloc(3 * rowSize * sizeof(int));
        thisRow = malloc(3 * rowSize * sizeof(int));
        src = malloc(3 * rowSize * sizeof(int));
    }
    memset(prevRow, 0, 3 * rowSize * sizeof(int));
    [target filterInitDone];
}

- (NSData*)filter:(NSData*)data rows:(unsigned)numRows
{
    int* tmp;
    unsigned int c, x, y;
    int est[3];
    int col[3];
    int max[3];
    unsigned char* dst;
    unsigned char* bytes = (unsigned char*)[data bytes];
    
    [filterData setLength:numRows * rowBytes];
    dst = [filterData mutableBytes];
    [frameBuffer getMaxValues:max];
    
    for(y=0; y<numRows; y++) {

        [frameBuffer splitRGB:bytes pixels:rowSize into:src];
        bytes += rowBytes;
           
		// col = (src + prevRow) & max
        // thisRow = col
        // dst = col

        for(c=0; c<3; c++) {
            col[c] = src[c] + prevRow[c] & max[c];
            thisRow[c] = col[c];
        }

        for(x=1; x<rowSize; x++) {
            // est = prevRow + col - prevRow[-1]
            // clip(est)
            // col = (src + est) & max
            // thisRow = col
            // dst = col

            for(c=0; c<3; c++) {
                est[c] = prevRow[x*3+c] + col[c] - prevRow[(x-1)*3+c];
                if(est[c] > max[c]) {
                    est[c] = max[c];
                } else if(est[c] < 0) {
                    est[c] = 0;
                }
                col[c] = src[x*3+c] + est[c] & max[c];
                thisRow[x*3+c] = col[c];
            }
        }

        [frameBuffer combineRGB:thisRow pixels:rowSize into:dst];
        dst += rowBytes;
	        
        // prevRow = thisRow

        tmp = thisRow;
        thisRow = prevRow;
        prevRow = tmp;
    }
    return filterData;
}

@end
