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

#import "ProfileManager.h"

#define PROFILES			@"ConnectProfiles"
#define NUMENCODINGS			8

static const NSString* encodingNames[NUMENCODINGS] = {
    @"Tight",
	@"Zlib",
	@"ZRLE",
	@"ZlibHex",
    @"Hextile",
    @"RRE",
    @"CoRRE",
    @"Raw"
};

static const unsigned int encodingValues[NUMENCODINGS] = {
	rfbEncodingTight,
	rfbEncodingZlib,
	rfbEncodingZRLE,
	rfbEncodingZlibHex,
	rfbEncodingHextile,
    rfbEncodingRRE,
    rfbEncodingCoRRE,
    rfbEncodingRaw
};

@implementation ProfileManager

+ (CARD32)encodingValue:(int)index
{
    return encodingValues[index];
}

+ (NSMutableArray*)getEncodings
{
    int i;
    
    NSMutableArray* encodings = [NSMutableArray array];
    for(i=0; i<NUMENCODINGS; i++) {
        [encodings addObject:[NSString stringWithFormat:@"%d", i]];
    }
    return encodings;
}

- (void)wakeup
{    
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    if((profiles = [[ud objectForKey:PROFILES] mutableCopy]) == nil) {
        NSMutableDictionary* def;

        def = [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSString stringWithFormat:@"%d", [[pixelFormatMatrix selectedCell] tag]], PixelFormat,
            [NSString stringWithFormat:@"%d", [enableCopyRect state]], CopyRectEnabled,
            [ProfileManager getEncodings], Encodings,
            [NSString stringWithFormat:@"%d", (1 << NUMENCODINGS) - 1], EnabledEncodings,
            [m3bTimeout stringValue], EmulateThreeButtonTimeout,
            [mkdTimeout stringValue], EmulateKeyDownTimeout,
            [mkbTimeout stringValue], EmulateKeyboardTimeout,
            [NSNumber numberWithShort: [commandKey indexOfSelectedItem]], NewCommandKeyMap,
            [NSNumber numberWithShort: [controlKey indexOfSelectedItem]], NewControlKeyMap,
            [NSNumber numberWithShort: [altKey indexOfSelectedItem]], NewAltKeyMap,
            [NSNumber numberWithShort: [shiftKey indexOfSelectedItem]], NewShiftKeyMap,
            nil];
	profiles = [[NSMutableDictionary alloc] initWithObjectsAndKeys:def, DefaultProfile, nil];
    } else {
        NSString* key;
        NSEnumerator* keys = [profiles keyEnumerator];

        while((key = [keys nextObject]) != nil) {
            NSMutableDictionary* d = [[[profiles objectForKey:key] mutableCopy] autorelease];
            [profiles setObject:d forKey:key];
        }
    }
    [encodingTableView setTarget:self];
    [encodingTableView setDoubleAction:@selector(changeEncodingState:)];
    [self selectProfileNamed:DefaultProfile];
}

- (void)updateBrowserButtons:(id)sender
{
    NSString* sp = [profileField stringValue];

    [deleteProfileButton setEnabled:
        ([profiles objectForKey:sp] && ![sp isEqualToString:DefaultProfile])];
    [newProfileButton setEnabled:
        (![profiles objectForKey:sp] && ![sp isEqualToString:@""])];
}

- (void)updateUpDownButtons:(id)sender
{
    int row = [encodingTableView selectedRow];
    id upb = [upDownButtonMatrix cellAtRow:0 column:0];
    id dnb = [upDownButtonMatrix cellAtRow:1 column:0];

    [upb setEnabled:(row > 0)];
    [dnb setEnabled:((row >= 0) && (row < (NUMENCODINGS-1)))];
}

- (void)upgradeEncodings:(NSMutableDictionary*)d
{
    NSArray* encodings = [d objectForKey:Encodings];

    if([encodings count] != NUMENCODINGS) {
        NSLog(@"supported encodings changed, upgrading profile\n");
        encodings = [ProfileManager getEncodings];
        [d setObject:encodings forKey:Encodings];
    }
}

- (NSMutableDictionary*)currentProfileDictionary
{
    NSMutableDictionary* pd;
    
    NSString* sp = [[profileBrowser selectedCell] stringValue];
    pd = [profiles objectForKey:sp];
    [self upgradeEncodings:pd];
    return pd;
}

