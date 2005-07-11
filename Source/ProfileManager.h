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

// Dictionary Keys
extern NSString *kProfile_PixelFormat_Key;
extern NSString *kProfile_EnableCopyrect_Key;
extern NSString *kProfile_Encodings_Key;
extern NSString *kProfile_EncodingValue_Key;
extern NSString *kProfile_EncodingEnabled_Key;
extern NSString *kProfile_LocalAltModifier_Key;
extern NSString *kProfile_LocalCommandModifier_Key;
extern NSString *kProfile_LocalControlModifier_Key;
extern NSString *kProfile_LocalShiftModifier_Key;
extern NSString *kProfile_Button2EmulationScenario_Key;
extern NSString *kProfile_Button3EmulationScenario_Key;
extern NSString *kProfile_ClickWhileHoldingModifierForButton2_Key;
extern NSString *kProfile_ClickWhileHoldingModifierForButton3_Key;
extern NSString *kProfile_MultiTapModifierForButton2_Key;
extern NSString *kProfile_MultiTapModifierForButton3_Key;
extern NSString *kProfile_MultiTapDelayForButton2_Key;
extern NSString *kProfile_MultiTapDelayForButton3_Key;
extern NSString *kProfile_MultiTapCountForButton2_Key;
extern NSString *kProfile_MultiTapCountForButton3_Key;
extern NSString *kProfile_TapAndClickModifierForButton2_Key;
extern NSString *kProfile_TapAndClickModifierForButton3_Key;
extern NSString *kProfile_TapAndClickButtonSpeedForButton2_Key;
extern NSString *kProfile_TapAndClickButtonSpeedForButton3_Key;
extern NSString *kProfile_TapAndClickTimeoutForButton2_Key;
extern NSString *kProfile_TapAndClickTimeoutForButton3_Key;
extern NSString *kProfile_IsDefault_Key;

// Notifications
extern NSString *ProfileAddDeleteNotification;

// Modifier Key Mapping
typedef enum {
	kRemoteAltModifier		= 0,
	kRemoteMetaModifier		= 1,
	kRemoteControlModifier	= 2,
	kRemoteShiftModifier	= 3,
	kRemoteWindowsModifier	= 4
} ModifierKeyIdentifier;

// Encodings
#define NUMENCODINGS					8
extern const unsigned int gEncodingValues[];
	
	
@interface ProfileManager : NSWindowController
{
    IBOutlet NSTableView *mProfileTable;
    IBOutlet NSTextField *mProfileNameField;
    IBOutlet NSButton *mNewProfileButton;
    IBOutlet NSButton *mDeleteProfileButton;
	IBOutlet NSPopUpButton *mEmulationPopup2;
	IBOutlet NSPopUpButton *mEmulationPopup3;
	IBOutlet NSTabView *mEmulationTabView2;
	IBOutlet NSTabView *mEmulationTabView3;
	IBOutlet NSPopUpButton *mClickWhileHoldingEmulationModifier2;
	IBOutlet NSPopUpButton *mClickWhileHoldingEmulationModifier3;
	IBOutlet NSPopUpButton *mMultiTapEmulationModifier2;
	IBOutlet NSPopUpButton *mMultiTapEmulationModifier3;
	IBOutlet NSStepper *mMultiTapEmulationCountStepper2;
	IBOutlet NSStepper *mMultiTapEmulationCountStepper3;
	IBOutlet NSTextField *mMultiTapEmulationCountText2;
	IBOutlet NSTextField *mMultiTapEmulationCountText3;
	IBOutlet NSPopUpButton *mTapAndClickEmulationModifier2;
	IBOutlet NSPopUpButton *mTapAndClickEmulationModifier3;
	IBOutlet NSTextField *mTapAndClickEmulationTimeout2;
	IBOutlet NSTextField *mTapAndClickEmulationTimeout3;
    IBOutlet NSPopUpButton *mAltKey;
    IBOutlet NSPopUpButton *mCommandKey;
    IBOutlet NSPopUpButton *mControlKey;
    IBOutlet NSPopUpButton *mShiftKey;
    IBOutlet NSTableView *mEncodingTableView;
	IBOutlet NSButton *mEnableCopyRect;
    IBOutlet NSMatrix *mPixelFormatMatrix;
	int mEncodingDragRow;
}

	// Shared Instance
+ (id)sharedManager;
- (void)wakeup;

	// Utilities
+ (NSString *)nameForEncodingType: (CARD32)type;
+ (CARD32)modifierCodeForPreference: (id)preference;

	// Profile Manager Window
- (IBAction)showWindow: (id)sender;

	// Profile Access
- (Profile *)defaultProfile;
- (BOOL)profileWithNameExists:(NSString*)name;
- (Profile*)profileNamed:(NSString*)name;

	// Action Methods
- (IBAction)addProfile:(id)sender;
- (IBAction)deleteProfile:(id)sender;
- (IBAction)formDidChange:(id)sender;
- (IBAction)toggleSelectedEncodingEnabled: (id)sender;

@end
