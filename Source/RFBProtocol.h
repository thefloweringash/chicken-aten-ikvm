/* RFBProtocol.h created by helmut on Tue 16-Jun-1998 */

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
#import "ByteReader.h"
#import "FrameBufferUpdateReader.h"

#define	MAX_MSGTYPE	rfbServerCutText

@class CARD8Reader;
@class FrameBuffer;
@class RFBConnection;

/* Handles processing data from the server once the connection is up and the
 * protocol is established. It has instance variables which handle each message
 * type, except for rfbBell, which is handled internally. */
@interface RFBProtocol : NSObject
{
    RFBConnection   *connection;

    CARD8Reader     *typeReader;
    id              msgTypeReader[MAX_MSGTYPE + 1];
    unsigned        lastMessage;
}

- (id)initWithConnection:(RFBConnection *)aTarget serverInfo:(id)info;
- (void)setFrameBuffer:(FrameBuffer *)aBuffer;
- (void)messageReaderDone;

- (void)setPixelFormat:(rfbPixelFormat*)aFormat;

- (void)setEncodings;

- (FrameBufferUpdateReader*)frameBufferUpdateReader;

@end
