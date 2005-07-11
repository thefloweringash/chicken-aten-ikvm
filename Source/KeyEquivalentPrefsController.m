//
//  KeyEquivalentPrefsController.m
//  Chicken of the VNC
//
//  Created by Jason Harris on Tue Apr 06 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "KeyEquivalentPrefsController.h"
#import "KeyEquivalent.h"
#import "KeyEquivalentEntry.h"
#import "KeyEquivalentManager.h"
#import "KeyEquivalentScenario.h"
#import "KeyEquivalentTextView.h"

@implementation KeyEquivalentPrefsController

#pragma mark Creation/Deletion


- (void)awakeFromNib
{
	NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];
	
	mTextView = [[KeyEquivalentTextView alloc] initWithFrame: NSZeroRect];
	[notif addObserver: self selector: @selector(textDidChange:) name: NSControlTextDidChangeNotification object: mOutlineView];
	[notif addObserver: self selector: @selector(textDidEndEditing:) name: NSTextDidEndEditingNotification object: mTextView];
	[notif addObserver: self selector: @selector(textViewDidChangeSelection:) name: NSTextViewDidChangeSelectionNotification object: mTextView];
	
	[[KeyEquivalentManager defaultManager] loadScenarios];
//	[[KeyEquivalentManager defaultManager] loadFromMainMenuIntoScenarioNamed: kNonConnectionWindowFrontmostScenario];
//	[[KeyEquivalentManager defaultManager] makeScenariosPersistant];
// end DEBUGGING
	[self loadSelectedScenario];
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[mSelectedScenario release];
	[mTextView release];
	[super dealloc];
}


#pragma mark -
#pragma mark Interface Interaction


- (IBAction)changeSelectedScenario: (NSPopUpButton *)sender
{
	[mOutlineView deselectAll: nil];
	[self loadSelectedScenario];
}


- (void)loadSelectedScenario
{
	NSString *scenarioName = [self selectedScenarioName];
	KeyEquivalentScenario *scenario = [[KeyEquivalentManager defaultManager] keyEquivalentsForScenarioName: scenarioName];
	NSMutableArray *newArray = [NSMutableArray array];
	NSMenu *mainMenu = [NSApp mainMenu];
	[self addEntriesInMenu: mainMenu toArray: newArray withScenario: scenario];
	[mSelectedScenario autorelease];
	mSelectedScenario = [newArray retain];
	[mOutlineView reloadData];
}


- (NSString *)selectedScenarioName
{
	switch ( [[mConnectionType selectedItem] tag] )
	{
		case 0:
			return kConnectionWindowFrontmostScenario;
		case 1:
			return kConnectionFullscreenScenario;
		case 2:
			return kNonConnectionWindowFrontmostScenario;
		default:
			[NSException raise: NSInternalInconsistencyException format: @"unsupported tag"];
	}
	return nil;
}


- (IBAction)restoreDefaults: (NSButton *)sender
{	
	[mOutlineView abortEditing];
	[[mOutlineView window] makeFirstResponder: mOutlineView];
	[self deactivateKeyEquivalentsInMenusIfNeeded];
	[[KeyEquivalentManager defaultManager] restoreDefaults];
	[self changeSelectedScenario: nil];
	[self updateKeyEquivalentsInMenusIfNeeded];
}


#pragma mark -
#pragma mark Menu Interaction


- (void)addEntriesInMenu: (NSMenu *)menu toArray: (NSMutableArray *)array withScenario: (KeyEquivalentScenario *)scenario
{
	NSEnumerator *menuEnumerator;
	NSMenuItem *menuItem;

	menuEnumerator = [[menu itemArray] objectEnumerator];
	while ( menuItem = [menuEnumerator nextObject] )
	{
		if ( ! [menuItem isSeparatorItem] )
		{
			if ( [menuItem hasSubmenu] )
			{
				NSMenu *submenu = [menuItem submenu];
				NSString *title = [submenu title];
				
				if (title && [title isEqualToString: @"Apple"])
					title = [[NSProcessInfo processInfo] processName];
				else if ( submenu == [NSApp servicesMenu] )
					continue;
				
				NSMutableArray *items = [NSMutableArray array];
				NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					title,		@"title", 
					items,		@"items", 
					nil,		nil];
				[array addObject: entry];
				[self addEntriesInMenu: submenu toArray: items withScenario: scenario];
			}
			
			else
			{
				NSString *title = [menuItem title];				
				KeyEquivalent *keyEquivalent = [scenario keyEquivalentForMenuItem: menuItem];
				NSAttributedString *keyEquivalentDisplayString = [keyEquivalent userString];
				NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					menuItem,					@"menuItem", 
					title,						@"title", 
					keyEquivalentDisplayString, @"keyEquivalent", 
					nil,						nil];
				if ( keyEquivalent )
				{
					KeyEquivalentEntry *keyEquivalentEntry = [scenario entryForKeyEquivalent: keyEquivalent];
					[entry setObject: keyEquivalentEntry forKey: @"entry"];
				}
				[array addObject: entry];
			}
		}
	}
}


