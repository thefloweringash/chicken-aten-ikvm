//
//  EventFilter.m
//  Chicken of the VNC
//
//  Created by Jason Harris on 7/1/05.
//  Copyright 2005 Geekspiff. All rights reserved.
//

#import "EventFilter.h"
#import "KeyEquivalentManager.h"
#import "Profile.h"
#import "QueuedEvent.h"
#import "RFBConnection.h"
#import "RFBView.h"


static inline unsigned int
ButtonNumberToArrayIndex( unsigned int buttonNumber )
{
	NSCParameterAssert( buttonNumber == 2 || buttonNumber == 3 );
	return buttonNumber - 2;
}


static inline unsigned int
ButtonNumberToRFBButtomMask( unsigned int buttonNumber )
{  return 1 << (buttonNumber-1);  }


@implementation EventFilter

#pragma mark Creation/Destruction

- (void)_resetMultiTapTimer: (NSTimer *)timer
{
	[_multiTapTimer invalidate];
	[_multiTapTimer release];
	_multiTapTimer = nil;
	if ( timer )
	{
//		NSLog(@"resetting multi-tap timer");
		[self sendAllPendingQueueEntriesNow];
	}
}


- (void)_resetTapModifierAndClick: (NSTimer *)timer
{
	[_tapAndClickTimer invalidate];
	[_tapAndClickTimer release];
	_tapAndClickTimer = nil;
	[_view setCursorTo: @"rfbCursor"];
	if ( timer )
		[self sendAllPendingQueueEntriesNow];
}


- (void)_updateCapsLockStateIfNecessary
{
	if ( _watchEventForCapsLock )
	{
		_watchEventForCapsLock = NO;
		NSEvent *currentEvent = [NSApp currentEvent];
		unsigned int modifierFlags = [currentEvent modifierFlags];
		if ( (NSAlphaShiftKeyMask & modifierFlags) != (NSAlphaShiftKeyMask & _pressedModifiers) )
			[self flagsChanged: currentEvent];
	}
}


- (id)init
{
	if ( self = [super init] )
	{
		_pendingEvents = [[NSMutableArray alloc] init];
		_pressedKeys = [[NSMutableSet alloc] init];
		_emulationButton = 1;
		
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(applicationDidBecomeActive:) name: NSApplicationDidBecomeActiveNotification object: nil];
	}
	return self;
}


- (void)dealloc
{
	[self _resetMultiTapTimer: nil];
	[self _resetTapModifierAndClick: nil];
	[self sendAllPendingQueueEntriesNow];
	[self synthesizeRemainingEvents];
	[self sendAllPendingQueueEntriesNow];
	[_pendingEvents release];
	[_pressedKeys release];
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}


#pragma mark -
#pragma mark Talking to the server


- (RFBConnection *)connection
{  return _connection;  }

- (void)setConnection: (RFBConnection *)connection
{
	_connection = connection;
	_viewOnly = [connection viewOnly];
	
	Profile *profile = [connection profile];
	if ( profile )
	{
		[self setButton2EmulationScenario: [profile button2EmulationScenario]];
		[self setButton3EmulationScenario: [profile button3EmulationScenario]];
	}
}


- (RFBView *)view
{  return _view;  }


- (void)setView: (RFBView *)view
{  _view = view;  }


#pragma mark -
#pragma mark Local Mouse Events


- (void)mouseDown: (NSEvent *)theEvent
{  [self queueMouseDownEventFromEvent: theEvent buttonNumber: 1];  }


- (void)mouseUp: (NSEvent *)theEvent
{  [self queueMouseUpEventFromEvent: theEvent buttonNumber: 1];  }


- (void)rightMouseDown: (NSEvent *)theEvent
{  [self queueMouseDownEventFromEvent: theEvent buttonNumber: 3];  }


- (void)rightMouseUp: (NSEvent *)theEvent
{  [self queueMouseUpEventFromEvent: theEvent buttonNumber: 3];  }


- (void)otherMouseDown: (NSEvent *)theEvent
{
	if ( 2 == [theEvent buttonNumber] )
		[self queueMouseDownEventFromEvent: theEvent buttonNumber: 2];
}


