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
#import "Profile.h"

#define DefaultProfile			@"default"
#define ProfileAddDeleteNotification	@"ProfileAddedOrDeleted"
#define PixelFormat			@"PixelFormat"
#define CopyRectEnabled			@"EnableCopyRect"
#define Encodings			@"Encodings"
#define EnabledEncodings                @"EnabledEncodings"
#define EmulateThreeButtonTimeout	@"E3BTimeout"
#define EmulateKeyDownTimeout           @"MKDTimeout"
#define EmulateKeyboardTimeout          @"EKBTimeout"
#define CommandKeyMap			@"CommandKey"
#define ShiftKeyMap			@"ShiftKey"
#define AltKeyMap			@"AltKey"
#define ControlKeyMap			@"ControlKey"
// Jason added the following mappings so we can use indices instead of titles
#define NewCommandKeyMap	@"NewCommandKey"
#define NewShiftKeyMap		@"NewShiftKey"
#define NewAltKeyMap		@"NewAltKey"
#define NewControlKeyMap	@"NewControlKey"

@interface ProfileManager : NSObject
{
    id altKey;
    id commandKey;
    id controlKey;
    id deleteProfileButton;
    id enableCopyRect;
    id encodingTableView;
    id m3bTimeout;
    id mkdTimeout;
    id mkbTimeout;
    id newProfileButton;
    id pixelFormatMatrix;
    id profileBrowser;
    id profileField;
    id profilePanel;
    id shiftKey;
    id upDownButtonMatrix;

    NSMutableDictionary*		profiles;
}

+ (CARD32)encodingValue:(int)index;
+ (NSMutableArray*)getEncodings;

- (void)wakeup;
- (void)addProfile:(id)sender;
- (void)changeEncodingState:(id)sender;
- (void)deleteProfile:(id)sender;
- (void)profileChanged:(id)sender;
- (void)profileSelected:(id)sender;
- (void)reorderEncodings:(id)sender;
- (void)selectProfileNamed:(NSString*)aProfile;

- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column;
- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column;

- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex;

- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidUpdate:(NSNotification *)aNotification;

- (Profile*)profileNamed:(NSString*)name;
- (NSArray*)profileNames;

@end
