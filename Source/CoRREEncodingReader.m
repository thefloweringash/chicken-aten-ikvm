/* CoRREEncodingReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "CoRREEncodingReader.h"
#import "ByteBlockReader.h"
#import "RectangleList.h"

@implementation CoRREEncodingReader

- (void)setBackground:(NSData*)data
{
    [frameBuffer fillRect:frame withPixel:(unsigned char*)[data bytes]];
    if(useList) {
        float	rgb[3];
        [frameBuffer getRGB:rgb fromPixel:(unsigned char*)[data bytes]];
        [rectList putRectangle:frame withColor:rgb];
    }
    if(numOfSubRects) {
        int size = ([frameBuffer bytesPerPixel] + 4) * numOfSubRects;
#ifdef COLLECT_STATS
        bytesTransferred += size;
#endif
        [subRectReader setBufferSize:size];
        [target setReader:subRectReader];
    } else {
        [target performSelector:action withObject:self];
    }
}

- (void)drawRectangles:(NSData*)data
{
    unsigned char*	bytes = (unsigned char*)[data bytes];
    unsigned char*	pixptr;
    float		rgb[3];
    NSRect		r;
    unsigned int	bpp = [frameBuffer bytesPerPixel];

    while(numOfSubRects--) {
        if(useList) {
            [frameBuffer getRGB:rgb fromPixel:bytes];
        }
        pixptr = bytes;
        bytes += bpp;
        r.origin.x = *bytes++ + frame.origin.x;
        r.origin.y = *bytes++ + frame.origin.y;
        r.size.width = *bytes++;
        r.size.height = *bytes++;
        [frameBuffer fillRect:r withPixel:pixptr];
        if(useList) {
            [rectList putRectangle:r withColor:rgb];
        }
    }
    [target performSelector:action withObject:self];
}

@end
