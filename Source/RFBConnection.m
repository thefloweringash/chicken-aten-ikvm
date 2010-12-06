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
#import "PrefController.h"
#import "Profile.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "RFBHandshaker.h"
#import "RFBProtocol.h"
#import "RFBServerInitReader.h"
#import "RFBView.h"
#define XK_MISCELLANY
#include <X11/keysymdef.h>
#include <libc.h>

// size of write buffer
#define BUFFER_SIZE 2048
#define READ_BUF_SIZE (1024*1024)

// tables for mapping Unicode characters to X11 keysyms, defined in Keymap.m
extern const unsigned int page0[];
extern const unsigned int page1[];
extern const unsigned int page3[];
extern const unsigned int page4[];
extern const unsigned int page5[];
extern const unsigned int page6[];
extern const unsigned int pagee[];
extern const unsigned int page30[];
extern const unsigned int pagef6[];
extern const unsigned int pagef7[];

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
    _isFullscreen = NO; // jason added for fullscreen display

    if((host = [server host]) == nil) {
        host = [DEFAULT_HOST retain];
    } else {
        [host retain];
    }

    currentReader = nil;
}

- (void)_finishInitWithFileHandle:(NSFileHandle*)file server:(id<IServerData>)server
{
    ByteBlockReader *versionReader;

    [NSBundle loadNibNamed:@"RFBConnection.nib" owner:self];
    server_ = [(id)server retain];
	
	_eventFilter = [[EventFilter alloc] init];
	[_eventFilter setConnection: self];

    versionReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setServerVersion:)];
    [versionReader setBufferSize: 12];
    [self setReader:versionReader];
    [versionReader release];

    socketHandler = [file retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readData:) 	name:NSFileHandleDataAvailableNotification object:socketHandler];
    [socketHandler waitForDataInBackgroundAndNotify];
    [rfbView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];

    password = [[server password] retain];

    lastMouseX = -1;
    lastMouseY = -1;
    lastMouseMovement = [[NSDate alloc] init];

    _horizScrollFactor = 0;
    _vertScrollFactor = 0;

    _connectionStartDate = [[NSDate alloc] init];
    _reconnectWaiter = nil;
    _reconnectSheetTimer = nil;

    _mouseMovedTrackingTag = 0;
    _lastUpdateRequestDate = nil;

    isReceivingUpdate = NO;
    isStopped = NO;
    shouldUpdate = NO;
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
	[newTitlePanel orderOut:self];
	[optionPanel orderOut:self];
	
	[window close];
    [windowedWindow close];
	[self terminateConnection: nil]; // just in case it didn't already get called somehow
    [_connectionStartDate release];
    free(writeBuffer);
    [super dealloc];
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
        [self terminateConnection: NSLocalizedString(@"NotVNC", nil)];
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

- (void)connectionHasTerminated
{
	[[RFBConnectionManager sharedManager] removeConnection:self];

    [socketHandler closeFile]; // release is not sufficient because the
                               // asynchronous reading seems to keep a retain
	[socketHandler release];	socketHandler = nil;
    [currentReader release];    currentReader = nil;
	[_eventFilter release];		_eventFilter = nil;
	[titleString release];		titleString = nil;
	[handshaker release];		handshaker = nil;
	[(id)server_ release];		server_ = nil;
    [password release];         password = nil;
	[rfbProtocol release];		rfbProtocol = nil;
	[frameBuffer release];		frameBuffer = nil;
    [lastMouseMovement release]; lastMouseMovement = nil;
	[_profile release];			_profile = nil;
	[host release];				host = nil;
	[realDisplayName release];	realDisplayName = nil;
    [_reconnectSheetTimer invalidate];
    [_reconnectSheetTimer release]; _reconnectSheetTimer = nil;
    [_reconnectWaiter cancel];
    [_reconnectWaiter release]; _reconnectWaiter = nil;
    [_lastUpdateRequestDate release]; _lastUpdateRequestDate = nil;
}

- (void)connectionTerminatedSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	/* One might reasonably argue that this should be handled by the connection manager. */
	switch (returnCode) {
		case NSAlertDefaultReturn:
			break;
		case NSAlertAlternateReturn:
            _reconnectWaiter = [[ConnectionWaiter alloc] initWithServer:server_
                        profile:_profile delegate:self window:window];
            NSString *templ = NSLocalizedString(@"NoReconnection", nil);
            NSString *err = [NSString stringWithFormat:templ, host];
            [_reconnectWaiter setErrorStr:err];
            _reconnectSheetTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5
                    target:self selector:@selector(createReconnectSheet:)
                    userInfo:nil repeats:NO] retain];
            return;
		default:
			NSLog(@"Unknown alert returnvalue: %d", returnCode);
			break;
	}
	[self connectionHasTerminated];
}

