/* CARD32Reader.m created by helmut on Tue 16-Jun-1998 */

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

#import "CARD32Reader.h"
#import "rfbproto.h"
#import "RFBConnection.h"

@implementation CARD32Reader

- (void)resetReader
{
    bytesToRead = sizeof(value);
}

- (unsigned)readBytes:(unsigned char*)theBytes length:(unsigned)aLength
{
    unsigned canConsume = MIN(aLength, bytesToRead);

    memcpy(value.card8 + (sizeof(value) - bytesToRead), theBytes, canConsume);
    if((bytesToRead -= canConsume) == 0) {
        value.card32 = ntohl(value.card32);
        [target performSelector:action withObject:[NSNumber numberWithUnsignedInt:value.card32]];
    }
    return canConsume;
}

@end
