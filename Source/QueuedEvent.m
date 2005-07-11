//
//  QueuedEvent.m
//  keysymtest
//
//  Created by Bob Newhart on 7/1/05.
//  Copyright 2005 Geekspiff. All rights reserved.
//

#import "QueuedEvent.h"


@implementation QueuedEvent

#pragma mark Creation

+ (QueuedEvent *)mouseDownEventForButton: (int)buttonNumber
								location: (NSPoint)location
							   timestamp: (NSTimeInterval)timestamp
{
	NSParameterAssert( buttonNumber >= 1 && buttonNumber <= 3 );
	
	QueuedEvent *event = [[[[self class] alloc] init] autorelease];
	event->_eventType = (QueuedEventType) ((buttonNumber-1) * 2);
	event->_location = location;
	event->_timestamp = timestamp;
	
	return event;
}


+ (QueuedEvent *)mouseUpEventForButton: (int)buttonNumber
							  location: (NSPoint)location
							 timestamp: (NSTimeInterval)timestamp
{
	NSParameterAssert( buttonNumber >= 1 && buttonNumber <= 3 );
	
	QueuedEvent *event = [[[[self class] alloc] init] autorelease];
	event->_eventType = (QueuedEventType) ((buttonNumber-1) * 2 + 1);
	event->_location = location;
	event->_timestamp = timestamp;
	
	return event;
}


+ (QueuedEvent *)keyDownEventWithCharacter: (unichar)character
				characterIgnoringModifiers: (unichar)unmodCharacter
								 timestamp: (NSTimeInterval)timestamp
{
	QueuedEvent *event = [[[[self class] alloc] init] autorelease];
	event->_eventType = kQueuedKeyDownEvent;
	event->_character = character;
	event->_characterIgnoringModifiers = unmodCharacter;
	event->_timestamp = timestamp;
	
	return event;
}


+ (QueuedEvent *)keyUpEventWithCharacter: (unichar)character
			  characterIgnoringModifiers: (unichar)unmodCharacter
							   timestamp: (NSTimeInterval)timestamp
{
	QueuedEvent *event = [[[[self class] alloc] init] autorelease];
	event->_eventType = kQueuedKeyUpEvent;
	event->_character = character;
	event->_characterIgnoringModifiers = unmodCharacter;
	event->_timestamp = timestamp;
	
	return event;
}	


+ (QueuedEvent *)modifierDownEventWithCharacter: (unsigned int)modifier
									  timestamp: (NSTimeInterval)timestamp
{
	QueuedEvent *event = [[[[self class] alloc] init] autorelease];
	event->_eventType = kQueuedModifierDownEvent;
	event->_modifier = modifier;
	event->_timestamp = timestamp;
	
	return event;
}	


+ (QueuedEvent *)modifierUpEventWithCharacter: (unsigned int)modifier
									timestamp: (NSTimeInterval)timestamp
{
	QueuedEvent *event = [[[[self class] alloc] init] autorelease];
	event->_eventType = kQueuedModifierUpEvent;
	event->_modifier = modifier;
	event->_timestamp = timestamp;
	
	return event;
}	


#pragma mark -
#pragma mark Event Attributes


- (QueuedEventType)type
{  return _eventType;  }

- (NSPoint)locationInWindow
{  return _location;  }

- (NSTimeInterval)timestamp
{  return _timestamp;  }

- (unichar)character
{  return _character;  }

- (unichar)characterIgnoringModifiers
{  return _characterIgnoringModifiers;  }

- (unsigned int)modifier
{  return _modifier;  }


#pragma mark -
#pragma mark Utilities


- (NSString *)_descriptionForEventType
{
	switch (_eventType)
	{
		case kQueuedMouse1DownEvent:
			return @"kQueuedMouse1DownEvent";
		case kQueuedMouse1UpEvent:
			return @"kQueuedMouse1UpEvent";
		case kQueuedMouse2DownEvent:
			return @"kQueuedMouse2DownEvent";
		case kQueuedMouse2UpEvent:
			return @"kQueuedMouse2UpEvent";
		case kQueuedMouse3DownEvent:
			return @"kQueuedMouse3DownEvent";
		case kQueuedMouse3UpEvent:
			return @"kQueuedMouse3UpEvent";
		case kQueuedKeyDownEvent:
			return @"kQueuedKeyDownEvent";
		case kQueuedKeyUpEvent:
			return @"kQueuedKeyUpEvent";
		case kQueuedModifierDownEvent:
			return @"kQueuedModifierDownEvent";
		case kQueuedModifierUpEvent:
			return @"kQueuedModifierUpEvent";
	}
	return nil;
}

- (NSString *)_descriptionForCharacter: (unichar)character
{  return [NSString stringWithCharacters: &character length: 1];  }


- (NSString *)_descriptionForModifier
{
	switch (_modifier)
	{
		case NSShiftKeyMask:
			return @"NSShiftKeyMask";
		case NSControlKeyMask:
			return @"NSControlKeyMask";
		case NSAlternateKeyMask:
			return @"NSAlternateKeyMask";
		case NSCommandKeyMask:
			return @"NSCommandKeyMask";
	}
	return nil;
}


- (NSString *)description
{
	NSString *eventType = [self _descriptionForEventType];
	if ( _eventType <= kQueuedMouse3UpEvent )
	{
		NSString *location = [NSString stringWithFormat: @"(%.0f, %.0f)", _location.x, _location.y];
		return [NSString stringWithFormat: @"%@ %@", eventType, location];
	}
	else if ( _eventType <= kQueuedKeyUpEvent )
	{
		NSString *chars = [self _descriptionForCharacter: _character];
		NSString *charsIgnoringModifiers = [self _descriptionForCharacter: _characterIgnoringModifiers];
		return [NSString stringWithFormat: @"%@ '%@' '%@']", eventType, chars, charsIgnoringModifiers];
	}
	NSString *modifier = [self _descriptionForModifier];
	return [NSString stringWithFormat: @"%@ %@]", eventType, modifier];
}

@end