// Problem with connection: make windowed and stop reading from socket
- (void)connectionProblem
{
    terminating = YES;
	
    if (_isFullscreen)
        [self makeConnectionWindowed: self];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cancelFrameBufferUpdateTimer];
}

/* Some kind of connection failure. Decide whether to try to reconnect. */
- (void)terminateConnection:(NSString*)aReason
{
    if(!terminating) {		
        [self connectionProblem];
		[self endFullscreenScrolling];
		[_eventFilter clearAllEmulationStates];
		[_eventFilter synthesizeRemainingEvents];
		[_eventFilter sendAllPendingQueueEntriesNow];

        if(aReason) {
            NSTimeInterval timeout = [[PrefController sharedController] intervalBeforeReconnect];
            BOOL supportReconnect = [server_ doYouSupport:CONNECT];

			if (supportReconnect
                    && -[_connectionStartDate timeIntervalSinceNow] > timeout) {
                NSLog(@"Automatically reconnecting to server.  The connection was closed because: \"%@\".", aReason);
				// begin reconnect
                [self connectionTerminatedSheetDidEnd:nil returnCode:0
                    contextInfo:NULL];
			}
			else {
				// Ask what to do
				NSString *header = NSLocalizedString( @"ConnectionTerminated", nil );
				NSString *okayButton = NSLocalizedString( @"Okay", nil );
				NSString *reconnectButton =  NSLocalizedString( @"Reconnect", nil );
				NSBeginAlertSheet(header, okayButton, supportReconnect ? reconnectButton : nil, nil, window, self, @selector(connectionTerminatedSheetDidEnd:returnCode:contextInfo:), nil, nil, aReason);
			}
        } else {
            [self connectionHasTerminated];
        }
    }
}

/* Authentication failed: give the user a chance to re-enter password. */
- (void)authenticationFailed:(NSString *)aReason
{
    if (terminating)
        return;

    [self connectionProblem];
    [authMessage setStringValue: aReason];
    [NSApp beginSheet:passwordSheet modalForWindow:window
           modalDelegate:self
           didEndSelector:@selector(passwordEnteredFor:returnCode:contextInfo:)
           contextInfo:nil];
    [rememberNewPassword setState: [server_ rememberPassword]];
}

/* User entered new password */
- (IBAction)reconnectWithNewPassword:(id)sender
{
    [password release];
    password = [[passwordField stringValue] retain];
    if ([rememberNewPassword state])
        [server_ setPassword: password];
    [server_ setRememberPassword: [rememberNewPassword state]];

    [self connectionTerminatedSheetDidEnd:nil returnCode:NSAlertAlternateReturn
                              contextInfo:NULL];
    [NSApp endSheet:passwordSheet];
}

/* User cancelled chance to enter new password */
- (IBAction)dontReconnect:(id)sender
{
    [NSApp endSheet:passwordSheet];
    [self connectionHasTerminated];
}

- (void)passwordEnteredFor:(NSWindow *)wind returnCode:(int)retCode
            contextInfo:(void *)info
{
    [passwordSheet orderOut:self];
}

/* Close the connection and then reconnect */
- (IBAction)forceReconnect:(id)sender
{
    if (terminating)
        return;

    [self connectionProblem];
    [socketHandler closeFile];
    [socketHandler release];
    socketHandler = nil;
    [self connectionTerminatedSheetDidEnd:nil returnCode:NSAlertAlternateReturn
                              contextInfo:NULL];
}

/* Returns the maximum possible size for the window. Also, determines whether or
 * not the scrollbars are necessary. */
- (NSSize)_maxSizeForWindowSize:(NSSize)aSize;
{
    NSRect  winframe;
    NSSize	maxviewsize;
    BOOL usesFullscreenScrollers = [[PrefController sharedController] fullscreenHasScrollbars];

    horizontalScroll = verticalScroll = NO;

    maxviewsize = [NSScrollView frameSizeForContentSize:[rfbView frame].size
                                  hasHorizontalScroller:horizontalScroll
                                    hasVerticalScroller:verticalScroll
                                             borderType:NSNoBorder];
    if (!_isFullscreen || usesFullscreenScrollers) {
        if(aSize.width < maxviewsize.width) {
            horizontalScroll = YES;
        }
        if(aSize.height < maxviewsize.height) {
            verticalScroll = YES;
        }
    }
    maxviewsize = [NSScrollView frameSizeForContentSize:[rfbView frame].size
                                  hasHorizontalScroller:horizontalScroll
                                    hasVerticalScroller:verticalScroll
                                             borderType:NSNoBorder];
    winframe = [window frame];
    winframe.size = maxviewsize;
    winframe = [NSWindow frameRectForContentRect:winframe styleMask:[window styleMask]];
    return winframe.size;
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
    _maxSize = aSize;
}

