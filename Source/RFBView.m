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
    NSRect bb;
    NSRect f = [self frame];
    
    [fbuf autorelease];
    fbuf = [aBuffer retain];
    f.size = [aBuffer size];
    [self setFrame:f];
    messageFont = [NSFont userFontOfSize:12.0];
    bb = [messageFont boundingRectForFont];
    fontHeight = bb.size.height + 1.0;
    messagePosition.height = (f.size.height - bb.size.height) / 2;
}

- (void)dealloc
{
    [fbuf release];
    [messages release];
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
        NSPoint p;
        id cursorImage = [NSImage imageNamed:@"rfbCursor"];
        p.x = p.y = 7;
        cursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:p];
        [[self window] invalidateCursorRectsForView:self];
    }
}

- (void)overlayMessage
{
    NSEnumerator* e;
    NSString* s;
    float h = messagePosition.height;
    NSRect theRect = NSMakeRect(messageBG.origin.x, messageBG.origin.y, messageBG.size.width, messageBG.size.height); // jason added this variable to avoid PS functions
    
    [messageFont set];
	// Jason - no PS functions
    [[NSColor colorWithCalibratedWhite: 0.66 alpha: 1.0] set];
    [NSBezierPath fillRect: theRect];
    [[NSColor colorWithCalibratedWhite: 0.0 alpha: 1.0] set];
    [NSBezierPath strokeRect: theRect];
/*    PSsetgray(0.66);
    PSrectfill(messageBG.origin.x, messageBG.origin.y, messageBG.size.width, messageBG.size.height);
    PSsetgray(0.0);
    PSrectstroke(messageBG.origin.x, messageBG.origin.y, messageBG.size.width, messageBG.size.height); */
    e = [messages objectEnumerator];
    while((s = [e nextObject]) != nil) {
		// Jason - no PS functions
        [s drawAtPoint: NSMakePoint(messagePosition.width, h) withAttributes: nil];
/*        PSmoveto(messagePosition.width, h);
        PSshow([s cString]); */
        h -= fontHeight;
    }
}

- (void)drawRect:(NSRect)destRect
{
    NSRect b = [self bounds];
    NSRect r = destRect;

    r.origin.y = b.size.height - NSMaxY(r);
    [fbuf drawRect:r at:destRect.origin];
    if(messages) {
        [self overlayMessage];
    }
}

- (void)displayFromBuffer:(NSRect)aRect
{
    NSRect b = [self bounds];
    NSRect r = aRect;

    r.origin.y = b.size.height - NSMaxY(r);
    [self displayRect:r];
}

- (void)setMessage:(NSString*)aMessage
{
    float max = 0.0;
    int i;
    NSRect f = [self frame];

    if((aMessage == nil) || ([aMessage isEqualToString:@""])) {
        if(messages) {
            [messages release];
            messages = nil;
            [self display];
        }
    } else {
        [messages release];
        messages = [[aMessage componentsSeparatedByString:[NSString stringWithFormat:@"\n"]] retain];
        for(i=0; i<[messages count]; i++) {
            if([messageFont widthOfString:[messages objectAtIndex:i]] > max) {
                max = [messageFont widthOfString:[messages objectAtIndex:i]];
            }
        }
        messagePosition.width = (f.size.width - max) / 2;
        messageBG.size.width = max + 10.0;
        messageBG.size.height = [messages count] * fontHeight + 10.0;
        messageBG.origin.x = messagePosition.width - 5.0;
        messageBG.origin.y = messagePosition.height - 7.5 - ([messages count] - 1) * fontHeight;
        [self display];
    }
}

- (void)drawRectList:(id)aList
{
    [self lockFocus];
    [aList drawRectsInRect:[self bounds]];
    if(messages) {
        [self overlayMessage];
    }
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
    buttonMask |= 1;
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    buttonMask |= 4;
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    buttonMask &= ~1;
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    buttonMask &= ~4;
    [delegate mouseAt:p buttons:buttonMask];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint	p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [delegate mouseAt:p buttons:buttonMask];
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

// jason added the -isDisplayingMessage method
- (BOOL)isDisplayingMessage
{
	return messages != nil;
}

@end
