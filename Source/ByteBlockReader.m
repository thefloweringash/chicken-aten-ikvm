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

extern BOOL gIsJaguar;

@implementation ByteBlockReader

- (id)initTarget:(id)aTarget action:(SEL)anAction size:(unsigned)aSize
{
	if (self = [super initTarget:aTarget action:anAction]) {
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
    if(aSize > capacity) {
        capacity = aSize;
        if(buffer) {
            free(buffer);
        }
        buffer = malloc(aSize);
    }
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
	// we can save some time here by not copying the data into a new NSData object.  Unfortunately, we can only save this time on Jaguar.  It's important to remember that all of our targets must treat this data as _READ_ONLY_!
	
    unsigned canConsume = MIN(aLength, (size - bytesRead));
    
    memcpy(buffer + bytesRead, theBytes, canConsume);
    if((bytesRead += canConsume) == size) {
		if (gIsJaguar) {
			[target performSelector:action withObject:[NSData dataWithBytesNoCopy:buffer length:size freeWhenDone: NO]];
		}
		else {
			[target performSelector:action withObject:[NSData dataWithBytes:buffer length:size]];
		}
    }
    return canConsume;
}

@end