- (void)otherMouseUp: (NSEvent *)theEvent
{
	if ( 2 == [theEvent buttonNumber] )
		[self queueMouseUpEventFromEvent: theEvent buttonNumber: 2];
}


- (void)scrollWheel: (NSEvent *)theEvent
{
	if ( _viewOnly )
		return;

	[self sendAllPendingQueueEntriesNow];
	int addMask;
    NSPoint	p = [_view convertPoint: [[_view window] convertScreenToBase: [NSEvent mouseLocation]] 
						  fromView: nil];
    if ( [theEvent deltaY] > 0.0 )
		addMask = rfbButton4Mask;
	else
		addMask = rfbButton5Mask;
    [_connection mouseAt: p buttons: _pressedButtons | addMask];	// 'Mouse button down'
    [_connection mouseAt: p buttons: _pressedButtons];			// 'Mouse button up'
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	if ( _viewOnly )
		return;

	// send this out of order, in front of anything we've got pending
    NSPoint	p = [_view convertPoint: [theEvent locationInWindow] fromView: nil];
    [_connection mouseAt: p buttons: _pressedButtons];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if ( _viewOnly )
		return;

	// getting this implies that we've gotten a mouse down, so we can just send it directly
    NSPoint	p = [_view convertPoint: [theEvent locationInWindow] fromView: nil];
    [_connection mouseAt: p buttons: _pressedButtons];
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
	if ( _viewOnly )
		return;

	// getting this implies that we've gotten a mouse down, so we can just send it directly
    NSPoint	p = [_view convertPoint: [theEvent locationInWindow] fromView: nil];
    [_connection mouseAt: p buttons: _pressedButtons];
}

- (void)otherMouseDragged:(NSEvent *)theEvent
{
	if ( _viewOnly )
		return;

	// getting this implies that we've gotten a mouse down, so we can just send it directly
	if ( 2 == [theEvent buttonNumber] )
	{
		NSPoint	p = [_view convertPoint: [theEvent locationInWindow] fromView: nil];
		[_connection mouseAt: p buttons: _pressedButtons];
	}
}


#pragma mark -
#pragma mark Local Keyboard Events


- (void)keyDown: (NSEvent *)theEvent
{
	[self _updateCapsLockStateIfNecessary];
	NSString *characters = [theEvent characters];
	NSString *charactersIgnoringModifiers = [theEvent charactersIgnoringModifiers];
	
	unsigned int modifiers = [theEvent modifierFlags];
	if ( [[KeyEquivalentManager defaultManager] performEquivalentWithCharacters: characters modifiers: modifiers] )
	{
		[self discardAllPendingQueueEntries];
		return;
	}
	
	unsigned int i, charLength = [characters length];
	unsigned int unmodLength = [charactersIgnoringModifiers length];
	unsigned int length = unmodLength > charLength ? unmodLength : charLength;
	
	NSParameterAssert( characters && charactersIgnoringModifiers );
	NSParameterAssert( charLength <= unmodLength );
	
	for ( i = 0; i < length; ++i )
	{
		unichar character;
		unichar characterIgnoringModifiers;
		
		if ( i < charLength )
			character = [characters characterAtIndex: i];
		else
			character = [charactersIgnoringModifiers characterAtIndex: i];
		
		if ( i < unmodLength )
			characterIgnoringModifiers = [charactersIgnoringModifiers characterAtIndex: i];
		else
			characterIgnoringModifiers = [characters characterAtIndex: i];
		
		QueuedEvent *event = [QueuedEvent keyDownEventWithCharacter: character
										 characterIgnoringModifiers: characterIgnoringModifiers
														  timestamp: [theEvent timestamp]];
		[_pendingEvents addObject: event];
		[self sendAnyValidEventsToServerNow];
	}
}

