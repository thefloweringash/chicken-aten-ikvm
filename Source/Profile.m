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
#import "FrameBufferUpdateReader.h"
#import <Carbon/Carbon.h>
#define XK_MISCELLANY
#include <X11/keysymdef.h>

#define INTERPRET_LOCALLY_PREFERENCE 6

const unsigned int gEncodingValues[NUMENCODINGS] = {
	rfbEncodingZRLE,
	rfbEncodingTight,
	rfbEncodingZlib,
	rfbEncodingZlibHex,
	rfbEncodingHextile,
    rfbEncodingCoRRE,
    rfbEncodingRRE,
    rfbEncodingRaw
};


static NSTimeInterval
DoubleClickInterval()
{
	SInt16 ticks = LMGetKeyThresh();
	return (NSTimeInterval)ticks * 1.0/60.0;
}


static inline unsigned int
ButtonNumberToArrayIndex( unsigned int buttonNumber )
{
	NSCParameterAssert( buttonNumber == 2 || buttonNumber == 3 );
	return buttonNumber - 2;
}


@implementation Profile

- (void)defaultEmulationScenarios
{
    _buttonEmulationScenario[0] = kNoMouseButtonEmulation;
    _buttonEmulationScenario[1] = kClickWhileHoldingModifierEmulation;
    _clickWhileHoldingModifier[0] = NSControlKeyMask;
    _clickWhileHoldingModifier[1] = NSControlKeyMask;
    _multiTapModifier[0] = NSCommandKeyMask;
    _multiTapModifier[1] = NSCommandKeyMask;
    _multiTapDelay[0] = 0.0;
    _multiTapDelay[1] = 0.0;
    _multiTapCount[0] = 2;
    _multiTapCount[1] = 2;
    _tapAndClickModifier[0] = NSAlternateKeyMask;
    _tapAndClickModifier[1] = NSShiftKeyMask;
    _tapAndClickButtonSpeed[0] = 0.0;
    _tapAndClickButtonSpeed[1] = 0.0;
    _tapAndClickTimeout[0] = 5.0;
    _tapAndClickTimeout[1] = 5.0;
}

// create the default profile
- (id)init
{
    if (self = [super init]) {
        int     i;

        name = [NSLocalizedString(@"defaultProfileName", nil) retain];
        isDefault = YES;

        commandKeyPreference = kRemoteAltModifier;
        altKeyPreference =  kRemoteMetaModifier;
        shiftKeyPreference = kRemoteShiftModifier;
        controlKeyPreference = kRemoteControlModifier;
        enableCopyRect = YES;
        jpegLevel = 6;
        numEncodings = NUMENCODINGS;
        encodings = (struct encoding*)malloc(NUMENCODINGS * sizeof(*encodings));
        for ( i = 0; i < NUMENCODINGS; ++i ) {
            encodings[i].encoding = gEncodingValues[i];
            encodings[i].enabled = YES;
        }
        [self makeEnabledEncodings];

        [self defaultEmulationScenarios];

        //_interpretModifiersLocally = NO;
        pixelFormatIndex = 0;
    }
    return self;
}

