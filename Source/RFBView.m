/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "RFBView.h"
#import "EventFilter.h"
#import "RFBConnection.h"
#import "FrameBuffer.h"
#import "RectangleList.h"

@implementation RFBView

+ (NSCursor *)_cursorForName: (NSString *)name
{
	static NSDictionary *sMapping = nil;
	if ( ! sMapping )
	{
		NSBundle *mainBundle = [NSBundle mainBundle];
		NSDictionary *entries = [NSDictionary dictionaryWithContentsOfFile: [mainBundle pathForResource: @"cursors" ofType: @"plist"]];
		NSParameterAssert( entries != nil );
		sMapping = [[NSMutableDictionary alloc] init];
		NSEnumerator *cursorNameEnumerator = [entries keyEnumerator];
		NSDictionary *cursorName;
		
		while ( cursorName = [cursorNameEnumerator nextObject] )
		{
			NSDictionary *cursorEntry = [entries objectForKey: cursorName];
			NSString *localPath = [cursorEntry objectForKey: @"localPath"];
			NSString *path = [mainBundle pathForResource: localPath ofType: nil];
			NSImage *image = [[[NSImage alloc] initWithContentsOfFile: path] autorelease];
			
			int hotspotX = [[cursorEntry objectForKey: @"hotspotX"] intValue];
			int hotspotY = [[cursorEntry objectForKey: @"hotspotY"] intValue];
			NSPoint hotspot = {hotspotX, hotspotY};
			
			NSCursor *cursor = [[[NSCursor alloc] initWithImage: image hotSpot: hotspot] autorelease];
			[(NSMutableDictionary *)sMapping setObject: cursor forKey: cursorName];
		}
	}
	
	return [sMapping objectForKey: name];
}


- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)setFrameBuffer:(id)aBuffer;
{
    NSRect f = [self frame];
    
    [fbuf autorelease];
    fbuf = [aBuffer retain];
    f.size = [aBuffer size];
    [self setFrame:f];
}

- (void)dealloc
{
    [fbuf release];
    [super dealloc];
}

- (void)setCursorTo: (NSString *)name
{
	if ( ! name )
		name = @"rfbCursor";
	_cursor = [[self class] _cursorForName: name];
    [[self window] invalidateCursorRectsForView: self];
}

- (void)setDelegate:(RFBConnection *)delegate
{
    _delegate = delegate;
	_eventFilter = [_delegate eventFilter];
	[self setCursorTo: nil];
	[self setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: _delegate selector: @selector(viewFrameDidChange:) name: NSViewFrameDidChangeNotification object: self];
}

- (RFBConnection *)delegate
{
	return _delegate;
}

- (void)drawRect:(NSRect)destRect
{
    NSRect b = [self bounds];
    NSRect r = destRect;

    r.origin.y = b.size.height - NSMaxY(r);
    [fbuf drawRect:r at:destRect.origin];
    //[delegate queueUpdateRequest];
}

- (void)displayFromBuffer:(NSRect)aRect
{
    NSRect b = [self bounds];
    NSRect r = aRect;

    r.origin.y = b.size.height - NSMaxY(r);
    [self displayRect:r];
}

- (void)drawRectList:(id)aList
{
    [self lockFocus];
    [aList drawRectsInRect:[self bounds]];
    [self unlockFocus];
}

- (void)resetCursorRects
{
    NSRect cursorRect;
    cursorRect = [self visibleRect];
    [self addCursorRect: cursorRect cursor: _cursor];
}

- (void)mouseDown:(NSEvent *)theEvent
{  [_eventFilter mouseDown: theEvent];  }

- (void)rightMouseDown:(NSEvent *)theEvent
{  [_eventFilter rightMouseDown: theEvent];  }

- (void)otherMouseDown:(NSEvent *)theEvent
{  [_eventFilter otherMouseDown: theEvent];  }

- (void)mouseUp:(NSEvent *)theEvent
{  [_eventFilter mouseUp: theEvent];  }

- (void)rightMouseUp:(NSEvent *)theEvent
{  [_eventFilter rightMouseUp: theEvent];  }

- (void)otherMouseUp:(NSEvent *)theEvent
{  [_eventFilter otherMouseUp: theEvent];  }

- (void)mouseEntered:(NSEvent *)theEvent
{  [[self window] setAcceptsMouseMovedEvents: YES];  }

- (void)mouseExited:(NSEvent *)theEvent
{  [[self window] setAcceptsMouseMovedEvents: NO];  }

- (void)mouseMoved:(NSEvent *)theEvent
{  [_eventFilter mouseMoved: theEvent];  }

- (void)mouseDragged:(NSEvent *)theEvent
{  [_eventFilter mouseDragged: theEvent];  }

- (void)rightMouseDragged:(NSEvent *)theEvent
{  [_eventFilter rightMouseDragged: theEvent];  }

- (void)otherMouseDragged:(NSEvent *)theEvent
{  [_eventFilter otherMouseDragged: theEvent];  }

// jason - this doesn't work, I think because the server I'm testing against doesn't support
// rfbButton4Mask and rfbButton5Mask (8 & 16).  They're not a part of rfbProto, so that ain't
// too surprising.
// 
// Later note - works fine now, maybe more servers have added support since I wrote the original
// comment
- (void)scrollWheel:(NSEvent *)theEvent
{  [_eventFilter scrollWheel: theEvent];  }

- (void)keyDown:(NSEvent *)theEvent
{  [_eventFilter keyDown: theEvent];  }

- (void)keyUp:(NSEvent *)theEvent
{  [_eventFilter keyUp: theEvent];  }

- (void)flagsChanged:(NSEvent *)theEvent
{  [_eventFilter flagsChanged: theEvent];  }


- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
    return NSDragOperationGeneric;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return NSDragOperationGeneric;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    return [_delegate pasteFromPasteboard:[sender draggingPasteboard]];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

@end
