/* Profile.m created by helmut on Fri 25-Jun-1999 */

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

#import "Profile.h"
#import "ProfileManager.h"
#import "FrameBuffer.h"

@implementation Profile

// Jason - replaced the following routine so that we use indices instead of string constants
static CARD32 getcode(id s)
{
	if([s shortValue] == kOptionKeyPopupIndex) {
		return 0xffe7;
	} else if([s shortValue] == kControlKeyPopupIndex) {
		return 0xffe3;
	} else if([s shortValue] == kCommmandKeyPopupIndex) {
		return 0xffe9;
	} else if([s shortValue] == kShiftKeyPopupIndex) {
		return 0xffe1;
	} else {
		return 0xffeb;
	}
}
/*
static CARD32 getcode(NSString* s)
{
    if([s isEqualToString:@"Meta"]) {
        return 0xffe7;
    } else if([s isEqualToString:@"Control"]) {
        return 0xffe3;
    } else if([s isEqualToString:@"Alt"]) {
        return 0xffe9;
    } else if([s isEqualToString:@"Shift"]) {
        return 0xffe1;
    } else {
        return 0xffea;
    }
}
*/

- (id)initWithDictionary:(NSDictionary*)d
{
    NSArray* enc;
    int i, mask;
    BOOL copyrect;
    
    [super init];
    info = [d copy];
    e3btimeout = [[info objectForKey:EmulateThreeButtonTimeout] intValue];
    e3btimeout /= 1000.0;
	// Jason replaced the following so we can use indices instead of titles
    commandKeyCode = getcode([info objectForKey:NewCommandKeyMap]);
    altKeyCode = getcode([info objectForKey:NewAltKeyMap]);
    shiftKeyCode = getcode([info objectForKey:NewShiftKeyMap]);
    controlKeyCode = getcode([info objectForKey:NewControlKeyMap]);
/*    commandKeyCode = getcode([info objectForKey:CommandKeyMap]);
    altKeyCode = getcode([info objectForKey:AltKeyMap]);
    shiftKeyCode = getcode([info objectForKey:ShiftKeyMap]);
    controlKeyCode = getcode([info objectForKey:ControlKeyMap]); */
    enc = [info objectForKey:Encodings];
    mask = [[info objectForKey:EnabledEncodings] intValue];
    if((copyrect = [[info objectForKey:CopyRectEnabled] intValue]) != 0) {
        numberOfEnabledEncodings = 1;
        enabledEncodings[0] = rfbEncodingCopyRect;
    } else {
        numberOfEnabledEncodings = 0;
    }
    for(i=0; i<[enc count]; i++) {
        int e = [[enc objectAtIndex:i] intValue];
        if(mask & (1 << e)) {
            enabledEncodings[numberOfEnabledEncodings++] = [ProfileManager encodingValue:e];
        }
    }
    return self;
}

- (void)dealloc
{
    [info release];
    [super dealloc];
}

- (NSString*)profileName
{
    return [info objectForKey:@"ProfileName"];
}

- (float)emulate3ButtonTimeout
{
    return e3btimeout;
}

- (CARD32)commandKeyCode
{
    return commandKeyCode;
}

- (CARD32)altKeyCode
{
    return altKeyCode;
}

- (CARD32)shiftKeyCode
{
    return shiftKeyCode;
}

- (CARD32)controlKeyCode
{
    return controlKeyCode;
}

- (CARD16)numberOfEnabledEncodings
{
    return numberOfEnabledEncodings;
}

- (CARD32)encodingAtIndex:(unsigned)index
{
    return enabledEncodings[index];
}

- (BOOL)useServerNativeFormat
{
    int i = [[info objectForKey:PixelFormat] intValue];

    return (i == 0) ? YES : NO;
}

- (void)getPixelFormat:(rfbPixelFormat*)format
{
    int i = [[info objectForKey:PixelFormat] intValue];

    format->bigEndian = [FrameBuffer bigEndian];
    format->trueColour = YES;
    switch(i) {
        case 0:
            break;
        case 1:
            format->bitsPerPixel = 8;
            format->depth = 8;
            format->redMax = format->greenMax = format->blueMax = 3;
            format->redShift = 6;
            format->greenShift = 4;
            format->blueShift = 2;
            break;
        case 2:
            format->bitsPerPixel = 16;
            format->depth = 16;
            format->redMax = format->greenMax = format->blueMax = 15;
            if(format->bigEndian) {
                format->redShift = 12;
                format->greenShift = 8;
                format->blueShift = 4;
            } else {
                format->redShift = 4;
                format->greenShift = 0;
                format->blueShift = 12;
            }
            break;
        case 3:
            format->bitsPerPixel = 32;
            format->depth = 24;
            format->redMax = format->greenMax = format->blueMax = 255;
            if(format->bigEndian) {
                format->redShift = 24;
                format->greenShift = 16;
                format->blueShift = 8;
            } else {
                format->redShift = 0;
                format->greenShift = 8;
                format->blueShift = 16;
            }
            break;
    }
}

@end