- (void)deactivateKeyEquivalentsInMenusIfNeeded
{
	NSString *selectedScenarioName;
	
	selectedScenarioName = [self selectedScenarioName];
	if ( selectedScenarioName == kNonConnectionWindowFrontmostScenario )
	{
		KeyEquivalentManager *keyEquivalentManager = [KeyEquivalentManager defaultManager];
		[keyEquivalentManager setCurrentScenarioToName: nil];
	}
}


- (void)updateKeyEquivalentsInMenusIfNeeded
{
	NSString *selectedScenarioName;

	selectedScenarioName = [self selectedScenarioName];
	if ( selectedScenarioName == kNonConnectionWindowFrontmostScenario )
	{
		KeyEquivalentManager *keyEquivalentManager = [KeyEquivalentManager defaultManager];
		[keyEquivalentManager setCurrentScenarioToName: kNonConnectionWindowFrontmostScenario];
	}
}


#pragma mark -
#pragma mark NSOutlineView methods


- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if (item == nil)
		return [mSelectedScenario count];
	return [[item objectForKey: @"items"] count];
}


- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item {
	if (item == nil)
		return [mSelectedScenario objectAtIndex: index];
	return [[item objectForKey: @"items"] objectAtIndex: index];
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSString *identifier = [tableColumn identifier];
	if (identifier)
	{
		if ([identifier isEqualToString: @"title"])
			return [item objectForKey: @"title"];
		if ([identifier isEqualToString: @"keyEquivalent"])
			return [item objectForKey: @"keyEquivalent"];
	}
	[NSException raise: NSInternalInconsistencyException format: @"unknown identifier"];
	return nil;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	NSArray *items = [item objectForKey: @"items"];
	return items != nil;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if ([item objectForKey: @"items"]) {
		BOOL childrenToo = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) ? YES : NO;
		if ([mOutlineView isItemExpanded: item])
			[mOutlineView collapseItem: item collapseChildren: childrenToo];
		else
			[mOutlineView expandItem: item expandChildren: childrenToo];
		return NO;
	}
	NSString *identifier = [tableColumn identifier];
	if (identifier)
	{
		if ([identifier isEqualToString: @"title"])
			return NO;
		if ([identifier isEqualToString: @"keyEquivalent"])
		{
			NSWindow *window = [mOutlineView window];
			mOriginalDelegate = [window delegate];
			[window setDelegate: self];
			return YES;
		}
	}
	[NSException raise: NSInternalInconsistencyException format: @"unknown identifier"];
	return NO;
}


- (void)textDidChange:(NSNotification *)aNotification
{
	KeyEquivalent *keyEquivalent;
	KeyEquivalentManager *keyEquivalentManager;
	KeyEquivalentTextView *text;
	KeyEquivalentEntry *entry;
	KeyEquivalentScenario *scenario;
	NSDictionary *selectedItem;
	NSMenuItem *menuItem;
	NSString *selectedScenarioName;
	NSAttributedString *keyEquivalentDisplayString;
	NSString *characters;
	
	selectedItem = [mOutlineView itemAtRow: [mOutlineView selectedRow]];
	menuItem = [selectedItem objectForKey: @"menuItem"];

	keyEquivalentManager = [KeyEquivalentManager defaultManager];
	text = (KeyEquivalentTextView *)[mOutlineView currentEditor];
	keyEquivalent = [text keyEquivalent];
	characters = [keyEquivalent characters];
	if ( characters && [characters isEqualToString: @" "] )
		keyEquivalent = nil;
	[self deactivateKeyEquivalentsInMenusIfNeeded];
	selectedScenarioName = [self selectedScenarioName];
	scenario = [keyEquivalentManager keyEquivalentsForScenarioName: selectedScenarioName];
	entry = [selectedItem objectForKey: @"entry"];
	if ( ! entry )
		entry = [[[KeyEquivalentEntry alloc] initWithMenuItem: [selectedItem objectForKey: @"menuItem"]] autorelease];
	else
	{
		[[entry retain] autorelease];
		[scenario removeEntry: entry];
	}
	if (keyEquivalent)
		[scenario setEntry: entry forEquivalent: keyEquivalent];
	[keyEquivalentManager makeScenariosPersistant];
	[self updateKeyEquivalentsInMenusIfNeeded];
	
	[mOutlineView abortEditing];
	[[mOutlineView window] makeFirstResponder: mOutlineView];
	if (keyEquivalent)
		keyEquivalentDisplayString = [keyEquivalent userString];
	else
		keyEquivalentDisplayString = [[[NSAttributedString alloc] initWithString: @""] autorelease];
	[(NSMutableDictionary *)selectedItem setObject: keyEquivalentDisplayString forKey: @"keyEquivalent"];
	[(NSMutableDictionary *)selectedItem setObject: entry forKey: @"entry"];
	[mOutlineView reloadItem: selectedItem];
}


- (void)textDidEndEditing:(NSNotification *)aNotification
{
	[[mOutlineView window] setDelegate: mOriginalDelegate];
}


- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{
	static BOOL calledRecursively = NO;
	if ( ! calledRecursively )
	{
		calledRecursively = YES;
		[mTextView selectAll:nil];
		calledRecursively = NO;
	}
}


- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject
{
	if (anObject == mOutlineView)
		return mTextView;
	return nil;
}

@end
