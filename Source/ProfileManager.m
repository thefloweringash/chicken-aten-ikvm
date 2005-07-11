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
#import "NSObject_Chicken.h"
#import "ProfileManager_private.h"
#import "ProfileDataManager.h"


static const NSString* gEncodingNames[NUMENCODINGS] = {
	@"ZRLE",
    @"Tight",
	@"Zlib",
	@"ZlibHex",
    @"Hextile",
    @"CoRRE",
    @"RRE",
    @"Raw"
};


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


// --- Dictionary Keys --- //
NSString *kProfile_PixelFormat_Key = @"PixelFormat";
NSString *kProfile_EnableCopyrect_Key = @"EnableCopyRect";
NSString *kProfile_Encodings_Key = @"Encodings";
NSString *kProfile_EncodingValue_Key = @"ID";
NSString *kProfile_EncodingEnabled_Key = @"Enabled";
NSString *kProfile_LocalAltModifier_Key = @"NewAltKey";
NSString *kProfile_LocalCommandModifier_Key = @"NewCommandKey";
NSString *kProfile_LocalControlModifier_Key = @"NewControlKey";
NSString *kProfile_LocalShiftModifier_Key = @"NewShiftKey";
NSString *kProfile_Button2EmulationScenario_Key = @"Button2EmulationScenario";
NSString *kProfile_Button3EmulationScenario_Key = @"Button3EmulationScenario";
NSString *kProfile_ClickWhileHoldingModifierForButton2_Key = @"ClickWhileHoldingModifierForButton2";
NSString *kProfile_ClickWhileHoldingModifierForButton3_Key = @"ClickWhileHoldingModifierForButton3";
NSString *kProfile_MultiTapModifierForButton2_Key = @"MultiTapModifierForButton2";
NSString *kProfile_MultiTapModifierForButton3_Key = @"MultiTapModifierForButton3";
NSString *kProfile_MultiTapDelayForButton2_Key = @"MultiTapDelayForButton2";
NSString *kProfile_MultiTapDelayForButton3_Key = @"MultiTapDelayForButton3";
NSString *kProfile_MultiTapCountForButton2_Key = @"MultiTapCountForButton2";
NSString *kProfile_MultiTapCountForButton3_Key = @"MultiTapCountForButton3";
NSString *kProfile_TapAndClickModifierForButton2_Key = @"TapAndClickModifierForButton2";
NSString *kProfile_TapAndClickModifierForButton3_Key = @"TapAndClickModifierForButton3";
NSString *kProfile_TapAndClickButtonSpeedForButton2_Key = @"TapAndClickButtonSpeedForButton2";
NSString *kProfile_TapAndClickButtonSpeedForButton3_Key = @"TapAndClickButtonSpeedForButton3";
NSString *kProfile_TapAndClickTimeoutForButton2_Key = @"TapAndClickTimeoutForButton2";
NSString *kProfile_TapAndClickTimeoutForButton3_Key = @"TapAndClickTimeoutForButton3";
NSString *kProfile_IsDefault_Key = @"IsDefault";

// --- Notifications --- //
NSString *ProfileAddDeleteNotification = @"ProfileAddedOrDeleted";

static NSString *kProfileDragEntry = @"com.geekspiff.cotvnc.ProfileDragEntry";


@implementation ProfileManager

#pragma mark Shared Instance

+ (id)sharedManager 
{
	static id sInstance = nil;
	if ( ! sInstance )
	{
		sInstance = [[self alloc] initWithWindowNibName: @"ProfileManager"];
		NSParameterAssert( sInstance != nil );
	}
	return sInstance;
}


- (void)wakeup
{
	// make sure our window is loaded
	[self window];
	[self setWindowFrameAutosaveName: @"profile_manager"];

	
	[mEncodingTableView setTarget:self];
    [mEncodingTableView setDoubleAction:@selector(toggleSelectedEncodingEnabled:)];
    [self _selectProfileAtIndex: 0];

	NSArray *dragTypes = [NSArray arrayWithObject: kProfileDragEntry];
	[mEncodingTableView registerForDraggedTypes: dragTypes];
}


