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

#import <AppKit/AppKit.h>

#import "FrameBuffer.h"

@interface RFBView : NSView
{
    id delegate;
    id cursor;
    FrameBuffer *fbuf;
    unsigned buttonMask;
}

- (void)setFrameBuffer:(id)aBuffer;
- (void)setDelegate:(id)aDelegate;
- (id)delegate;
- (void)drawRect:(NSRect)aRect;
- (void)displayFromBuffer:(NSRect)aRect;
- (void)drawRectList:(id)aList;

- (void)setCursorTo:(NSString*)icon hotSpot:(int)hs;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;
- (void)draggingExited:(id <NSDraggingInfo>)sender;
- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

@end