- (void)keyUp: (NSEvent *)theEvent
{
	[self _updateCapsLockStateIfNecessary];
	NSString *characters = [theEvent characters];
	NSString *charactersIgnoringModifiers = [theEvent charactersIgnoringModifiers];
	
	unsigned int i, charLength = [characters length];
	unsigned int unmodLength = [charactersIgnoringModifiers length];
	unsigned int length = unmodLength > charLength ? unmodLength : charLength;

	NSParameterAssert( characters && charactersIgnoringModifiers );
	NSParameterAssert( charLength <= unmodLength );
	
	for ( i = 0; i < length; ++i )
	{
		unichar character;
		unichar characterIgnoringModifiers;
		
		if ( i < charLength )
			character = [characters characterAtIndex: i];
		else
			character = [charactersIgnoringModifiers characterAtIndex: i];
		
		if ( i < unmodLength )
			characterIgnoringModifiers = [charactersIgnoringModifiers characterAtIndex: i];
		else
			characterIgnoringModifiers = [characters characterAtIndex: i];
		
		QueuedEvent *event = [QueuedEvent keyUpEventWithCharacter: character
									   characterIgnoringModifiers: characterIgnoringModifiers
														timestamp: [theEvent timestamp]];
		[_pendingEvents addObject: event];
		[self sendAnyValidEventsToServerNow];
	}
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	unsigned int newState = [theEvent modifierFlags];
    newState = ~(~newState | 0xFFFF);
	unsigned int changedState = newState ^ _queuedModifiers;
	NSTimeInterval timestamp = [theEvent timestamp];
	_queuedModifiers = newState;
	
	if ( NSShiftKeyMask & changedState )
	{
		if ( NSShiftKeyMask & newState )
			[self queueModifierPressed: NSShiftKeyMask timestamp: timestamp];
		else
			[self queueModifierReleased: NSShiftKeyMask timestamp: timestamp];
	}
	if ( NSControlKeyMask & changedState )
	{
		if ( NSControlKeyMask & newState )
			[self queueModifierPressed: NSControlKeyMask timestamp: timestamp];
		else
			[self queueModifierReleased: NSControlKeyMask timestamp: timestamp];
	}
	if ( NSAlternateKeyMask & changedState )
	{
		if ( NSAlternateKeyMask & newState )
			[self queueModifierPressed: NSAlternateKeyMask timestamp: timestamp];
		else
			[self queueModifierReleased: NSAlternateKeyMask timestamp: timestamp];
	}
	if ( NSCommandKeyMask & changedState )
	{
		if ( NSCommandKeyMask & newState )
			[self queueModifierPressed: NSCommandKeyMask timestamp: timestamp];
		else
			[self queueModifierReleased: NSCommandKeyMask timestamp: timestamp];
	}
	if ( NSAlphaShiftKeyMask & changedState )
	{
		if ( NSAlphaShiftKeyMask & newState )
			[self queueModifierPressed: NSAlphaShiftKeyMask timestamp: timestamp];
		else
			[self queueModifierReleased: NSAlphaShiftKeyMask timestamp: timestamp];
	}
	if ( NSNumericPadKeyMask & changedState )
	{
		if ( NSNumericPadKeyMask & newState )
			[self queueModifierPressed: NSNumericPadKeyMask timestamp: timestamp];
		else
			[self queueModifierReleased: NSNumericPadKeyMask timestamp: timestamp];
	}
	if ( NSHelpKeyMask & changedState )
	{
		if ( NSHelpKeyMask & newState )
			[self queueModifierPressed: NSHelpKeyMask timestamp: timestamp];
		else
			[self queueModifierReleased: NSHelpKeyMask timestamp: timestamp];
	}
}


#pragma mark -
#pragma mark Synthesized Events


- (void)clearAllEmulationStates
{
	[self sendAllPendingQueueEntriesNow];
	_emulationButton = 1;
	_clickWhileHoldingModifierStillDown[0] = NO;
	_clickWhileHoldingModifierStillDown[1] = NO;
	[self _resetMultiTapTimer: nil];
	[self _resetTapModifierAndClick: nil];
}


- (void)_queueEmulatedMouseDownForButton: (unsigned int) button basedOnEvent: (QueuedEvent *)event
{
	_emulationButton = button;
	QueuedEvent *mousedown = [QueuedEvent mouseDownEventForButton: _emulationButton
														 location: [event locationInWindow]
														timestamp: [event timestamp]];
	[_pendingEvents addObject: mousedown];
}


