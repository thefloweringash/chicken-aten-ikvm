/* FrameBufferUpdateReader.m created by helmut on Wed 17-Jun-1998 */

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

#import "FrameBufferUpdateReader.h"
#import "ByteBlockReader.h"
#import "CursorPseudoEncodingReader.h"
#import "DesktopNameEncodingReader.h"
#import "RawEncodingReader.h"
#import "CopyRectangleEncodingReader.h"
#import "CoRREEncodingReader.h"
#import "HextileEncodingReader.h"
#import "PrefController.h"
#import "RFBConnection.h"
#import "RFBConnectionManager.h"
#import "RFBProtocol.h"
#import "RREEncodingReader.h"
#import "TightEncodingReader.h"
#import "ZlibEncodingReader.h"
#import "ZlibHexEncodingReader.h"
#import "ZRLEEncodingReader.h"

#import "debug.h"

@implementation FrameBufferUpdateReader

- (id)initWithProtocol: (RFBProtocol *)aProtocol connection: (RFBConnection *)aConnection;
{
    if (self = [super init]) {
		connection = aConnection;
        protocol = aProtocol;
        bytesPerPixel = 0;

		headerReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setHeader:) size:3];
		rectHeaderReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setRect:) size:12];

        rawEncodingReader = [[RawEncodingReader alloc] initWithUpdater: self connection: connection];
        copyRectangleEncodingReader = [[CopyRectangleEncodingReader alloc] initWithUpdater: self connection: connection];
        rreEncodingReader = [[RREEncodingReader alloc] initWithUpdater: self connection: connection];
        coRreEncodingReader = [[CoRREEncodingReader alloc] initWithUpdater: self connection: connection];
        hextileEncodingReader = [[HextileEncodingReader alloc] initWithUpdater: self connection: connection];
        tightEncodingReader = [[TightEncodingReader alloc] initWithUpdater: self connection: connection];
        zlibEncodingReader = [[ZlibEncodingReader alloc] initWithUpdater: self connection: connection];
        zrleEncodingReader = [[ZRLEEncodingReader alloc] initWithUpdater: self connection: connection];
        zlibHexEncodingReader = [[ZlibHexEncodingReader alloc] initWithUpdater: self connection: connection];

        desktopNameReader = [[DesktopNameEncodingReader alloc] initWithUpdater:self
                                                     connection:connection];
        cursorReader = [[CursorPseudoEncodingReader alloc] initWithUpdater: self
                connection: connection];

        invalidRects = [[NSMutableArray alloc] init];
        shouldResize = NO;
	}
    return self;
}

- (void)dealloc
{
    [headerReader release];
    [rectHeaderReader release];

    [rawEncodingReader release];
    [copyRectangleEncodingReader release];
    [rreEncodingReader release];
    [coRreEncodingReader release];
    [hextileEncodingReader release];
    [tightEncodingReader release];
	[zlibEncodingReader release];
	[zrleEncodingReader release];
	[zlibHexEncodingReader release];

    [desktopNameReader release];
    [cursorReader release];

    [invalidRects release];

    [super dealloc];
}

- (void)setFrameBuffer:(id)aBuffer
{
    bytesPerPixel = [aBuffer bytesPerPixel];
    [rawEncodingReader setFrameBuffer:aBuffer];
    [copyRectangleEncodingReader setFrameBuffer:aBuffer];
    [cursorReader setFrameBuffer:aBuffer];
    [rreEncodingReader setFrameBuffer:aBuffer];
    [coRreEncodingReader setFrameBuffer:aBuffer];
    [hextileEncodingReader setFrameBuffer:aBuffer];
    [tightEncodingReader setFrameBuffer:aBuffer];
	[zlibEncodingReader setFrameBuffer:aBuffer];
	[zrleEncodingReader setFrameBuffer:aBuffer];
	[zlibHexEncodingReader setFrameBuffer:aBuffer];
}

- (void)readMessage
{
    [connection setReader:headerReader];
    [connection frameBufferUpdateBeginning];
}

- (void)setHeader:(NSData*)header
{
    rfbFramebufferUpdateMsg msg;

#ifdef COLLECT_STATS
    bytesTransferred += [header length];
#endif
    memcpy(&msg.pad, [header bytes], sizeof(msg) - 1);
    numberOfRects = ntohs(msg.nRects);
    if (numberOfRects > 0)
        [connection setReader:rectHeaderReader];
    else
        /* OSXvnc/Vine Server version 3.11 will sometimes send FramebufferUpdate
         * messages with no rectangles. */
        [self updateComplete];
}

