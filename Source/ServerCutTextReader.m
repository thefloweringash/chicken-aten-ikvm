/* ServerCutTextReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "ServerCutTextReader.h"
#import "RFBStringReader.h"
#import "ByteBlockReader.h"

@implementation ServerCutTextReader

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
	if (self = [super initTarget:aTarget action:anAction]) {
		dummyReader = [[ByteBlockReader alloc] initTarget:self action:@selector(padding:) size:3];
		textReader = [[RFBStringReader alloc] initTarget:self action:@selector(setText:)];
	}
    return self;
}

- (void)dealloc
{
    [dummyReader release];
    [textReader release];
    [super dealloc];
}

- (void)resetReader
{
    [target setReader:dummyReader];
}

- (void)padding:(NSData*)pad
{
    [target setReader:textReader];
}

- (void)setText:(NSString*)aText
{
    NSPasteboard* pb = [NSPasteboard generalPasteboard];

    [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pb setString:aText forType:NSStringPboardType];
    [target performSelector:action withObject:aText];
}

@end