- (void)queueMouseDownEventFromEvent: (NSEvent *)theEvent buttonNumber: (unsigned int)button
{
	if ( 1 != _emulationButton )
		[self queueMouseUpEventFromEvent: theEvent buttonNumber: _emulationButton];
	
    NSPoint	p = [_view convertPoint: [theEvent locationInWindow] fromView: nil];
	QueuedEvent *event = [QueuedEvent mouseDownEventForButton: button
													 location: p
													timestamp: [theEvent timestamp]];
	[_pendingEvents addObject: event];
	[self sendAnyValidEventsToServerNow];
}


- (void)queueMouseUpEventFromEvent: (NSEvent *)theEvent buttonNumber: (unsigned int)button
{
	if ( 1 != _emulationButton )
	{
		button = _emulationButton;
		_emulationButton = 1;
	}
	
    NSPoint	p = [_view convertPoint: [theEvent locationInWindow] fromView: nil];
	QueuedEvent *event = [QueuedEvent mouseUpEventForButton: button
												   location: p
												  timestamp: [theEvent timestamp]];
	[_pendingEvents addObject: event];
	[self sendAnyValidEventsToServerNow];
}


- (void)queueModifierPressed: (unsigned int)modifier timestamp: (NSTimeInterval)timestamp
{
	QueuedEvent *event = [QueuedEvent modifierDownEventWithCharacter: modifier
													  timestamp: timestamp];
	[_pendingEvents addObject: event];
	[self sendAnyValidEventsToServerNow];
}


- (void)queueModifierReleased: (unsigned int)modifier timestamp: (NSTimeInterval)timestamp
{
	if ( kClickWhileHoldingModifierEmulation == _buttonEmulationScenario[0] 
		 && _clickWhileHoldingModifierStillDown[0] 
		 && modifier == _clickWhileHoldingModifier[0] )
	{
		_clickWhileHoldingModifierStillDown[0] = NO;
	}
	if ( kClickWhileHoldingModifierEmulation == _buttonEmulationScenario[1] 
		 && _clickWhileHoldingModifierStillDown[1] 
		 && modifier == _clickWhileHoldingModifier[1] )
	{
		_clickWhileHoldingModifierStillDown[1] = NO;
	}
	
	QueuedEvent *event = [QueuedEvent modifierUpEventWithCharacter: modifier
													timestamp: timestamp];
	[_pendingEvents addObject: event];
	[self sendAnyValidEventsToServerNow];
}


- (void)pasteString: (NSString *)string
{
	[self _updateCapsLockStateIfNecessary];
	int index, strLength = [string length];
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	
	[self clearAllEmulationStates];
	BOOL capsLockWasPressed = (_pressedModifiers & NSAlphaShiftKeyMask) ? YES : NO;
	
	for ( index = 0; index < strLength; ++index )
	{
		unichar character = [string characterAtIndex: index];
		
		// hack - lets' be polite to the server
		if ( '\n' == character )
			character = '\r';
		
		QueuedEvent *event = [QueuedEvent keyDownEventWithCharacter: character
										 characterIgnoringModifiers: character
														  timestamp: now];
		[_pendingEvents addObject: event];
		event = [QueuedEvent keyUpEventWithCharacter: character
						  characterIgnoringModifiers: character
										   timestamp: now];
		[_pendingEvents addObject: event];
	}
	
	[self sendAllPendingQueueEntriesNow];
	if ( capsLockWasPressed )
		_pressedModifiers |= NSAlphaShiftKeyMask;
}


- (void)applicationDidBecomeActive: (NSNotification *)notification
{  _watchEventForCapsLock = YES;  }


#pragma mark -
#pragma mark Event Processing


- (unsigned int)_sendAnyValidEventsToServerForButton: (unsigned int)button 
									scenario: (EventFilterEmulationScenario)scenario
{
	unsigned int eventsToDelay = 0;
	switch (scenario)
	{
		case kNoMouseButtonEmulation:
			break;
		case kClickWhileHoldingModifierEmulation:
			eventsToDelay = [self handleClickWhileHoldingForButton: button];
			break;
		case kMultiTapModifierEmulation:
			eventsToDelay = [self handleMultiTapForButton: button];
			break;
		case kTapModifierAndClickEmulation:
			eventsToDelay = [self handleTapModifierAndClickForButton: button];
			break;
		default:
			[NSException raise: NSInternalInconsistencyException format: @"unsupported emulation scenario %d for button %d", (int)scenario, button];
	}
	return eventsToDelay;
}


