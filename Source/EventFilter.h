//
//  EventFilter.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 7/1/05.
//  Copyright 2005 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class Profile;
@class RFBConnection, RFBView;

/*
 * Philosophy:  The EventFilter sits between an NSResponder and an object that sends
 * events to the VNC server.  It handles several things:
 *	- converting from a native representation to a VNC representation
 *	- siphoning off events that are intended to trigger emulation of non-native features
 *	- siphoning off menu key equivalent events
 *
 * The EventFilter does this by maintaining a queue of pending events.  Whenever a "definitive"
 * event is received, the queue is sent en mass to the server, in the same order that the events
 * occurred.  This means that queued events are not sent in realtime.  Hopefully, this is not an
 * issue.
 *
 * A "definitive" event is an event who's occurrence means that no previous events need to be 
 * removed from the queue.  For example, if mouse-button emulation is not being used, a mouse
 * event will be "definitive".  If there are no menu key equivalents, a non-modifier key press
 * event will be "definitive".
 *
 * Mouse button emulation can be triggered by the following scenarios:
 *
 *	- kClickWhileHoldingModifierEmulation
 *		- Action:	a key down event of the emulation modifier occurs
 *		- Action:	a mouse down event occurs
 *		- Result:	the two pending events are removed from the queue and an emulated mouse down 
 *					event is sent instead
 *		- Action:	a mouse up event occurs
 *		- Result:	the event is removed from the queue and an emulated mouse up event is sent instead
 *
 *	- kMultiTapModifierEmulation
 *		- Action:	a key down event of the emulation modifier occurs
 *		- Action:	a key up event of the emulation modifier occurs within the time limit
 *		- Action:	the above occurs as many times as the emulation setting requires
 *		- Result:	the pending events are removed from the queue and an emulated mouse down and 
 *					mouse up event are sent instead
 *
 *	- kTapModifierAndClickEmulation
 *		- Action:	a key down event of the emulation modifier occurs
 *		- Action:	a key up event of the emulation modifier occcurs within the time limit
 *		- Result:	the cursor is changed to show which mouse button will be emulated if mouse is clicked
 *		- Action:	a mouse down event occurs
 *		- Result:	the pending events are removed from the queue and an emulated mouse down is sent 
 *					instead
 *
 * Emulation will be cancelled if any event other than the ones specified above are received as the 
 * emulation is progressing.  If this happens, the pending events will be sent normally.
 *
 * The EventFilter maintains several state variables:
 *
 *	_pendingEvents:		An ordered array of the events that have occurred but have not yet been sent to 
 *						the server.  These events might be edited or removed if needed.
 *
 *	_pressedKeys:		A set of all keysym codes that the server has been instructed have been "pressed".  
 *						When a key down event is sent to the server, the key is added to this set.  Likewise, 
 *						the key must be present in this set in order for a key up event to be sent to the 
 *						server.  Sending a key up event to the server removes the character from this set.
 *
 *	_queuedModifiers:	A set of all keyboard modifier codes that are waiting to be sent to the server.  
 *						This is used to determine whether changed modifier flags represent key presses 
 *						or releases.
 *
 *	_pressedButtons:	A set of all button codes that the server has been instructed have been pressed.
 *						When a mouse down event is sent to the server, the button is added to this bitfield.  
 *						Likewise, the button must be in the bitfield in order for a mouse up event to be sent 
 *						to the sever.  Sending a mouse up event to the server removes the button from this
 *						bitfield.
 *
 *	_emulationScenario:	The emulation scenario currently in effect, as described above.  This setting 
 *						determines how events in _pendingEvents will be parsed.
 *
 *	_emulationButton:	The button number that mouse button #1 is currently being emulated as.  A mouse up
 *						event on button #1 will be mapped to a mouse up event on this button.
 *
 * When an event is received from the NSResponder, it is added to _pendingEvents.  Then, _pendingEvents 
 * is scanned to determine whether any action can be taken.  Things that might occur at this point are:
 *
 *	- all/some pending events are sent to the server
 *	- emulation is triggered, changing and possibly sending some pending events
 *	- a menu key equivalent is found and triggered, and the associated events are removed from the queue
 *	- no action, the events remain queued
 *
 */
 

typedef enum {
	kNoMouseButtonEmulation, 
	kClickWhileHoldingModifierEmulation, 
	kMultiTapModifierEmulation, 
	kTapModifierAndClickEmulation, 
} EventFilterEmulationScenario;


@interface EventFilter : NSObject {
	RFBConnection *_connection;
	Profile *_profile;
	RFBView *_view;
	
	NSMutableArray *_pendingEvents;
	unsigned int _queuedModifiers;
	BOOL _watchEventForCapsLock;
	BOOL _viewOnly;
	
	NSMutableSet *_pressedKeys;
	unsigned int _pressedButtons;
	unsigned int _pressedModifiers;
	
    // emulation state
	unsigned int _emulationButton;
	BOOL _clickWhileHoldingModifierStillDown[2];
	NSTimer *_multiTapTimer;
	NSTimer *_tapAndClickTimer;
}

// Talking to the server
- (RFBConnection *)connection;
- (void)setConnection: (RFBConnection *)connection;
- (RFBView *)view;
- (void)setView: (RFBView *)view;

// Local Mouse Events
- (void)mouseDown: (NSEvent *)theEvent;
- (void)mouseUp: (NSEvent *)theEvent;
- (void)rightMouseDown: (NSEvent *)theEvent;
- (void)rightMouseUp: (NSEvent *)theEvent;
- (void)otherMouseDown: (NSEvent *)theEvent;
- (void)otherMouseUp: (NSEvent *)theEvent;
- (void)scrollWheel: (NSEvent *)theEvent;
- (void)mouseMoved:(NSEvent *)theEvent;
- (void)mouseDragged:(NSEvent *)theEvent;
- (void)rightMouseDragged:(NSEvent *)theEvent;
- (void)otherMouseDragged:(NSEvent *)theEvent;

// Local Keyboard Events
- (void)keyDown: (NSEvent *)theEvent;
- (void)keyUp: (NSEvent *)theEvent;
- (void)flagsChanged:(NSEvent *)theEvent;

// Synthesized Events
- (void)clearAllEmulationStates;
- (void)queueMouseDownEventFromEvent: (NSEvent *)theEvent buttonNumber: (unsigned int)button;
- (void)queueMouseUpEventFromEvent: (NSEvent *)theEvent buttonNumber: (unsigned int)button;
- (void)queueKeyEventFromEvent: (NSEvent *)theEvent;
- (void)queueModifiers:(unsigned int)newState
             timestamp:(NSTimeInterval)timestamp;
- (void)queueModifierPressed: (unsigned int)modifier timestamp: (NSTimeInterval)timestamp;
- (void)queueModifierReleased: (unsigned int)modifier timestamp: (NSTimeInterval)timestamp;
- (void)pasteString: (NSString *)string;

// Event Processing
- (void)sendAnyValidEventsToServerNow;
- (void)sendAllPendingQueueEntriesNow;
- (void)sendPendingQueueEntriesInRange: (NSRange)range;
- (void)discardAllPendingQueueEntries;
- (void)synthesizeRemainingEvents;
- (unsigned int)handleClickWhileHoldingForButton: (unsigned int)button;
- (unsigned int)handleMultiTapForButton: (unsigned int)button;
- (unsigned int)handleTapModifierAndClickForButton: (unsigned int)button;

@end
