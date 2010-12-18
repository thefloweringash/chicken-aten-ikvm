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

/* The basic path of an event through this system is as follows (this ignores
 * any emulation scenarios which might be triggered):
    - First the mouseDown, keyDown, etc. message is invoked.
    - This creates a QueuedEvent and adds it to _pendingQueue, possibly by
      calling a queue... message.
    - Then sendAnyValidEventsToServerNow checks the queued events against
      possible emulations scenarios. This step is sometimes skipped.
    - The sendAllPendingQueueEntriesNow and sendPendingQueueEntriesInRange:
      methods are call sendEvent: with the QueuedEvent instance.
    - The sendEvent: message dispatches the event to send... messages.
    - The send... messages call send.. or mouse(Clicked)At: in RFBConnection.
    - The methods in RFBConnection have responsibility for translating Cocoa
      representations of characters and modifiers to RFB key symbols and
      packaging the event in a RFB message.
    - With the exception of mouseAt:, the messages sent to RFBConnection only
      buffer the messages, so writeBuffer is sent in write this data. */

#define SCROLL_THRESH 1.0

static inline unsigned int
ButtonNumberToArrayIndex( unsigned int buttonNumber )
{
	NSCParameterAssert( buttonNumber == 2 || buttonNumber == 3 );
	return buttonNumber - 2;
}


static inline unsigned int
ButtonNumberToRFBButtomMask( unsigned int buttonNumber )
{  return 1 << (buttonNumber-1);  }

@interface EventFilter (Private)

- (void)_synthesizeRemainingKeyUpEvents;
- (void)_sendKeyEvent:(QueuedEvent *)event;

@end

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
        [_connection writeBuffer];
	}
}


- (void)_resetTapModifierAndClick: (NSTimer *)timer
{
	[_tapAndClickTimer invalidate];
	[_tapAndClickTimer release];
	_tapAndClickTimer = nil;
	[_view setCursorTo: nil];
	if ( timer ) {
		[self sendAllPendingQueueEntriesNow];
        [_connection writeBuffer];
	}
}


/* Checks to see if caps lock has been pressed while we were not the active
 * application, in which case we wouldn't have received a flagsChanged: message.
 * */
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
    [_connection writeBuffer];

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
    _profile = [connection profile];
	_viewOnly = [connection viewOnly];
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
	int addMask;

	if ( _viewOnly )
		return;

    // touchpads can generate lots of scroll events with deltaY close to 0,
    // which we ignore
    if ( [theEvent deltaY] > SCROLL_THRESH )
		addMask = rfbButton4Mask;
	else if ( [theEvent deltaY] < -SCROLL_THRESH )
		addMask = rfbButton5Mask;
    else
        return;

	[self sendAllPendingQueueEntriesNow];
    NSPoint	p = [_view convertPoint: [[_view window] convertScreenToBase: [NSEvent mouseLocation]] 
						  fromView: nil];

    [_connection mouseClickedAt: p buttons: _pressedButtons | addMask];	// 'Mouse button down'
    [_connection mouseClickedAt: p buttons: _pressedButtons];			// 'Mouse button up'
    [_connection writeBuffer];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    if (_viewOnly)
        return;

	NSPoint currentPoint = [_view convertPoint: [theEvent locationInWindow] fromView: nil];
    [_connection mouseAt: currentPoint buttons: _pressedButtons];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	[self mouseMoved:theEvent];
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
	[self mouseMoved:theEvent];
}

- (void)otherMouseDragged:(NSEvent *)theEvent
{
	[self mouseMoved:theEvent];
}


#pragma mark -
#pragma mark Local Keyboard Events


- (void)keyDown: (NSEvent *)theEvent
{
	[self _updateCapsLockStateIfNecessary];

	NSString *characters = [theEvent characters];
	unsigned int modifiers = [theEvent modifierFlags];
	if ( [[KeyEquivalentManager defaultManager] performEquivalentWithCharacters: characters modifiers: modifiers] )
	{
		[self discardAllPendingQueueEntries];
	} else
        [self queueKeyEventFromEvent:theEvent];
}

- (void)keyUp: (NSEvent *)theEvent
{
	[self _updateCapsLockStateIfNecessary];
    [self queueKeyEventFromEvent:theEvent];
}

- (void)flagsChanged:(NSEvent *)theEvent
{
    [self _synthesizeRemainingKeyUpEvents];

    [self queueModifiers:[theEvent modifierFlags]
               timestamp:[theEvent timestamp]];
    [_connection writeBuffer];
}

