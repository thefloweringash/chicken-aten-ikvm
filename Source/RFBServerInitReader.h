/* RFBServerInitReader.h created by helmut on Tue 16-Jun-1998 */

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
#import "rfbproto.h"

@class RFBConnection;
@class RFBHandshaker;
@class RFBStringReader;

/* This reads the intitial message from the server, which consists of a server
 * initiailization message. */
@interface ServerInitMessage : NSObject
{
    rfbServerInitMsg fixed;
    NSString*	name;
}

- (void)setFixed:(NSData*)data;
- (void)setName:(NSString*)aName;
- (NSString*)name;
- (NSSize)size;
- (rfbPixelFormat *)pixelFormatData;

@end

@interface RFBServerInitReader : NSObject
{
    RFBConnection       *connection;
    RFBHandshaker       *handshaker;
    RFBStringReader     *nameReader;
    ServerInitMessage*  msg;
}

- (id)initWithConnection: (RFBConnection *)aConnection
          andHandshaker: (RFBHandshaker *)aHandshaker;
- (void)readServerInit;

@end
