/* Copyright (C) 2010 Dustin Cartwright
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

#import "ZlibStreamReader.h"
#import "RFBConnection.h"

@implementation ZlibStreamReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
    connection:(RFBConnection *)aConnection
{
    if (self = [super initTarget:aTarget action:anAction]) {
        connection = aConnection;
        buffer = NULL;
        capacity = 0;

        int result = inflateInit(&stream);
        if (result != Z_OK) {
            [self zlibError:result tag:@"InflateInit"];
            [self dealloc];
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (buffer)
        free(buffer);
    inflateEnd(&stream);
    [super dealloc];
}

/* Sets the number of compressed bytes to read, and the maximum size that the
 * data will take up uncompressed. */
- (void)setCompressedSize: (unsigned)compr maxUncompressed: (unsigned)maxSize
{
    bytesLeft = compr;
    if (maxSize > capacity) {
        if (buffer)
            free(buffer);
        buffer = malloc(maxSize);
        capacity = maxSize;

        if (buffer == NULL) {
            NSString    *err = NSLocalizedString(@"InflateMem", nil);
            [connection terminateConnection:err];
            capacity = 0;
        }
    }
    stream.next_out = buffer;
    stream.avail_out = capacity;
}

- (unsigned)readBytes:(unsigned char *)bytes length:(unsigned)len
{
    unsigned    consume = MIN(len, bytesLeft);
    int         inflateResult;

    stream.next_in = bytes;
    stream.avail_in = consume;
    inflateResult = inflate(&stream, Z_SYNC_FLUSH);

    if (inflateResult != Z_OK) {
        [self zlibError:inflateResult tag:@"InflateError"];
		return 0;
    }

    if (stream.avail_out == 0 && stream.avail_in > 0) {
        /* The uncompressed size was larger than what we were supposed to
        * expect. If this happens, either we have a bug, or the server is
        * sending invalid data. Nonetheless, we'll try to handle it by enlarging
        * the buffer. */
        unsigned    newCapacity = 2 * capacity;

        NSLog(@"Having to expand storage in ZlibStreamReader");
        buffer = reallocf(buffer, newCapacity);
        if (buffer == NULL) {
            NSString    *err = NSLocalizedString(@"InflateMem", nil);
            [connection terminateConnection:err];
            capacity = 0;
            return 0;
        }
        stream.next_in = buffer + capacity;
        stream.avail_in = newCapacity - capacity;
        capacity = newCapacity;

        consume -= stream.avail_in;
    }

    bytesLeft -= consume;
    if (bytesLeft == 0) {
        NSData  *data = [[NSData alloc] initWithBytesNoCopy:buffer
                                length:capacity - stream.avail_out
                                freeWhenDone:NO];
        [target performSelector:action withObject:data];
        [data release];
    }
    return consume;
}

/* An error occurred in a zlib routine. */
- (void)zlibError:(int)result tag:(NSString *)tag
{
    NSString    *fmt = NSLocalizedString(tag, nil);
    char        *msg = stream.msg ? stream.msg : "";
    NSString    *err = [NSString stringWithFormat:fmt, result, msg];
    [connection terminateConnection:err];
}

@end
