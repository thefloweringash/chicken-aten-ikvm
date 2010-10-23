/* RFBServerInitReader.m created by helmut on Tue 16-Jun-1998 */

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

#import "RFBServerInitReader.h"
#import "ByteBlockReader.h"
#import "RFBHandshaker.h"
#import "RFBStringReader.h"

@implementation ServerInitMessage

- (void)setFixed:(NSData*)data
{
    memcpy(&fixed, [data bytes], sizeof(fixed));
    fixed.framebufferWidth = ntohs(fixed.framebufferWidth);
    fixed.framebufferHeight = ntohs(fixed.framebufferHeight);
    fixed.format.redMax = ntohs(fixed.format.redMax);
    fixed.format.greenMax = ntohs(fixed.format.greenMax);
    fixed.format.blueMax = ntohs(fixed.format.blueMax);
}

- (rfbPixelFormat *)pixelFormatData
{
    return &fixed.format;
}

- (void)dealloc
{
    [name release];
    [super dealloc];
}

- (void)setName:(NSString*)aName
{
    [name release];
    name = [aName retain];
}

- (NSString*)name
{
    return name;
}

- (NSSize)size
{
    NSSize s;

    s.width = fixed.framebufferWidth;
    s.height = fixed.framebufferHeight;
    return s;
}

@end

@implementation RFBServerInitReader

- (id)initWithConnection: (RFBConnection *)aConnection
          andHandshaker: (RFBHandshaker *)aHandshaker
{
    if (self = [super init]) {
        connection = aConnection;
        handshaker = aHandshaker;
        nameReader = [[RFBStringReader alloc] initTarget:self
                action:@selector(setName:) connection: connection];
        msg = [[ServerInitMessage alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [nameReader release];
    [msg release];
    [super dealloc];
}

- (void)readServerInit
{
    ByteBlockReader *blockReader;

    blockReader = [[ByteBlockReader alloc] initTarget:self
            action:@selector(setBlock:) size:20];
    [connection setReader:blockReader];
    [blockReader release];
}

- (void)setBlock:(NSData*)theBlock
{
    [msg setFixed:theBlock];
    [nameReader readString];
}

- (void)setName:(NSString*)aName
{
    [msg setName:aName];
    [handshaker setServerInit: msg];
}

@end
