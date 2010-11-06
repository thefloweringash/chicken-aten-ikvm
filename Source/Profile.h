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
#import "EventFilter.h"
#import "rfbproto.h"

// Encodings
#define NUMENCODINGS					8
extern const unsigned int gEncodingValues[];

struct encoding {
    CARD32  encoding;
    BOOL    enabled;
};

@interface Profile : NSObject
{
    NSString *name;
    BOOL isDefault;
    int pixelFormatIndex;

    int commandKeyPreference;
    int altKeyPreference;
    int shiftKeyPreference;
    int controlKeyPreference;

    // encodings
    CARD16 numberOfEnabledEncodings;
    CARD32 *enabledEncodings; // enabled encodings, including pseudo
    BOOL enableCopyRect;
    int jpegLevel;
    struct encoding *encodings; // all non-pseudo encodings, even disabled
    int numEncodings;

    // emulation
	EventFilterEmulationScenario _buttonEmulationScenario[2];
	unsigned int _clickWhileHoldingModifier[2];
	unsigned int _multiTapModifier[2];
	NSTimeInterval _multiTapDelay[2]; // 0 means double click interval
	unsigned int _multiTapCount[2];
	unsigned int _tapAndClickModifier[2];
	NSTimeInterval _tapAndClickButtonSpeed[2]; // 0 means double click interval
	NSTimeInterval _tapAndClickTimeout[2];

//	BOOL _interpretModifiersLocally;
}

- (id)init;
- (id)initWithDictionary:(NSDictionary*)d name: (NSString *)name;
- (id)initWithProfile: (Profile *)profile andName: (NSString *)aName;
- (void)makeEnabledEncodings;
- (NSDictionary *)dictionary;
- (NSString*)profileName;
- (BOOL)isDefault;

- (CARD32)commandKeyCode;
- (CARD32)altKeyCode;
- (CARD32)shiftKeyCode;
- (CARD32)controlKeyCode;
- (int)commandKeyPreference;
- (int)altKeyPreference;
- (int)shiftKeyPreference;
- (int)controlKeyPreference;
- (int)pixelFormatIndex;
- (CARD16)numberOfEnabledEncodings;
- (CARD32)encodingAtIndex:(unsigned)index;
- (BOOL)enableCopyRect;
- (BOOL)enableJpegEncoding;
- (int)jpegLevel;
- (BOOL)useServerNativeFormat;
- (void)getPixelFormat:(rfbPixelFormat*)format;
- (EventFilterEmulationScenario)button2EmulationScenario;
- (EventFilterEmulationScenario)button3EmulationScenario;
- (unsigned int)clickWhileHoldingModifierForButton: (unsigned int)button;
- (unsigned int)multiTapModifierForButton: (unsigned int)button;
- (NSTimeInterval)multiTapDelayForButton: (unsigned int)button;
- (unsigned int)multiTapCountForButton: (unsigned int)button;
- (unsigned int)tapAndClickModifierForButton: (unsigned int)button;
- (NSTimeInterval)tapAndClickButtonSpeedForButton: (unsigned int)button;
- (NSTimeInterval)tapAndClickTimeoutForButton: (unsigned int)button;
- (BOOL)interpretModifiersLocally;
- (int)numEncodings;
- (NSString *)encodingNameAtIndex: (int)index;
- (BOOL)encodingEnabledAtIndex: (int)index;

- (void)setCommandKeyPreference:(int)pref;
- (void)setAltKeyPreference:(int)pref;
- (void)setShiftKeyPreference:(int)pref;
- (void)setControlKeyPreference:(int)pref;
- (void)setPixelFormatIndex:(int)index;
- (void)setEmulationScenario:(EventFilterEmulationScenario)scenario
                   forButton:(unsigned)button;
- (void)setClickWhileHoldingModifier:(unsigned)modifier
                           forButton:(unsigned)button;
- (void)setMultiTapModifier:(unsigned)modifier forButton:(unsigned)button;
- (void)setMultiTapCount: (unsigned)count forButton:(unsigned)button;
- (void)setMultiTapDelay:(NSTimeInterval)delay forButton:(unsigned) button;
- (void)setTapAndClickModifier:(unsigned)modifer forButton:(unsigned)button;
- (void)setTapAndClickButtonSpeed:(NSTimeInterval)speed
                        forButton:(unsigned)button;
- (void)setTapAndClickTimeout:(NSTimeInterval)timeout
                    forButton:(unsigned)button;
//- (void)setInterpretModifiersLocally:(BOOL)interpretModifiersLocally;
- (void)setEncodingEnabled:(BOOL)enabled atIndex:(int)index;
- (void)moveEncodingFrom:(int)src to:(int)dst;
- (void)setCopyRectEnabled:(BOOL)enabled;
- (void)setJpegEncodingEnabled:(BOOL)enabled;
- (void)setJpegLevel:(int)level;

@end