/* Received header for a rectangle as part of update. Dispatch to appropriate
 * encoding reader. */
- (void)setRect:(NSData*)rectInfo
{
    EncodingReader  *theReader = nil;
    CARD32          e;
    rfbFramebufferUpdateRectHeader* msg = (rfbFramebufferUpdateRectHeader*)[rectInfo bytes];

#ifdef COLLECT_STATS
    bytesTransferred += [rectInfo length];
#endif
    currentRect.origin.x = ntohs(msg->r.x);
    currentRect.origin.y = ntohs(msg->r.y);
    currentRect.size.width = ntohs(msg->r.w);
    currentRect.size.height = ntohs(msg->r.h);
    e = ntohl(msg->encoding);
    if (currentRect.size.width == 0 && currentRect.size.height == 0
            && e != rfbEncodingPointerPos) {
		// this is a hack for compatibility with OSXvnc 1.0
		[self updateComplete];
		return;
    }
    switch(e) {
        case rfbEncodingRaw:
            theReader = rawEncodingReader;
            break;
        case rfbEncodingCopyRect:
            theReader = copyRectangleEncodingReader;
            break;
        case rfbEncodingRRE:
            theReader = rreEncodingReader;
            break;
        case rfbEncodingCoRRE:
            theReader = coRreEncodingReader;
            break;
        case rfbEncodingHextile:
            theReader = hextileEncodingReader;
            break;
		case rfbEncodingZlib:
			theReader = zlibEncodingReader;
			break;
        case rfbEncodingTight:
            theReader = tightEncodingReader;
            break;
		case rfbEncodingZlibHex:
			theReader = zlibHexEncodingReader;
			break;
		case rfbEncodingZRLE:
			theReader = zrleEncodingReader;
			break;

        // pseudo-encodings
        case rfbEncodingDesktopName:
            theReader = desktopNameReader;
            break;
        case rfbEncodingRichCursor:
            theReader = cursorReader;
			break;
        case rfbEncodingPointerPos:
            [connection serverMovedMouseTo:currentRect.origin];
            [self didRect:nil];
            return;
        case rfbEncodingLastRect:
            [self updateComplete];
            return;
        case rfbEncodingDesktopSize:
            resize = currentRect.size;
            shouldResize = YES;
            [self didRect: nil];
            return;
    }
    if(theReader == nil) {
        [connection terminateConnection:[NSString stringWithFormat:
            @"Unknown rectangle encoding %d -> exiting", e]];
    } else {
        [theReader setRectangle:currentRect];
        [theReader readEncoding];
        if (e <= rfbEncodingMax) { // not a pseudo-encoding
            [invalidRects addObject: [NSValue valueWithRect:currentRect]];
            bytesRepresented += currentRect.size.width * currentRect.size.height
                                    * bytesPerPixel;
            rectsTransferred++;
        }
    }
}

/* Message from encoder that it has finished drawing its rectangle. Read the
 * next rectangle */
- (void)didRect:(EncodingReader*)aReader
{
#ifdef COLLECT_STATS
    bytesTransferred += [aReader bytesTransferred];
    rectsTransferred++;
#endif

    numberOfRects--;
    if(numberOfRects) {
        [connection setReader:rectHeaderReader];
    } else {
        [self updateComplete];
    }
}

#if 0
- (double)compressRatio
{
    return (bytesRepresented/bytesTransferred);
}
#endif

- (double)rectanglesTransferred
{
    return rectsTransferred;
}

#if 0
- (double)bytesTransferred
{
    return bytesTransferred;
}
#endif

- (double)bytesRepresented
{
    return bytesRepresented;
}

- (void)updateComplete
{
    if (shouldResize) {
        shouldResize = NO;
        [connection frameBufferUpdateCompleteWithResize:resize];
    } else {
        int     i;

        /* We only mark the changed rectangles as dirty at the end of the
         * update.  This means that normally the framebuffer will not be drawn,
         * and thus the user will not see partial updates. However, if the user
         * scrolls, the OS will ask the RFBView to draw, and it will draw from
         * the possibly partially updated framebuffer. */
        for (i = 0; i < [invalidRects count]; i++) {
            [connection invalidateRect: [[invalidRects objectAtIndex:i]
                rectValue]];
        }
        [invalidRects removeAllObjects];

        [connection frameBufferUpdateComplete];
    }
    [protocol messageReaderDone];
}

@end