- (void)updateProfileInfo:(id)sender
{
    NSDictionary* spd = [self currentProfileDictionary];

    if(spd == nil) {
        return;
    }
    [pixelFormatMatrix selectCellWithTag:[[spd objectForKey:PixelFormat] intValue]];
    [enableCopyRect setState:[[spd objectForKey:CopyRectEnabled] intValue]];
    [m3bTimeout setIntValue:[[spd objectForKey:EmulateThreeButtonTimeout] intValue]];
    [mkdTimeout setIntValue:[[spd objectForKey:EmulateKeyDownTimeout] intValue]];
    [mkbTimeout setIntValue:[[spd objectForKey:EmulateKeyboardTimeout] intValue]];
    
	// jason - changed following to use indices instead of names
    [commandKey selectItemAtIndex:[[spd objectForKey:NewCommandKeyMap] shortValue]];
    [controlKey selectItemAtIndex:[[spd objectForKey:NewControlKeyMap] shortValue]];
    [altKey selectItemAtIndex:[[spd objectForKey:NewAltKeyMap] shortValue]];
    [shiftKey selectItemAtIndex:[[spd objectForKey:NewShiftKeyMap] shortValue]];
/*    [commandKey selectItemWithTitle:[spd objectForKey:CommandKeyMap]];
    [controlKey selectItemWithTitle:[spd objectForKey:ControlKeyMap]];
    [altKey selectItemWithTitle:[spd objectForKey:AltKeyMap]];
    [shiftKey selectItemWithTitle:[spd objectForKey:ShiftKeyMap]]; */
    [encodingTableView reloadData];
}

- (void)selectProfileNamed:(NSString*)aProfile
{
	[profileBrowser loadColumnZero];
	[profileBrowser setPath:[NSString stringWithFormat:@"/%@", aProfile]];
	[profileField setStringValue:aProfile];
	[self updateBrowserButtons:self];
	[self updateProfileInfo:self];
}

- (void)addProfile:(id)sender
{
    NSMutableDictionary* newProfile;

    newProfile = [[[self currentProfileDictionary] mutableCopy] autorelease];
    [profiles setObject:newProfile forKey:[profileField stringValue]];
    [self selectProfileNamed:[profileField stringValue]];
    [self updateBrowserButtons:self];
    [self profileChanged:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:ProfileAddDeleteNotification
                                                        object:self];
}

- (void)changeEncodingState:(id)sender
{
    int row, mask;
    NSArray* enc;
    NSMutableDictionary* profile;

    if((row = [sender selectedRow]) < 0) {
        return;
    }
    profile = [self currentProfileDictionary];
    enc = [profile objectForKey:Encodings];
    row = [[enc objectAtIndex:row] intValue];
    mask = [[profile objectForKey:EnabledEncodings] intValue];
    mask ^= (1 << row);
    [profile setObject:[NSString stringWithFormat:@"%d", mask] forKey:EnabledEncodings];
    [[NSUserDefaults standardUserDefaults] setObject:profiles forKey:PROFILES];
    [encodingTableView reloadData];
}

- (void)deleteProfile:(id)sender
{
    NSString* current = [[profileBrowser selectedCell] stringValue];

    [profiles removeObjectForKey:current];
    [[NSUserDefaults standardUserDefaults] setObject:profiles forKey:PROFILES];
    [self selectProfileNamed:DefaultProfile];
    [[NSNotificationCenter defaultCenter] postNotificationName:ProfileAddDeleteNotification
                                                        object:self];
}

- (void)profileChanged:(id)sender
{
    NSMutableDictionary* profile = [self currentProfileDictionary];

    [profile setObject:[NSString stringWithFormat:@"%d", [[pixelFormatMatrix selectedCell] tag]]
                forKey:PixelFormat];
    [profile setObject:[NSString stringWithFormat:@"%d", [enableCopyRect state]]
                forKey:CopyRectEnabled];
    [profile setObject:[m3bTimeout stringValue] forKey:EmulateThreeButtonTimeout];
    [profile setObject:[mkdTimeout stringValue] forKey:EmulateKeyDownTimeout];
    [profile setObject:[mkbTimeout stringValue] forKey:EmulateKeyboardTimeout];
    
	// Jason - changed from using titleOfSelectedItem to an NSNumber indicating the selected item
    [profile setObject:[NSNumber numberWithShort: [commandKey indexOfSelectedItem]] forKey:NewCommandKeyMap];
    [profile setObject:[NSNumber numberWithShort: [controlKey indexOfSelectedItem]] forKey:NewControlKeyMap];
    [profile setObject:[NSNumber numberWithShort: [altKey indexOfSelectedItem]] forKey:NewAltKeyMap];
    [profile setObject:[NSNumber numberWithShort: [shiftKey indexOfSelectedItem]] forKey:NewShiftKeyMap];
/*    [profile setObject:[commandKey titleOfSelectedItem] forKey:CommandKeyMap];
    [profile setObject:[controlKey titleOfSelectedItem] forKey:ControlKeyMap];
    [profile setObject:[altKey titleOfSelectedItem] forKey:AltKeyMap];
    [profile setObject:[shiftKey titleOfSelectedItem] forKey:ShiftKeyMap]; */
    [[NSUserDefaults standardUserDefaults] setObject:profiles forKey:PROFILES];
}