- (void)sendAnyValidEventsToServerNow
{
	unsigned int eventsToDelay2;
	unsigned int eventsToDelay3;
	
	eventsToDelay2 = [self _sendAnyValidEventsToServerForButton: 2 scenario: _buttonEmulationScenario[0]];
	eventsToDelay3 = [self _sendAnyValidEventsToServerForButton: 3 scenario: _buttonEmulationScenario[1]];
	
	unsigned int eventsToDelay = eventsToDelay3 > eventsToDelay2 ? eventsToDelay3 : eventsToDelay2;
	if ( eventsToDelay )
	{
		unsigned int pendingEvents = [_pendingEvents count];
		if ( eventsToDelay < pendingEvents )
		{
			NSRange range = NSMakeRange( 0, pendingEvents - eventsToDelay );
			[self sendPendingQueueEntriesInRange: range];
		}
	}
	else
		[self sendAllPendingQueueEntriesNow];
}


- (void)_sendMouseEvent: (QueuedEvent *)event
{
	unsigned int oldPressedButtons = _pressedButtons;
	
	switch ([event type])
	{
		case kQueuedMouse1DownEvent:
			_pressedButtons |= rfbButton1Mask;
			break;
		case kQueuedMouse1UpEvent:
			if ( _pressedButtons & rfbButton1Mask )
				_pressedButtons &= ~rfbButton1Mask;
			break;
		case kQueuedMouse2DownEvent:
			_pressedButtons |= rfbButton2Mask;
			break;
		case kQueuedMouse2UpEvent:
			if ( _pressedButtons & rfbButton2Mask )
				_pressedButtons &= ~rfbButton2Mask;
			break;
		case kQueuedMouse3DownEvent:
			_pressedButtons |= rfbButton3Mask;
			break;
		case kQueuedMouse3UpEvent:
			if ( _pressedButtons & rfbButton3Mask )
				_pressedButtons &= ~rfbButton3Mask;
			break;
		default:
			[NSException raise: NSInternalInconsistencyException format: @"unsupported event type"];
	}
	
	if ( _pressedButtons != oldPressedButtons )
		[_connection mouseAt: [event locationInWindow] buttons: _pressedButtons];
}


- (void)_sendKeyEvent: (QueuedEvent *)event
{
	unichar character = [event character];
	unichar characterIgnoringModifiers = [event characterIgnoringModifiers];
	NSNumber *encodedChar = [NSNumber numberWithInt: (int)characterIgnoringModifiers];
	unichar sendKey;
	
	// turns out that servers seem to ignore any keycodes over 128.  so no point in 
	// sending 'em.  Also, turns out that RealVNC doesn't track the status of the capslock
	// key.  So, I'll repurpose 'character' here to be the shifted character, if needed.
	// 
	// I'll maintain state of the unmodified character because, for example, if you set 
	// caps lock and then keyrepeat something and unset caps lock while you're doing it, 
	// the key up character will be for the lowercase letter.
	if ( NSAlphaShiftKeyMask & _pressedModifiers )
		character = toupper(characterIgnoringModifiers);
	else
		character = characterIgnoringModifiers;
	sendKey = character;
	
	if ( kQueuedKeyDownEvent == [event type] )
	{
		[_pressedKeys addObject: encodedChar];
		[_connection sendKey: sendKey pressed: YES];
	}
	else if ( [_pressedKeys containsObject: encodedChar] )
	{
		[_pressedKeys removeObject: encodedChar];
		[_connection sendKey: sendKey pressed: NO];
	}
}


- (void)_sendModifierEvent: (QueuedEvent *)event
{
	unsigned int modifier = [event modifier];
	
	if ( kQueuedModifierDownEvent == [event type] )
	{
		_pressedModifiers |= modifier;
		[_connection sendModifier: modifier pressed: YES];
	}
	else if ( _pressedModifiers & modifier )
	{
		_pressedModifiers &= ~modifier;
		[_connection sendModifier: modifier pressed: NO];
	}
}


