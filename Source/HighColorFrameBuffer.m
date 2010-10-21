/* HighColorFrameBuffer.m created by helmut on Wed 23-Jun-1999 */

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

#import "HighColorFrameBuffer.h"

typedef	unsigned short			FBColor;

@implementation HighColorFrameBuffer

- (id)initWithSize:(NSSize)aSize andFormat:(rfbPixelFormat*)theFormat
{
    if (self = [super initWithSize:aSize andFormat:theFormat]) {
		unsigned int sps;
	
		if(isBig) {
			rshift = 12;
			gshift = 8;
			bshift = 4;
		} else {
			rshift = 4;
			gshift = 0;
			bshift = 12;
		}
		maxValue = 15;
		samplesPerPixel = 3;
		bitsPerColor = 4;
		[self setPixelFormat:theFormat];
		sps = MIN((SCRATCHPAD_SIZE * sizeof(FBColor)), (aSize.width * aSize.height * sizeof(FBColor)));
		pixels = calloc(aSize.width * aSize.height, sizeof(FBColor));
		scratchpad = malloc(sps);
	}
    return self;
}

- (void)dealloc
{
    free(pixels);
    free(scratchpad);
    [super dealloc];
}

+ (void)getPixelFormat:(rfbPixelFormat*)aFormat
{
   aFormat->bitsPerPixel = 16;
   aFormat->redMax = aFormat->greenMax = aFormat->blueMax = 15;
   aFormat->redShift = 4;
   aFormat->greenShift = 0;
   aFormat->blueShift = 12;
   aFormat->depth = 16;
}


#include "FrameBufferDrawing.h"

@end