- (void)profileSelected:(id)sender
{
    id cell = [sender selectedCell];

    if(cell) {
        [profileField setStringValue:[cell stringValue]];
        [self updateBrowserButtons:self];
        [self updateProfileInfo:self];
    }
}

- (void)reorderEncodings:(id)sender
{
    int tag = [[sender selectedCell] tag];
    int row = [encodingTableView selectedRow];
    NSMutableDictionary* profile = [self currentProfileDictionary];
    NSMutableArray* encodings = [[[profile objectForKey:Encodings] mutableCopy] autorelease];

    if(tag == 0) {
        if(row <= 0) {
            return;
        }
        [encodings insertObject:[encodings objectAtIndex:row] atIndex:row - 1];
        [encodings removeObjectAtIndex:row + 1];
        [encodingTableView selectRow:row-1 byExtendingSelection:NO];
        [encodingTableView scrollRowToVisible:row-1];
    } else {
        if((row < 0) || (row >= (NUMENCODINGS - 1))) {
            return;
        }
        [encodings insertObject:[encodings objectAtIndex:row] atIndex:row + 2];
        [encodings removeObjectAtIndex:row];
        [encodingTableView selectRow:row+1 byExtendingSelection:NO];
        [encodingTableView scrollRowToVisible:row+1];
    }
    [profile setObject:encodings forKey:Encodings];
    [[NSUserDefaults standardUserDefaults] setObject:profiles forKey:PROFILES];
    [encodingTableView reloadData];
}

- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column
{
    return [profiles count];
}

- (NSArray*)sortedProfileNames
{
    return [[profiles allKeys] sortedArrayUsingSelector:@selector(compare:)];
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
    NSArray* profileNames = [self sortedProfileNames];

    if(row < [profileNames count]) {
        [cell setLeaf:YES];
        [cell setStringValue:[profileNames objectAtIndex:row]];
    }
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return NUMENCODINGS;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
    NSDictionary* spd = [self currentProfileDictionary];
    NSArray* encodingIndices = [spd objectForKey:Encodings];
    int index;
    
    if(rowIndex >= [encodingIndices count]) {
        return @"";
    }
    index = [[encodingIndices objectAtIndex:rowIndex] intValue];
    if(index >= NUMENCODINGS) {
        return @"";
    }
    if([[aTableColumn identifier] isEqualToString:@"Enabled"]) {
        unsigned int mask = [[spd objectForKey:EnabledEncodings] intValue];
        return (mask & (1 << index)) ? @"YES" : @"NO";
    } else {
        return (id)encodingNames[index];
    }
}

- (void)windowWillClose:(NSNotification *)aNotification
{
}

- (void)windowDidUpdate:(NSNotification *)aNotification
{
    [self updateBrowserButtons:self];
    [self updateUpDownButtons:self];
}

- (Profile*)profileNamed:(NSString*)name
{
    NSMutableDictionary* p = [profiles objectForKey:name];

    if(p == nil) {
        p = [profiles objectForKey:DefaultProfile];
        [p setObject:DefaultProfile forKey:@"ProfileName"];
    } else {
        [p setObject:name forKey:@"ProfileName"];
    }
    return [[[Profile alloc] initWithDictionary:p] autorelease];
}

- (NSArray*)profileNames
{
    NSMutableArray* n = [[[[profiles allKeys] sortedArrayUsingSelector:@selector(compare:)] mutableCopy] autorelease];
    if(n == nil) {
        n = [NSMutableArray array];
    }
    if(![n containsObject:DefaultProfile]) {
        [n insertObject:DefaultProfile atIndex:0];
    } else {
        unsigned int idx = [n indexOfObject:DefaultProfile];
        if(idx > 0) {
            [n removeObjectAtIndex:idx];
            [n insertObject:DefaultProfile atIndex:0];
        }
    }
    return n;
}

@end