- (void)_sendEvent: (QueuedEvent *)event
{
	if ( _viewOnly )
		return;
	
	QueuedEventType eventType = [event type];
	
	if ( eventType <= kQueuedMouse3UpEvent )
		[self _sendMouseEvent: event];
	else if ( eventType <= kQueuedKeyUpEvent )
		[self _sendKeyEvent: event];
	else
		[self _sendModifierEvent: event];
}


- (void)sendAllPendingQueueEntriesNow
{
	NSEnumerator *eventEnumerator = [_pendingEvents objectEnumerator];
	QueuedEvent *event;
	
	while ( event = [eventEnumerator nextObject] )
		[self _sendEvent: event]; // this sets stuff like _pressedKeyes, _pressedButtons, etc.
	[self discardAllPendingQueueEntries];
}


- (void)sendPendingQueueEntriesInRange: (NSRange)range
{
	unsigned int i, last = NSMaxRange(range);
	
	for ( i = range.location; i < last; ++i )
	{
		QueuedEvent *event = [_pendingEvents objectAtIndex: i];
		[self _sendEvent: event];
	}
	[_pendingEvents removeObjectsInRange: range];
}


- (void)discardAllPendingQueueEntries
{  [_pendingEvents removeAllObjects];  }


- (void)_synthesizeRemainingMouseUpEvents
{
	NSPoint p = NSZeroPoint;
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	
	if ( rfbButton1Mask && _pressedButtons )
	{
		QueuedEvent *event = [QueuedEvent mouseUpEventForButton: 1
													   location: p
													  timestamp: now];
		[_pendingEvents addObject: event];
	}
	if ( rfbButton2Mask && _pressedButtons )
	{
		QueuedEvent *event = [QueuedEvent mouseUpEventForButton: 2
													   location: p
													  timestamp: now];
		[_pendingEvents addObject: event];
	}
	if ( rfbButton3Mask && _pressedButtons )
	{
		QueuedEvent *event = [QueuedEvent mouseUpEventForButton: 3
													   location: p
													  timestamp: now];
		[_pendingEvents addObject: event];
	}
	if ( rfbButton4Mask && _pressedButtons )
	{
		QueuedEvent *event = [QueuedEvent mouseUpEventForButton: 4
													   location: p
													  timestamp: now];
		[_pendingEvents addObject: event];
	}
	if ( rfbButton5Mask && _pressedButtons )
	{
		QueuedEvent *event = [QueuedEvent mouseUpEventForButton: 5
													   location: p
													  timestamp: now];
		[_pendingEvents addObject: event];
	}
}


- (void)_synthesizeRemainingKeyUpEvents
{
	NSEnumerator *keyEnumerator = [_pressedKeys objectEnumerator];
	NSNumber *encodedKey;
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	
	while ( encodedKey = [keyEnumerator nextObject] )
	{
		unichar character = (unichar) [encodedKey intValue];
		QueuedEvent *event = [QueuedEvent keyUpEventWithCharacter: character
									   characterIgnoringModifiers: character
														timestamp: now];
		[_pendingEvents addObject: event];
	}
}


- (void)_synthesizeRemainingModifierUpEvents
{
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	
	if ( NSShiftKeyMask && _pressedModifiers )
	{
		QueuedEvent *event = [QueuedEvent modifierUpEventWithCharacter: NSShiftKeyMask
															 timestamp: now];
		[_pendingEvents addObject: event];
	}
	if ( NSControlKeyMask && _pressedModifiers )
	{
		QueuedEvent *event = [QueuedEvent modifierUpEventWithCharacter: NSControlKeyMask
															 timestamp: now];
		[_pendingEvents addObject: event];
	}
	if ( NSAlternateKeyMask && _pressedModifiers )
	{
		QueuedEvent *event = [QueuedEvent modifierUpEventWithCharacter: NSAlternateKeyMask
															 timestamp: now];
		[_pendingEvents addObject: event];
	}
	if ( NSCommandKeyMask && _pressedModifiers )
	{
		QueuedEvent *event = [QueuedEvent modifierUpEventWithCharacter: NSCommandKeyMask
															 timestamp: now];
		[_pendingEvents addObject: event];
	}
}