#pragma mark -
#pragma mark Utilities


+ (NSString *)nameForEncodingType: (CARD32)type
{
	int index = [self _indexForEncodingType: type];
	return (NSString *)gEncodingNames[index];
}


+ (CARD32)modifierCodeForPreference: (id)preference
{
	switch ([preference shortValue])
	{
		case kRemoteAltModifier:
			return kAltKeyCode;
		case kRemoteMetaModifier:
			return kMetaKeyCode;
		case kRemoteControlModifier:
			return kControlKeyCode;
		case kRemoteShiftModifier:
			return kShiftKeyCode;
		case kRemoteWindowsModifier:
			return kWindowsKeyCode;
	}
	[NSException raise: NSInternalInconsistencyException format: @"Invalid modifier code"];
	return 0; // never executed
	
}


#pragma mark -
#pragma mark Profile Manager Window


- (IBAction)showWindow: (id)sender
{  [[self window] makeKeyAndOrderFront: nil];  }


#pragma mark -
#pragma mark Profile Access


- (Profile *)defaultProfile 
{
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
	NSMutableDictionary *defaultProfile = [profiles defaultProfile];
	NSParameterAssert( defaultProfile != nil );
	NSString *defaultProfileName = [profiles defaultProfileName];
	NSParameterAssert( defaultProfileName != nil );
    return [[[Profile alloc] initWithDictionary:defaultProfile name: defaultProfileName] autorelease];
}


- (BOOL)profileWithNameExists:(NSString*)name
{
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
    NSMutableDictionary* p = [profiles profileForKey: name];
	
    return nil != p;
}


- (Profile *)profileNamed: (NSString*)name
{
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
    NSMutableDictionary* p = [profiles profileForKey: name];
	
    if( nil == p )
		return [self defaultProfile];
    return [[[Profile alloc] initWithDictionary:p name: name] autorelease];
}


#pragma mark -
#pragma mark Action Methods


- (IBAction)addProfile: (id)sender
{
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];

    NSMutableDictionary *newProfile = [[self _currentProfileDictionary] deepMutableCopy];
	[newProfile removeObjectForKey: kProfile_IsDefault_Key];
	NSString *newName = [mProfileNameField stringValue];
    [profiles setProfile:newProfile forKey: newName];
    [profiles save];
	
	[mProfileTable reloadData];
    [self _selectProfileNamed: newName];
	
    [[NSNotificationCenter defaultCenter] postNotificationName: ProfileAddDeleteNotification
                                                        object: self];
}


- (IBAction)deleteProfile: (id)sender
{
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
	
    [profiles removeProfileForKey: [self _currentProfileName]];
    [profiles save];
	[mProfileTable reloadData];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ProfileAddDeleteNotification
                                                        object:self];

	int selectedRow = [mProfileTable selectedRow];
	[self _selectProfileAtIndex: selectedRow];
}


