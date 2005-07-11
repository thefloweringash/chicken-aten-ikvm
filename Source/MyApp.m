//
//  MyApp.m
//  Chicken of the VNC
//
//  Created by Jason Harris on 12/8/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "MyApp.h"
#import "KeyEquivalentManager.h"
#import "RFBConnection.h"
#import "RFBView.h"


@implementation MyApp

- (void)sendEvent:(NSEvent *)anEvent
{
	/*
	 * The idea here is to be able to grab command-keys as NSKeyDown and NSKeyUp events. 
	 * Under normal operation, we can't do that - our front view just gets a single 
	 * performKeyEquivalent message, which isn't too cool.  So we grab the events here and 
	 * route 'em ourself.  The secondary goal is to pass key equivalents off to the 
	 * KeyEquivalentManger here, so we can get valid key equivalents before they get into 
	 * the RFBView and RFBConnection toolchain.
	 */
	
	// do some static lookups for a tiny speed gain
	static Class RFBViewClass = nil;
	static Class NSScrollViewClass = nil;
	if ( ! RFBViewClass )
	{
		RFBViewClass = [RFBView class];
		NSScrollViewClass = [NSScrollView class];
	}

	// if the frontmost window isn't a VNC connection, let's just skip all this and let things
	// proceed normally.  Note that if we add new scenarios at some point, we might need to 
	// change this.
	KeyEquivalentManager *keyManager = [KeyEquivalentManager defaultManager];
	NSString *currentScenario = [keyManager currentScenarioName];
	if ( currentScenario && ! [currentScenario isEqualToString: kNonConnectionWindowFrontmostScenario] )
	{
		// we only care about keyboard events.  flagsChanged events get passed fine, so we'll 
		// let them be handled normally.
		NSEventType eventType = [anEvent type];
		if ( NSKeyDown == eventType || NSKeyUp == eventType )
		{
			RFBView *rfbView = [keyManager keyRFBView];;
			NSParameterAssert( rfbView != nil );
			static NSString *lastCharacters = nil;
			NSString *characters = [anEvent charactersIgnoringModifiers];
			
			// if it's an NSKeyDown, we either treat it as a key equivalent, or pass it to 
			// our view as a keyDown: event.
			if ( NSKeyDown == eventType )
			{
				unsigned int modifiers = [anEvent modifierFlags] & 0xFFFF0000;
				
				[lastCharacters autorelease];
				lastCharacters = nil;
				if ( [keyManager performEquivalentWithCharacters: characters modifiers: modifiers] )
				{
					lastCharacters = [characters retain];
					RFBConnection *delegate = [rfbView delegate];
					[delegate clearAllEmulationStates];
				}
				else
				{
					[rfbView keyDown: anEvent];
				}
			}
			
			// if it's an NSKeyUp that corresponds to a key equivalent, we dump it - it's 
			// already been handled.
			else if ( lastCharacters && [lastCharacters isEqualToString: characters] )
			{
				[lastCharacters autorelease];
				lastCharacters = nil;
				return;
			}
			
			// otherwise, it's an NSKeyUp that needs to be handled by our view
			else
			{
				[rfbView keyUp: anEvent];
			}
			return;
		}
	}
	
	[super sendEvent: anEvent];
}

@end
