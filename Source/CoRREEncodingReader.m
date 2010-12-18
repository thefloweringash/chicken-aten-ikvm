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
#import "RFBConnection.h"
#import "FrameBufferUpdateReader.h"

@implementation CoRREEncodingReader

- (void)setBackground:(NSData*)data
{
    [frameBuffer fillRect:frame withPixel:(unsigned char*)[data bytes]];
    if(numOfSubRects) {
        int size = ([frameBuffer bytesPerPixel] + 4) * numOfSubRects;
        [subRectReader setBufferSize:size];
        [connection setReader:subRectReader];
    } else {
        [updater didRect: self];
    }
}

- (void)drawRectangles:(NSData*)data
{
    unsigned char*	bytes = (unsigned char*)[data bytes];
    unsigned char*	pixptr;
    NSRect		r;
    unsigned int	bpp = [frameBuffer bytesPerPixel];

    while(numOfSubRects--) {
        pixptr = bytes;
        bytes += bpp;
        r.origin.x = *bytes++ + frame.origin.x;
        r.origin.y = *bytes++ + frame.origin.y;
        r.size.width = *bytes++;
        r.size.height = *bytes++;
        [frameBuffer fillRect:r withPixel:pixptr];
    }
    [updater didRect: self];
}

@end