- (void)synthesizeRemainingEvents
{
	[self _synthesizeRemainingMouseUpEvents];
	[self _synthesizeRemainingKeyUpEvents];
	[self _synthesizeRemainingModifierUpEvents];
}


- (unsigned int)handleClickWhileHoldingForButton: (unsigned int)button
{
	int eventCount = [_pendingEvents count];
	if ( eventCount > 2 )
		return 0;
	
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	
	if ( eventCount == 2 )
	{
		QueuedEvent *event1 = [_pendingEvents objectAtIndex: 0];
		
		if ( kQueuedModifierDownEvent == [event1 type] 
			 && _clickWhileHoldingModifier[buttonIndex] == [event1 modifier] )
		{
			QueuedEvent *event2 = [_pendingEvents objectAtIndex: 1];
			
			if ( kQueuedMouse1DownEvent == [event2 type] )
			{
				[[event2 retain] autorelease];
				[self discardAllPendingQueueEntries];
				[self _queueEmulatedMouseDownForButton: button basedOnEvent: event2];
				_clickWhileHoldingModifierStillDown[buttonIndex] = YES;
				return 0;
			}
		}
	}
	
	if ( eventCount == 1 )
	{
		QueuedEvent *event = [_pendingEvents objectAtIndex: 0];

		if ( kQueuedModifierDownEvent == [event type] 
			 && _clickWhileHoldingModifier[buttonIndex] == [event modifier] )
		{
			return 1;
		}
		else if ( YES == _clickWhileHoldingModifierStillDown[buttonIndex] 
				  && kQueuedMouse1DownEvent == [event type] )
		{
			[[event retain] autorelease];
			[self discardAllPendingQueueEntries];
			[self _queueEmulatedMouseDownForButton: button basedOnEvent: event];
			return 0;
		}
	}
	
	return 0;
}


- (unsigned int)handleMultiTapForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	NSEnumerator *eventEnumerator = [_pendingEvents objectEnumerator];
	QueuedEvent *event;
	unsigned int validEvents = 0;
	
	[self _resetMultiTapTimer: nil];

	while ( event = [eventEnumerator nextObject] )
	{
		QueuedEventType eventType = [event type];
		unsigned int modifier = [event modifier];
		
		if ( _multipTapModifier[buttonIndex] != modifier )
			return 0;
		
		if ( 0 == validEvents % 2 )
		{
			if ( kQueuedModifierDownEvent != eventType )
				return 0;
			validEvents++;
		}
		else
		{
			if ( kQueuedModifierUpEvent != eventType )
				return 0;
			validEvents++;
			if ( validEvents / 2 == _multipTapCount[buttonIndex] )
			{
				[self discardAllPendingQueueEntries];
				NSPoint	p = [_view convertPoint: [[_view window] convertScreenToBase: [NSEvent mouseLocation]] 
									  fromView: nil];
				unsigned int rfbButton = ButtonNumberToRFBButtomMask( button );
				[_connection mouseAt: p buttons: _pressedButtons | rfbButton];	// 'Mouse button down'
				[_connection mouseAt: p buttons: _pressedButtons];				// 'Mouse button up'
				return 0;
			}
		}
	}
	
	if ( validEvents && (validEvents % 2 == 0) )
	{
		_multiTapTimer = [[NSTimer scheduledTimerWithTimeInterval: _multipTapDelay[buttonIndex] target: self selector: @selector(_resetMultiTapTimer:) userInfo: nil repeats: NO] retain];
//		NSLog(@"starting multi-tap timer");
	}
	
	return validEvents;
}


