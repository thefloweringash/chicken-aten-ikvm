/* FrameBufferUpdateReader.h created by helmut on Wed 17-Jun-1998 */

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

extern NSString *encodingNames[];

@class ByteBlockReader;
@class CopyRectangleEncodingReader;
@class CoRREEncodingReader;
@class CursorPseudoEncodingReader;
@class DesktopNameEncodingReader;
@class EncodingReader;
@class HextileEncodingReader;
@class RawEncodingReader;
@class RFBConnection;
@class RFBProtocol;
@class RREEncodingReader;
@class TightEncodingReader;
@class ZlibEncodingReader;
@class ZlibHexEncodingReader;
@class ZRLEEncodingReader;

/* Handles frame buffer update messages from the server, which form the crux of
 * the RFB protocol. This message consists of a list of rectangles, and there is
 * an instance variable for each encoding of a rectangle. */
@interface FrameBufferUpdateReader : NSObject
{
    ByteBlockReader	    *headerReader;
    ByteBlockReader     *rectHeaderReader;

    RawEncodingReader           *rawEncodingReader;
    CopyRectangleEncodingReader *copyRectangleEncodingReader;
    RREEncodingReader           *rreEncodingReader;
    CoRREEncodingReader         *coRreEncodingReader;
    HextileEncodingReader       *hextileEncodingReader;
    TightEncodingReader         *tightEncodingReader;
    ZlibEncodingReader          *zlibEncodingReader;
    ZRLEEncodingReader          *zrleEncodingReader;
    ZlibHexEncodingReader       *zlibHexEncodingReader;

    DesktopNameEncodingReader   *desktopNameReader;
    CursorPseudoEncodingReader  *cursorReader;

    RFBConnection   *connection;
    RFBProtocol     *protocol;
    unsigned        bytesPerPixel;  // bytes per pixel in framebuffer

    CARD32 encoding;
    CARD16 numberOfRects;
    NSMutableArray  *invalidRects;
    NSSize resize;
    BOOL shouldResize;
    //double bytesTransferred;

    // transfer statistics
    double bytesRepresented;
    double rectsTransferred;
    unsigned rectsByType[rfbEncodingMax + 1];
}

- (id)initWithProtocol: (RFBProtocol *)aProtocol connection: (RFBConnection *)aConnection;

- (void)readMessage;
- (void)setFrameBuffer:(id)aBuffer;
- (void)updateComplete;
- (void)didRect:(EncodingReader*)aReader;

- (NSString *)lastEncodingName; // encoding of last rectangle read

- (double)rectanglesTransferred;
- (double)bytesRepresented;
- (NSString *)rectsByTypeString;

@end
