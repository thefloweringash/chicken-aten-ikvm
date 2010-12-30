/* ByteBlockReader.m created by helmut on Tue 16-Jun-1998 */

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

#import "ByteBlockReader.h"

@implementation ByteBlockReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    return [self initTarget:aTarget action:anAction size:0];
}

- (id)initTarget:(id)aTarget action:(SEL)anAction size:(unsigned)aSize
{
	if (self = [super initTarget:aTarget action:anAction]) {
		capacity = 0;
		buffer = NULL;
		[self setBufferSize:aSize];
	}
    return self;
}

- (void)dealloc
{
    if(buffer) {
        free(buffer);
    }
    [super dealloc];
}

- (void)setBufferSize:(unsigned)aSize
{
    size = aSize;
}

- (unsigned)bufferSize
{
    return size;
}

- (void)resetReader
{
    bytesRead = 0;
}

- (unsigned)readBytes:(unsigned char*)theBytes length:(unsigned)aLength
{
    // we can save some time here by not copying the data into a new NSData object.  It's important to remember that all of our targets must treat this data as _READ_ONLY_ and temporary!

    unsigned canConsume = MIN(aLength, (size - bytesRead));

    if (canConsume == size) {
        NSData  *data = [[NSData alloc] initWithBytesNoCopy:theBytes length:size
                            freeWhenDone: NO];
        bytesRead = size;
        [target performSelector:action withObject:data];
        [data release];
    } else {
        if (size > capacity) {
            capacity = size;
            if (buffer)
                free(buffer);
            buffer = malloc(size);
            if (buffer == NULL) {
                NSLog(@"Memory allocation failed in ByteBlockReader");
                capacity = 0;
                return 0;
            }
        }

        memcpy(buffer + bytesRead, theBytes, canConsume);
        if((bytesRead += canConsume) == size) {
            NSData  *data = [[NSData alloc] initWithBytesNoCopy:buffer
                                                         length:size
                                                   freeWhenDone:NO];
            [target performSelector:action withObject:data];
            [data release];
        }
    }
    return canConsume;
}

@end
