/* CopyRectangleEncodingReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "CopyRectangleEncodingReader.h"
#import "ByteBlockReader.h"
#import "RFBConnection.h"

@implementation CopyRectangleEncodingReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    if (self = [super initTarget:aTarget action:anAction]) {
		posReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setPosition:) size:4];
#ifdef COLLECT_STATS
		bytesTransferred = 4;
#endif
	}
    return self;
}

- (void)dealloc
{
    [posReader release];
    [super dealloc];
}

- (void)resetReader
{
    [target setReader:posReader];
}

- (void)setPosition:(NSData*)position
{
    CARD16	source[2];
    NSRect	srect = frame;

    memcpy(source, [position bytes], sizeof(source));
    srect.origin.x = ntohs(source[0]);
    srect.origin.y = ntohs(source[1]);
    [frameBuffer copyRect:srect to:frame.origin];
    [target performSelector:action withObject:self];
}

@end
