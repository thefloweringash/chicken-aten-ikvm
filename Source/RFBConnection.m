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

#import "RFBConnection.h"
#import "AppDelegate.h"
#import "ByteBlockReader.h"
#import "ConnectionWaiter.h"
#import "EncodingReader.h"
#import "EventFilter.h"
#import "FrameBuffer.h"
#import "FrameBufferUpdateReader.h"
#import "FullscreenWindow.h"
#import "IServerData.h"
#import "KeyEquivalent.h"
#import "KeyEquivalentManager.h"
#import "KeyEquivalentScenario.h"
#import "Keymap.h"
#import "PersistentServer.h"
#import "PrefController.h"
#import "Profile.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "RFBHandshaker.h"
#import "RFBProtocol.h"
#import "RFBServerInitReader.h"
#import "RFBView.h"
#import "Session.h"
#define XK_MISCELLANY
#include <X11/keysymdef.h>
#include <libc.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>

// size of write buffer
#define BUFFER_SIZE 2048
#define READ_BUF_SIZE (1024*1024)

@implementation RFBConnection

// jason added for Jaguar check
+ (void)initialize {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithFloat: 0.0], @"FrameBufferUpdateSeconds", nil];
	
	[standardUserDefaults registerDefaults: dict];
}


// mark refactored init methods
- (void)_prepareWithServer:(id<IServerData>)server profile:(Profile*)p
{
    _profile = [p retain];

    currentReader = nil;
}

- (void)_finishInitWithFileHandle:(NSFileHandle*)file server:(id<IServerData>)server
{
    ByteBlockReader *versionReader;

    server_ = [(id)server retain];
    password = [[server password] retain];
	
	_eventFilter = [[EventFilter alloc] init];
	[_eventFilter setConnection: self];

    versionReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setServerVersion:)];
    [versionReader setBufferSize: 12];
    [self setReader:versionReader];
    [versionReader release];

    socketHandler = [file retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readData:) 	name:NSFileHandleDataAvailableNotification object:socketHandler];
    [socketHandler waitForDataInBackgroundAndNotify];

    lastMouseX = -1;
    lastMouseY = -1;
    lastMouseMovement = [[NSDate alloc] init];

    _mouseMovedTrackingTag = 0;
    _lastUpdateRequestDate = nil;

    isReceivingUpdate = NO;
    bytesReceived = 0;

    int     keepAliveTime = 5 * 60; // 5 minutes
    if (setsockopt([socketHandler fileDescriptor], IPPROTO_TCP, TCP_KEEPALIVE,
                (char *)&keepAliveTime, sizeof(int)) < 0)
        NSLog(@"Error with setsockopt TCP_KEEPALIVE: %d", errno);

#if 1
    int     nodelay = 1;
    if (setsockopt([socketHandler fileDescriptor], IPPROTO_TCP, TCP_NODELAY,
                    (char *)&nodelay, sizeof(int)) < 0)
        NSLog(@"Error with setsockopt TCP_NODELAY: %d", errno);
#endif

    writeBuffer = (unsigned char *)malloc(BUFFER_SIZE);
    bufferLen = 0;
    lastBufferedIsMouseMovement = NO;
}

- (id)initWithFileHandle:(NSFileHandle*)file server:(id<IServerData>)server profile:(Profile*)p
{
    if (self = [super init]) {
        [self _prepareWithServer:server profile:p];
        [self _finishInitWithFileHandle:(NSFileHandle*)file server:server];
	}
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeMouseMovedTrackingRect];

    [rfbView setDelegate:nil];

    [_frameUpdateTimer invalidate];
    [_frameUpdateTimer release];
    [socketHandler closeFile]; // release is not sufficient because the
                               // asynchronous reading seems to keep a retain
	[socketHandler release];
    [currentReader release];
	[_eventFilter release];
	[handshaker release];
    [password release];
	[rfbProtocol release];
	[frameBuffer release];
    [lastMouseMovement release];
    [_lastUpdateRequestDate release];
    free(writeBuffer);

    [super dealloc];
}

- (void)setRfbView:(RFBView *)view
{
    rfbView = view;
    window = [rfbView window];
	[_eventFilter setView: rfbView];
    if (frameBuffer)
        [rfbView setFrameBuffer:frameBuffer];
}

- (void)setSession:(Session *)aSession
{
    session = aSession;
}

- (void)setPassword:(NSString *)aPassword
{
    [password release];
    password = [aPassword retain];
}

- (id<IServerData>)server
{
    return server_;
}

