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
#import "RFBServerInitReader.h"
#import "RFBConnection.h"
#import "FrameBufferUpdateReader.h"
#import "SetColorMapEntriesReader.h"
#import "ServerCutTextReader.h"
#import "FrameBuffer.h"
#import "RFBConnectionManager.h"
#import "Profile.h"

@implementation RFBProtocol

- (CARD16)numberOfEncodings
{
    return numberOfEncodings;
}

- (CARD32*)encodings
{
    return encodings;
}

- (void)changeEncodingsTo:(CARD32*)newEncodings length:(CARD16)l
{
    int i;
    rfbSetEncodingsMsg msg;
    CARD32	enc[64];

    numberOfEncodings = l;
    msg.type = rfbSetEncodings;
    msg.nEncodings = htons(l);
    [target writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    for(i=0; i<l; i++) {
        encodings[i] = newEncodings[i];
        enc[i] = htonl(encodings[i]);
    }
    [target writeBytes:(unsigned char*)&enc length:numberOfEncodings * sizeof(CARD32)];
}

- (void)setEncodings
{
    Profile* profile = [target profile];
    CARD16 i, l = [profile numberOfEnabledEncodings];
    CARD32	enc[64];

    for(i=0; i<l; i++) {
        enc[i] = [profile encodingAtIndex:i];
    }
    [self changeEncodingsTo:enc length:l];
}

- (void)requestUpdate:(NSRect)frame incremental:(BOOL)aFlag
{
    rfbFramebufferUpdateRequestMsg	msg;

    msg.type = rfbFramebufferUpdateRequest;
    msg.incremental = aFlag;
    msg.x = frame.origin.x; msg.x = htons(msg.x);
    msg.y = frame.origin.y; msg.y = htons(msg.y);
    msg.w = frame.size.width; msg.w = htons(msg.w);
    msg.h = frame.size.height; msg.h = htons(msg.h);
    [target writeBytes:(unsigned char*)&msg length:sz_rfbFramebufferUpdateRequestMsg];
}

- (void)setPixelFormat:(rfbPixelFormat*)aFormat
{
    Profile* profile = [target profile];
    rfbSetPixelFormatMsg	msg;

    msg.type = rfbSetPixelFormat;
    aFormat->trueColour = YES;
    if([profile useServerNativeFormat]) {
        if(!aFormat->redMax || !aFormat->bitsPerPixel) {
            NSLog(@"Server proposes invalid format: redMax = %d, bitsPerPixel = %d, using local format",
                  aFormat->redMax, aFormat->bitsPerPixel);
            [RFBConnectionManager getLocalPixelFormat:aFormat];
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
    [target writeBytes:(unsigned char*)&msg length:sz_rfbSetPixelFormatMsg];
}

- (id)initTarget:(id)aTarget serverInfo:(id)info
{
	rfbPixelFormat	myFormat;
	
    [super initTarget:aTarget action:NULL];
    memcpy(&myFormat, (rfbPixelFormat*)[info pixelFormatData], sizeof(myFormat));
    [self setPixelFormat:&myFormat];
    [aTarget setDisplaySize:[info size] andPixelFormat:&myFormat];
    [aTarget setDisplayName:[info name]];
    [self setEncodings];
    [self requestUpdate:[aTarget visibleRect] incremental:NO];
    typeReader = [[CARD8Reader alloc] initTarget:self action:@selector(receiveType:)];
    msgTypeReader[rfbFramebufferUpdate] = [[FrameBufferUpdateReader alloc] initTarget:self action:@selector(frameBufferUpdate:)];
    msgTypeReader[rfbSetColourMapEntries] = [[SetColorMapEntriesReader alloc] initTarget:self action:@selector(setColormapEntries:)];
    msgTypeReader[rfbBell] = nil;
    msgTypeReader[rfbServerCutText] = [[ServerCutTextReader alloc] initTarget:self action:@selector(serverCutText:)];
    return self;
}

- (FrameBufferUpdateReader*)frameBufferUpdateReader
{
    return msgTypeReader[rfbFramebufferUpdate];
}

- (void)setFrameBuffer:(id)aBuffer
{
    [msgTypeReader[rfbFramebufferUpdate] setFrameBuffer:aBuffer];
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

- (void)frameBufferUpdate:(id)aReader
{
    [target setReader:self];
    if(isStopped) {
        shouldUpdate = YES;
    } else {
        [self requestUpdate:[target visibleRect] incremental:YES];
    }
}

- (void)setColormapEntries:(id)aReader
{
    [target setReader:self];
}

- (void)serverCutText:(NSString*)aText
{
    [target setReader:self];
}

- (void)resetReader
{
    [target setReader:typeReader];
}

- (void)receiveType:(NSNumber*)type
{
    unsigned t = [type unsignedIntValue];

    if(t > MAX_MSGTYPE) {
        [target terminateConnection:[NSString stringWithFormat:@"Unknown message type %@\n", type]];
    } else if(t == rfbBell) {
        [target ringBell];
        [target setReader:self];
    } else {
        [target setReader:(msgTypeReader[t])];
    }
}

- (void)continueUpdate
{
    if(isStopped) {
        isStopped = NO;
        if(shouldUpdate) {
            [self requestUpdate:[target visibleRect] incremental:YES];
            shouldUpdate = NO;
        }
    }
}

- (void)stopUpdate
{
    if(!isStopped) {
        isStopped = YES;
    }
}


@end
