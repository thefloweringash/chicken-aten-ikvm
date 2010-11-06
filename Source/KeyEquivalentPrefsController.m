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

static KeyEquivalentPrefsController *sharedController = nil;

+ (KeyEquivalentPrefsController *)sharedController;
{
    return sharedController;
}

- (void)awakeFromNib
{
	NSNotificationCenter *notif = [NSNotificationCenter defaultCenter];
	
	mTextView = [[KeyEquivalentTextView alloc] initWithFrame: NSZeroRect];
	[notif addObserver: self selector: @selector(textDidChange:) name: NSControlTextDidChangeNotification object: mOutlineView];
	[notif addObserver: self selector: @selector(textDidEndEditing:) name: NSTextDidEndEditingNotification object: mTextView];
	[notif addObserver: self selector: @selector(textViewDidChangeSelection:) name: NSTextViewDidChangeSelectionNotification object: mTextView];
	
//	[[KeyEquivalentManager defaultManager] loadScenarios];
//	[[KeyEquivalentManager defaultManager] loadFromMainMenuIntoScenarioNamed: kNonConnectionWindowFrontmostScenario];
//	[[KeyEquivalentManager defaultManager] makeScenariosPersistant];
// end DEBUGGING
	[self loadSelectedScenario];

	sharedController = self;
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


/* Recursive method to determine list of all menus which are expanded in the
 * current view. */
- (void)getExpandedNames:(NSMutableSet *)expanded from:(NSDictionary *)obj
{
    if (![mOutlineView isItemExpanded:obj])
        return;

    NSEnumerator    *en = [[obj objectForKey:@"items"] objectEnumerator];
    NSDictionary    *child;

    [expanded addObject: [obj objectForKey:@"title"]];

    while ((child = [en nextObject]) != nil) {
        [self getExpandedNames:expanded from:child];
    }
}

/* Returns a list of all menu names which are currently viewed as expanded. */
- (NSSet *)getAllExpandedNames
{
    NSMutableSet    *expanded = [[NSMutableSet alloc] init];
    NSEnumerator    *en = [mSelectedScenario objectEnumerator];
    NSDictionary    *obj;

    while ((obj = [en nextObject]) != nil)
        [self getExpandedNames:expanded from:obj];
    return [expanded autorelease];
}

/* Recursive function for expanding all menus whose name is in expanded. */
- (void)expandByName:(NSSet *)expanded from:(NSDictionary *)entry
{
    if (![expanded member: [entry objectForKey:@"title"]])
        return;

    [mOutlineView expandItem:entry];

    NSEnumerator   *children = [[entry objectForKey:@"items"] objectEnumerator];
    NSDictionary   *child;

    while ((child = [children nextObject]) != nil)
        [self expandByName:expanded from:child];
}

/* Expands all menus whose name is in expanded. */
- (void)expandByName:(NSSet *)expanded
{
    NSEnumerator    *en = [mSelectedScenario objectEnumerator];
    NSDictionary    *obj;
    while ((obj = [en nextObject]) != nil)
        [self expandByName:expanded from:obj];
}

/* When the scenario's changed or the menus have changed, we rebuild the tree of
 * key equivalents to display. We want to keep the expansion states the same, so
 * we save these in expanded and then expand all entries with the same name. */
- (IBAction)changeSelectedScenario: (NSPopUpButton *)sender
{
    NSSet   *expanded = [self getAllExpandedNames];

	[mOutlineView deselectAll: nil];
	[self loadSelectedScenario];
    [self expandByName:expanded];
}


- (void)loadSelectedScenario
{
	NSString *scenarioName = [self selectedScenarioName];
	KeyEquivalentScenario *scenario = [[KeyEquivalentManager defaultManager] keyEquivalentsForScenarioName: scenarioName];
	NSMutableArray *newArray = [NSMutableArray array];
	NSMenu *mainMenu = [NSApp mainMenu];
	[self addEntriesInMenu: mainMenu toArray: newArray withScenario: scenario];
	[mSelectedScenario release];
	mSelectedScenario = [newArray retain];
	[mOutlineView reloadData];
}

- (void)menusChanged
{
    [self changeSelectedScenario: nil];
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