- (unsigned int)handleTapModifierAndClickForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	int eventIndex, eventCount = [_pendingEvents count];
	NSTimeInterval time1, time2;
	
	for ( eventIndex = 0; eventIndex < eventCount; ++eventIndex )
	{
		QueuedEvent *event = [_pendingEvents objectAtIndex: eventIndex];
		QueuedEventType eventType = [event type];
		unsigned int modifier = [event modifier];
		
		if ( 0 == eventIndex )
		{
			if ( ! (kQueuedModifierDownEvent == eventType && modifier == _tapAndClickModifier[buttonIndex]) )
				return 0;
			time1 = [event timestamp];
		}
		
		else if ( 1 == eventIndex )
		{
			if ( ! (kQueuedModifierUpEvent == eventType && modifier == _tapAndClickModifier[buttonIndex]) )
				return 0;
			time2 = [event timestamp];
			if ( time2 - time1 > _tapAndClickButtonSpeed[buttonIndex] )
				return 0;

			if ( ! _tapAndClickTimer )
			{
				_tapAndClickTimer = [[NSTimer scheduledTimerWithTimeInterval: _tapAndClickTimeout[buttonIndex] target: self selector: @selector(_resetTapModifierAndClick:) userInfo: nil repeats: NO] retain];
				[_view setCursorTo: (button == 2) ? @"rfbCursor2" : @"rfbCursor3"];
			}
		}
		
		else if ( 2 == eventIndex )
		{
			if ( kQueuedKeyDownEvent == eventType && '\e' == [event character] )
			{
				[self discardAllPendingQueueEntries];
				[self _resetTapModifierAndClick: nil];
				return 0;
			}
			
			if ( kQueuedMouse1DownEvent != eventType )
			{
				[self _resetTapModifierAndClick: nil];
				return 0;
			}
			
			[[event retain] autorelease];
			[self discardAllPendingQueueEntries];
			[self _queueEmulatedMouseDownForButton: button basedOnEvent: event];
			[self _resetTapModifierAndClick: nil];
			return 0;
		}
	}

	return eventCount;
}


#pragma mark -
#pragma mark Configuration


- (void)_updateConfigurationForButton: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	Profile *profile = [_connection profile];
	
	switch (_buttonEmulationScenario[buttonIndex])
	{
		case kNoMouseButtonEmulation:
			break;
		case kClickWhileHoldingModifierEmulation:
			[self setClickWhileHoldingModifier: [profile clickWhileHoldingModifierForButton: button] button: button];
			break;
		case kMultiTapModifierEmulation:
			[self setMultiTapModifier: [profile multiTapModifierForButton: button] button: button];
			[self setMultiTapDelay: [profile multiTapDelayForButton: button] button: button];
			[self setMultiTapCount: [profile multiTapCountForButton: button] button: button];
			break;
		case kTapModifierAndClickEmulation:
			[self setTapAndClickModifier: [profile tapAndClickModifierForButton: button] button: button];
			[self setTapAndClickButtonSpeed: [profile tapAndClickButtonSpeedForButton: button] button: button];
			[self setTapAndClickTimeout: [profile tapAndClickTimeoutForButton: button] button: button];
			break;
		default:
			[NSException raise: NSInternalInconsistencyException format: @"unsupported emulation scenario for button %d", button];
	}
}


- (void)setButton2EmulationScenario: (EventFilterEmulationScenario)scenario
{
	_buttonEmulationScenario[0] = scenario;
	if ( _viewOnly )
		_buttonEmulationScenario[0] = kNoMouseButtonEmulation;
	[self _updateConfigurationForButton: 2];
}


- (void)setButton3EmulationScenario: (EventFilterEmulationScenario)scenario
{
	_buttonEmulationScenario[1] = scenario;
	if ( _viewOnly )
		_buttonEmulationScenario[1] = kNoMouseButtonEmulation;
	[self _updateConfigurationForButton: 3];
}


- (void)setClickWhileHoldingModifier: (unsigned int)modifier button: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	_clickWhileHoldingModifier[buttonIndex] = modifier;
}


- (void)setMultiTapModifier: (unsigned int)modifier button: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	_multipTapModifier[buttonIndex] = modifier;
}


- (void)setMultiTapDelay: (NSTimeInterval)delay button: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	_multipTapDelay[buttonIndex] = delay;
}


- (void)setMultiTapCount: (unsigned int)count button: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	_multipTapCount[buttonIndex] = count;
}


- (void)setTapAndClickModifier: (unsigned int)modifier button: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	_tapAndClickModifier[buttonIndex] = modifier;
}


- (void)setTapAndClickButtonSpeed: (NSTimeInterval)speed button: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	_tapAndClickButtonSpeed[buttonIndex] = speed;
}


- (void)setTapAndClickTimeout: (NSTimeInterval)timeout button: (unsigned int)button
{
	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	_tapAndClickTimeout[buttonIndex] = timeout;
}

@end
