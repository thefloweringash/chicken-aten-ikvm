//
//  ProfileManager_private.m
//  Chicken of the VNC
//
//  Created by Bob Newhart on 8/19/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "ProfileManager_private.h"
#import "ProfileDataManager.h"


@implementation ProfileManager (Private)

+ (int)_indexForEncodingType: (CARD32)type
{
	int i;
	
	for ( i = 0; i < NUMENCODINGS; ++i )
		if ( gEncodingValues[i] == type )
			return i;
	[NSException raise: NSInternalInconsistencyException format: @"Bad encoding type given, no corresponding index"];
	return -1; // never executed
}


+ (NSNumber *)_tagForModifierIndex: (int)index
{
	switch ( index )
	{
		case 0:
			return [NSNumber numberWithShort: kRemoteAltModifier];
		case 1:
			return [NSNumber numberWithShort: kRemoteMetaModifier];
		case 2:
			return [NSNumber numberWithShort: kRemoteControlModifier];
		case 3:
			return [NSNumber numberWithShort: kRemoteShiftModifier];
		case 4:
			return [NSNumber numberWithShort: kRemoteWindowsModifier];
	}
	[NSException raise: NSInternalInconsistencyException format: @"Unsupported modifier index tag %d", index];
	return nil; // never executed
}


- (NSMutableDictionary *)_currentProfileDictionary
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
	[mProfileTable selectRow: index byExtendingSelection: NO];
	
	NSArray *profileNames = [self _sortedProfileNames];
	[mProfileNameField setStringValue: [profileNames objectAtIndex: index]];
	
	[self _updateForm];
	[self _updateBrowserButtons];
}


- (void)_selectProfileNamed:(NSString*)aProfile
{
	NSArray *profileNames = [self _sortedProfileNames];
	int index = [profileNames indexOfObject: aProfile];
	NSParameterAssert( NSNotFound != index );
	[self _selectProfileAtIndex: index];
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
	
	enabled = [profiles profileForKey: profileName] && ![profileName isEqualToString: [profiles defaultProfileName]];
    [mDeleteProfileButton setEnabled: enabled];
	
	enabled = ![profiles profileForKey: profileName] && (0 != [profileName length]);
    [mNewProfileButton setEnabled: enabled];
}


- (void)_updateForm
{
    NSDictionary* spd = [self _currentProfileDictionary];
	NSParameterAssert( spd != nil );

    [mPixelFormatMatrix selectCellWithTag: [[spd objectForKey: kProfile_PixelFormat_Key] intValue]];
    [m3bTimeout setIntValue: [[spd objectForKey: kProfile_E3BTimeout_Key] intValue]];
    [mkdTimeout setIntValue: [[spd objectForKey: kProfile_EmulateKeyDown_Key] intValue]];
    [mkbTimeout setIntValue: [[spd objectForKey: kProfile_EmulateKeyboard_Key] intValue]];
    [mEnableCopyRect setState: [[spd objectForKey: kProfile_EnableCopyrect_Key] boolValue] ? NSOnState : NSOffState];
	
    [mCommandKey selectItemAtIndex:[[spd objectForKey: kProfile_LocalCommandModifier_Key] shortValue]];
    [mControlKey selectItemAtIndex:[[spd objectForKey: kProfile_LocalControlModifier_Key] shortValue]];
    [mAltKey selectItemAtIndex:[[spd objectForKey: kProfile_LocalAltModifier_Key] shortValue]];
    [mShiftKey selectItemAtIndex:[[spd objectForKey: kProfile_LocalShiftModifier_Key] shortValue]];
	
    [mEncodingTableView reloadData];
}

@end