/* Initialize profile from saved dictionary */
- (id)initWithDictionary:(NSDictionary*)info name: (NSString *)aName
{
    if (self = [super init]) {
		NSArray* enc;
		int i;

        name = [aName retain];
        isDefault = [[info objectForKey:kProfile_IsDefault_Key] boolValue];
		
        commandKeyPreference = [[info objectForKey: kProfile_LocalCommandModifier_Key]
                                intValue];
        
        altKeyPreference = [[info objectForKey: kProfile_LocalAltModifier_Key]
                                intValue];
        
        shiftKeyPreference = [[info objectForKey: kProfile_LocalShiftModifier_Key]
                                intValue];
        
        controlKeyPreference = [[info objectForKey: kProfile_LocalControlModifier_Key]
                                intValue];
		
        id obj = [info objectForKey: kProfile_JpegQualityLevel_Key];
        if (obj) {
            jpegLevel = [obj intValue];
        } else {
            obj = [info objectForKey: kProfile_EnableJpegEncoding_Key];
            if (obj == nil || [obj boolValue])
                jpegLevel = 6;
            else
                jpegLevel = -1;
        }
        enableCopyRect = [[info objectForKey: kProfile_EnableCopyrect_Key]
                                    boolValue];

		enc = [info objectForKey: kProfile_Encodings_Key];
        numEncodings = [enc count];
        encodings = (struct encoding*)malloc(numEncodings * sizeof(*encodings));
        for (i = 0; i < numEncodings; i++) {
            NSDictionary *e = [enc objectAtIndex:i];
            encodings[i].encoding = [[e objectForKey:kProfile_EncodingValue_Key]
                                            intValue];
            encodings[i].enabled = [[e objectForKey:kProfile_EncodingEnabled_Key]
                                            boolValue];
        }

        [self makeEnabledEncodings];
		
        if ([info objectForKey:kProfile_Button2EmulationScenario_Key]) {
            _buttonEmulationScenario[0] = (EventFilterEmulationScenario)[[info objectForKey: kProfile_Button2EmulationScenario_Key] intValue];
            
            _buttonEmulationScenario[1] = (EventFilterEmulationScenario)[[info objectForKey: kProfile_Button3EmulationScenario_Key] intValue];
            
            _clickWhileHoldingModifier[0] = [[info objectForKey: kProfile_ClickWhileHoldingModifierForButton2_Key] unsignedIntValue];
            
            _clickWhileHoldingModifier[1] = [[info objectForKey: kProfile_ClickWhileHoldingModifierForButton3_Key] unsignedIntValue];
            
            _multiTapModifier[0] = [[info objectForKey: kProfile_MultiTapModifierForButton2_Key] unsignedIntValue];
            
            _multiTapModifier[1] = [[info objectForKey: kProfile_MultiTapModifierForButton3_Key] unsignedIntValue];
            
            _multiTapDelay[0] = (NSTimeInterval)[[info objectForKey: kProfile_MultiTapDelayForButton2_Key] doubleValue];
        //	if ( 0.0 == _multiTapDelay[0] )
        //		_multiTapDelay[0] = DoubleClickInterval();
            
            _multiTapDelay[1] = (NSTimeInterval)[[info objectForKey: kProfile_MultiTapDelayForButton3_Key] doubleValue];
    //		if ( 0.0 == _multiTapDelay[1] )
    //			_multiTapDelay[1] = DoubleClickInterval();
            
            _multiTapCount[0] = [[info objectForKey: kProfile_MultiTapCountForButton2_Key] unsignedIntValue];
            
            _multiTapCount[1] = [[info objectForKey: kProfile_MultiTapCountForButton3_Key] unsignedIntValue];
            
            _tapAndClickModifier[0] = [[info objectForKey: kProfile_TapAndClickModifierForButton2_Key] unsignedIntValue];
            
            _tapAndClickModifier[1] = [[info objectForKey: kProfile_TapAndClickModifierForButton3_Key] unsignedIntValue];
            
            _tapAndClickButtonSpeed[0] = (NSTimeInterval)[[info objectForKey: kProfile_TapAndClickButtonSpeedForButton2_Key] doubleValue];
    //		if ( 0.0 == _tapAndClickButtonSpeed[0] )
    //			_tapAndClickButtonSpeed[0] = DoubleClickInterval();
            
            _tapAndClickButtonSpeed[1] = (NSTimeInterval)[[info objectForKey: kProfile_TapAndClickButtonSpeedForButton3_Key] doubleValue];
    //		if ( 0.0 == _tapAndClickButtonSpeed[1] )
    //			_tapAndClickButtonSpeed[1] = DoubleClickInterval();
            
            _tapAndClickTimeout[0] = (NSTimeInterval)[[info objectForKey: kProfile_TapAndClickTimeoutForButton2_Key] doubleValue];
            
            _tapAndClickTimeout[1] = (NSTimeInterval)[[info objectForKey: kProfile_TapAndClickTimeoutForButton3_Key] doubleValue];
        } else {
            [self defaultEmulationScenarios];
        }
		
        //_interpretModifiersLocally = [[info objectForKey: kProfile_InterpretModifiersLocally_Key] boolValue];

        pixelFormatIndex = [[info objectForKey: kProfile_PixelFormat_Key]
                                intValue];
	}
    return self;
}