- (void)formDidChange:(id)sender
{
	int tag, value;
	
    NSMutableDictionary* profile = [self _currentProfileDictionary];
	
    [profile setObject: [NSNumber numberWithInt: [[mPixelFormatMatrix selectedCell] tag]]
                forKey: kProfile_PixelFormat_Key];
	[profile setObject: [NSNumber numberWithBool: ([mEnableCopyRect state] == NSOnState) ? YES : NO]
				forKey: kProfile_EnableCopyrect_Key];
    
	tag = [[mEmulationPopup2 selectedItem] tag];
	[profile setObject:[NSNumber numberWithUnsignedInt: tag]
				forKey: kProfile_Button2EmulationScenario_Key];
	[mEmulationTabView2 selectTabViewItemAtIndex: tag];
	tag = [[mClickWhileHoldingEmulationModifier2 selectedItem] tag];
	[profile setObject:[NSNumber numberWithUnsignedInt: tag]
				forKey: kProfile_ClickWhileHoldingModifierForButton2_Key];
	tag = [[mMultiTapEmulationModifier2 selectedItem] tag];
	[profile setObject:[NSNumber numberWithUnsignedInt: tag]
				forKey: kProfile_MultiTapModifierForButton2_Key];
	value = [mMultiTapEmulationCountStepper2 intValue];
	[profile setObject:[NSNumber numberWithUnsignedInt: value]
				forKey: kProfile_MultiTapCountForButton2_Key];
	[mMultiTapEmulationCountText2 setIntValue: value];
	tag = [[mTapAndClickEmulationModifier2 selectedItem] tag];
	[profile setObject:[NSNumber numberWithUnsignedInt: tag]
				forKey: kProfile_TapAndClickModifierForButton2_Key];
	[profile setObject: [NSNumber numberWithDouble: [mTapAndClickEmulationTimeout2 doubleValue]]
				forKey: kProfile_TapAndClickTimeoutForButton2_Key];
	
	tag = [[mEmulationPopup3 selectedItem] tag];
	[profile setObject:[NSNumber numberWithUnsignedInt: tag]
				forKey: kProfile_Button3EmulationScenario_Key];
	[mEmulationTabView3 selectTabViewItemAtIndex: tag];
	tag = [[mClickWhileHoldingEmulationModifier3 selectedItem] tag];
	[profile setObject:[NSNumber numberWithUnsignedInt: tag]
				forKey: kProfile_ClickWhileHoldingModifierForButton3_Key];
	tag = [[mMultiTapEmulationModifier3 selectedItem] tag];
	[profile setObject:[NSNumber numberWithUnsignedInt: tag]
				forKey: kProfile_MultiTapModifierForButton3_Key];
	value = [mMultiTapEmulationCountStepper3 intValue];
	[profile setObject:[NSNumber numberWithUnsignedInt: value]
				forKey: kProfile_MultiTapCountForButton3_Key];
	[mMultiTapEmulationCountText3 setIntValue: value];
	tag = [[mTapAndClickEmulationModifier3 selectedItem] tag];
	[profile setObject:[NSNumber numberWithUnsignedInt: tag]
				forKey: kProfile_TapAndClickModifierForButton3_Key];
	[profile setObject: [NSNumber numberWithDouble: [mTapAndClickEmulationTimeout3 doubleValue]]
				forKey: kProfile_TapAndClickTimeoutForButton3_Key];
	
    [profile setObject: [[self class] _tagForModifierIndex: [mCommandKey indexOfSelectedItem]] 
				forKey: kProfile_LocalCommandModifier_Key];
    [profile setObject: [[self class] _tagForModifierIndex: [mControlKey indexOfSelectedItem]] 
				forKey: kProfile_LocalControlModifier_Key];
    [profile setObject: [[self class] _tagForModifierIndex: [mAltKey indexOfSelectedItem]] 
				forKey: kProfile_LocalAltModifier_Key];
    [profile setObject: [[self class] _tagForModifierIndex: [mShiftKey indexOfSelectedItem]] 
				forKey: kProfile_LocalShiftModifier_Key];
	
    [[ProfileDataManager sharedInstance] save];
}


- (IBAction)toggleSelectedEncodingEnabled: (id)sender
{
	NSMutableArray *encodings = [[self _currentProfileDictionary] objectForKey: kProfile_Encodings_Key];
	int selectedIndex = [mEncodingTableView selectedRow];
	NSParameterAssert ( selectedIndex >= 0 && selectedIndex < NUMENCODINGS );
	
	NSMutableDictionary *encoding = [encodings objectAtIndex: selectedIndex];
	BOOL wasEnabled = [[encoding objectForKey: kProfile_EncodingEnabled_Key] boolValue];
	[encoding setObject: [NSNumber numberWithBool: !wasEnabled] forKey: kProfile_EncodingEnabled_Key];
	
	[[ProfileDataManager sharedInstance] save];
	[mEncodingTableView reloadData];
}


- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[self _updateBrowserButtons];
}


- (BOOL)windowShouldClose:(id)sender
{
	if ( ! [sender makeFirstResponder:sender] )
		return NO;
	return YES;
}


