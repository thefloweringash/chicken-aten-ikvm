/* RawEncodingReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "RawEncodingReader.h"
#import "ByteBlockReader.h"

@implementation RawEncodingReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    if (self = [super initTarget:aTarget action:anAction]) {
		pixelReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setPixels:)];
	}
    return self;
}

- (void)dealloc
{
    [pixelReader release];
    [super dealloc];
}

- (void)resetReader
{
    unsigned s = [frameBuffer bytesPerPixel] * frame.size.width * frame.size.height;

#ifdef COLLECT_STATS
    bytesTransferred = s;
#endif
    [pixelReader setBufferSize:s];
    [target setReader:pixelReader];
}

- (void)setPixels:(NSData*)pixel
{
    [frameBuffer putRect:frame fromData:(unsigned char*)[pixel bytes]];
    [target performSelector:action withObject:self];
}

@end
