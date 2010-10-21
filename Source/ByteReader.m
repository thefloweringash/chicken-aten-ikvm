/* ByteReader.m created by helmut on Tue 16-Jun-1998 */

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

#import "ByteReader.h"

@implementation ByteReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
	if (self = [super init]) {
		action = anAction;
		target = aTarget;
	}
    return self;
}

- (void)resetReader
{
}

- (id)topTarget
{
    if(target) {
        return [target topTarget];
    } else {
        return self;
    }
}

- (void)setReader:(ByteReader*)aReader
{
    [target setReader:aReader];
}

- (unsigned)readBytes:(unsigned char*)theBytes length:(unsigned)aLength
{
    return 0;
}

@end
