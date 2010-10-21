/* RFBProtocol.m created by helmut on Tue 16-Jun-1998 */

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

#import "RFBProtocol.h"
#import "CARD8Reader.h"
#import "FrameBuffer.h"
#import "FrameBufferUpdateReader.h"
#import "PrefController.h"
#import "Profile.h"
#import "RFBServerInitReader.h"
#import "RFBConnection.h"
#import "ServerCutTextReader.h"
#import "SetColorMapEntriesReader.h"

/* This class essentially handles all messages from the server once the initial
 * handshaking has been completed. It also sends the initial messages with the
 * supported encodings and the pixel format to the server. */
@implementation RFBProtocol

- (id)initWithConnection:(RFBConnection*)aConnection
          andServerInfo:(id)info
{
    if (self = [super init]) {
        connection = aConnection;
       
        [self setPixelFormat:[info pixelFormatData]];

		[self setEncodings];
		typeReader = [[CARD8Reader alloc] initTarget:self action:@selector(receiveType:)];
        msgTypeReader[rfbFramebufferUpdate] = [[FrameBufferUpdateReader alloc]
                initWithProtocol:self connection:connection];
        msgTypeReader[rfbSetColourMapEntries] = [[SetColorMapEntriesReader alloc] initWithProtocol:self connection:connection];
        msgTypeReader[rfbBell] = nil;
        msgTypeReader[rfbServerCutText] = [[ServerCutTextReader alloc]
                initWithProtocol:self connection:connection];

        [connection setReader: typeReader];
	}
    return self;
}

- (void)dealloc
{
    int i;

    [typeReader release];
    for(i=0; i<=MAX_MSGTYPE; i++) {
        [msgTypeReader[i] release];
    }
    [super dealloc];
}

/* Sends the list of supported encodings to the server. Note that it only
 * buffers the message, without actually writing it. It is assumed that a
 * subsequent message will be written without buffering. */
- (void)changeEncodingsTo:(CARD32*)newEncodings length:(CARD16)l
{
    int i;
    rfbSetEncodingsMsg msg;
    CARD32	*enc = (CARD32 *)malloc(l * sizeof(CARD32));

    msg.type = rfbSetEncodings;
    msg.nEncodings = htons(l);
    [connection writeBufferedBytes:(unsigned char*)&msg length:sizeof(msg)];
    for(i=0; i<l; i++) {
        enc[i] = htonl(newEncodings[i]);
    }
    [connection writeBufferedBytes:(unsigned char*)enc length:l*sizeof(CARD32)];
    free(enc);
}

- (void)setEncodings
{
    Profile* profile = [connection profile];
    CARD16 i, l = [profile numberOfEnabledEncodings];
    CARD32	*enc = (CARD32 *)malloc(l * sizeof(CARD32));

    for(i=0; i<l; i++) {
        enc[i] = [profile encodingAtIndex:i];
    }
    [self changeEncodingsTo:enc length:l];
    free(enc);
}

/* Sends the pixel format to the server. Note that it buffers without writing.
 * It is assumed that a later message will do a non-buffered write. */
- (void)setPixelFormat:(rfbPixelFormat*)aFormat
{
    Profile* profile = [connection profile];
    rfbSetPixelFormatMsg	msg;

    msg.type = rfbSetPixelFormat;
    aFormat->trueColour = YES;
    if([profile useServerNativeFormat]) {
        if(!aFormat->redMax || !aFormat->bitsPerPixel) {
            NSLog(@"Server proposes invalid format: redMax = %d, bitsPerPixel = %d, using local format",
                  aFormat->redMax, aFormat->bitsPerPixel);
            [[PrefController sharedController] getLocalPixelFormat:aFormat];
            aFormat->bigEndian = [FrameBuffer bigEndian];
        }
    } else {
       	[profile getPixelFormat:aFormat];
        aFormat->bigEndian = [FrameBuffer bigEndian];
    }

    NSLog(@"Transport Pixelformat:");
    NSLog(@"\ttrueColor = %s", aFormat->trueColour ? "YES" : "NO");
    NSLog(@"\tbigEndian = %s", aFormat->bigEndian ? "YES" : "NO");
    NSLog(@"\tbitsPerPixel = %d", aFormat->bitsPerPixel);
    NSLog(@"\tdepth = %d", aFormat->depth);
    NSLog(@"\tmaxValue(r/g/b) = (%d/%d/%d)", aFormat->redMax, aFormat->greenMax, aFormat->blueMax);
    NSLog(@"\tshift(r/g/b) = (%d/%d/%d)", aFormat->redShift, aFormat->greenShift, aFormat->blueShift);
    
    memcpy(&msg.format, aFormat, sizeof(rfbPixelFormat));
    msg.format.redMax = htons(msg.format.redMax);
    msg.format.greenMax = htons(msg.format.greenMax);
    msg.format.blueMax = htons(msg.format.blueMax);
    [connection writeBufferedBytes:(unsigned char*)&msg
                            length:sz_rfbSetPixelFormatMsg];
}

- (FrameBufferUpdateReader*)frameBufferUpdateReader
{
    return msgTypeReader[rfbFramebufferUpdate];
}

- (void)setFrameBuffer:(id)aBuffer
{
    [msgTypeReader[rfbFramebufferUpdate] setFrameBuffer:aBuffer];
}

- (void)messageReaderDone
{
    [connection setReader:typeReader];
}

- (void)receiveType:(NSNumber*)type
{
    unsigned t = [type unsignedIntValue];

    if(t > MAX_MSGTYPE) {
		NSString *errorStr = NSLocalizedString( @"UnknownMessageType", nil );
		errorStr = [NSString stringWithFormat:errorStr, type];
        [connection terminateConnection:errorStr];
    } else if(t == rfbBell) {
        NSBeep();
        [connection setReader:typeReader];
    } else {
        [msgTypeReader[t] readMessage];
    }
}

@end