- (Profile*)profile
{
    return _profile;
}

- (int) protocolMajorVersion {
	return MIN(rfbProtocolMajorVersion, serverMajorVersion);
}

- (int) protocolMinorVersion {
    if (serverMajorVersion > rfbProtocolMajorVersion)
        return rfbProtocolMinorVersion;
    else
        return MIN(rfbProtocolMinorVersion, serverMinorVersion);
}

- (void)setReader:(ByteReader*)aReader
{
    [currentReader release];
    currentReader = [aReader retain];
    [aReader resetReader];
}

- (void)setServerVersion:(NSData*)aVersion
{
        // C-string version of server versions: 12 bytes + NULL
    char    cStr[13];

    [aVersion getBytes: cStr length: 12];
    cStr[12] = '\0';
	if (sscanf(cStr, rfbProtocolVersionFormat, &serverMajorVersion, &serverMinorVersion) < 2) {
        [session terminateConnection: NSLocalizedString(@"NotVNC", nil)];
        return;
    }
	
    NSLog(@"Server reports Version %d.%d\n", serverMajorVersion, serverMinorVersion);
    // ARD sends this bogus 889 version#, at least for ARD 2.2 they actually
    // comply with version 003.007 so we'll force that
	if (serverMinorVersion == 889) {
		NSLog(@"\tBogus RFB Protocol Version Number from AppleRemoteDesktop, switching to protocol 003.007\n");
		serverMinorVersion = 7;
	}
	
    handshaker = [[RFBHandshaker alloc] initWithConnection: self];
	[handshaker handshake];
}

- (void)setCursor: (NSCursor *)aCursor
{
    if (![server_ viewOnly])
        [rfbView setServerCursorTo: aCursor];
}

- (void)terminateConnection:(NSString *)reason
{
    [self setReader:nil]; // causes readData to stop
    [session terminateConnection:reason];
}

- (void)authenticationFailed:(NSString *)reason
{
    [session authenticationFailed:reason];
}

/* Creates a framebuffer and sets up rfbView for a given display size */
- (void)sizeDisplay:(NSSize)aSize withPixelFormat:(rfbPixelFormat *)pixf
{
    id frameBufferClass;

	[frameBuffer release];
    frameBufferClass = [[PrefController sharedController] defaultFrameBufferClass];
    frameBuffer = [[frameBufferClass alloc] initWithSize:aSize andFormat:pixf];
	[frameBuffer setServerMajorVersion: serverMajorVersion minorVersion: serverMinorVersion];
	
    [rfbView setFrameBuffer:frameBuffer];
}

- (void)setDisplayName:(NSString*)aName
{
    [session setDisplayName:aName];
}

/* Handshaking has been completed */
- (void)start:(ServerInitMessage*)info
{
    [rfbProtocol release];
    rfbProtocol = [[RFBProtocol alloc] initWithConnection:self serverInfo:info];

    [self sizeDisplay:[info size] withPixelFormat:[info pixelFormatData]];
    [session setSize:[info size]];
    [rfbView setFrameBuffer:frameBuffer];
    [rfbView setDelegate:self];
    [session setupWindow];
    [session setDisplayName: [info name]];
    [self requestUpdate:[rfbView bounds] incremental:NO];
    [rfbProtocol setFrameBuffer:frameBuffer];

    [handshaker release];
    handshaker = nil;
}

- (NSString*)password
{
    return password;
}

- (BOOL)connectShared
{
    return [server_ shared];
}

- (BOOL)viewOnly
{
	return [server_ viewOnly];
}

- (void)invalidateRect:(NSRect)aRect
{
    NSRect b = [rfbView bounds];
    NSRect r = aRect;

    r.origin.y = b.size.height - NSMaxY(r);
    [rfbView setNeedsDisplayInRect: r];
}

- (void)frameBufferUpdateBeginning
{
    isReceivingUpdate = YES;
}

- (void)frameBufferUpdateComplete {
	if (! _hasManualFrameBufferUpdates)
		[self queueUpdateRequest];
    [self writeBuffer]; // flush buffered mouse movement, if any
    [rfbView displayIfNeededIgnoringOpacity];
    [session frameBufferUpdateComplete];
    isReceivingUpdate = NO;
}

/* End of a framebuffer update which included a resize. We enact the resize
 * here. */