/* Initialize profile as copy of other profile */
- (id)initWithProfile: (Profile *)profile andName: (NSString *)aName
{
    if (self = [super init]) {
        int     i;

        name = [aName retain];
        isDefault = NO;
        pixelFormatIndex = profile->pixelFormatIndex;

        commandKeyPreference = profile->commandKeyPreference;
        altKeyPreference = profile->altKeyPreference;
        shiftKeyPreference = profile->shiftKeyPreference;
        controlKeyPreference = profile->controlKeyPreference;

        numEncodings = profile->numEncodings;
        encodings = (struct encoding*)malloc(numEncodings * sizeof(*encodings));
        memcpy(encodings, profile->encodings, numEncodings *sizeof(*encodings));
        enableCopyRect = profile->enableCopyRect;
        jpegLevel = profile->jpegLevel;
        [self makeEnabledEncodings];

        for (i = 0; i < 2; i++) {
            _buttonEmulationScenario[i] = profile->_buttonEmulationScenario[i];
            _clickWhileHoldingModifier[i] = profile->_clickWhileHoldingModifier[i];
            _multiTapModifier[i] = profile->_multiTapModifier[i];
            _multiTapDelay[i] = profile->_multiTapDelay[i];
            _multiTapCount[i] = profile->_multiTapCount[i];
            _tapAndClickModifier[i] = profile->_tapAndClickModifier[i];
            _tapAndClickButtonSpeed[i] = profile->_tapAndClickButtonSpeed[i];
            _tapAndClickTimeout[i] = profile->_tapAndClickTimeout[i];
        }

        //_interpretModifiersLocally = profile->_interpretModifiersLocally;
    }
    return self;
}

- (void)dealloc
{
    [name release];
    free(encodings);
    if (enabledEncodings)
        free(enabledEncodings);
    [super dealloc];
}

#define NUM_INTERACTIVE_PSEUDOS 2

/* Makes list of encodings and pseudo-encodings which gets sent to server */
- (void)makeEnabledEncodings
{
    int     i;
    CARD32  pseudoEncodings[] = {rfbEncodingDesktopName, rfbEncodingLastRect,
        rfbEncodingDesktopSize,
        // The last NUM_INTERACTIVE_PSEUDOS are not used for view-only
        // connections.
        rfbEncodingPointerPos, rfbEncodingRichCursor};
    int     numPseudos = sizeof(pseudoEncodings)/sizeof(*pseudoEncodings);

    if (enabledEncodings)
        free(enabledEncodings);
            // + 2 for CopyRect and Jpeg quality level
    enabledEncodings = (CARD32 *)malloc((numEncodings + numPseudos + 2) * sizeof(CARD32));
    numberOfEnabledEncodings = 0;

    // User-specified list of encodings
    if (enableCopyRect) 
        enabledEncodings[numberOfEnabledEncodings++] = rfbEncodingCopyRect;
    for(i=0; i<numEncodings; i++) {
        if (encodings[i].enabled) {
            CARD32 encoding = encodings[i].encoding;
            enabledEncodings[numberOfEnabledEncodings++] = encoding;
            if (encoding == rfbEncodingTight && jpegLevel >= 0)
                enabledEncodings[numberOfEnabledEncodings++]
                    = rfbEncodingQualityLevel0 + jpegLevel;
        }
    }

    // Fixed pseudo-encodings, which we always support
    memcpy(enabledEncodings + numberOfEnabledEncodings, pseudoEncodings,
            numPseudos * sizeof(CARD32));
    numberOfEnabledEncodings += numPseudos;
}


