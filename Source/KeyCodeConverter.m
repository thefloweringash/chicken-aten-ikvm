/* KeyCodeConverter.m created by helmut on Thu 24-Jun-1999 */

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

#import "KeyCodeConverter.h"

/* --------------------------------------------------------------------------------- */
static NSMapTable*	keyCodeToUni = NULL;

static NSMapTableKeyCallBacks	kcc_kc = {
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        (void*)0x7fffffff
};

static NSMapTableValueCallBacks	kcc_vc = {
        NULL,
        NULL,
        NULL
};

/* --------------------------------------------------------------------------------- */

@implementation KeyCodeConverter

+ (void)save
{
    NSFileManager* fman = [NSFileManager defaultManager];

// Jason changed the path from ~/.AppInfo/VNCViewer to ~/Library/Preferences/Chicken of the VNC
	NSString* p = [@"~/Library/Preferences/Chicken of the VNC" stringByExpandingTildeInPath];
//	NSString* p = [@"~/.AppInfo/VNCViewer" stringByExpandingTildeInPath];
    NSMutableDictionary* d = [NSMutableDictionary dictionary];
    void* key, *value;
    BOOL isdir;
    
    NSMapEnumerator me = NSEnumerateMapTable(keyCodeToUni);
    while(NSNextMapEnumeratorPair(&me, &key, &value)) {
        [d setObject:[NSString stringWithFormat:@"%u", (unsigned int)value]
              forKey:[NSString stringWithFormat:@"%u", (unsigned int)key]];
    }
    if(![fman fileExistsAtPath:p isDirectory:&isdir]) {
        [fman createDirectoryAtPath:p attributes:nil];
    }
    p = [p stringByAppendingString:@"/AutoKeyCodes"];
    [d writeToFile:p atomically:YES];
}

+ (void)loadKeyCodes
{
    BOOL isdir;
    NSFileManager* fman = [NSFileManager defaultManager];
	// Jason changed path from ~/.AppInfo/VNCViewer/AutoKeyCodes to ~/Library/Preferences/Chicken of the VNC/AutoKeyCodes
    NSString* p = [@"~/Library/Preferences/Chicken of the VNC/AutoKeyCodes" stringByExpandingTildeInPath];
//    NSString* p = [@"~/.AppInfo/VNCViewer/AutoKeyCodes" stringByExpandingTildeInPath];
    
    if([fman fileExistsAtPath:p isDirectory:&isdir]) {
        if(!isdir) {
            NSString* key, *value;
            NSDictionary* d = [[NSDictionary alloc] initWithContentsOfFile:p];
            NSEnumerator* e = [d keyEnumerator];

            while((key = [e nextObject]) != nil) {
                value = [d objectForKey:key];
                NSMapInsertKnownAbsent(keyCodeToUni, (const void*)[key intValue],
                                       (const void*)[value intValue]);
            }
        }
    }
}

+ (void)initialize
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    keyCodeToUni = NSCreateMapTable(kcc_kc, kcc_vc, 1024);
    [self loadKeyCodes];
    [pool release];
}

+ (BOOL)keyCodeIsKnown:(unsigned int)keyCode
{
    void* keyDummy, *valueDummy;
    
    return NSMapMember(keyCodeToUni, (const void*)keyCode, &keyDummy, &valueDummy);
}

+ (void)registerUnichar:(unichar)theChar forCode:(unsigned short)keyCode modifiers:(unsigned int)mod
{
    unsigned int i, j;

    if((mod & (NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask)) != 0) {
        return;
    }
    i = (unsigned int)keyCode;
    if(mod & NSShiftKeyMask) {
        i |= 0x10000;
    }
    if([self keyCodeIsKnown:i]) {
        return;
    }
    j = (unsigned int)theChar;
    NSMapInsertKnownAbsent(keyCodeToUni, (const void*)i, (const void*)j);
    [self save];
}

+ (unichar)uniFromKeyCode:(unsigned short)keyCode modifiers:(unsigned int)mod
{
    unsigned int i;

    i = (unsigned int)keyCode;
    if(mod & NSShiftKeyMask) {
        i |= 0x10000;
    }
    i = (int)NSMapGet(keyCodeToUni, (const void*)i);
    return (unichar)i;
}

@end
