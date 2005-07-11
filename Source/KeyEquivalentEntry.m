//
//  KeyEquivalentEntry.m
//  Chicken of the VNC
//
//  Created by Jason Harris on Sun Mar 21 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "KeyEquivalentEntry.h"
#import "KeyEquivalent.h"


@implementation KeyEquivalentEntry

+ (NSMenuItem *)menuItemWithTitle: (NSString *)title inMenu: (NSMenu *)menu
{
	NSEnumerator *menuEnumerator;
	NSMenuItem *menuItem;
	
	menuEnumerator = [[menu itemArray] objectEnumerator];
	while ( menuItem = [menuEnumerator nextObject] )
	{
		id thisTitle = [menuItem title];
		if ( thisTitle && [thisTitle isEqualToString: title] )
			return menuItem;
		if ( [menuItem hasSubmenu] )
		{
			NSMenuItem *foundItem = [self menuItemWithTitle: title inMenu: [menuItem submenu]];
			if (foundItem)
				return foundItem;
		}
	}
	return nil;
}


- (id)initWithTitle: (NSString *)title
{
	if ( self = [super init] )
	{
		NSMenu *mainMenu = [NSApp mainMenu];
		mMenuItem = [[self class] menuItemWithTitle: title inMenu: mainMenu];
	}
	return self;
}


- (id)initWithMenuItem: (NSMenuItem *)menuItem
{
	if ( self = [super init] )
	{
		mMenuItem = menuItem; // weak reference
	}
	return self;
}


- (NSMenuItem *)menuItem
{  return mMenuItem;  }


- (void)makeActive: (BOOL)active forKeyEquivalent: (KeyEquivalent *)keyEquivalent
{
	if (active)
	{
		[mMenuItem setKeyEquivalent: [keyEquivalent characters]];
		[mMenuItem setKeyEquivalentModifierMask: [keyEquivalent modifiers]];
	}
	else
	{
		[mMenuItem setKeyEquivalent: @""];
		[mMenuItem setKeyEquivalentModifierMask: 0];
	}
}


- (BOOL)isEqualToEntry: (KeyEquivalentEntry *)x
{
	
	if ( self == x )
		return YES;
	NSString *thisTitle = [mMenuItem title];
	NSString *otherTitle = x ? [x->mMenuItem title] : nil;
	if ( thisTitle && otherTitle )
		return [thisTitle isEqualToString: otherTitle];
	return thisTitle == otherTitle;
}


- (NSString *)description
{
	if ( mMenuItem )
		return [mMenuItem title];
	return @"undefined";
}

@end
