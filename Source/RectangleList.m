/* RectangleList.m created by helmut on Sun 21-Jun-1998 */

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

#import "RectangleList.h"

@implementation RectangleList

- (id)initElements:(unsigned int)number
{
    [super init];
    [self startWithNumber:number];
    return self;
}

- (void)dealloc
{
    if (rectList != NULL) {
        free(rectList);
    }
    if (rgbList != NULL) {
        free(rgbList);
    }
    [super dealloc];
}

- (void)startWithNumber:(unsigned int)n
{
    if(n > capacity) {
		if (rectList != NULL) {
			free(rectList);
		}
		if (rgbList != NULL) {
			free(rgbList);
		}
        rectList = malloc(sizeof(NSRect) * n);
		NSParameterAssert( rectList != NULL );
        rgbList = malloc(sizeof(float) * n * 3);
		NSParameterAssert( rgbList != NULL );
        capacity = n;
    }
    used = 0;
    rectPos = rectList;
    rgbPos = rgbList;
}

- (void)putRectangle:(NSRect)aRect withColor:(float*)rgb
{
    if(used < capacity) {
        used++;
        *rectPos++ = aRect;
        memcpy(rgbPos, rgb, sizeof(float) * 3);
        rgbPos += 3;
    }
}

- (void)drawRectsInRect:(NSRect)frame
{
    int i;
    NSRect* rp = rectList;
    float* fp = rgbList;

    for(i=0; i<used; i++) {
        rp->origin.y = frame.size.height - rp->origin.y - rp->size.height;
		// Jason - no PS functions
		[[NSColor colorWithCalibratedRed: fp[0] green: fp[1] blue: fp[2] alpha: 1.0] set];
//        PSsetrgbcolor(fp[0], fp[1], fp[2]);
        NSRectFill(*rp);
        rp++;
        fp += 3;
    }
}

@end
