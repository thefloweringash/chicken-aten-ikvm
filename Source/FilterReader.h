/* FilterReader.h created by helmut on 01-Nov-2000 */

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
#import "TightEncodingReader.h"
#import "RFBConnection.h"

/* Base class for filters which are used by the Tight encoding */
@interface FilterReader : NSObject
{
    TightEncodingReader *target;
    RFBConnection       *connection;

    FrameBuffer*        frameBuffer;
    unsigned            bytesPerPixel;
    unsigned            bytesTransferred;
}

- (id)initWithTarget: (TightEncodingReader *)aTarget
          andConnection: (RFBConnection *)aConnection;

- (void)resetFilterForRect:(NSRect)rect;

- (void)setFrameBuffer:(FrameBuffer*)aFrameBuffer;
- (NSData*)filter:(NSData*)data rows:(unsigned)numRows;
- (unsigned)bitsPerPixel;
- (unsigned)bytesTransferred;

@end
