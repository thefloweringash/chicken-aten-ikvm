/* RectangleList.h created by helmut on Sun 21-Jun-1998 */

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

#import <AppKit/AppKit.h>

@interface RectangleList : NSObject
{
    NSRect*		rectList;
    float*		rgbList;
    unsigned int	capacity;
    unsigned int	used;
    NSRect*		rectPos;
    float*		rgbPos;
}

- (id)initElements:(unsigned int)number;
- (void)startWithNumber:(unsigned int)n;
- (void)putRectangle:(NSRect)aRect withColor:(float*)rgb;
- (void)drawRectsInRect:(NSRect)frame;

@end
