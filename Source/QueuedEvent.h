//
//  QueuedEvent.h
//  keysymtest
//
//  Created by Bob Newhart on 7/1/05.
//  Copyright 2005 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>


typedef enum {
	kQueuedMouse1DownEvent, 
	kQueuedMouse1UpEvent, 
	kQueuedMouse2DownEvent, 
	kQueuedMouse2UpEvent, 
	kQueuedMouse3DownEvent, 
	kQueuedMouse3UpEvent, 
	kQueuedKeyDownEvent, 
	kQueuedKeyUpEvent, 
	kQueuedModifierDownEvent, 
	kQueuedModifierUpEvent, 
} QueuedEventType;


@interface QueuedEvent : NSObject {
	QueuedEventType _eventType;
	NSPoint _location;
	NSTimeInterval _timestamp;
	unichar _character;
	unichar _characterIgnoringModifiers;
	unsigned int _modifier;
}

// Creation
+ (QueuedEvent *)mouseDownEventForButton: (int)buttonNumber
								location: (NSPoint)location
							   timestamp: (NSTimeInterval)timestamp;
+ (QueuedEvent *)mouseUpEventForButton: (int)buttonNumber
							  location: (NSPoint)location
							 timestamp: (NSTimeInterval)timestamp;
+ (QueuedEvent *)keyDownEventWithCharacter: (unichar)character
				characterIgnoringModifiers: (unichar)unmodCharacter
								 timestamp: (NSTimeInterval)timestamp;
+ (QueuedEvent *)keyUpEventWithCharacter: (unichar)character
			  characterIgnoringModifiers: (unichar)unmodCharacter
							   timestamp: (NSTimeInterval)timestamp;
+ (QueuedEvent *)modifierDownEventWithCharacter: (unsigned int)modifier
								 timestamp: (NSTimeInterval)timestamp;
+ (QueuedEvent *)modifierUpEventWithCharacter: (unsigned int)modifier
							   timestamp: (NSTimeInterval)timestamp;

// Event Attributes
- (QueuedEventType)type;
- (NSPoint)locationInWindow;
- (NSTimeInterval)timestamp;
- (unichar)character;
- (unichar)characterIgnoringModifiers;
- (unsigned int)modifier;

@end