- (void)frameBufferUpdateCompleteWithResize:(NSSize)newSize
{
    [self sizeDisplay:newSize withPixelFormat:[frameBuffer pixelFormat]];
    [rfbProtocol setFrameBuffer:frameBuffer];
    [self requestUpdate:[rfbView bounds] incremental:NO];
    isReceivingUpdate = NO;
    [session frameBufferUpdateComplete];

    [session resize:newSize];
}

- (void)readData:(NSNotification*)aNotification
{
    unsigned        consumed;
    ssize_t         length;
    unsigned char   *buf = malloc(READ_BUF_SIZE);
    unsigned char   *bytes = buf;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // if we process slower than our requests, we don't autorelease until we get a break, which could be never.

    length = read([socketHandler fileDescriptor], buf, READ_BUF_SIZE);

    if(length <= 0) {	// server closed socket
		NSString *reason = NSLocalizedString( @"ServerClosed", nil );
        [self terminateConnection:reason];
		[pool release];
        free(buf);
        return;
    }
    
    while(length) {
        consumed = [currentReader readBytes:bytes length:length];

        if (consumed == 0) {
            [self terminateConnection: NSLocalizedString(@"ProtocolError", nil)];
            [pool release];
            return;
        }

        length -= consumed;
        bytes += consumed;
        if (isReceivingUpdate)
            bytesReceived += consumed;
        if (currentReader == nil) {
			[pool release];
            free(buf);
            return;
        }
    }
    [socketHandler waitForDataInBackgroundAndNotify];
    [self retain];
	[pool release];
    [self autorelease];
    free(buf);
}

/* Request frame buffer update, possibly after a delay */
- (void)queueUpdateRequest {
    if (_frameBufferUpdateSeconds > 0.0) {
        if (_frameUpdateTimer == nil) {
            _frameUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval: _frameBufferUpdateSeconds target: self selector: @selector(requestFrameBufferUpdate:) userInfo: nil repeats: NO] retain];
        }
    } else {
        NSTimeInterval delay;

        delay = [_lastUpdateRequestDate timeIntervalSinceNow] + 1.0/60.0;
        if (_lastUpdateRequestDate && delay > 0.0) {
            /* Delays update request so that we send at most 60/second, which is
               fast as will be visible. Note that an NSTimer will be too slow to
               be responsive here. */
            struct timespec t;
            t.tv_sec = 0;
            t.tv_nsec = (long) (delay * 1000.0 * 1000.0 * 1000.0);
            nanosleep(&t, NULL);
        }

        [self requestFrameBufferUpdate: nil];
    }

}

/* Send incremental update request for whole framebuffer */
- (void)requestFrameBufferUpdate:(id)sender {
	[_frameUpdateTimer invalidate];
	[_frameUpdateTimer release];
	_frameUpdateTimer = nil;

    [self requestUpdate:[rfbView bounds] incremental:YES];
}

- (void)requestUpdate:(NSRect)frame incremental:(BOOL)aFlag
{
    rfbFramebufferUpdateRequestMsg	msg;

    msg.type = rfbFramebufferUpdateRequest;
    msg.incremental = aFlag;
    // :TORESOLVE: do coordinates need to be translated here?
    msg.x = frame.origin.x; msg.x = htons(msg.x);
    msg.y = frame.origin.y; msg.y = htons(msg.y);
    msg.w = frame.size.width; msg.w = htons(msg.w);
    msg.h = frame.size.height; msg.h = htons(msg.h);
    [self writeBytes:(unsigned char*)&msg length:sz_rfbFramebufferUpdateRequestMsg];

    [_lastUpdateRequestDate release];
    _lastUpdateRequestDate = [[NSDate alloc] init];
}

/* The server has moved the cursor to pos in RFB coordinates */
- (void)serverMovedMouseTo:(NSPoint)pos
{
    if ([session hasKeyWindow] && -[lastMouseMovement timeIntervalSinceNow] > 0.5
            && ![server_ viewOnly])
    {
        NSSize  size = [frameBuffer size];
        CGPoint screenCoords;

        pos.y = size.height - pos.y;
        pos = [rfbView convertPoint:pos toView:nil];
        pos = [window convertBaseToScreen:pos];
        if (!NSPointInRect(pos, [window frame]))
            return;
        screenCoords.x = pos.x;
        screenCoords.y = CGDisplayPixelsHigh(CGMainDisplayID()) - pos.y;
        CGWarpMouseCursorPosition(screenCoords);
    }
}

/* Translates a coordinate point into an RFB message. Also records the mouse
 * movement in lastMouseMovement. */