#pragma mark -
#pragma mark NSTableView Data Source


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if ( mEncodingTableView == aTableView )
	{
		NSDictionary* profile = [self _currentProfileDictionary];
		NSArray* encodings = [profile objectForKey: kProfile_Encodings_Key];
		return [encodings count];
	}
	
    return [[ProfileDataManager sharedInstance] count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
	if ( mEncodingTableView == aTableView )
	{
		NSDictionary* profile = [self _currentProfileDictionary];
		NSArray* encodings = [profile objectForKey: kProfile_Encodings_Key];
		NSParameterAssert( rowIndex >= 0 && rowIndex< [encodings count] );		

		NSDictionary *entry = [encodings objectAtIndex: rowIndex];
		NSParameterAssert( entry != nil );

		if ( [[aTableColumn identifier] isEqualToString:@"Enabled"] )
			return [entry objectForKey: kProfile_EncodingEnabled_Key];
		int index = [[entry objectForKey: kProfile_EncodingValue_Key] intValue];
		return [[self class] nameForEncodingType: index];
	}

    NSArray* profileNames = [self _sortedProfileNames];
	NSParameterAssert( rowIndex >= 0 && rowIndex< [profileNames count] );		
	
	return [profileNames objectAtIndex: rowIndex];
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if ( mProfileTable == [aNotification object] )
	{
		int selectedRow = [mProfileTable selectedRow];
		NSString *profileName = [[self _sortedProfileNames] objectAtIndex: selectedRow];
		
        [mProfileNameField setStringValue: profileName];
        [self _updateBrowserButtons];
        [self _updateForm];
	}
}


- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	if ( mEncodingTableView == tableView )
	{
		if ([info draggingSource] == mEncodingTableView)
		{
			if ( row == mEncodingDragRow || row == mEncodingDragRow + 1 )
				return NSDragOperationNone;
			
			if ( NSTableViewDropOn == operation )
				[mEncodingTableView setDropRow: row dropOperation: NSTableViewDropAbove];
					
			return NSDragOperationMove;
		}
	}
	return NSDragOperationNone;
}


- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	if ( mEncodingTableView == tableView )
	{
		NSPasteboard *pboard = [info draggingPasteboard];
		if ( [pboard availableTypeFromArray: [NSArray arrayWithObject: kProfileDragEntry]] )
		{
			NSData *data = [pboard dataForType: kProfileDragEntry];
			NSMutableDictionary *encoding = [NSPropertyListSerialization propertyListFromData: data mutabilityOption: NSPropertyListMutableContainersAndLeaves format: nil errorDescription: nil];
			
			NSDictionary* profile = [self _currentProfileDictionary];
			NSMutableArray* encodings = [profile objectForKey: kProfile_Encodings_Key];
			NSParameterAssert( row >= 0 && row <= [encodings count] );
			
			int oldIndex = [encodings indexOfObject: encoding];
			NSParameterAssert( NSNotFound != oldIndex );
			
			[encodings insertObject: encoding atIndex: row];
			
			if ( row < oldIndex )
				oldIndex++;
			[encodings removeObjectAtIndex: oldIndex];
			
			[[ProfileDataManager sharedInstance] save];
			[mEncodingTableView reloadData];
			return YES;
		}
	}
	return NO;
}


- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	if ( mEncodingTableView == tableView )
	{
		NSParameterAssert( [rows count] == 1 );
		int rowIndex = [[rows objectAtIndex: 0] intValue];
		
		NSDictionary* profile = [self _currentProfileDictionary];
		NSArray* encodings = [profile objectForKey: kProfile_Encodings_Key];
		NSParameterAssert( rowIndex >= 0 && rowIndex< [encodings count] );		
		
		NSDictionary *encoding = [encodings objectAtIndex: rowIndex];
		NSParameterAssert( encoding != nil );

		NSData *data = [NSPropertyListSerialization dataFromPropertyList: encoding format: NSPropertyListXMLFormat_v1_0 errorDescription: nil];
		[pboard declareTypes: [NSArray arrayWithObject: kProfileDragEntry] owner: nil];
		[pboard setData: data forType: kProfileDragEntry];
		
		mEncodingDragRow = rowIndex;
		
		return YES;
	}
	return NO;
}

@end
