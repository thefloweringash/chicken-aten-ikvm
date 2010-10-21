/* LowColorFrameBuffer.m created by helmut on Wed 23-Jun-1999 */

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

#import "LowColorFrameBuffer.h"

typedef	unsigned char			FBColor;

@implementation LowColorFrameBuffer

- (id)initWithSize:(NSSize)aSize andFormat:(rfbPixelFormat*)theFormat
{
    if (self = [super initWithSize:aSize andFormat:theFormat]) {
		unsigned int sps;
			
		rshift = 6;
		gshift = 4;
		bshift = 2;
		maxValue = 3;
		samplesPerPixel = 3;
		bitsPerColor = 2;
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
   aFormat->bitsPerPixel = 8;
   aFormat->redMax = aFormat->greenMax = aFormat->blueMax = 3;
   aFormat->redShift = 6;
   aFormat->greenShift = 4;
   aFormat->blueShift = 2;
   aFormat->depth = 8;
}


#include "FrameBufferDrawing.h"

@end