- (void)putPosition:(NSPoint)thePoint inPointerMessage:(rfbPointerEventMsg *)msg
{
    NSRect b = [rfbView bounds];
    NSSize s = [frameBuffer size];

    if(thePoint.x < 0) thePoint.x = 0;
    if(thePoint.y < 0) thePoint.y = 0;
    if(thePoint.x > s.width - 1) thePoint.x = s.width - 1;
    if(thePoint.y > s.height - 1) thePoint.y = s.height - 1;

    msg->x = htons((CARD16) thePoint.x);
    msg->y = htons((CARD16) (b.size.height - thePoint.y));

    [lastMouseMovement release];
    lastMouseMovement = [[NSDate alloc] init];
}

- (void)mouseAt:(NSPoint)thePoint buttons:(unsigned int)mask
{
    rfbPointerEventMsg  msg;

    msg.type = rfbPointerEvent;
    msg.buttonMask = mask;
    [self putPosition:thePoint inPointerMessage:&msg];

    if (msg.x == lastMouseX && msg.y == lastMouseY)
        return;

    if (lastBufferedIsMouseMovement)
        bufferLen -= sizeof(msg); // coalesce successive mouse movements

    if (isReceivingUpdate) {
        [self writeBufferedBytes: (unsigned char *)&msg length:sizeof(msg)];
        lastBufferedIsMouseMovement = YES;
    } else {
        [self writeBytes: (unsigned char *)&msg length:sizeof(msg)];
        lastBufferedIsMouseMovement = NO;
    }

    lastMouseX = msg.x;
    lastMouseY = msg.y;
}

- (void)mouseClickedAt:(NSPoint)thePoint buttons:(unsigned int)mask
{
    rfbPointerEventMsg msg;
	
    msg.type = rfbPointerEvent;
    msg.buttonMask = mask;
    [self putPosition:thePoint inPointerMessage:&msg];

    [self writeBufferedBytes: (unsigned char *)&msg length:sizeof(msg)];

    lastMouseX = msg.x;
    lastMouseY = msg.y;
}

- (void)sendModifier:(unsigned int)m pressed: (BOOL)pressed
{
	/*NSString *modifierStr =nil;
	switch (m)
	{
		case NSShiftKeyMask:
			modifierStr = @"NSShiftKeyMask";		break;
		case NSControlKeyMask:
			modifierStr = @"NSControlKeyMask";		break;
		case NSAlternateKeyMask:
			modifierStr = @"NSAlternateKeyMask";	break;
		case NSCommandKeyMask:
			modifierStr = @"NSCommandKeyMask";		break;
		case NSAlphaShiftKeyMask:
			modifierStr = @"NSAlphaShiftKeyMask";	break;
	}
	NSLog(@"modifier %@ %s", modifierStr, pressed ? "pressed" : "released"); */

    rfbKeyEventMsg msg;

    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
	msg.down = pressed;
	
    if( NSShiftKeyMask == m )
        msg.key = htonl([_profile shiftKeyCode]);
	else if( NSControlKeyMask == m )
        msg.key = htonl([_profile controlKeyCode]);
	else if( NSAlternateKeyMask == m )
        msg.key = htonl([_profile altKeyCode]);
	else if( NSCommandKeyMask == m )
        msg.key = htonl([_profile commandKeyCode]);
    else if(NSAlphaShiftKeyMask == m)
        msg.key = htonl(XK_Caps_Lock);
    else if(NSHelpKeyMask == m)		// this is F1
        msg.key = htonl(XK_F1);
	else if (NSNumericPadKeyMask == m) // don't know how to handle, eat it
		return;
	
    // XK_VoidSymbol is used for unbound modifier keys
    if (msg.key != htonl(XK_VoidSymbol)) {
        [self writeBufferedBytes:(unsigned char*)&msg length:sizeof(msg)];
    }
}