/* Sets up window. */
- (void)setupWindow
{
    NSRect wf;
	NSRect screenRect;
	NSClipView *contentView;
	NSString *serverName;

    [rfbView setDelegate:self];
	[_eventFilter setView: rfbView];

	screenRect = [[NSScreen mainScreen] visibleFrame];
    wf.origin.x = wf.origin.y = 0;
    wf.size = [NSScrollView frameSizeForContentSize:_maxSize hasHorizontalScroller:NO hasVerticalScroller:NO borderType:NSNoBorder];
    wf = [NSWindow frameRectForContentRect:wf styleMask:[window styleMask]];
	if (NSWidth(wf) > NSWidth(screenRect)) {
		horizontalScroll = YES;
		wf.size.width = NSWidth(screenRect);
	}
	if (NSHeight(wf) > NSHeight(screenRect)) {
		verticalScroll = YES;
		wf.size.height = NSHeight(screenRect);
	}
	
	// According to the Human Interace Guidelines, new windows should be "visually centered"
	// If screenRect is X1,Y1-X2,Y2, and wf is x1,y1 -x2,y2, then
	// the origin (bottom left point of the rect) for wf should be
	// Ox = ((X2-X1)-(x2-x1)) * (1/2)    [I.e., one half screen width less window width]
	// Oy = ((Y2-Y1)-(y2-y1)) * (2/3)    [I.e., two thirds screen height less window height]
	// Then the origin must be offset by the "origin" of the screen rect.
	// Note that while Rects are floats, we seem to have an issue if the origin is
	// not an integer, so we use the floor() function.
	wf.origin.x = floor((NSWidth(screenRect) - NSWidth(wf))/2 + NSMinX(screenRect));
	wf.origin.y = floor((NSHeight(screenRect) - NSHeight(wf))*2/3 + NSMinY(screenRect));
	
	serverName = [server_ name];
	if(![window setFrameUsingName:serverName]) {
		// NSLog(@"Window did NOT have an entry: %@\n", serverName);
		[window setFrame:wf display:NO];
	}
	[window setFrameAutosaveName:serverName];

    if ([server_ fullscreen]) {
        [self makeConnectionFullscreen:self];
        return;
    }

	contentView = [scrollView contentView];
    [contentView scrollToPoint: [contentView constrainScrollPoint: NSMakePoint(0.0, _maxSize.height - [scrollView contentSize].height)]];
    [scrollView reflectScrolledClipView: contentView];

    [window makeFirstResponder:rfbView];
	[self windowDidResize: nil];
    [window makeKeyAndOrderFront:self];
    [window display];
}

- (void)setNewTitle:(id)sender
{
    [titleString release];
    titleString = [[newTitleField stringValue] retain];

    [[RFBConnectionManager sharedManager] setDisplayNameTranslation:titleString forName:realDisplayName forHost:host];
    [window setTitle:titleString];
    [newTitlePanel orderOut:self];
}

- (void)setDisplayName:(NSString*)aName
{
	[realDisplayName release];
    realDisplayName = [aName retain];
    [titleString release];
    titleString = [[[RFBConnectionManager sharedManager] translateDisplayName:realDisplayName forHost:host] retain];
    [window setTitle:titleString];
}

- (NSSize)displaySize
{
    return [frameBuffer size];
}

/* Handshaking has been completed */
- (void)start:(ServerInitMessage*)info
{
    [rfbProtocol release];
    rfbProtocol = [[RFBProtocol alloc] initWithConnection:self serverInfo:info
                                                 viewOnly:[server_ viewOnly]];

    [self sizeDisplay:[info size] withPixelFormat:[info pixelFormatData]];
    [self setupWindow];
    [self setDisplayName: [info name]];
    [self requestUpdate:[rfbView bounds] incremental:NO];
    [rfbProtocol setFrameBuffer:frameBuffer];

    [handshaker release];
    handshaker = nil;
}

- (void)setPassword:(NSString *)aPassword
{
    [password release];
    password = [aPassword retain];
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
    [rfbView displayIfNeededIgnoringOpacity];
    if ([optionPanel isVisible])
        [self updateStatistics:nil];
    isReceivingUpdate = NO;
}