- (NSDictionary *)dictionary
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    int i;

    if (isDefault)
        [dict setObject:[NSNumber numberWithBool:YES]
                 forKey:kProfile_IsDefault_Key];

    // modifier keys
    [dict setObject:[NSNumber numberWithInt:commandKeyPreference]
             forKey:kProfile_LocalCommandModifier_Key];
    [dict setObject:[NSNumber numberWithInt:altKeyPreference]
             forKey:kProfile_LocalAltModifier_Key];
    [dict setObject:[NSNumber numberWithInt:shiftKeyPreference]
             forKey:kProfile_LocalShiftModifier_Key];
    [dict setObject:[NSNumber numberWithInt:controlKeyPreference]
             forKey:kProfile_LocalControlModifier_Key];

    // encodings
    [dict setObject:[NSNumber numberWithInt:jpegLevel]
             forKey:kProfile_JpegQualityLevel_Key];
    [dict setObject:[NSNumber numberWithBool:enableCopyRect]
             forKey:kProfile_EnableCopyrect_Key];
    NSMutableArray  *enc = [[NSMutableArray alloc] init];
    for (i = 0; i < numEncodings; i++) {
        NSMutableDictionary *e = [[NSMutableDictionary alloc] init];
        [e setObject:[NSNumber numberWithUnsignedInt:encodings[i].encoding]
              forKey:kProfile_EncodingValue_Key];
        [e setObject:[NSNumber numberWithBool:encodings[i].enabled]
              forKey:kProfile_EncodingEnabled_Key];
        [enc addObject:e];
        [e release];
    }
    [dict setObject:enc forKey:kProfile_Encodings_Key];
    [enc release];
    
    // mouse emulation
    [dict setObject:[NSNumber numberWithInt:_buttonEmulationScenario[0]]
             forKey:kProfile_Button2EmulationScenario_Key];
    [dict setObject:[NSNumber numberWithInt:_buttonEmulationScenario[1]]
             forKey:kProfile_Button3EmulationScenario_Key];
    [dict setObject:[NSNumber numberWithUnsignedInt:_clickWhileHoldingModifier[0]]
             forKey:kProfile_ClickWhileHoldingModifierForButton2_Key];
    [dict setObject:[NSNumber numberWithUnsignedInt:_clickWhileHoldingModifier[1]]
             forKey:kProfile_ClickWhileHoldingModifierForButton3_Key];
    [dict setObject:[NSNumber numberWithUnsignedInt:_multiTapModifier[0]]
             forKey:kProfile_MultiTapModifierForButton2_Key];
    [dict setObject:[NSNumber numberWithUnsignedInt:_multiTapModifier[1]]
             forKey:kProfile_MultiTapModifierForButton3_Key];
    [dict setObject:[NSNumber numberWithDouble:_multiTapDelay[0]]
             forKey:kProfile_MultiTapDelayForButton2_Key];
    [dict setObject:[NSNumber numberWithDouble:_multiTapDelay[1]]
             forKey:kProfile_MultiTapDelayForButton3_Key];
    [dict setObject:[NSNumber numberWithUnsignedInt:_multiTapCount[0]]
             forKey:kProfile_MultiTapCountForButton2_Key];
    [dict setObject:[NSNumber numberWithUnsignedInt:_multiTapCount[1]]
             forKey:kProfile_MultiTapCountForButton3_Key];
    [dict setObject:[NSNumber numberWithUnsignedInt:_tapAndClickModifier[0]]
             forKey:kProfile_TapAndClickModifierForButton2_Key];
    [dict setObject:[NSNumber numberWithUnsignedInt:_tapAndClickModifier[1]]
             forKey:kProfile_TapAndClickModifierForButton3_Key];
    [dict setObject:[NSNumber numberWithDouble:_tapAndClickButtonSpeed[0]]
             forKey:kProfile_TapAndClickButtonSpeedForButton2_Key];
    [dict setObject:[NSNumber numberWithDouble:_tapAndClickButtonSpeed[1]]
             forKey:kProfile_TapAndClickButtonSpeedForButton3_Key];
    [dict setObject:[NSNumber numberWithDouble:_tapAndClickTimeout[0]]
             forKey:kProfile_TapAndClickTimeoutForButton2_Key];
    [dict setObject:[NSNumber numberWithDouble:_tapAndClickTimeout[1]]
             forKey:kProfile_TapAndClickTimeoutForButton3_Key];

    //[dict setObject:[NSNumber numberWithBool:_interpretModifiersLocally]
     //        forKey:kProfile_InterpretModifiersLocally_Key];
    [dict setObject:[NSNumber numberWithInt:pixelFormatIndex]
             forKey:kProfile_PixelFormat_Key];

    return [dict autorelease];
}


