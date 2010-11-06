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

#if 0
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
#endif


// --- Dictionary Keys --- //
NSString *kProfile_PixelFormat_Key = @"PixelFormat";
NSString *kProfile_EnableCopyrect_Key = @"EnableCopyRect";
NSString *kProfile_EnableJpegEncoding_Key = @"EnableJpegEncoding";
NSString *kProfile_JpegQualityLevel_Key = @"JpegQualityLevel";
NSString *kProfile_Encodings_Key = @"Encodings";
NSString *kProfile_EncodingValue_Key = @"ID";
NSString *kProfile_EncodingEnabled_Key = @"Enabled";
NSString *kProfile_LocalAltModifier_Key = @"NewAltKey";
NSString *kProfile_LocalCommandModifier_Key = @"NewCommandKey";
NSString *kProfile_LocalControlModifier_Key = @"NewControlKey";
NSString *kProfile_LocalShiftModifier_Key = @"NewShiftKey";
NSString *kProfile_InterpretModifiersLocally_Key = @"InterpretModifiersLocally";
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

static NSString *kProfileDragEntry = @"net.sourceforge.chicken.ProfileDragEntry";


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


#if 0
#pragma mark -
#pragma mark Utilities


+ (NSString *)nameForEncodingType: (CARD32)type
{
	int index = [self _indexForEncodingType: type];
	return (NSString *)gEncodingNames[index];
}
#endif

#pragma mark -
#pragma mark Profile Manager Window


- (IBAction)showWindow: (id)sender
{  [[self window] makeKeyAndOrderFront: nil];  }


#pragma mark -
#pragma mark Profile Access


- (Profile *)defaultProfile 
{
    return [[ProfileDataManager sharedInstance] defaultProfile];
}


- (BOOL)profileWithNameExists:(NSString*)name
{
    return [[ProfileDataManager sharedInstance] profileWithNameExists:name];
}


- (Profile *)profileNamed: (NSString*)name
{
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
    Profile* p = [profiles profileForKey: name];
	
    if( nil == p )
		return [profiles defaultProfile];
    else
        return p;
}


#pragma mark -
#pragma mark Action Methods


- (IBAction)addProfile: (id)sender
{
    ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
    Profile *current = [self _currentProfile];
	NSString *newName = [mProfileNameField stringValue];
    Profile *newProfile = [[Profile alloc] initWithProfile:current
                                                   andName:newName];
    [profiles setProfile:newProfile forKey: newName];
	
	[mProfileTable reloadData];
    [self _selectProfileNamed: newName];
	
    [[NSNotificationCenter defaultCenter] postNotificationName: ProfileAddDeleteNotification
                                                        object: self];
}


- (IBAction)deleteProfile: (id)sender
{
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
	
    [profiles removeProfileForKey: [self _currentProfileName]];
	[mProfileTable reloadData];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ProfileAddDeleteNotification
                                                        object:self];

	int selectedRow = [mProfileTable selectedRow];
	[self _selectProfileAtIndex: selectedRow];
}