/* End of a framebuffer update which included a resize. We enact the resize
 * here. */
- (void)frameBufferUpdateCompleteWithResize:(NSSize)newSize
{
    NSSize  maxSize;
    NSRect  frame;

    [self sizeDisplay:newSize withPixelFormat:[frameBuffer pixelFormat]];
    [rfbProtocol setFrameBuffer:frameBuffer];
    [self requestUpdate:[rfbView bounds] incremental:NO];
    isReceivingUpdate = NO;
    if ([optionPanel isVisible])
        [self updateInfoField];

    // resize window, if necessary
    maxSize = [self _maxSizeForWindowSize:[[window contentView] frame].size];
    frame = [window frame];
    if (frame.size.width > maxSize.width)
        frame.size.width = maxSize.width;
    if (frame.size.height > maxSize.height)
        frame.size.height = maxSize.height;
    [window setFrame:frame display:YES];

    [self windowDidResize:nil]; // setup scroll bars if necessary
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
        if(terminating) {
			[pool release];
            free(buf);
            return;
        }
    }
    [socketHandler waitForDataInBackgroundAndNotify];
	[pool release];
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
    [self cancelFrameBufferUpdateTimer];

	if (terminating) return;

    if(isStopped) {
        shouldUpdate = YES;
    } else {
		[self requestUpdate:[rfbView bounds] incremental:YES];
	}
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

- (void)cancelFrameBufferUpdateTimer
{
	[_frameUpdateTimer invalidate];
	[_frameUpdateTimer release];
	_frameUpdateTimer = nil;
}

