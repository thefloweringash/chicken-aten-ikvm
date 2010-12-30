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

#import <AppKit/AppKit.h>
#import <zlib.h>
#import "ByteReader.h"

@class RFBConnection;

/* ZlibStreamReader processes zlib data from the server, inflating as the data
 * arrives. When done, it will message its target with an NSData containing the
 * uncompressed data. The memory backing this object will be re-used, so it
 * should not be held for longer than the target call. */
@interface ZlibStreamReader : ByteReader
{
    unsigned char   *buffer;
    unsigned        capacity;   // size of buffer
    z_stream        stream;
    unsigned        bytesLeft;  // number of compressed bytes left to read
    RFBConnection   *connection;
}

- (id)initTarget:(id)aTarget action:(SEL)anAction
        connection:(RFBConnection *)aConnection;
- (void)setCompressedSize: (unsigned)compr maxUncompressed: (unsigned)uncompr;
- (void)zlibError:(int)result tag:(NSString *)tag;

@end