/* --------------------------------------------------------------------------------- */
- (void)sendKey:(unichar)c pressed:(BOOL)pressed
{
    rfbKeyEventMsg msg;
    unsigned int keysym = 0;

    if (pressed)
        pressed = 1; // make sure it's 0 or 1 for index

    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = pressed;

    if ((c & 0xf800) == 0xd800) { // surrogate code point
        /* The unichar type is not really a unicode code point, because it is
         * only 16-bit, so it codes non-BMP characters using surrogate pairs.
         * Here, we coalesce successive key events for surrogate pairs into a
         * single key event, using highSurrogate. */
        if (c & 0x0400) { // low surrogate
            if (highSurrogate[pressed]) {
                keysym = 0x01000000 // keysym offset for Unicode
                            + 0x00010000 // non-Basic Multilingual Plane offset
                            + ((highSurrogate[pressed] - 0xd800) << 10)
                            + (c - 0xdc00);
                highSurrogate[pressed] = 0;
            } else
                return;
        } else { // high surrogate
            highSurrogate[pressed] = c;
            return;
        }
    } else {
        highSurrogate[pressed] = 0;

        switch (c & 0xff80) {
            case 0x0000: // ASCII
            case 0x0080: // Latin-I supplement
                keysym = page0[c];
                if (keysym == 0)
                    return;
                break;
            case 0x0100: keysym = page1[c & 0x7f]; break; // Latin Extended-A
            case 0x0380: keysym = page3[c & 0x7f]; break; // Greek
            case 0x0400: keysym = page4[c & 0x7f]; break; // Cyrillic
            case 0x0580:
                if (c & 0x040)
                    keysym = page5[c & 0x3f]; // Hebrew
                break;
            case 0x0600: keysym = page6[c & 0x7f]; break; // Arabic
            case 0x0e00: keysym = pagee[c & 0x7f]; break; // Thai
            case 0x3080: keysym = page30[c & 0x7f]; break; // Japanese
            case 0xf600:
                if (c < 0xf640) {
                    keysym = pagef6[c & 0x3f]; // key pad
                    if (keysym == 0)
                        return;
                }
                break;
            case 0xf700:
                keysym = pagef7[c & 0x7f]; // Apple's function keys
                if (keysym == 0) // don't send special-use Unicode characters
                    return;
                break;
        }

        if (keysym == 0)
            keysym = c + 0x01000000; // default: map character algorithmically
    }

    msg.key = htonl(keysym);
    [self writeBufferedBytes:(unsigned char*)&msg length:sizeof(msg)];
}

/* Send a raw (RFB) key code. Used for simulated key sequences. */
- (void)sendKeyCode: (CARD32)key pressed: (BOOL)pressed
{
    rfbKeyEventMsg msg;
	
    msg.type = rfbKeyEvent;
    msg.down = pressed;
    msg.pad = 0;
	msg.key = htonl(key);
    [self writeBufferedBytes: (unsigned char*)&msg length:sizeof(msg)];
}

- (BOOL)pasteFromPasteboard:(NSPasteboard*)pb
{
    id types, theType;
	NSString *str;
	
    types = [NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil];
    if((theType = [pb availableTypeFromArray:types]) == nil) {
        NSLog(@"No supported pasteboard type\n");
        return NO;
    }
    str = [pb stringForType:theType];
    if([str isKindOfClass:[NSArray class]]) {
        str = [(id)str objectAtIndex:0];
    }
    
	[_eventFilter pasteString: str];
    return YES;
}

- (EventFilter *)eventFilter
{  return _eventFilter;  }

- (Session *)session
{
    return session;
}

- (void)reallyWriteBytes:(unsigned char*)bytes length:(unsigned int)length
{
    int result;
    int written = 0;

    /* Seemingly, this loop is actually unnecessary: write will only do a
     * partial write if we were doing non-blocking IO, which we aren't */
    do {
        result = write([socketHandler fileDescriptor], bytes + written, length);
        if(result >= 0) {
            length -= result;
            written += result;
        } else {
            if(errno == EAGAIN) {
                continue;
            }
            if(errno == EPIPE) {
				NSString *reason = NSLocalizedString( @"ServerClosed", nil );
                [self terminateConnection:reason];
                return;
            }
			NSString *reason = NSLocalizedString( @"ServerError", nil );
			reason = [NSString stringWithFormat: reason, strerror(errno)];
            [self terminateConnection:reason];
            return;
        }
    } while(length > 0);
}

- (void)writeBytes:(unsigned char *)bytes length:(unsigned int)length
{
    if (bufferLen > 0) {
        [self writeBufferedBytes:bytes length:length];
        [self writeBuffer];
    } else
        [self reallyWriteBytes:bytes length:length];
}

/* Writes the bytes to a buffer. Note that the buffering reduces context
 * switches to the kernel and network traffic. */
- (void)writeBufferedBytes:(unsigned char *)bytes length:(unsigned int)length
{
    if (bufferLen + length > BUFFER_SIZE) {
        [self writeBuffer];
        if (length > BUFFER_SIZE) {
            [self reallyWriteBytes: bytes length: length];
            return;
        }
    }

    memcpy(writeBuffer + bufferLen, bytes, length);
    bufferLen += length;
    lastBufferedIsMouseMovement = NO;
}