/* The server has moved the cursor to pos in RFB coordinates */
- (void)serverMovedMouseTo:(NSPoint)pos
{
    if ([window isKeyWindow] && -[lastMouseMovement timeIntervalSinceNow] > 0.5
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
        bufferLen -= sizeof(msg); // collapse successive mouse movements

    if (isReceivingUpdate) {
        [self writeBufferedBytes: (unsigned char *)&msg length:sizeof(msg)];
        lastBufferedIsMouseMovement = YES;
    } else
        [self writeBytes: (unsigned char *)&msg length:sizeof(msg)];

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

- (void)sendCmdOptEsc: (id)sender
{
    [self sendKeyCode: XK_Alt_L pressed: YES];
    [self sendKeyCode: XK_Meta_L pressed: YES];
    [self sendKeyCode: XK_Escape pressed: YES];
    [self sendKeyCode: XK_Escape pressed: NO];
    [self sendKeyCode: XK_Meta_L pressed: NO];
    [self sendKeyCode: XK_Alt_L pressed: NO];
    [self writeBuffer];
}

- (void)sendCtrlAltDel: (id)sender
{
    [self sendKeyCode: XK_Control_L pressed: YES];
    [self sendKeyCode: XK_Alt_L pressed: YES];
    [self sendKeyCode: XK_Delete pressed: YES];
    [self sendKeyCode: XK_Delete pressed: NO];
    [self sendKeyCode: XK_Alt_L pressed: NO];
    [self sendKeyCode: XK_Control_L pressed: NO];
    [self writeBuffer];
}

- (void)sendPauseKeyCode: (id)sender
{
    [self sendKeyCode: XK_Pause pressed: YES];
    [self sendKeyCode: XK_Pause pressed: NO];
    [self writeBuffer];
}

- (void)sendBreakKeyCode: (id)sender
{
    [self sendKeyCode: XK_Break pressed: YES];
    [self sendKeyCode: XK_Break pressed: NO];
    [self writeBuffer];
}

- (void)sendPrintKeyCode: (id)sender
{
    [self sendKeyCode: XK_Print pressed: YES];
    [self sendKeyCode: XK_Print pressed: NO];
    [self writeBuffer];
}

- (void)sendExecuteKeyCode: (id)sender
{
    [self sendKeyCode: XK_Execute pressed: YES];
    [self sendKeyCode: XK_Execute pressed: NO];
    [self writeBuffer];
}

- (void)sendInsertKeyCode: (id)sender
{
    [self sendKeyCode: XK_Insert pressed: YES];
    [self sendKeyCode: XK_Insert pressed: NO];
    [self writeBuffer];
}

- (void)sendDeleteKeyCode: (id)sender
{
    [self sendKeyCode: XK_Delete pressed: YES];
    [self sendKeyCode: XK_Delete pressed: NO];
    [self writeBuffer];
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

- (void)paste:(id)sender
{
    [self pasteFromPasteboard:[NSPasteboard generalPasteboard]];
}

/* --------------------------------------------------------------------------------- */
- (void)openNewTitlePanel:(id)sender
{
    [newTitleField setStringValue:titleString];
    [newTitlePanel makeKeyAndOrderFront:self];
}

/* --------------------------------------------------------------------------------- */
- (BOOL)hasKeyWindow
{
    return [window isKeyWindow];
}

- (EventFilter *)eventFilter
{  return _eventFilter;  }


- (void)reallyWriteBytes:(unsigned char*)bytes length:(unsigned int)length
{
    int result;
    int written = 0;

    /* Seemingly, this loop is actually unnecessary: write will only do a
     * partial write if we were doing non-blocking IO, which we aren't */
    do {
        result = write([socketHandler fileDescriptor], bytes + written, length - written);
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

/* Window delegate methods */

- (void)windowDidDeminiaturize:(NSNotification *)aNotification
{
    isStopped = NO;
    if(shouldUpdate) {
        [self requestFrameBufferUpdate: nil];
        shouldUpdate = NO;
    }

	[self installMouseMovedTrackingRect];
}

- (void)windowDidMiniaturize:(NSNotification *)aNotification
{
    isStopped = YES;
	[self removeMouseMovedTrackingRect];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    // terminateConnection closes the window, so we have to null it out here
    // The window will autorelease itself when closed.  If we allow terminateConnection
    // to close it again, it will get double-autoreleased.  Bummer.
    window = NULL;
    [self terminateConnection:nil];
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    NSSize max = [self _maxSizeForWindowSize:proposedFrameSize];

    max.width = (proposedFrameSize.width > max.width) ? max.width : proposedFrameSize.width;
    max.height = (proposedFrameSize.height > max.height) ? max.height : proposedFrameSize.height;
    return max;
}

- (void)windowDidResize:(NSNotification *)aNotification
{
	[scrollView setHasHorizontalScroller:horizontalScroll];
	[scrollView setHasVerticalScroller:verticalScroll];
	if (_isFullscreen) {
		[self removeFullscreenTrackingRects];
		[self installFullscreenTrackingRects];
	}
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    if (!_isFullscreen) {
        /* If the user sets and uses a keyboard shortcut, then they can make us
         * key while another window is in fullscreen mode. Because of this
         * possibility, we need to make the other connections windowed. */
        [[RFBConnectionManager sharedManager] makeAllConnectionsWindowed];
        if (![window isKeyWindow]) {
            /* If some other window was in fullscreen mode, it will become key,
             * so we need to make our own window key again. Then this method
             * will be called again, so we can return from this invocation. */
            [window makeKeyWindow];
            return;
        }
    }
	[self installMouseMovedTrackingRect];
	[self setFrameBufferUpdateSeconds: [[PrefController sharedController] frontFrameBufferUpdateSeconds]];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	[self removeMouseMovedTrackingRect];
	[self setFrameBufferUpdateSeconds: [[PrefController sharedController] otherFrameBufferUpdateSeconds]];
	
	//Reset keyboard state on remote end
	[_eventFilter clearAllEmulationStates];
}

- (void)viewFrameDidChange:(NSNotification *)aNotification
{
	[self removeMouseMovedTrackingRect];
	[self installMouseMovedTrackingRect];
    [window invalidateCursorRectsForView: rfbView];
}

- (void)openOptions:(id)sender
{
    [self updateInfoField];
    [self updateStatistics:self];
    [optionPanel setTitle:titleString];
    [optionPanel makeKeyAndOrderFront:self];
}

- (void)updateInfoField
{
    NSString    *endian;
    NSString    *trueColor;

    endian = NSLocalizedString([frameBuffer serverIsBigEndian] ?  @"big-endian" : @"little-endian", nil);
    trueColor = NSLocalizedString(frameBuffer->pixelFormat.trueColour ? @"yes" : @"no", nil);

    [infoField setStringValue:
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
                frameBuffer->pixelFormat.blueShift]];
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

- (void)updateStatistics:(id)sender
{
    FrameBufferUpdateReader* reader = [rfbProtocol frameBufferUpdateReader];
    double  represented = [reader bytesRepresented];

    [statisticField setStringValue:
        [NSString stringWithFormat: NSLocalizedString(@"ConnectionStatistics", nil),
            byteString(bytesReceived), byteString(represented),
            represented/bytesReceived, (unsigned)[reader rectanglesTransferred],
            [reader rectsByTypeString]
    	]
    ];
}

- (BOOL)connectionIsFullscreen {
	return _isFullscreen;
}

- (IBAction)toggleFullscreenMode: (id)sender
{
	_isFullscreen ? [self makeConnectionWindowed: self] : [self makeConnectionFullscreen: self];
}

- (IBAction)makeConnectionWindowed: (id)sender {
	_isFullscreen = NO;
	[self removeFullscreenTrackingRects];
	[scrollView retain];
	[scrollView removeFromSuperview];
	[window setDelegate: nil];
	[window close];
	if (CGDisplayRelease( kCGDirectMainDisplay ) != kCGErrorSuccess) {
		NSLog( @"Couldn't release the main display!" );
	}
    window = windowedWindow;
    windowedWindow = nil;
    [window orderFront:nil];
	[window setDelegate: self];
	[window setContentView: scrollView];
	[scrollView release];
	[self _maxSizeForWindowSize: [[window contentView] frame].size];
	[window setTitle:titleString];
	[window makeFirstResponder: rfbView];
	[self windowDidResize: nil];
	[window makeKeyAndOrderFront:nil];
	[self viewFrameDidChange: nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                name:NSApplicationWillHideNotification object:nil];
}

- (void)connectionWillGoFullscreen:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	int windowLevel;
	NSRect screenRect;

	if (returnCode == NSAlertDefaultReturn) {
		[[RFBConnectionManager sharedManager] makeAllConnectionsWindowed];
		if (CGDisplayCapture( kCGDirectMainDisplay ) != kCGErrorSuccess) {
			NSLog( @"Couldn't capture the main display!" );
		}
		windowLevel = CGShieldingWindowLevel();
		screenRect = [[NSScreen mainScreen] frame];
	
		[scrollView retain];
		[scrollView removeFromSuperview];
        [[KeyEquivalentManager defaultManager]
                removeEquivalentForWindow:[window title]];
		[window setDelegate: nil];
        windowedWindow = window;
		window = [[FullscreenWindow alloc] initWithContentRect:screenRect
											styleMask:NSBorderlessWindowMask
											backing:NSBackingStoreBuffered
											defer:NO
											screen:[NSScreen mainScreen]];
		[window setDelegate: self];
		[window setContentView: scrollView];
		[scrollView release];
		[window setLevel:windowLevel];
		_isFullscreen = YES;
		[self _maxSizeForWindowSize: screenRect.size];
		[scrollView setHasHorizontalScroller:horizontalScroll];
		[scrollView setHasVerticalScroller:verticalScroll];

        if (_maxSize.width < screenRect.size.width
                || _maxSize.height < screenRect.size.height) {
            // center in screen
            NSClipView *contentView = [scrollView contentView];
            NSPoint     scrollPt;

            scrollPt = NSMakePoint((_maxSize.width - screenRect.size.width) / 2,
                               (_maxSize.height - screenRect.size.height) / 2);
            [contentView scrollToPoint:scrollPt];
            [scrollView reflectScrolledClipView:contentView];
        }

		[self installFullscreenTrackingRects];
		[self windowDidResize: nil];
		[window makeFirstResponder: rfbView];
		[window makeKeyAndOrderFront:nil];
        [windowedWindow orderOut:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                selector:@selector(applicationWillHide:)
                    name:NSApplicationWillHideNotification
                  object:nil];
	}
}

- (IBAction)makeConnectionFullscreen: (id)sender {
	BOOL displayFullscreenWarning = [[PrefController sharedController] displayFullScreenWarning];

	if (displayFullscreenWarning) {
        NSMutableString         *reason = [NSMutableString string];
        KeyEquivalentScenario   *scen;
        NSMenuItem              *menuItem;
        NSString *header = NSLocalizedString( @"FullscreenHeader", nil );

        [_eventFilter synthesizeRemainingEvents];

        [reason appendString: NSLocalizedString( @"FullscreenReason1", nil )];

            // Use the default KeyEquivalentManager to get the key equivalents
            // for the fullscreen scenario
        scen = [[KeyEquivalentManager defaultManager] keyEquivalentsForScenarioName: kConnectionFullscreenScenario]; 
        menuItem = [[[NSApplication sharedApplication] delegate] getFullScreenMenuItem];
        
        if (scen && menuItem) {
            KeyEquivalent *keyEquiv = [scen keyEquivalentForMenuItem: menuItem];
            NSString      *keyStr = [[keyEquiv userString] string];

            if (keyStr) {
                // If we can determine the fullscreen key combination, we include
                // it in the message
                [reason appendString: @"("];
                [reason appendString: keyStr];
                [reason appendString: @") "];
                [reason appendString: NSLocalizedString(@"FullscreenReason2", nil)];
            } else {
                reason = [NSMutableString stringWithString:NSLocalizedString(@"FullscreenNoKey", nil)];
                header = NSLocalizedString(@"FullscreenNoKeyHeader", nil);
            }
        } else {
            [reason appendString: NSLocalizedString(@"FullscreenReason2", nil)];
        }

        NSString *fullscreenButton = NSLocalizedString( @"Fullscreen", nil );
        NSString *cancelButton = NSLocalizedString( @"Cancel", nil );
        NSBeginAlertSheet(header, fullscreenButton, cancelButton, nil, window,
                          self, nil, @selector(connectionWillGoFullscreen:returnCode:contextInfo:),
                          nil, reason);
	} else {
		[self connectionWillGoFullscreen:nil returnCode:NSAlertDefaultReturn contextInfo:nil]; 
	}
}

- (void)applicationWillHide:(NSNotification *)notif
{
    [self makeConnectionWindowed:self];
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

- (void)installFullscreenTrackingRects {
	NSRect scrollRect = [scrollView bounds];
	const float minX = NSMinX(scrollRect);
	const float minY = NSMinY(scrollRect);
	const float maxX = NSMaxX(scrollRect);
	const float maxY = NSMaxY(scrollRect);
	const float width = NSWidth(scrollRect);
	const float height = NSHeight(scrollRect);
	float scrollWidth = [NSScroller scrollerWidth];
	NSRect aRect;

	if ( ! [[PrefController sharedController] fullscreenHasScrollbars] )
		scrollWidth = 0.0;
    if (_maxSize.width > width) {
        aRect = NSMakeRect(minX, minY, kTrackingRectThickness, height);
        _leftTrackingTag = [scrollView addTrackingRect:aRect owner:self userData:nil assumeInside: NO];
        aRect = NSMakeRect(maxX - kTrackingRectThickness - (horizontalScroll ? scrollWidth : 0.0), minY, kTrackingRectThickness, height);
        _rightTrackingTag = [scrollView addTrackingRect:aRect owner:self userData:nil assumeInside: NO];
    }

    if (_maxSize.height > height) {
        aRect = NSMakeRect(minX, minY, width, kTrackingRectThickness);
        _topTrackingTag = [scrollView addTrackingRect:aRect owner:self userData:nil assumeInside: NO];
        aRect = NSMakeRect(minX, maxY - kTrackingRectThickness - (verticalScroll ? scrollWidth : 0.0), width, kTrackingRectThickness);
        _bottomTrackingTag = [scrollView addTrackingRect:aRect owner:self userData:nil assumeInside: NO];
    }
}

- (void)removeMouseMovedTrackingRect
{
	[rfbView removeTrackingRect: _mouseMovedTrackingTag];
	[window setAcceptsMouseMovedEvents: NO];
    _mouseMovedTrackingTag = 0;
}

- (void)removeFullscreenTrackingRects {
	[self endFullscreenScrolling];
	[scrollView removeTrackingRect: _leftTrackingTag];
	[scrollView removeTrackingRect: _topTrackingTag];
	[scrollView removeTrackingRect: _rightTrackingTag];
	[scrollView removeTrackingRect: _bottomTrackingTag];
    _vertScrollFactor = _horizScrollFactor = 0;
}

- (void)mouseEntered:(NSEvent *)theEvent {
	NSTrackingRectTag trackingNumber = [theEvent trackingNumber];
	
	if (trackingNumber == _mouseMovedTrackingTag)
		[window setAcceptsMouseMovedEvents: YES];
	else {
        if (trackingNumber == _leftTrackingTag)
            _horizScrollFactor = -1;
        else if (trackingNumber == _topTrackingTag)
            _vertScrollFactor = +1;
        else if (trackingNumber == _rightTrackingTag)
            _horizScrollFactor = +1;
        else if (trackingNumber == _bottomTrackingTag)
            _vertScrollFactor = -1;
        else
            NSLog(@"Unknown trackingNumber %d", trackingNumber);

        if ([self connectionIsFullscreen])
            [self beginFullscreenScrolling];
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
	NSTrackingRectTag trackingNumber = [theEvent trackingNumber];

	if (trackingNumber == _mouseMovedTrackingTag)
		[window setAcceptsMouseMovedEvents: NO];
	else {
        if (trackingNumber == _leftTrackingTag
                || trackingNumber == _rightTrackingTag) {
            _horizScrollFactor = 0;
            if (_vertScrollFactor == 0)
                [self endFullscreenScrolling];
        } else {
            _vertScrollFactor = 0;
            if (_horizScrollFactor == 0)
                [self endFullscreenScrolling];
        }
    }
}

/* The tracking rectangles don't apply to mouse movement when the button is
 * down. So this method tests mouse drags to see if it should trigger fullscreen
 * scrolling. */
- (void)mouseDragged:(NSEvent *)theEvent
{
    if (!_isFullscreen)
        return;
    
    NSPoint pt = [scrollView convertPoint: [theEvent locationInWindow]
                                 fromView:nil];
    NSRect  scrollRect = [scrollView bounds];

    if (pt.x - NSMinX(scrollRect) < kTrackingRectThickness)
        _horizScrollFactor = -1;
    else if (NSMaxX(scrollRect) - pt.x < kTrackingRectThickness)
        _horizScrollFactor = 1;
    else
        _horizScrollFactor = 0;

    if (pt.y - NSMinY(scrollRect) < kTrackingRectThickness)
        _vertScrollFactor = 1;
    else if (NSMaxY(scrollRect) - pt.y < kTrackingRectThickness)
        _vertScrollFactor = -1;
    else
        _vertScrollFactor = 0;

    if (_horizScrollFactor || _vertScrollFactor)
        [self beginFullscreenScrolling];
    else
        [self endFullscreenScrolling];
}

- (void)beginFullscreenScrolling {
    if (_autoscrollTimer)
        return;
	_autoscrollTimer = [[NSTimer scheduledTimerWithTimeInterval: kAutoscrollInterval
											target: self
										  selector: @selector(scrollFullscreenView:)
										  userInfo: nil repeats: YES] retain];
}

- (void)endFullscreenScrolling {
	[_autoscrollTimer invalidate];
	[_autoscrollTimer release];
	_autoscrollTimer = nil;
}

- (void)scrollFullscreenView: (NSTimer *)timer {
	NSClipView *contentView = [scrollView contentView];
	NSPoint origin = [contentView bounds].origin;
	float autoscrollIncrement = [[PrefController sharedController] fullscreenAutoscrollIncrement];
    NSPoint newOrigin = NSMakePoint(origin.x + _horizScrollFactor * autoscrollIncrement, origin.y + _vertScrollFactor * autoscrollIncrement);

    newOrigin = [contentView constrainScrollPoint: newOrigin];
    // don't let constrainScrollPoint screw up centering
    if (_horizScrollFactor == 0)
        newOrigin.x = origin.x;
    if (_vertScrollFactor == 0)
        newOrigin.y = origin.y;

    [contentView scrollToPoint: newOrigin];
    [scrollView reflectScrolledClipView: contentView];
}

- (void)setFrameBufferUpdateSeconds: (float)seconds {
    int     hadManualUpdates = _hasManualFrameBufferUpdates;

	_frameBufferUpdateSeconds = seconds;
	_hasManualFrameBufferUpdates = _frameBufferUpdateSeconds >= [[PrefController sharedController] maxPossibleFrameBufferUpdateSeconds];

    if (hadManualUpdates && !_hasManualFrameBufferUpdates)
        [self requestFrameBufferUpdate:nil];
}

/* Reconnection attempts */

- (void)createReconnectSheet:(id)sender
{
    [NSApp beginSheet:_reconnectPanel modalForWindow:window
           modalDelegate:self
           didEndSelector:@selector(reconnectEnded:returnCode:contextInfo:)
           contextInfo:nil];
    [_reconnectIndicator startAnimation:self];

    [_reconnectSheetTimer release];
    _reconnectSheetTimer = nil;
}

- (void)reconnectCancelled:(id)sender
{
    [_reconnectWaiter cancel];
    [_reconnectWaiter release];
    _reconnectWaiter = nil;
    [NSApp endSheet:_reconnectPanel];
    [self connectionHasTerminated];
}

- (void)reconnectEnded:(id)sender returnCode:(int)retCode
           contextInfo:(void *)info
{
    [_reconnectPanel orderOut:self];
}

- (void)connectionPrepareForSheet
{
    [NSApp endSheet:_reconnectPanel];
}

/* Reconnect attempt has failed */
- (void)connectionFailed
{
    [self connectionHasTerminated];
}

/* Reconnect attempt has succeeded */
- (void)connectionSucceeded:(RFBConnection *)newConnection
{
    [newConnection setPassword: password];
    [[RFBConnectionManager sharedManager] successfulConnection:newConnection
            toServer:server_];

    [_reconnectWaiter release];
    _reconnectWaiter = nil;
    [self connectionHasTerminated];
}

- (IBAction)showProfileManager:(id)sender
{
    [[ProfileManager sharedManager] showWindowWithProfile:
        [_profile profileName]];
}

@end
