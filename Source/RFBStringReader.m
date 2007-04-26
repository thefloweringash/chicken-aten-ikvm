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
#import "CARD32Reader.h"

@implementation RFBStringReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
	if (self = [super initTarget:aTarget action:anAction]) {
		lengthReader = [[CARD32Reader alloc] initTarget:self action:@selector(setLength:)];
	}
    return self;
}

- (void)dealloc
{
    [lengthReader release];
    if(buffer != NULL) {
        free(buffer);
    }
    [super dealloc];
}

- (void)resetReader
{
    [target setReader:lengthReader];
}

- (unsigned)readBytes:(unsigned char*)theBytes length:(unsigned)aLength
{
    unsigned canConsume = MIN(aLength, (length - bytesRead));

    memcpy(buffer + bytesRead, theBytes, canConsume);
    if((bytesRead += canConsume) == length) {
        [target performSelector:action withObject:[NSString stringWithCString:buffer length:length]];
    }
    return canConsume;
}

- (void)setLength:(NSNumber*)theLength
{
    length = [theLength unsignedIntValue];
    if(buffer) {
        free(buffer);
    }
    buffer = malloc(length);
    
    // - Prevent the DOS attack on http://www.securityfocus.com/archive/1/458907/100/0/threaded
    
    if (!buffer)
        [NSException raise: NSGenericException format: @"Invalid computer name size sent by server, Chicken will bail out"];
    
    [target setReaderWithoutReset:self];
    bytesRead = 0;
}

@end