#pragma mark -
#pragma mark Synthesized Events


- (void)clearAllEmulationStates
{
	[self sendAllPendingQueueEntriesNow];
    [self synthesizeRemainingEvents];
    [self sendAllPendingQueueEntriesNow];
    [_connection writeBuffer];

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
    [_connection writeBuffer];
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
    [_connection writeBuffer];
}

- (void)queueKeyEventFromEvent: (NSEvent *)theEvent
{
    NSString *unmodified = [theEvent charactersIgnoringModifiers];
    NSString *modified = [theEvent characters];
    NSString *characters;
    unsigned int length;
	unsigned int i;
    unsigned int oldModifiers = 0;
    unsigned int modifiers = [theEvent modifierFlags];

    /* If shift is down, the OS does the capitalization on
     * charactersIgnoringModifiers, but if caps lock is down, it doesn't. */
    if (modifiers & NSAlphaShiftKeyMask)
        unmodified = [unmodified uppercaseString];

    // figure out the appropriate string to send to the server
    if ([modified length] > 0 && [modified characterAtIndex:0] < 0x20) {
        /* The OS translates Ctrl + letter into ASCII control sequences,
         * which are also used for Tab, Escape, Return, and Enter. So, in
         * these cases, we use the unmodified characters instead. */
        characters = unmodified;
    } else if ([modified length] > 0 && [modified characterAtIndex:0] < 0x80
                    && !(modifiers & NSCommandKeyMask)
                    && ![modified isEqualToString: unmodified]) {
        /* Some non-US keyboards require holding option or control in order to
         * type basic ASCII characters. Since these characters can be so
         * crucial, we the modified key if it's in the ASCII range.
         *
         * Note that the command key tends to block the effect of the shift key
         * on [theEvent characters], so this heuristic can't be applied with the
         * command key is down. */
        characters = modified;

        if ([theEvent type] == NSKeyDown) {
            /* We clear the modifiers for a keydown event so that the server
             * doesn't try to interpret the modifiers on top of the already
             * modified character. */
            oldModifiers = modifiers;
            [self queueModifiers:modifiers & ~NSControlKeyMask
                                           & ~NSAlternateKeyMask
                       timestamp:[theEvent timestamp]];
        }
    } else if ([_profile interpretModifiersLocally]) {
        characters = modified;
        if ((modifiers & (NSShiftKeyMask | NSAlphaShiftKeyMask))
                    && (modifiers & NSCommandKeyMask)) {
            // command tends to block the effect of shift
            characters = [characters uppercaseString];
        }
    } else {
        characters = unmodified;
    }

    length = [characters length];
	NSParameterAssert( characters );
	
	for ( i = 0; i < length; ++i )
	{
		unichar character;
        QueuedEvent *event;

        character = [characters characterAtIndex: i];

        if ((modifiers & NSNumericPadKeyMask) && character < 0x40)
            character += 0xf600; // encode numpad keys in private use area
		
        if ([theEvent type] == NSKeyDown) {
            event = [QueuedEvent keyDownEventWithCharacter: character
                                                 timestamp: [theEvent timestamp]];
        } else {
            event = [QueuedEvent keyUpEventWithCharacter: character
                                               timestamp: [theEvent timestamp]];
        }
		[_pendingEvents addObject: event];
		[self sendAnyValidEventsToServerNow];
	}

    if (oldModifiers) {
        /* Note that it would probably be better to wait until after the
         * matching key up event before restoring the modifiers. */
        [self queueModifiers:oldModifiers timestamp:[theEvent timestamp]];
    }

    [_connection writeBuffer];
}

/* Queues a change in the modifier state. Note that unlike the preceeding
 * queue... messages, this does not write the connection buffer. */
