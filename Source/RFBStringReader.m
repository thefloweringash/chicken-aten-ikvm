/* RFBStringReader.m created by helmut on Tue 16-Jun-1998 */

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

#import "RFBStringReader.h"
#import "ByteBlockReader.h"
#import "CARD32Reader.h"
#import "RFBConnection.h"

/* Reads a string from the server. The default is to assume that the string is
 * in UTF-8 format, although that can be overriden by the encoding: parameter */
@implementation RFBStringReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
      connection: (RFBConnection *)aConnection
{
    return [self initTarget:aTarget action:anAction connection:aConnection
                   encoding:NSUTF8StringEncoding];
}

- (id)initTarget:(id)aTarget action:(SEL)anAction
      connection: (RFBConnection *)aConnection
        encoding:(NSStringEncoding)anEncoding
{
	if (self = [super init]) {
        target = aTarget;
        action = anAction;
        connection = aConnection;
        encoding = anEncoding;
	}
    return self;
}

- (void)readString
{
    CARD32Reader    *lengthReader;

    lengthReader = [[CARD32Reader alloc] initTarget:self action:@selector(setLength:)];
    [connection setReader:lengthReader];
    [lengthReader release];
}

- (void)setLength:(NSNumber *)theLength
{
    ByteBlockReader *contentReader;
    unsigned    length = [theLength unsignedIntValue];

    if (length == 0) {
        [target performSelector:action withObject:@""];
        return;
    }

    contentReader = [[ByteBlockReader alloc] initTarget:self
                                 action:@selector(setContent:) size:length];
    [connection setReader:contentReader];
    [contentReader release];
}

- (void)setContent:(NSData *)content
{
    NSString    *str;
    str = [[NSString alloc] initWithData:content encoding:encoding];
    [target performSelector:action withObject:str];
    [str release];
}

@end
