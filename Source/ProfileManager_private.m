//
//  ProfileManager_private.m
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/19/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "ProfileManager_private.h"
#import "ProfileDataManager.h"


@implementation ProfileManager (Private)

#if 0
+ (int)_indexForEncodingType: (CARD32)type
{
	int i;
	
	for ( i = 0; i < NUMENCODINGS; ++i )
		if ( gEncodingValues[i] == type )
			return i;
	[NSException raise: NSInternalInconsistencyException format: @"Bad encoding type given, no corresponding index"];
	return -1; // never executed
}
#endif


- (Profile *)_currentProfile
{
	NSString *name = [self _currentProfileName];
	if ( nil == name )
		return nil;
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
	return [profiles profileForKey: name];
}


- (NSString *)_currentProfileName
{
	int selectedRow = [mProfileTable selectedRow];
	if ( selectedRow < 0 )
		return nil;
	
	return [[self _sortedProfileNames] objectAtIndex: selectedRow];
}


- (void)_selectProfileAtIndex: (int)index
{
    NSIndexSet  *set = [[NSIndexSet alloc] initWithIndex: index];
    [mProfileTable selectRowIndexes: set byExtendingSelection: NO];
    [set release];
	
	NSArray *profileNames = [self _sortedProfileNames];
	[mProfileNameField setStringValue: [profileNames objectAtIndex: index]];
	
	[self _updateForm];
	[self _updateBrowserButtons];
}


- (void)_selectProfileNamed:(NSString*)aProfile
{
	NSArray *profileNames = [self _sortedProfileNames];
	int index = [profileNames indexOfObject: aProfile];
    if (index != NSNotFound)
        [self _selectProfileAtIndex: index];
    else
        NSLog(@"Couldn't select profile with name %@", aProfile);
}


- (NSArray*)_sortedProfileNames
{
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
    NSMutableArray* n = [[[profiles sortedKeyArray] mutableCopy] autorelease];
	NSString *defaultProfileName = [profiles defaultProfileName];
	
	unsigned int idx = [n indexOfObject: defaultProfileName];
	NSParameterAssert( NSNotFound != idx );
	[n removeObjectAtIndex:idx];
	[n insertObject: defaultProfileName atIndex: 0];
    return n;
}


- (void)_updateBrowserButtons
{
    NSString* profileName = [mProfileNameField stringValue];
	ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
	BOOL enabled;
	
	enabled = [profiles profileWithNameExists: profileName] && ![profileName isEqualToString: [profiles defaultProfileName]];
    [mDeleteProfileButton setEnabled: enabled];
	
	enabled = ![profiles profileWithNameExists: profileName] && (0 != [profileName length]);
    [mNewProfileButton setEnabled: enabled];
}


- (void)_updateForm
{
	int tag, value;
	
    Profile *profile = [self _currentProfile];
	NSParameterAssert( profile != nil );

    [mPixelFormatMatrix selectCellWithTag: [profile pixelFormatIndex]];
    [mEnableCopyRect setState: [profile enableCopyRect]];
    [mEnableJpegEncoding setState: [profile enableJpegEncoding]];
	
    tag = [profile button2EmulationScenario];
	[mEmulationPopup2 selectItemAtIndex: [mEmulationPopup2 indexOfItemWithTag: tag]];
	[mEmulationTabView2 selectTabViewItemAtIndex: tag];
    tag = [profile clickWhileHoldingModifierForButton:2];
	[mClickWhileHoldingEmulationModifier2 selectItemAtIndex: [mClickWhileHoldingEmulationModifier2 indexOfItemWithTag: tag]];
    tag = [profile multiTapModifierForButton:2];
	[mMultiTapEmulationModifier2 selectItemAtIndex: [mMultiTapEmulationModifier2 indexOfItemWithTag: tag]];
    value = [profile multiTapCountForButton:2];
	[mMultiTapEmulationCountStepper2 setIntValue: value];
	[mMultiTapEmulationCountText2 setIntValue: value];
    tag = [profile tapAndClickModifierForButton:2];
	[mTapAndClickEmulationModifier2 selectItemAtIndex: [mTapAndClickEmulationModifier2 indexOfItemWithTag: tag]];
    [mTapAndClickEmulationTimeout2 setDoubleValue: [profile tapAndClickTimeoutForButton:2]];
	
	tag = [profile button3EmulationScenario];
	[mEmulationPopup3 selectItemAtIndex: [mEmulationPopup3 indexOfItemWithTag: tag]];
	[mEmulationTabView3 selectTabViewItemAtIndex: tag];
    tag = [profile clickWhileHoldingModifierForButton:3];
	[mClickWhileHoldingEmulationModifier3 selectItemAtIndex: [mClickWhileHoldingEmulationModifier3 indexOfItemWithTag: tag]];
    tag = [profile multiTapModifierForButton:3];
	[mMultiTapEmulationModifier3 selectItemAtIndex: [mMultiTapEmulationModifier3 indexOfItemWithTag: tag]];
    value = [profile multiTapDelayForButton:3];
	[mMultiTapEmulationCountStepper3 setIntValue: value];
	[mMultiTapEmulationCountText3 setIntValue: value];
    tag = [profile tapAndClickModifierForButton:3];
	[mTapAndClickEmulationModifier3 selectItemAtIndex: [mTapAndClickEmulationModifier3 indexOfItemWithTag: tag]];
    [mTapAndClickEmulationTimeout3 setDoubleValue: [profile tapAndClickTimeoutForButton:3]];
	
	[mCommandKey selectItemAtIndex:[profile commandKeyPreference]];
    [mControlKey selectItemAtIndex:[profile controlKeyPreference]];
    [mAltKey selectItemAtIndex:[profile altKeyPreference]];
    [mShiftKey selectItemAtIndex:[profile shiftKeyPreference]];
    //[mInterpretModifiersLocally setState:[profile interpretModifiersLocally]];
	
    [mEncodingTableView reloadData];
}

@end