- (void)writeBuffer
{
    if (bufferLen == 0)
        return;

    [self reallyWriteBytes:writeBuffer length:bufferLen];
    bufferLen = 0;
    lastBufferedIsMouseMovement = NO;
}

- (void)writeRFBString:(NSString *)aString {
    const char	*str = [aString UTF8String]; // null-terminated utf8-encoded string
	CARD32      len=htonl(strlen(str));
	[self writeBufferedBytes:(unsigned char *)&len length:4];
	[self writeBufferedBytes:(unsigned char *)str length:len];
}

- (void)viewFrameDidChange:(NSNotification *)aNotification
{
	[self removeMouseMovedTrackingRect];
	[self installMouseMovedTrackingRect];
    [window invalidateCursorRectsForView: rfbView];
}

- (NSString *)infoString
{
    NSString    *endian;
    NSString    *trueColor;

    endian = NSLocalizedString([frameBuffer serverIsBigEndian] ?  @"big-endian" : @"little-endian", nil);
    trueColor = NSLocalizedString(frameBuffer->pixelFormat.trueColour ? @"yes" : @"no", nil);

    return
        [NSString stringWithFormat: NSLocalizedString(@"ServerInfo", nil),
                serverMajorVersion, serverMinorVersion,
                (int)[frameBuffer size].width, (int)[frameBuffer size].height,
                frameBuffer->pixelFormat.bitsPerPixel,
                frameBuffer->pixelFormat.depth, endian, trueColor,
                frameBuffer->pixelFormat.redMax,
                frameBuffer->pixelFormat.greenMax,
                frameBuffer->pixelFormat.blueMax,
                frameBuffer->pixelFormat.redShift,
                frameBuffer->pixelFormat.greenShift,
                frameBuffer->pixelFormat.blueShift];
}

static NSString* byteString(double d)
{
    if(d < 10000) {
        return [NSString stringWithFormat:@"%u", (unsigned)d];
    } else if(d < (1024*1024)) {
        return [NSString stringWithFormat:@"%.2fKB", d / 1024];
    } else if(d < (1024*1024*1024)) {
        return [NSString stringWithFormat:@"%.2fMB", d / (1024*1024)];
    } else {
        return [NSString stringWithFormat:@"%.2fGB", d / (1024*1024*1024)];
    }
}

- (NSString *)statisticsString
{
    FrameBufferUpdateReader* reader = [rfbProtocol frameBufferUpdateReader];
    double  represented = [reader bytesRepresented];

    return
        [NSString stringWithFormat: NSLocalizedString(@"ConnectionStatistics", nil),
            byteString(bytesReceived), byteString(represented),
            represented/bytesReceived, (unsigned)[reader rectanglesTransferred],
            [reader rectsByTypeString]
    	];
}

- (void)installMouseMovedTrackingRect
{
	NSPoint mousePoint = [rfbView convertPoint: [window convertScreenToBase: [NSEvent mouseLocation]] fromView: nil];
	BOOL mouseInVisibleRect = [rfbView mouse: mousePoint inRect: [rfbView visibleRect]];

    if (_mouseMovedTrackingTag)
        [rfbView removeTrackingRect: _mouseMovedTrackingTag];
	_mouseMovedTrackingTag = [rfbView addTrackingRect: [rfbView bounds] owner: self userData: nil assumeInside: mouseInVisibleRect];
	if (mouseInVisibleRect)
		[window setAcceptsMouseMovedEvents: YES];
}

- (void)removeMouseMovedTrackingRect
{
	[rfbView removeTrackingRect: _mouseMovedTrackingTag];
	[window setAcceptsMouseMovedEvents: NO];
    _mouseMovedTrackingTag = 0;
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [window setAcceptsMouseMovedEvents: YES];
}

- (void)mouseExited:(NSEvent *)theEvent {
    [window setAcceptsMouseMovedEvents: NO];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    [session mouseDragged:theEvent];
}

- (void)setFrameBufferUpdateSeconds: (float)seconds {
    int     hadManualUpdates = _hasManualFrameBufferUpdates;

	_frameBufferUpdateSeconds = seconds;
	_hasManualFrameBufferUpdates = _frameBufferUpdateSeconds >= [[PrefController sharedController] maxPossibleFrameBufferUpdateSeconds];

    if (hadManualUpdates && !_hasManualFrameBufferUpdates)
        [self requestFrameBufferUpdate:nil];
}

@end
