//
//  KeyEquivalentScenario.m
//  Chicken of the VNC
//
//  Created by Jason Harris on Sun Mar 21 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "KeyEquivalentScenario.h"
#import "KeyEquivalent.h"
#import "KeyEquivalentEntry.h"


@implementation KeyEquivalentScenario

#pragma mark Creation

- (id)init
{
	if ( self = [super init] )
	{
		mEquivalentToEntryMapping = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (id)initWithPropertyList: (NSArray *)array
{
	if ( self = [super init] )
	{
		mEquivalentToEntryMapping = [[NSMutableDictionary alloc] init];
		NSEnumerator *entryEnumerator = [array objectEnumerator];
		NSDictionary *plistEntry;
		
		while ( plistEntry = [entryEnumerator nextObject] )
		{
			NSString *characters = [plistEntry objectForKey: @"Characters"];
			unsigned int modifiers = [[plistEntry objectForKey: @"Modifiers"] unsignedIntValue];
			NSString *title = [plistEntry objectForKey: @"Title"];
			
			if ( characters && title )
			{
				KeyEquivalent *keyEquivalent = [[[KeyEquivalent alloc] initWithCharacters: characters modifiers: modifiers] autorelease];
				KeyEquivalentEntry *keyEquivalentEntry = [[[KeyEquivalentEntry alloc] initWithTitle: title] autorelease];
				[mEquivalentToEntryMapping setObject: keyEquivalentEntry forKey: keyEquivalent];
			}
		}
	}
	return self;
}


- (void)dealloc
{
	[mEquivalentToEntryMapping release];
	[super dealloc];
}


- (NSString *)description
{  return [mEquivalentToEntryMapping description];  }


#pragma mark -
#pragma mark Persistance


- (NSArray *)propertyList
{
	NSMutableArray *array = [NSMutableArray array];
	NSEnumerator *keyEquivalentEnumerator = [mEquivalentToEntryMapping keyEnumerator];
	KeyEquivalent *keyEquivalent;
	
	while ( keyEquivalent = [keyEquivalentEnumerator nextObject] )
	{
		KeyEquivalentEntry *entry = [mEquivalentToEntryMapping objectForKey: keyEquivalent];
		NSString *characters = [keyEquivalent characters];
		NSNumber *modifiers = [NSNumber numberWithUnsignedInt: [keyEquivalent modifiers]];
		NSMenuItem *menuItem = [entry menuItem];
		NSString *title = [menuItem title];
		NSDictionary *plistEntry = [NSDictionary dictionaryWithObjectsAndKeys:
			characters,		@"Characters", 
			modifiers,		@"Modifiers", 
			title,			@"Title", 
			nil,			nil];
		[array addObject: plistEntry];
	}
	return array;
}


#pragma mark -
#pragma mark Accessing Key Equivalents


- (KeyEquivalentEntry *)entryForKeyEquivalent: (KeyEquivalent *)equivalent
{  return [mEquivalentToEntryMapping objectForKey: equivalent];  }


- (NSMenuItem *)menuItemForKeyEquivalent: (KeyEquivalent *)equivalent
{  return [(KeyEquivalentEntry *)[mEquivalentToEntryMapping objectForKey: equivalent] menuItem];  }


- (void)setEntry: (KeyEquivalentEntry *)entry forEquivalent: (KeyEquivalent *)equivalent
{
	[mEquivalentToEntryMapping setObject: entry forKey: equivalent];
}


- (KeyEquivalent *)keyEquivalentForMenuItem: (NSMenuItem *)menuItem
{
	NSString *title = [menuItem title];	
	NSEnumerator *keyEquivalentEnumerator = [mEquivalentToEntryMapping keyEnumerator];
	KeyEquivalent *thisKeyEquivalentObj;
	
	while ( thisKeyEquivalentObj = [keyEquivalentEnumerator nextObject] )
	{
		NSMenuItem *thisMenuItem = [[mEquivalentToEntryMapping objectForKey: thisKeyEquivalentObj] menuItem];
		NSString *thisTitle = [thisMenuItem title];
		if ( title && thisTitle && [thisTitle isEqualToString: title] )
			return thisKeyEquivalentObj;
	}
	return nil;
}


- (void)removeEntry: (KeyEquivalentEntry *)entry
{
	NSEnumerator *keyEquivalentEnumerator = [mEquivalentToEntryMapping keyEnumerator];
	KeyEquivalent *thisKeyEquivalent;
	
	while ( thisKeyEquivalent = [keyEquivalentEnumerator nextObject] )
	{
		KeyEquivalentEntry *thisEntry = [mEquivalentToEntryMapping objectForKey: thisKeyEquivalent];
		if ( entry && [entry isEqualToEntry: thisEntry] )
		{
			[mEquivalentToEntryMapping removeObjectForKey: thisKeyEquivalent];
		}
	}
}


#pragma mark -
#pragma mark Making Scenarios Active


- (void)makeActive: (BOOL)active
{
	if (mIsActive != active)
	{
		mIsActive = active;
		NSEnumerator *keyEquivalentEnumerator = [mEquivalentToEntryMapping keyEnumerator];
		KeyEquivalent *keyEquivalent;
		
		while ( keyEquivalent = [keyEquivalentEnumerator nextObject] )
			[[mEquivalentToEntryMapping objectForKey: keyEquivalent] makeActive: active forKeyEquivalent: keyEquivalent];
	}
}

@end