- (void)queueModifiers:(unsigned int)newState
             timestamp:(NSTimeInterval)timestamp
{
    unsigned int pressed = newState & ~_queuedModifiers;
    unsigned int released = ~newState & _queuedModifiers;
    unsigned int masks[] = {NSShiftKeyMask, NSControlKeyMask,
                            NSAlternateKeyMask, NSCommandKeyMask,
                            NSAlphaShiftKeyMask, NSNumericPadKeyMask,
                            NSHelpKeyMask};
    int i;

	_queuedModifiers = newState;
	
    for (i = 0; i < sizeof(masks) / sizeof(masks[0]); i++) {
        if (masks[i] & pressed)
			[self queueModifierPressed: masks[i] timestamp: timestamp];
        else if (masks[i] & released)
			[self queueModifierReleased: masks[i] timestamp: timestamp];
    }
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
    if ( kClickWhileHoldingModifierEmulation == [_profile button2EmulationScenario]
		 && _clickWhileHoldingModifierStillDown[0] 
		 && modifier == [_profile clickWhileHoldingModifierForButton:2] )
	{
		_clickWhileHoldingModifierStillDown[0] = NO;
	}
    if ( kClickWhileHoldingModifierEmulation == [_profile button3EmulationScenario]
		 && _clickWhileHoldingModifierStillDown[1] 
		 && modifier == [_profile clickWhileHoldingModifierForButton:3] )
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
    unsigned oldModifiers = _pressedModifiers;
	BOOL shiftKeyDown = NO;
	NSCharacterSet  *upper = [NSCharacterSet uppercaseLetterCharacterSet];
	QueuedEvent *event;

	[self clearAllEmulationStates];

	for ( index = 0; index < strLength; ++index )
	{
		unichar character = [string characterAtIndex: index];
		
		/* Fake shift key presses for uppercase letters. Strictly speaking, this
         * shouldn't be necessary, since the server should not depend on the
         * state of the shift key to interpret the keysym, but it helps with
         * some servers. */
		if (!shiftKeyDown && [upper characterIsMember:character]) {
			event = [QueuedEvent modifierDownEventWithCharacter:NSShiftKeyMask
													  timestamp:now];
            [self _sendKeyEvent:event];
			shiftKeyDown = YES;
		} else if (shiftKeyDown && ![upper characterIsMember:character]) {
			event = [QueuedEvent modifierUpEventWithCharacter:NSShiftKeyMask
													timestamp:now];
            [self _sendKeyEvent:event];
			shiftKeyDown = NO;
		}

		event = [QueuedEvent keyDownEventWithCharacter: character
											 timestamp: now];
        [self _sendKeyEvent:event];
		event = [QueuedEvent keyUpEventWithCharacter: character
										   timestamp: now];
        [self _sendKeyEvent:event];
	}

	if (shiftKeyDown) {
		event = [QueuedEvent modifierUpEventWithCharacter:NSShiftKeyMask
												timestamp:now];
        [self _sendKeyEvent:event];
	}
	
    [self queueModifiers: oldModifiers timestamp:now];
    [self sendAllPendingQueueEntriesNow];
    [_connection writeBuffer];
}


- (void)applicationDidBecomeActive: (NSNotification *)notification
{  _watchEventForCapsLock = YES;  }


#pragma mark -
#pragma mark Event Processing


/* Returns the number of events from the end of the queue to delay sending,
 * because they might be part of an emulation scheme */
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


/* Sends events from the queue which are not part of an emulation sequence. */
- (void)sendAnyValidEventsToServerNow
{
	unsigned int eventsToDelay2;
	unsigned int eventsToDelay3;
	
	eventsToDelay2 = [self _sendAnyValidEventsToServerForButton: 2 scenario:
                            [_profile button2EmulationScenario]];
	eventsToDelay3 = [self _sendAnyValidEventsToServerForButton: 3 scenario:
                            [_profile button3EmulationScenario]];
	
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


/* The _send* methods send particular queued events */

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
    {
		[_connection mouseClickedAt: [event locationInWindow] buttons: _pressedButtons];
    }
}