- (NSString*)profileName
{
    return name;
}

- (BOOL)isDefault
{
    return isDefault;
}

- (CARD32)modifierCodeForPreference: (int)pref
{
    CARD32 modifierKeyCodes[] = {XK_Alt_L, XK_Meta_L, XK_Control_L,
        XK_Shift_L, XK_Super_L, XK_VoidSymbol, XK_VoidSymbol};

    if (pref >= 0 && pref < sizeof(modifierKeyCodes) / sizeof(CARD32))
        return modifierKeyCodes[pref];
    else {
        NSLog(@"Invalid modifier code: %d", pref);
        return XK_VoidSymbol;
    }
}

- (CARD32)commandKeyCode
{
    return [self modifierCodeForPreference:commandKeyPreference];
}

- (CARD32)altKeyCode
{
    return [self modifierCodeForPreference:altKeyPreference];
}

- (CARD32)shiftKeyCode
{
    return [self modifierCodeForPreference:shiftKeyPreference];
}

- (CARD32)controlKeyCode
{
    return [self modifierCodeForPreference:controlKeyPreference];
}

- (int)commandKeyPreference
{
    return commandKeyPreference;
}

- (int)altKeyPreference
{
    return altKeyPreference;
}

- (int)shiftKeyPreference
{
    return shiftKeyPreference;
}

- (int)controlKeyPreference
{
    return controlKeyPreference;
}

- (int)pixelFormatIndex
{
    return pixelFormatIndex;
}

- (CARD16)numEnabledEncodingsIfViewOnly:(BOOL)viewOnly
{
    if (viewOnly)
        return numberOfEnabledEncodings - NUM_INTERACTIVE_PSEUDOS;
    else
        return numberOfEnabledEncodings;
}

- (CARD32)encodingAtIndex:(unsigned)index
{
    return enabledEncodings[index];
}

- (BOOL)enableCopyRect
{
    return enableCopyRect;
}

- (BOOL)enableJpegEncoding
{
    return jpegLevel >= 0;
}

- (int)jpegLevel
{
    return jpegLevel;
}

- (BOOL)useServerNativeFormat
{
    return (pixelFormatIndex == 0) ? YES : NO;
}

- (void)getPixelFormat:(rfbPixelFormat*)format
{
    format->bigEndian = [FrameBuffer bigEndian];
    format->trueColour = YES;
    switch(pixelFormatIndex) {
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
                format->redShift = 16;
                format->greenShift = 8;
                format->blueShift = 0;
            } else {
                format->redShift = 0;
                format->greenShift = 8;
                format->blueShift = 16;
            }
            break;
    }
}

- (EventFilterEmulationScenario)button2EmulationScenario
{  return _buttonEmulationScenario[ButtonNumberToArrayIndex(2)];  }

- (EventFilterEmulationScenario)button3EmulationScenario
{  return _buttonEmulationScenario[ButtonNumberToArrayIndex(3)];  }

- (unsigned int)clickWhileHoldingModifierForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	return _clickWhileHoldingModifier[buttonIndex];
}

- (unsigned int)multiTapModifierForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	return _multiTapModifier[buttonIndex];
}

- (NSTimeInterval)multiTapDelayForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
    if (_multiTapDelay[buttonIndex] == 0.0)
        return DoubleClickInterval();
    else
        return _multiTapDelay[buttonIndex];
}

- (unsigned int)multiTapCountForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	return _multiTapCount[buttonIndex];
}

- (unsigned int)tapAndClickModifierForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	return _tapAndClickModifier[buttonIndex];
}

- (NSTimeInterval)tapAndClickButtonSpeedForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
    if (_tapAndClickButtonSpeed[buttonIndex] == 0.0)
        return DoubleClickInterval();
    else
        return _tapAndClickButtonSpeed[buttonIndex];
}

- (NSTimeInterval)tapAndClickTimeoutForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	return _tapAndClickTimeout[buttonIndex];
}

- (BOOL)interpretModifiersLocally
{
	return altKeyPreference == INTERPRET_LOCALLY_PREFERENCE; //_interpretModifiersLocally;
}

