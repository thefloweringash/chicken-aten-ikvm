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
#import "RFBConnection.h"
#import "FrameBuffer.h"
#import "RectangleList.h"

@implementation RFBView

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

- (void)setCursorTo:(NSString*)icon hotSpot:(int)hs
{
	NSPoint p;
	id cursorImage = [NSImage imageNamed:icon];
	p.x = p.y = hs;
	[cursor autorelease];
	cursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:p];
    [[self window] invalidateCursorRectsForView:self];
}

- (void)setDelegate:(id)aDelegate
{
    delegate = aDelegate;
    if(!cursor) {
		[self setCursorTo: @"rfbCursor" hotSpot: 7];
    }
	[self setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: delegate selector: @selector(viewFrameDidChange:) name: NSViewFrameDidChangeNotification object: self];
}

- (void)drawRect:(NSRect)destRect
{
    NSRect b = [self bounds];
    NSRect r = destRect;

    r.origin.y = b.size.height - NSMaxY(r);
    [fbuf drawRect:r at:destRect.origin];
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
    NSRect crect;

    crect = [self visibleRect];
    [self addCursorRect:crect cursor:cursor];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    buttonMask |= rfbButton1Mask;
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    buttonMask |= rfbButton3Mask;
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)otherMouseDown:(NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == 2) {
		NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		buttonMask |= rfbButton2Mask;
		[delegate mouseAt:p buttons:buttonMask];
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    buttonMask &= ~rfbButton1Mask;
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    buttonMask &= ~rfbButton3Mask;
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)otherMouseUp:(NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == 2) {
		NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		buttonMask &= ~rfbButton2Mask;
		[delegate mouseAt:p buttons:buttonMask];
	}
}

- (void)mouseEntered:(NSEvent *)theEvent {
	[[self window] setAcceptsMouseMovedEvents: YES];
}

- (void)mouseExited:(NSEvent *)theEvent {
	[[self window] setAcceptsMouseMovedEvents: NO];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [delegate mouseMovedTo:p];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)otherMouseDragged:(NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == 2) {
		NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		[delegate mouseAt:p buttons:buttonMask];
	}
}

// jason - this doesn't work, I think because the server I'm testing against doesn't support
// rfbButton4Mask and rfbButton5Mask (8 & 16).  They're not a part of rfbProto, so that ain't
// too surprising.

- (void)scrollWheel:(NSEvent *)theEvent {
  int  addMask;
    NSPoint	p = [self convertPoint:[[self window] convertScreenToBase: [NSEvent mouseLocation]] fromView:nil];
    if ([theEvent deltaY] > 0.0)
      addMask = rfbButton4Mask;
	else
      addMask = rfbButton5Mask;
    [delegate mouseAt:p buttons:(buttonMask | addMask)];	// 'Mouse button down'
    [delegate mouseAt:p buttons:0];				// 'Mouse button up'
}


- (void)keyDown:(NSEvent *)theEvent
{
    [delegate processKey:theEvent pressed:YES];
}

- (void)keyUp:(NSEvent *)theEvent
{
    [delegate processKey:theEvent pressed:NO];
}

- (void)flagsChanged:(NSEvent *)theEvent
{
    [delegate sendModifier:[theEvent modifierFlags]];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	// Jason rewrote this so we don't send multiple instances - we can use NSKeyDown and NSKeyUp instead

	BOOL isPressed = ([theEvent type] == NSKeyDown) ? YES : NO;

    if([NSApp keyWindow] == [self window]) {
        [delegate processKey:theEvent pressed:isPressed];
        return YES;
    } else {
        return NO;
    }
/*
    if([NSApp keyWindow] == [self window]) {
		[delegate processKey:theEvent pressed:YES];
		[delegate processKey:theEvent pressed:NO];
		return YES;
	} else {
		return NO;
*/
}


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
    return [delegate pasteFromPasteboard:[sender draggingPasteboard]];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

@end