- (void)formDidChange:(id)sender
{
	int tag, value;
	
    Profile* profile = [self _currentProfile];
	
    [profile setPixelFormatIndex:[[mPixelFormatMatrix selectedCell] tag]];
    [profile setCopyRectEnabled:[mEnableCopyRect state]];
    [profile setJpegEncodingEnabled:[mEnableJpegEncoding state]];
    
    tag = [[mEmulationPopup2 selectedItem] tag];
    [profile setEmulationScenario:tag forButton:2];
    [mEmulationTabView2 selectTabViewItemAtIndex: tag];
    tag = [[mClickWhileHoldingEmulationModifier2 selectedItem] tag];
    [profile setClickWhileHoldingModifier:tag forButton:2];
    tag = [[mMultiTapEmulationModifier2 selectedItem] tag];
    [profile setMultiTapModifier:tag forButton:2];
    value = [mMultiTapEmulationCountStepper2 intValue];
    [profile setMultiTapCount:value forButton:2];
    [mMultiTapEmulationCountText2 setIntValue: value];
    tag = [[mTapAndClickEmulationModifier2 selectedItem] tag];
    [profile setTapAndClickModifier:tag forButton:2];
    [profile setTapAndClickTimeout:[mTapAndClickEmulationTimeout2 doubleValue]
                         forButton:2];
    
    tag = [[mEmulationPopup3 selectedItem] tag];
    [profile setEmulationScenario:tag forButton:3];
    [mEmulationTabView3 selectTabViewItemAtIndex: tag];
    tag = [[mClickWhileHoldingEmulationModifier3 selectedItem] tag];
    [profile setClickWhileHoldingModifier:tag forButton:3];
    tag = [[mMultiTapEmulationModifier3 selectedItem] tag];
    [profile setMultiTapModifier:tag forButton:3];
    value = [mMultiTapEmulationCountStepper3 intValue];
    [profile setMultiTapCount:value forButton:3];
    [mMultiTapEmulationCountText3 setIntValue: value];
    tag = [[mTapAndClickEmulationModifier3 selectedItem] tag];
    [profile setTapAndClickModifier:tag forButton:3];
    [profile setTapAndClickTimeout:[mTapAndClickEmulationTimeout3 doubleValue]
                forButton:3];
    
    [profile setCommandKeyPreference:[mCommandKey indexOfSelectedItem]];
    [profile setControlKeyPreference: [mControlKey indexOfSelectedItem]];
    [profile setAltKeyPreference: [mAltKey indexOfSelectedItem]];
    [profile setShiftKeyPreference: [mShiftKey indexOfSelectedItem]];
    //[profile setInterpretModifiersLocally: [mInterpretModifiersLocally state]];
    
    [[ProfileDataManager sharedInstance] saveProfile:profile];
}


- (IBAction)toggleSelectedEncodingEnabled: (id)sender
{
    Profile *profile = [self _currentProfile];
    int selectedIndex = [mEncodingTableView selectedRow];
    NSParameterAssert ( selectedIndex >= 0 && selectedIndex < NUMENCODINGS );
    
    BOOL wasEnabled = [profile encodingEnabledAtIndex:selectedIndex];
    [profile setEncodingEnabled:!wasEnabled atIndex:selectedIndex];
    
    [[ProfileDataManager sharedInstance] saveProfile:profile];
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
        return [[self _currentProfile] numEncodings];
	}
	
    return [[ProfileDataManager sharedInstance] count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
	if ( mEncodingTableView == aTableView )
	{
		Profile* profile = [self _currentProfile];
		NSParameterAssert( rowIndex >= 0 && rowIndex< [profile numEncodings] );

		if ( [[aTableColumn identifier] isEqualToString:@"Enabled"] ) {
            BOOL enabled = [profile encodingEnabledAtIndex:rowIndex];
            return [NSNumber numberWithBool:enabled];
        } else
            return [profile encodingNameAtIndex:rowIndex];
	} else {
        NSArray* profileNames = [self _sortedProfileNames];
        NSParameterAssert( rowIndex >= 0 && rowIndex< [profileNames count] );
        
        return [profileNames objectAtIndex: rowIndex];
    }
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
			
			Profile* profile = [self _currentProfile];
            [profile moveEncodingFrom:*(int *)[data bytes] to:row];
			
            [[ProfileDataManager sharedInstance] saveProfile:profile];
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
		
        NSData *data = [[NSData alloc] initWithBytes:&rowIndex
                                              length:sizeof(int)];
		[pboard declareTypes: [NSArray arrayWithObject: kProfileDragEntry] owner: nil];
		[pboard setData: data forType: kProfileDragEntry];
        [data release];
		
		mEncodingDragRow = rowIndex;
		
		return YES;
	}
	return NO;
}

@end