- (int)numEncodings
{
    return numEncodings;
}

- (NSString *)encodingNameAtIndex: (int)index
{
    CARD32  encoding = encodings[index].encoding;

    if (encoding <= rfbEncodingMax)
        return encodingNames[encoding];
    else
        return @"";
}

- (BOOL)encodingEnabledAtIndex: (int)index
{
    return encodings[index].enabled;
}

- (void)setCommandKeyPreference:(int)pref
{
    commandKeyPreference = pref;
}

- (void)setAltKeyPreference:(int)pref
{
    altKeyPreference = pref;
}

- (void)setShiftKeyPreference:(int)pref
{
    shiftKeyPreference = pref;
}

- (void)setControlKeyPreference:(int)pref
{
    controlKeyPreference = pref;
}

- (void)setPixelFormatIndex:(int)index
{
    pixelFormatIndex = index;
}

- (void)setEmulationScenario:(EventFilterEmulationScenario)scenario
                   forButton:(unsigned)button;
{
    unsigned    index = ButtonNumberToArrayIndex(button);
    _buttonEmulationScenario[index] = scenario;
}

- (void)setClickWhileHoldingModifier:(unsigned)modifier
                           forButton:(unsigned)button
{
    _clickWhileHoldingModifier[ButtonNumberToArrayIndex(button)] = modifier;
}

- (void)setMultiTapModifier:(unsigned)modifier forButton:(unsigned)button
{
    _multiTapModifier[ButtonNumberToArrayIndex(button)] = modifier;
}

- (void)setMultiTapCount:(unsigned)count forButton:(unsigned)button
{
    _multiTapCount[ButtonNumberToArrayIndex(button)] = count;
}

- (void)setMultiTapDelay:(NSTimeInterval)delay forButton:(unsigned) button
{
    unsigned    index = ButtonNumberToArrayIndex(button);
    _multiTapDelay[index] = delay;
}

- (void)setTapAndClickModifier:(unsigned)modifier forButton:(unsigned)button
{
    _tapAndClickModifier[ButtonNumberToArrayIndex(button)] = modifier;
}

- (void)setTapAndClickButtonSpeed:(NSTimeInterval)speed
                        forButton:(unsigned)button
{
    unsigned    index = ButtonNumberToArrayIndex(button);
    _tapAndClickButtonSpeed[index] = speed;
}

- (void)setTapAndClickTimeout:(NSTimeInterval)timeout forButton:(unsigned)button
{
    unsigned    index = ButtonNumberToArrayIndex(button);
    _tapAndClickTimeout[index] = timeout;
}

#if 0
- (void)setInterpretModifiersLocally:(BOOL)interpretModifiersLocally
{
    //_interpretModifiersLocally = interpretModifiersLocally;
}
#endif

- (void)setEncodingEnabled:(BOOL)enabled atIndex:(int)index
{
    if (index >= 0 && index < numEncodings)
        encodings[index].enabled = enabled;
    else
        NSLog(@"Bad encoding index: %d", index);
    [self makeEnabledEncodings];
}

/* Reorders the encodings so that the one at src is now at dst, and the relative
 * order of the others is unchanged. Note that the index dst is counted
 * including the encoding being at src. */
- (void)moveEncodingFrom:(int)src to:(int)dst
{
    struct encoding e = encodings[src];
    if (src > dst) 
        memmove(encodings + dst + 1, encodings + dst,
                (src - dst) * sizeof(struct encoding));
    else {
        dst--;
        memmove(encodings + src, encodings + src + 1,
                (dst - src) * sizeof(struct encoding));
    }
    encodings[dst] = e;
    [self makeEnabledEncodings];
}

- (void)setCopyRectEnabled:(BOOL)enabled
{
    enableCopyRect = enabled;
    [self makeEnabledEncodings];
}

- (void)setJpegEncodingEnabled:(BOOL)enabled
{
    if (!enabled)
        [self setJpegLevel: -1];
    else if (jpegLevel < 0)
        [self setJpegLevel: 6];
}

- (void)setJpegLevel: (int)level
{
    jpegLevel = level;
    [self makeEnabledEncodings];
}

@end
