/* Profile.h created by helmut on Fri 25-Jun-1999 */

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
#import "rfbproto.h"

// Jason added the following constants that represent the different possible modifier key popup choices
typedef enum {
	kCommmandKeyPopupIndex	= 0,
	kOptionKeyPopupIndex	= 1,
	kControlKeyPopupIndex	= 2,
	kShiftKeyPopupIndex		= 3, 
	kWindowsKeyPopupIndex		= 4
} ModifierKeyIndex;

#define kMetaKeyCode 0xffe7
#define kControlKeyCode 0xffe3
#define kAltKeyCode 0xffe9
#define kShiftKeyCode 0xffe1
#define kWindowsKeyCode 0xffeb

// end of Jason's addition

@interface Profile : NSObject
{
    NSMutableDictionary* info;
    float e3btimeout;
    CARD32 commandKeyCode, altKeyCode, shiftKeyCode, controlKeyCode;
    CARD16 numberOfEnabledEncodings;
    CARD32 enabledEncodings[20];
}

- (id)initWithDictionary:(NSDictionary*)d;
- (float)emulate3ButtonTimeout;
- (CARD32)commandKeyCode;
- (CARD32)altKeyCode;
- (CARD32)shiftKeyCode;
- (CARD32)controlKeyCode;
- (CARD16)numberOfEnabledEncodings;
- (CARD32)encodingAtIndex:(unsigned)index;
- (BOOL)useServerNativeFormat;
- (void)getPixelFormat:(rfbPixelFormat*)format;
- (NSString*)profileName;

@end
