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
#import "NSObject_Chicken.h"
#import "ProfileManager.h"
#import "FrameBuffer.h"

@implementation Profile

- (id)initWithDictionary:(NSDictionary*)d name: (NSString *)name
{
    if (self = [super init]) {
		NSArray* enc;
		int i;

		info = [[d deepMutableCopy] retain];
		[info setObject: name forKey: @"ProfileName"];
		
		// we're guaranteed that all keys are present
		e3btimeout = [[info objectForKey:kProfile_E3BTimeout_Key] intValue];
		e3btimeout /= 1000.0;

		ekdtimeout = [[info objectForKey:kProfile_EmulateKeyDown_Key] intValue];
		ekdtimeout /= 1000.0;

		ekbtimeout = [[info objectForKey:kProfile_EmulateKeyboard_Key] intValue];
                
		commandKeyCode = [ProfileManager modifierCodeForPreference: 
			[info objectForKey: kProfile_LocalCommandModifier_Key]];
		
		altKeyCode = [ProfileManager modifierCodeForPreference: 
			[info objectForKey: kProfile_LocalAltModifier_Key]];
		
		shiftKeyCode = [ProfileManager modifierCodeForPreference: 
			[info objectForKey: kProfile_LocalShiftModifier_Key]];
		
		controlKeyCode = [ProfileManager modifierCodeForPreference: 
			[info objectForKey: kProfile_LocalControlModifier_Key]];
		
		enc = [info objectForKey: kProfile_Encodings_Key];
		if( YES == [[info objectForKey: kProfile_EnableCopyrect_Key] boolValue] ) {
			numberOfEnabledEncodings = 1;
			enabledEncodings[0] = rfbEncodingCopyRect;
		} else {
			numberOfEnabledEncodings = 0;
		}
		for(i=0; i<[enc count]; i++) {
			NSDictionary *e = [enc objectAtIndex:i];
			if ( [[e objectForKey: kProfile_EncodingEnabled_Key] boolValue] )
				enabledEncodings[numberOfEnabledEncodings++] = [[e objectForKey: kProfile_EncodingValue_Key] intValue];
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

- (float)emulateKeyDownTimeout
{
    return ekdtimeout;
}

- (float)emulateKeyboardTimeout
{
    return ekbtimeout;
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
    int i = [[info objectForKey: kProfile_PixelFormat_Key] intValue];

    return (i == 0) ? YES : NO;
}

- (void)getPixelFormat:(rfbPixelFormat*)format
{
    int i = [[info objectForKey: kProfile_PixelFormat_Key] intValue];

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
