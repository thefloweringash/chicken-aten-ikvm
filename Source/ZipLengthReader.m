/* ZipLengthReader.m created by helmut on 01-Nov-2000 */

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

#import "ZipLengthReader.h"

@implementation ZipLengthReader

static const unsigned char _mask[3] = {
    0x7f, 0x7f, 0xff
};

static const unsigned int _shift[3] = {
    0, 7, 14
};

- (void)resetReader
{
    bytenr = 0;
    value = 0;
}

- (unsigned)readBytes:(unsigned char*)theBytes length:(unsigned)aLength
{
    unsigned canConsume = 0;
    
    while(aLength > 0) {
        canConsume++;
        value |= ((int)(*theBytes) & _mask[bytenr]) << _shift[bytenr];
        if((++bytenr >= 3) || ((*theBytes & 0x80) == 0)) {
            [target performSelector:action withObject:[NSNumber numberWithUnsignedInt:value]];
            return canConsume;
        }
        aLength--;
        theBytes++;
    }
    return canConsume;
}

@end
