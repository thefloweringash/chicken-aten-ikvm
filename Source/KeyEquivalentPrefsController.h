//
//  KeyEquivalentPrefsController.h
//  Chicken of the VNC
//
//  Created by Jason Harris on Tue Apr 06 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class KeyEquivalentScenario, KeyEquivalentTextView;


@interface KeyEquivalentPrefsController : NSObject {
	IBOutlet NSPopUpButton *mConnectionType;
	IBOutlet NSOutlineView *mOutlineView;
	NSMutableArray *mSelectedScenario;
	KeyEquivalentTextView *mTextView;
	id mOriginalDelegate;
}

+ (KeyEquivalentPrefsController *)sharedController;

// Interface Interaction
- (IBAction)changeSelectedScenario: (NSPopUpButton *)sender;
- (void)loadSelectedScenario;
- (void)menusChanged;
- (NSString *)selectedScenarioName;
- (IBAction)restoreDefaults: (NSButton *)sender;

// Menu Interaction
- (void)addEntriesInMenu: (NSMenu *)menu toArray: (NSMutableArray *)array withScenario: (KeyEquivalentScenario *)scenario;
- (void)deactivateKeyEquivalentsInMenusIfNeeded;
- (void)updateKeyEquivalentsInMenusIfNeeded;

@end