- (void)_sendKeyEvent: (QueuedEvent *)event
{
	unichar character = [event character];
	NSNumber *encodedChar = [NSNumber numberWithInt: (int)character];

	if ( kQueuedKeyDownEvent == [event type] )
	{
		[_pressedKeys addObject: encodedChar];
		[_connection sendKey: character pressed: YES];
	}
	else if ( [_pressedKeys containsObject: encodedChar] )
	{
		[_pressedKeys removeObject: encodedChar];
		[_connection sendKey: character pressed: NO];
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


// :TOFIX: all the events setting a timestamp using timeIntervalSince1970 are
// inconsistent with NSEvent's timestamps, which are time since start-up
- (void)_synthesizeRemainingMouseUpEvents
{
	NSPoint p = NSZeroPoint;
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    int     button;

    for (button = 1; button <= 5; button++) {
        if (_pressedButtons & ButtonNumberToRFBButtomMask(button)) {
            QueuedEvent *event = [QueuedEvent mouseUpEventForButton: button
                                                           location: p
                                                          timestamp: now];
            [_pendingEvents addObject: event];
        }
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
														timestamp: now];
		[_pendingEvents addObject: event];
	}
}


- (void)_synthesizeRemainingModifierUpEvents
{
	NSTimeInterval  now = [[NSDate date] timeIntervalSince1970];
    [self queueModifiers:0 timestamp:now];
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
    unsigned    cwhModifier = [_profile clickWhileHoldingModifierForButton:button];
	if ( eventCount > 2 )
		return 0;

	unsigned int buttonIndex = ButtonNumberToArrayIndex( button );
	
	if ( eventCount == 2 )
	{
		QueuedEvent *event1 = [_pendingEvents objectAtIndex: 0];
		
		if ( kQueuedModifierDownEvent == [event1 type] 
            && cwhModifier == [event1 modifier] )
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
		unsigned	buttonIndex = ButtonNumberToArrayIndex(button);

		if ( kQueuedModifierDownEvent == [event type] 
            && cwhModifier == [event modifier] )
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
	NSEnumerator *eventEnumerator = [_pendingEvents objectEnumerator];
	QueuedEvent *event;
	unsigned int validEvents = 0;
    unsigned int    mtModifier = [_profile multiTapModifierForButton:button];
	
	[self _resetMultiTapTimer: nil];

	while ( event = [eventEnumerator nextObject] )
	{
		QueuedEventType eventType = [event type];
		unsigned int modifier = [event modifier];
		
        if ( mtModifier != modifier )
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
            if ( validEvents / 2 == [_profile multiTapCountForButton:button] )
			{
				[self discardAllPendingQueueEntries];
				NSPoint	p = [_view convertPoint: [[_view window] convertScreenToBase: [NSEvent mouseLocation]] 
									  fromView: nil];
				unsigned int rfbButton = ButtonNumberToRFBButtomMask( button );
				[_connection mouseClickedAt: p buttons: _pressedButtons | rfbButton];	// 'Mouse button down'
				[_connection mouseClickedAt: p buttons: _pressedButtons];				// 'Mouse button up'
				return 0;
			}
		}
	}
	
	if ( validEvents && (validEvents % 2 == 0) )
	{
		_multiTapTimer = [[NSTimer scheduledTimerWithTimeInterval: [_profile multiTapDelayForButton:button] target: self selector: @selector(_resetMultiTapTimer:) userInfo: nil repeats: NO] retain];
//		NSLog(@"starting multi-tap timer");
	}
	
	return validEvents;
}


- (unsigned int)handleTapModifierAndClickForButton: (unsigned int)button
{
	int eventIndex, eventCount = [_pendingEvents count];
	NSTimeInterval time1 = 0, time2;
    unsigned    emulModifier = [_profile tapAndClickModifierForButton:button];
	
	for ( eventIndex = 0; eventIndex < eventCount; ++eventIndex )
	{
		QueuedEvent *event = [_pendingEvents objectAtIndex: eventIndex];
		QueuedEventType eventType = [event type];
		unsigned int modifier = [event modifier];
		
		if ( 0 == eventIndex )
		{
			if ( ! (kQueuedModifierDownEvent == eventType && modifier == emulModifier) )
				return 0;
			time1 = [event timestamp];
		}
		
		else if ( 1 == eventIndex )
		{
			if ( ! (kQueuedModifierUpEvent == eventType && modifier == emulModifier) )
				return 0;
			time2 = [event timestamp];
			if ( time2 - time1 > [_profile tapAndClickButtonSpeedForButton:button] )
				return 0;

			if ( ! _tapAndClickTimer )
			{
                _tapAndClickTimer = [[NSTimer scheduledTimerWithTimeInterval: [_profile tapAndClickTimeoutForButton:button] target: self selector: @selector(_resetTapModifierAndClick:) userInfo: nil repeats: NO] retain];
				[_view setCursorTo: (button == 2) ? @"rfbCursor2" : @"rfbCursor3"];
			}
		}
		
		else if ( 2 == eventIndex )
		{
			if ( kQueuedMouse1DownEvent != eventType )
			{
                if ( kQueuedKeyDownEvent == eventType
                        && '\e' == [event character] )
                    [self discardAllPendingQueueEntries];
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

@end
