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
#import "EncodingReader.h"
#import "FrameBuffer.h"
#import "FrameBufferUpdateReader.h"
#import "FullscreenWindow.h"
#import "IServerData.h"
#import "KeyEquivalentManager.h"
#import "NLTStringReader.h"
#import "PrefController.h"
#import "RectangleList.h"
#import "RFBConnectionManager.h"
#import "RFBHandshaker.h"
#import "RFBProtocol.h"
#import "RFBServerInitReader.h"
#import "RFBView.h"
#include <unistd.h>
#include <libc.h>

#define	F1_KEYCODE		0xffbe
#define F2_KEYCODE		0xffbf
#define	F3_KEYCODE		0xffc0

// jason added definition for capslock
#define CAPSLOCK		0xffe5

// jason added a check for Jaguar
BOOL gIsJaguar;

#define UMLAUTE			'u'

@implementation RFBConnection

const unsigned int page0[256] = {
    0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0xff09, 0xa, 0xb, 0xc, 0xff0d, 0xe, 0xf,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0xff09, 0x1a, 0xff1b, 0x1c, 0x1d, 0x1e, 0x1f,
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
    0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f,
    0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5e, 0x5f,
    0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f,
    0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0xff08,
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f,
    0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf,
    0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe, 0xbf,
    0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf,
    0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde, 0xdf,
    0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xeb, 0xec, 0xed, 0xee, 0xef,
    0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff,
};

const unsigned int pagef7[256] = {
    0xff52, 0xff54, 0xff51, 0xff53, 0xf704, 0xffbf, 0xffc0, 0xffc1, 0xffc2, 0xffc3, 0xffc4, 0xffc5, 0xffc6, 0xffc7, 0xffc8, 0xffc9,
    0xf710, 0xf711, 0xf712, 0xf713, 0xf714, 0xf715, 0xf716, 0xf717, 0xf718, 0xf719, 0xf71a, 0xf71b, 0xf71c, 0xf71d, 0xf71e, 0xf71f,
    0xf720, 0xf721, 0xf722, 0xf723, 0xf724, 0xf725, 0xf726, 0xff63, 0xffff, 0xff50, 0xf72a, 0xff57, 0xff55, 0xff56, 0xf72e, 0xf72f,
    0xf730, 0xf731, 0xf732, 0xf733, 0xf734, 0xf735, 0xf736, 0xf737, 0xf738, 0xf739, 0xf73a, 0xf73b, 0xf73c, 0xf73d, 0xf73e, 0xf73f,
    0xf740, 0xf741, 0xf742, 0xf743, 0xf744, 0xf745, 0xf746, 0xf747, 0xf748, 0xf749, 0xf74a, 0xf74b, 0xf74c, 0xf74d, 0xf74e, 0xf74f,
    0xf750, 0xf751, 0xf752, 0xf753, 0xf754, 0xf755, 0xf756, 0xf757, 0xf758, 0xf759, 0xf75a, 0xf75b, 0xf75c, 0xf75d, 0xf75e, 0xf75f,
    0xf760, 0xf761, 0xf762, 0xf763, 0xf764, 0xf765, 0xf766, 0xf767, 0xf768, 0xf769, 0xf76a, 0xf76b, 0xf76c, 0xf76d, 0xf76e, 0xf76f,
    0xf770, 0xf771, 0xf772, 0xf773, 0xf774, 0xf775, 0xf776, 0xf777, 0xf778, 0xf779, 0xf77a, 0xf77b, 0xf77c, 0xf77d, 0xf77e, 0xf77f,
    0xf780, 0xf781, 0xf782, 0xf783, 0xf784, 0xf785, 0xf786, 0xf787, 0xf788, 0xf789, 0xf78a, 0xf78b, 0xf78c, 0xf78d, 0xf78e, 0xf78f,
    0xf790, 0xf791, 0xf792, 0xf793, 0xf794, 0xf795, 0xf796, 0xf797, 0xf798, 0xf799, 0xf79a, 0xf79b, 0xf79c, 0xf79d, 0xf79e, 0xf79f,
    0xf7a0, 0xf7a1, 0xf7a2, 0xf7a3, 0xf7a4, 0xf7a5, 0xf7a6, 0xf7a7, 0xf7a8, 0xf7a9, 0xf7aa, 0xf7ab, 0xf7ac, 0xf7ad, 0xf7ae, 0xf7af,
    0xf7b0, 0xf7b1, 0xf7b2, 0xf7b3, 0xf7b4, 0xf7b5, 0xf7b6, 0xf7b7, 0xf7b8, 0xf7b9, 0xf7ba, 0xf7bb, 0xf7bc, 0xf7bd, 0xf7be, 0xf7bf,
    0xf7c0, 0xf7c1, 0xf7c2, 0xf7c3, 0xf7c4, 0xf7c5, 0xf7c6, 0xf7c7, 0xf7c8, 0xf7c9, 0xf7ca, 0xf7cb, 0xf7cc, 0xf7cd, 0xf7ce, 0xf7cf,
    0xf7d0, 0xf7d1, 0xf7d2, 0xf7d3, 0xf7d4, 0xf7d5, 0xf7d6, 0xf7d7, 0xf7d8, 0xf7d9, 0xf7da, 0xf7db, 0xf7dc, 0xf7dd, 0xf7de, 0xf7df,
    0xf7e0, 0xf7e1, 0xf7e2, 0xf7e3, 0xf7e4, 0xf7e5, 0xf7e6, 0xf7e7, 0xf7e8, 0xf7e9, 0xf7ea, 0xf7eb, 0xf7ec, 0xf7ed, 0xf7ee, 0xf7ef,
    0xf7f0, 0xf7f1, 0xf7f2, 0xf7f3, 0xf7f4, 0xf7f5, 0xf7f6, 0xf7f7, 0xf7f8, 0xf7f9, 0xf7fa, 0xf7fb, 0xf7fc, 0xf7fd, 0xf7fe, 0xf7ff,
};

static unsigned address_for_name(char *name)
{
    unsigned    address = INADDR_NONE;

    address = (name == NULL || *name == 0) ? INADDR_ANY : inet_addr(name);
    if(address == INADDR_NONE) {
        struct hostent *hostinfo = gethostbyname(name);
        if(hostinfo != NULL && (hostinfo->h_addr_list[0] != NULL)) {
            address = *((unsigned*)hostinfo->h_addr_list[0]);
        }
    }
    return address;
}

static void socket_address(struct sockaddr_in *addr, NSString* host, int port)
{
    addr->sin_family = AF_INET;
    addr->sin_port = htons(port);
    addr->sin_addr.s_addr = address_for_name((char*)[host cString]);
}

- (void)perror:(NSString*)theAction call:(NSString*)theFunction
{
    NSString* s = [NSString stringWithFormat:@"%s: %@", strerror(errno), theFunction];
    NSRunAlertPanel(theAction, s, @"Ok", NULL, NULL, NULL);
}

// jason added for Jaguar check
+ (void)initialize {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithFloat: 0.0], @"FrameBufferUpdateSeconds", nil];
	
	[standardUserDefaults registerDefaults: dict];
	gIsJaguar = [NSString instancesRespondToSelector: @selector(decomposedStringWithCanonicalMapping)];
}

// jason changed for fullscreen display
- (id)initWithServer:(id<IServerData>)server profile:(Profile*)p owner:(id)owner
{
    if (self = [super init]) {
		struct sockaddr_in	remote;
		int sock, port;

		profile = [p retain];
		_owner = owner; // jason added for fullscreen display
		_isFullscreen = NO; // jason added for fullscreen display
		if((sock = socket(PF_INET, SOCK_STREAM, 0)) < 0) {
			[self perror:@"Open Connection" call:@"socket()"];
			[self release];
			return nil;
		}
		if((host = [server host]) == nil) {
			host = [DEFAULT_HOST retain];
		} else {
			[host retain];
		}
		port = [server display];
		// displays >= 100 are treated as port numbers, in the
		// same way as RealVNC and others does. 
		if (port < 100)
		    port += RFB_PORT;
		socket_address(&remote, host, port);
		if( INADDR_NONE == remote.sin_addr.s_addr ) {
			[self perror: [NSString stringWithFormat:@"Could not find a server with the name \"%@\"", host] call:@"connect()"];
			[self release];
			return nil;
		}
		if(connect(sock, (struct sockaddr *)&remote, sizeof(remote)) < 0) {
			[self perror:[NSString stringWithFormat:@"Could not connect to server %@:%d", host, port] call:@"connect()"];
			[self release];
			return nil;
		}
		[NSBundle loadNibNamed:@"RFBConnection.nib" owner:self];
		server_ = [(id)server retain];
	
		versionReader = [[NLTStringReader alloc] initTarget:self action:@selector(setServerVersion:)];
		[self setReader:versionReader];

		socketHandler = [[NSFileHandle alloc] initWithFileDescriptor:sock closeOnDealloc: YES];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readData:) 	name:NSFileHandleReadCompletionNotification object:socketHandler];
		[socketHandler readInBackgroundAndNotify];
		[rfbView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];


		if ([server fullscreen]) {
			[self makeConnectionFullscreen: self];
		}
	}
    return self;
}

- (void)dealloc
{
	[newTitlePanel orderOut:self];
	[optionPanel orderOut:self];
	
	[window close];
	[self terminateConnection: nil]; // just in case it didn't already get called somehow
    [super dealloc];
}

- (Profile*)profile
{
    return profile;
}

- (void)ringBell
{
    NSBeep();
}

- (NSString*)serverVersion
{
    return serverVersion;
}

- (void)setReader:(ByteReader*)aReader
{
    currentReader = aReader;
    [aReader resetReader];
}

- (void)setReaderWithoutReset:(ByteReader*)aReader
{
    currentReader = aReader;
}

- (void)setServerVersion:(NSString*)aVersion
{
	[serverVersion autorelease];
    serverVersion = [aVersion retain];
    NSLog(@"Server reports Version %@\n", aVersion);
	[handshaker autorelease];
    handshaker = [[RFBHandshaker alloc] initTarget:self action:@selector(start:)];
    [self setReader:handshaker];
}

- (void)connectionHasTerminated
{
	[manager removeConnection:self];

	[socketHandler release];	socketHandler = nil;
	[titleString release];		titleString = nil;
	[manager release];			manager = nil;
	[versionReader release];	versionReader = nil;
	[handshaker release];		handshaker = nil;
	[(id)server_ release];		server_ = nil;
	[serverVersion release];	serverVersion = nil;
	[rfbProtocol release];		rfbProtocol = nil;
	[frameBuffer release];		frameBuffer = nil;
	[profile release];			profile = nil;
	[host release];				host = nil;
	[realDisplayName release];	realDisplayName = nil;
}

- (void)connectionTerminatedSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	/* One might reasonably argue that this should be handled by the connection manager. */
	switch (returnCode) {
		case NSAlertDefaultReturn:
			break;
		case NSAlertAlternateReturn:
			[_owner createConnectionWithServer:server_ profile:profile owner:_owner];
			break;
		default:
			NSLog(@"Unknown alert returnvalue: %d", returnCode);
	}
	[self connectionHasTerminated];
}

- (void)terminateConnection:(NSString*)aReason
{
    if(!terminating) {		
        terminating = YES;

		if (_isFullscreen)
			[self makeConnectionWindowed: self];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		[self cancelFrameBufferUpdateRequest];
		[self endFullscreenScrolling];
		[self clearAllEmulationStates];

        if(aReason) {
			NSBeginAlertSheet(@"Connection Terminated", @"Okay", @"Reconnect", nil, window, self, @selector(connectionTerminatedSheetDidEnd:returnCode:contextInfo:), nil, nil, aReason);
			return;
        }

		[self connectionHasTerminated];
    }
}

- (NSSize)_maxSizeForWindowSize:(NSSize)aSize;
{
    NSRect  winframe;
    NSSize	maxviewsize;
	BOOL usesFullscreenScrollers = [[PrefController sharedController] fullscreenHasScrollbars];
	
    horizontalScroll = verticalScroll = NO;
    winframe = [window frame];
    if(aSize.width < maxSize.width) {
        horizontalScroll = YES;
    }
    if(aSize.height < maxSize.height) {
        verticalScroll = YES;
    }
	// jason added
	if (_isFullscreen && !usesFullscreenScrollers)
		horizontalScroll = verticalScroll = NO;
	// end jason
		maxviewsize = [NSScrollView frameSizeForContentSize:[rfbView frame].size
                                  hasHorizontalScroller:horizontalScroll
                                    hasVerticalScroller:verticalScroll
                                             borderType:NSNoBorder];
    if(aSize.width < maxviewsize.width) {
        horizontalScroll = YES;
    }
    if(aSize.height < maxviewsize.height) {
        verticalScroll = YES;
    }
	// jason added
	if (_isFullscreen && !usesFullscreenScrollers)
		horizontalScroll = verticalScroll = NO;
	// end jason
    aSize = [NSScrollView frameSizeForContentSize:[rfbView frame].size
                            hasHorizontalScroller:horizontalScroll
                              hasVerticalScroller:verticalScroll
                                       borderType:NSNoBorder];
    winframe = [window frame];
    winframe.size = aSize;
    winframe = [NSWindow frameRectForContentRect:winframe styleMask:[window styleMask]];
    return winframe.size;
}

- (void)setDisplaySize:(NSSize)aSize andPixelFormat:(rfbPixelFormat*)pixf
{
    id frameBufferClass;
    NSRect wf;
	NSRect screenRect;
	NSClipView *contentView;

    frameBufferClass = [[PrefController sharedController] defaultFrameBufferClass];
	[frameBuffer autorelease];
    frameBuffer = [[frameBufferClass alloc] initWithSize:aSize andFormat:pixf];

    [rfbView setFrameBuffer:frameBuffer];
    [rfbView setDelegate:self];

	screenRect = [[NSScreen mainScreen] visibleFrame];
    wf.origin.x = wf.origin.y = 0;
    wf.size = [NSScrollView frameSizeForContentSize:[rfbView frame].size hasHorizontalScroller:NO hasVerticalScroller:NO borderType:NSNoBorder];
    wf = [NSWindow frameRectForContentRect:wf styleMask:[window styleMask]];
	if (NSWidth(wf) > NSWidth(screenRect)) {
		horizontalScroll = YES;
		wf.size.width = NSWidth(screenRect);
	}
	if (NSHeight(wf) > NSHeight(screenRect)) {
		verticalScroll = YES;
		wf.size.height = NSHeight(screenRect);
	}
	maxSize = wf.size;
	wf.origin.y = NSMaxY(screenRect) - NSHeight(wf);
    [window setFrame:wf display:NO];
	contentView = [scrollView contentView];
    [contentView scrollToPoint: [contentView constrainScrollPoint: NSMakePoint(0.0, aSize.height - [scrollView contentSize].height)]];
    [scrollView reflectScrolledClipView: contentView];

    [window makeFirstResponder:rfbView];
	[self windowDidResize: nil];
    [window makeKeyAndOrderFront:self];
    [window display];
}

- (void)setNewTitle:(id)sender
{
    [titleString autorelease];
    titleString = [[newTitleField stringValue] retain];

    [manager setDisplayNameTranslation:titleString forName:realDisplayName forHost:host];
    [window setTitle:titleString];
    [newTitlePanel orderOut:self];
}

- (void)setDisplayName:(NSString*)aName
{
	[realDisplayName autorelease];
    realDisplayName = [aName retain];
    [titleString autorelease];
    titleString = [[manager translateDisplayName:realDisplayName forHost:host] retain];
    [window setTitle:titleString];
    [window setMiniwindowImage:[NSImage imageNamed:@"vnc"]];
}

- (NSSize)displaySize
{
    return [frameBuffer size];
}

- (void)start:(ServerInitMessage*)info
{
	[rfbProtocol autorelease];
    rfbProtocol = [[RFBProtocol alloc] initTarget:self serverInfo:info];
    [rfbProtocol setFrameBuffer:frameBuffer];
    [self setReader:rfbProtocol];
}

- (id)connectionHandle
{
    return socketHandler;
}

- (NSString*)password
{
    return [server_ password];
}

- (BOOL)connectShared
{
    return [server_ shared];
}

- (NSRect)visibleRect
{
    return [rfbView bounds];
}

- (void)drawRectFromBuffer:(NSRect)aRect
{
    [rfbView displayFromBuffer:aRect];
}

- (void)drawRectList:(id)aList
{
    [rfbView drawRectList:aList];
    [window flushWindow];
}

- (void)pauseDrawing {
    [window disableFlushWindow];
}

- (void)flushDrawing {
	if ([window isFlushWindowDisabled])
		[window enableFlushWindow];
    [window flushWindow];
    [self queueUpdateRequest];
}

- (void)readData:(NSNotification*)aNotification
{
    NSData* data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    unsigned consumed, length = [data length];
    unsigned char* bytes = (unsigned char*)[data bytes];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // if we process slower than our requests, we don't autorelease until we get a break, which could be never.

    if(!length) {	// server closed socket obviously
        [self terminateConnection:@"The server closed the connection"];
		[pool release];
        return;
    }
    
    while(length) {
        consumed = [currentReader readBytes:bytes length:length];
        length -= consumed;
        bytes += consumed;
        if(terminating) {
			[pool release];
            return;
        }
    }
    [socketHandler readInBackgroundAndNotify];
	[pool release];
}

- (void)setManager:(id)aManager
{
    [manager autorelease];
    manager = [aManager retain];
}

// reset means "unset", not "restart"
- (void)resetButtonEmulationKeyDownTimer
{
	[buttonEmulationKeyDownTimer invalidate];
	[buttonEmulationKeyDownTimer release];
	buttonEmulationKeyDownTimer = nil;
	// NSLog(@"Key-Down Timer Reset!\n");
}

- (int)checkButtonEmulationKeyDownTimer
{
    float to;
    // if the timer is running, well, just return;
    if (buttonEmulationKeyDownTimer) {
        return 1;
    }
    // otherwise we must check if there *is* a timer
    to = [profile emulateKeyDownTimeout];
    // Nope, just say yes
    if (to < 0) {
        return 1;
    }
    // So, there is a valid timeout, so it must have expired.
    return 0;
}

- (void)setButtonEmulationKeyDownTimer
{
    float to = [profile emulateKeyDownTimeout];
    // NSLog(@"Button Emulation Timer is %f\n", to);
    // If the timeout value is 0 or negative, just return
    if (to <= 0) {
        return;
    }
    [self resetButtonEmulationKeyDownTimer];
    buttonEmulationKeyDownTimer = [[NSTimer scheduledTimerWithTimeInterval:to target:self selector:@selector(buttonEmulationKeyDownTimeout:) userInfo:nil repeats:NO] retain];
}
- (void)buttonEmulationKeyDownTimeout:(id)sender
{
    // Timeout the keydown emulation
    [self resetButtonEmulationKeyDownTimer];
    // NSLog(@"Button Emulation Keydown Timer Timeout!\n");
}

// Timer for KeyboardEmulationTimeout.
- (void)resetButtonEmulationKeyboardTimer
{
	[buttonEmulationKeyboardTimer invalidate];
	[buttonEmulationKeyboardTimer release];
	buttonEmulationKeyboardTimer = nil;
	// NSLog(@"Keyboard Timer Reset!\n");
}

- (void)buttonEmulationKeyboardTimeout:(id)sender
{
    // NSLog(@"Button Emulation Keyboard Timer Timeout\n");
    [self resetButtonEmulationKeyboardTimer];
    [self clearEmulationActiveMask];
}

- (void)setButtonEmulationKeyboardTimer
{
    float to = [profile emulateKeyboardTimeout];
    if (to <= 0) {
        return;
    }
    // NSLog(@"Here's where I'd set the timer for %f\n",to);
    [self resetButtonEmulationKeyboardTimer];
    buttonEmulationKeyboardTimer = [[NSTimer scheduledTimerWithTimeInterval:to target:self selector:@selector(buttonEmulationKeyboardTimeout:) userInfo:nil repeats:NO] retain];
    
}

- (void)resetButtonEmulationTimer
{
	[emulate3ButtonTimer invalidate];
	[emulate3ButtonTimer release];
	emulate3ButtonTimer = nil;
	//NSLog(@"Key-Down Timer Reset!\n");
}

- (void)emulateButtonTimeout:(id)sender
{
	//NSLog(@"Timed out\n");
	[self resetButtonEmulationTimer];
	if ( window ) // possible that this could be called between NULLing window and self being dealloc'ed
	{
		NSPoint p = [window mouseLocationOutsideOfEventStream];
		lastComputedMask = lastButtonMask;
		p = [rfbView convertPoint:p fromView:nil];
		[self mouseMovedTo: p];
	}
}

#define _ABS(x)	(((x)<0.0)?(-(x)):(x))

- (unsigned)performButtonEmulation:(unsigned)mask at:(NSPoint)thePoint
{
	// This does two things:
	// 1. If you press buttons 1 and 3 together, sends a button 2 event
	// 2. If you do the shift- or control tap thingie, it sends the button that corresponds to that.
	// To do 1, it has a timer, emulate3buttontimer. Press 1 and 3 within the timer of each other and they press 2.
	//    Note that this means that not always a button event is passed on.
	// To do 2, it uses a mask that is set up in the modifier code.
    unsigned diff = mask ^ lastButtonMask;
    unsigned pressed = diff & mask;
    unsigned released = diff & lastButtonMask;

    if(pressed) {
		// button 1 or 3 pressed
        if((mask & (rfbButton1Mask | rfbButton3Mask)) == (rfbButton1Mask | rfbButton3Mask)) {
            // both 1 and 3 buttons pressed
            if( emulate3ButtonTimer) {
				// timer is running, so we generate a button 2 press
				[self resetButtonEmulationTimer];
				// emulate button 2 in lastComputedMask
                lastComputedMask = rfbButton2Mask;
            } else {
				// Timer is not running, so the second button press was too late.
				// don't emulate button 2 but set mask to 1 and 3.
                lastComputedMask = mask;
            }
        } else {
			// only one button is pressed
            if(emulate3ButtonTimer) {
				// only one but the timer is running -> bug
                NSLog(@"emulate3ButtonTimer running when no button was pressed ???\n");
            } else {
				if(buttonEmulationActiveMask && mask == rfbButton1Mask) {
					// Button emulation and mouse button 1 pressed, we should emulate buttons
                    lastComputedMask = buttonEmulationActiveMask;
				} else {
                    float to = [profile emulate3ButtonTimeout];

					// first button is pressed, start emulation-timer if button 1 or 3
					if(to && (mask == rfbButton1Mask || mask == rfbButton3Mask)) {
						mouseButtonPressedLocation = thePoint;
						emulate3ButtonTimer = [[NSTimer scheduledTimerWithTimeInterval:to target:self selector:@selector(emulateButtonTimeout:) userInfo:nil repeats:NO] retain];
					} else {
						// Any other button pressed or no emulation -> send
						lastComputedMask = mask;
					}
				}
            }
        }
    }
    if(released) {
		// button 1 or 3 released
        if(emulate3ButtonTimer) {
			// timer running, so this was a short press of either button 1 or button 3
   // we must generate a button down/up in quick succession.
			[self resetButtonEmulationTimer];
			// in order to generate the down/up sequence we set lastComputed to
   // lastButtonMask which contains the released button in down-state.
   // next time we get here the button is reported up again.
            lastComputedMask = lastButtonMask;
        } else {
            if(lastComputedMask == rfbButton2Mask) {
				// button up during emulation
               	if(mask & (rfbButton1Mask | rfbButton3Mask)) {
                    lastComputedMask = rfbButton2Mask;
                } else {
                    lastComputedMask = mask;
                }
            } else {
				// normal button up event.
				lastComputedMask = mask;
            }
        }
		if(!(mask & rfbButton1Mask)) {
			[self clearEmulationActiveMask];
			buttonEmulationKeyDownMask = 0;
		}
    }

    if(emulate3ButtonTimer) {
		// Timer is running, check if the mouse has moved too much and abort
  // emulation mode if so
        float dx = thePoint.x - mouseButtonPressedLocation.x;
        float dy = thePoint.y - mouseButtonPressedLocation.y;

        dx = _ABS(dx); dy = _ABS(dy);
        if((dx > 5) || (dy > 5)) {
			// If the mouse moved too far, terminate emulation-timer
   // and return the physical state
			[self resetButtonEmulationTimer];
            lastComputedMask = lastButtonMask;
        }
    }

   	// If nothing changed and we are not in emulation-mode or waiting for the
	// second press, we return the last physical state.
 // This the default case.
    if(!diff && (lastComputedMask != rfbButton2Mask) && !emulate3ButtonTimer && !buttonEmulationActiveMask) {
        lastComputedMask = lastButtonMask;
    }
	// update last physical state and
    lastButtonMask = mask;
	// return the modified state
    return lastComputedMask;
}

- (void)mouseAt:(NSPoint)thePoint buttons:(unsigned)mask
{
    rfbPointerEventMsg msg;
    NSRect b = [rfbView bounds];
    NSSize s = [frameBuffer size];

    if(thePoint.x < 0) thePoint.x = 0;
    if(thePoint.y < 0) thePoint.y = 0;
    if(thePoint.x >= s.width) thePoint.x = s.width - 1;
    if(thePoint.y >= s.height) thePoint.y = s.height - 1;
    mask = [self performButtonEmulation:mask at:thePoint];
    if((mouseLocation.x != thePoint.x) || (mouseLocation.y != thePoint.y) || 
       ((mask != lastMask) || (mask & (rfbButton4Mask | rfbButton5Mask)))) {
        //NSLog(@"here %d", mask);
        mouseLocation = thePoint;
        msg.type = rfbPointerEvent;
        msg.buttonMask = mask;
        msg.x = thePoint.x; msg.x = htons(msg.x);
        msg.y = b.size.height - thePoint.y; msg.y = htons(msg.y);
        [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
        /* HACK this code should really go in the view code. */
        /* I think that ALL events should probably be caught using NSWindow's nextEventMatchingMask:NSAnyEventMask */
        if (mask & (rfbButton4Mask | rfbButton5Mask)) {
            msg.buttonMask = mask & !(rfbButton4Mask | rfbButton5Mask);
            [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
        }
        /* Sigh */
        lastMask = mask;
    }
    [self queueUpdateRequest];
}

- (void)_queueUpdateRequest {
    if (!updateRequested) {
        updateRequested = TRUE;
		[self cancelFrameBufferUpdateRequest];
		if (_frameBufferUpdateSeconds > 0.0) {
			_frameUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval: _frameBufferUpdateSeconds target: self selector: @selector(requestFrameBufferUpdate:) userInfo: nil repeats: NO] retain];
		} else {
			[self requestFrameBufferUpdate: nil];
		}
    }
}

- (void)queueUpdateRequest {
	if (! _hasManualFrameBufferUpdates)
		[self _queueUpdateRequest];
}

- (void)requestFrameBufferUpdate:(id)sender {
	if ( terminating) return;
    updateRequested = FALSE;
	[rfbProtocol requestIncrementalFrameBufferUpdateForVisibleRect: nil];
}

- (void)cancelFrameBufferUpdateRequest
{
	[_frameUpdateTimer invalidate];
	[_frameUpdateTimer release];
	_frameUpdateTimer = nil;
    updateRequested = FALSE;
}

- (void)mouseMovedTo:(NSPoint)thePoint
{
	[self mouseAt: thePoint buttons: lastButtonMask];
}

- (void)setEmulationActiveMask:(unsigned int)k
{
    switch (k) {
        case 2:
            buttonEmulationActiveMask = rfbButton2Mask;
            [rfbView setCursorTo:@"rfbCursor2" hotSpot:13];
            break;
        case 3:
            buttonEmulationActiveMask = rfbButton3Mask;
            [rfbView setCursorTo:@"rfbCursor3" hotSpot:13];
            break;
    }
    [self setButtonEmulationKeyboardTimer];
}

- (void)clearEmulationActiveMask
{
    // Undo the Active Mask
    buttonEmulationActiveMask = 0;
    // Reset the cursor
    [rfbView setCursorTo:@"rfbCursor" hotSpot:7];
    // Reset the timer (turn it off)
    [self resetButtonEmulationKeyDownTimer];
    [self resetButtonEmulationKeyboardTimer];
}

- (void)clearAllEmulationStates
{
	[self resetButtonEmulationTimer];
	[self clearEmulationActiveMask];
	lastButtonMask = lastComputedMask = lastMask = 0;
	buttonEmulationActiveMask = buttonEmulationKeyDownMask = 0;
}

- (void)sendModifier:(unsigned int)m
{
    rfbKeyEventMsg msg;
    unsigned int diff;
    
    // The API says the lower 16 bits of the modifier are reserved for device-dependent
    // modifiers.  Since INTs used to be 16 bits, and may someday be 128 bits, rather
    // than AND with 0xFFFF0000, I choose to flip the bits, set the lower 16, and then
    // flip them back, thus setting the lower 16 bits to 0.
    m = ~(~m | 0xFFFF);
    
    diff = m ^ lastModifier;
    
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    if(diff & NSShiftKeyMask) {
        msg.down = (m & NSShiftKeyMask) ? YES : NO;
        msg.key = htonl([profile shiftKeyCode]);
//		fprintf(stderr, "%04X / %d\n", msg.key, msg.down);
        [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
        if(msg.down) {
            if(!(lastButtonMask & rfbButton1Mask)) {
                buttonEmulationKeyDownMask = rfbButton3Mask;
				[self setButtonEmulationKeyDownTimer];
            }
        } else {
            if(buttonEmulationKeyDownMask & rfbButton3Mask) {
                if(buttonEmulationActiveMask) {
                    [self clearEmulationActiveMask];
                } else {
                    // We only go into emulation mode if the timer hasn't expired
                    if ([self checkButtonEmulationKeyDownTimer]) {
                        [self setEmulationActiveMask:3];
                    }
                }
            }
            // regardless of the state of the timer, turn it off now.
            [self resetButtonEmulationKeyDownTimer];
        }
    }
    if(diff & NSControlKeyMask) {
        msg.down = (m & NSControlKeyMask) ? YES : NO;
        msg.key = htonl([profile controlKeyCode]);
//		fprintf(stderr, "%04X / %d\n", msg.key, msg.down);
        [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
        if(msg.down) {
            if(!(lastButtonMask & rfbButton1Mask)) {
                buttonEmulationKeyDownMask = rfbButton2Mask;
                [self setButtonEmulationKeyDownTimer];
            }
        } else {
            if(buttonEmulationKeyDownMask & rfbButton2Mask) {
                if(buttonEmulationActiveMask & rfbButton2Mask) {
					// Allow cancelling emulation by pressing button again
                    [self clearEmulationActiveMask];
                } else {
                    if ([self checkButtonEmulationKeyDownTimer]) {
                        [self setEmulationActiveMask:2];
                    }
                }
            }
            // regardless of the state of the timer, turn it off now.
            [self resetButtonEmulationKeyDownTimer];
        }
    }
    if(diff & NSAlternateKeyMask) {
        msg.down = (m & NSAlternateKeyMask) ? YES : NO;
        msg.key = htonl([profile altKeyCode]);
//		fprintf(stderr, "%04X / %d\n", msg.key, msg.down);
        [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    }
    if(diff & NSCommandKeyMask) {
        msg.down = (m & NSCommandKeyMask) ? YES : NO;
        msg.key = htonl([profile commandKeyCode]);
//		fprintf(stderr, "%04X / %d\n", msg.key, msg.down);
        [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    }
    if(diff & NSHelpKeyMask) {		// this is F1
        msg.down = (m & NSHelpKeyMask) ? YES : NO;
        msg.key = htonl(F1_KEYCODE);
//		fprintf(stderr, "%04X / %d\n", msg.key, msg.down);
        [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    }

	// jason added a check for capslock
    if(diff & NSAlphaShiftKeyMask) {
		/* This mCapsLock crap is a horrible hack.  I was completely unable to figure out why
		 * sending the CAPSLOCK modifier to RealVNC wouldn't work, so my work around is to keep 
		 * track of whether or not we're supposed to be sending a capslocked string.  If we are, 
		 * we'll ask the OS to convert our string to uppercase for us before we send it.  Yuckage.
		 */
        mCapsLock = msg.down = (m & NSAlphaShiftKeyMask) ? YES : NO;
        msg.key = htonl(CAPSLOCK);
//		fprintf(stderr, "%04X / %d\n", msg.key, msg.down);
        [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
   }
    lastModifier = m;
}

/* --------------------------------------------------------------------------------- */
- (void)sendKey:(unichar)c pressed:(BOOL)aFlag
{
    rfbKeyEventMsg msg;
    int kc;

    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = aFlag;
	if(c < 256) {
        kc = page0[c & 0xff];
    } else if((c & 0xff00) == 0xf700) {
        kc = pagef7[c & 0xff];
    } else {
		kc = c;
    }
    msg.key = htonl(kc);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    buttonEmulationKeyDownMask = 0;
    [self resetButtonEmulationKeyDownTimer];
	if(buttonEmulationActiveMask) {
		[self clearEmulationActiveMask];
	}
}

- (void)sendCtrlAltDel: (id)sender
{
    rfbKeyEventMsg msg;

    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kControlKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kAltKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(0xffff);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];

    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(0xffff);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kAltKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kControlKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
}

- (BOOL)pasteFromPasteboard:(NSPasteboard*)pb
{
    int i;
    id sel, types, theType;
    NSRange r;

    types = [NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil];
    if((theType = [pb availableTypeFromArray:types]) == nil) {
        NSLog(@"No supported pasteboard type\n");
        return NO;
    }
    sel = [pb stringForType:theType];
    if([sel isKindOfClass:[NSArray class]]) {
        sel = [sel objectAtIndex:0];
    }
    
    r.length = 1;
    for(i=0; i<[(NSString *)sel length]; i++) {
        unichar c = [sel characterAtIndex:i];
        [self sendKey:c pressed:YES];
        [self sendKey:c pressed:NO];
    }
    [self sendModifier:lastModifier & ~NSCommandKeyMask];
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
    [self sendModifier:lastModifier & ~NSCommandKeyMask];
}

/* --------------------------------------------------------------------------------- */
- (void)processKey:(NSEvent*)theEvent pressed:(BOOL)aFlag
{
	NSString *characters;
	int i, length;
	
	// Jason - decomposedStringWithCanonicalMapping is a jaguar-only API call
	if (gIsJaguar)
		characters = [[theEvent charactersIgnoringModifiers] decomposedStringWithCanonicalMapping];
	else
		characters = [theEvent charactersIgnoringModifiers];
			
	if ( mCapsLock )
		characters = [characters uppercaseString];
	
	// if this is a key equivalent, perform it and get the rock outta here
	if ( aFlag && characters && [[KeyEquivalentManager defaultManager] performEquivalentWithCharacters: [theEvent charactersIgnoringModifiers] modifiers: [theEvent modifierFlags] & 0xFFFF0000] )
	{
		// if we've closed down our window as a result of the key command, do nothing
		if ( nil == socketHandler )
			return;
		[self clearEmulationActiveMask];
		buttonEmulationKeyDownMask = 0;
		[self sendModifier:0];
		return;
	}
	
	length = [characters length];
	for (i = 0; i < length; ++i) {
		unichar c;
		
		c = [characters characterAtIndex: i];
		[self sendKey:c pressed:aFlag];
	}
}

- (id)frameBuffer
{
    return frameBuffer;
}

- (NSWindow *)window;
{
	return window;
}

- (void)writeBytes:(unsigned char*)bytes length:(unsigned int)length
{
    int result;
    int written = 0;
/*
    {
        int i;
        
        fprintf(stderr, "%s: ", [[window title] cString]);
        for(i=0; i<length; i++) {
            fprintf(stderr, "%02X ", bytes[i]);
        }
        fprintf(stderr, "\n");
        fflush(stderr);
    }
*/
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
                [self terminateConnection:@"The server closed the connection"];
                return;
            }
            [self terminateConnection:[NSString stringWithFormat:@"Write to server: %s",
                strerror(errno)]];
            return;
        }
    } while(length > 0);
}

- (void)windowDidDeminiaturize:(NSNotification *)aNotification
{
    [rfbProtocol continueUpdate];
	[self installMouseMovedTrackingRect];
}

- (void)windowDidMiniaturize:(NSNotification *)aNotification
{
    [rfbProtocol stopUpdate];
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
	//NSLog(@"Key\n");
	[self installMouseMovedTrackingRect];
	[self setFrameBufferUpdateSeconds: [[PrefController sharedController] frontFrameBufferUpdateSeconds]];
	
	//Reset keyboard state on remote end
	[self sendModifier:0];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	//NSLog(@"Not Key\n");
	[self removeMouseMovedTrackingRect];
	[self setFrameBufferUpdateSeconds: [[PrefController sharedController] otherFrameBufferUpdateSeconds]];
	
	//Reset keyboard state on remote end
	[self sendModifier:0];
	[self clearAllEmulationStates];
}

- (void)viewFrameDidChange:(NSNotification *)aNotification
{
	[self removeMouseMovedTrackingRect];
	[self installMouseMovedTrackingRect];
    [window invalidateCursorRectsForView: rfbView];
}

- (void)openOptions:(id)sender
{
    [infoField setStringValue:
        [NSString stringWithFormat: @"VNC Protocol Version: %@\nVNC Screensize: %dx%d\nProtocol Parameters\n\tBits Per Pixel: %d\n\tDepth: %d\n\tByteorder: %s\n\tTruecolor: %s\n\tMaxValues (r/g/b): %d/%d/%d\n\tShift (r/g/b): %d/%d/%d", serverVersion, (int)[frameBuffer size].width, (int)[frameBuffer size].height, frameBuffer->pixelFormat.bitsPerPixel, frameBuffer->pixelFormat.depth, frameBuffer->pixelFormat.bigEndian ? "big-endian" : "little-endian", frameBuffer->pixelFormat.trueColour ? "yes" : "no", frameBuffer->pixelFormat.redMax, frameBuffer->pixelFormat.greenMax, frameBuffer->pixelFormat.blueMax, frameBuffer->pixelFormat.redShift, frameBuffer->pixelFormat.greenShift, frameBuffer->pixelFormat.blueShift]
        ];
    [self updateStatistics:self];
    [optionPanel setTitle:titleString];
    [optionPanel makeKeyAndOrderFront:self];
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

    [statisticField setStringValue:
#ifdef COLLECT_STATS
	[NSString stringWithFormat: @"Bytes Received: %@\nBytes Represented: %@\nCompression: %.2f\nRectangles: %u",
            byteString([reader bytesTransferred]), byteString([reader bytesRepresented]), [reader compressRatio],
            (unsigned)[reader rectanglesTransferred]
    	]
#else
	@"Statistic data collection\nnot enabled at compiletime"
#endif
    ];
}

// Jason added the following methods for full-screen display
- (BOOL)connectionIsFullscreen {
	return _isFullscreen;
}

- (IBAction)toggleFullscreenMode: (id)sender
{
	_isFullscreen ? [self makeConnectionWindowed: self] : [self makeConnectionFullscreen: self];
}

- (IBAction)makeConnectionWindowed: (id)sender {
	[self removeFullscreenTrackingRects];
	[scrollView retain];
	[scrollView removeFromSuperview];
	[window setDelegate: nil];
	[window close];
	if (CGDisplayRelease( kCGDirectMainDisplay ) != kCGErrorSuccess) {
		NSLog( @"Couldn't release the main display!" );
	}
	window = [[NSWindow alloc] initWithContentRect:[NSWindow contentRectForFrameRect: _windowedFrame styleMask: _styleMask]
										styleMask:_styleMask
										backing:NSBackingStoreBuffered
										defer:NO
										screen:[NSScreen mainScreen]];
	[window setDelegate: self];
	[(NSWindow *)window setContentView: scrollView];
	[scrollView release];
	_isFullscreen = NO;
	[self _maxSizeForWindowSize: [[window contentView] frame].size];
	[window setTitle:titleString];
	[window makeFirstResponder: rfbView];
	[self windowDidResize: nil];
	[window makeKeyAndOrderFront:nil];
	[self viewFrameDidChange: nil];
}

- (void)connectionWillGoFullscreen:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	int windowLevel;
	NSRect screenRect;

	if (returnCode == NSAlertDefaultReturn) {
		_windowedFrame = [window frame];
		_styleMask = [window styleMask];
		[_owner makeAllConnectionsWindowed];
		if (CGDisplayCapture( kCGDirectMainDisplay ) != kCGErrorSuccess) {
			NSLog( @"Couldn't capture the main display!" );
		}
		windowLevel = CGShieldingWindowLevel();
		screenRect = [[NSScreen mainScreen] frame];
	
		[scrollView retain];
		[scrollView removeFromSuperview];
		[window setDelegate: nil];
		[window close];
		window = [[FullscreenWindow alloc] initWithContentRect:screenRect
											styleMask:NSBorderlessWindowMask
											backing:NSBackingStoreBuffered
											defer:NO
											screen:[NSScreen mainScreen]];
		[window setDelegate: self];
		[(NSWindow *)window setContentView: scrollView];
		[scrollView release];
		[window setLevel:windowLevel];
		_isFullscreen = YES;
		[self _maxSizeForWindowSize: screenRect.size];
		[scrollView setHasHorizontalScroller:horizontalScroll];
		[scrollView setHasVerticalScroller:verticalScroll];
		[self installFullscreenTrackingRects];
		[self windowDidResize: nil];
		[window makeFirstResponder: rfbView];
		[window makeKeyAndOrderFront:nil];
	}
}

- (IBAction)makeConnectionFullscreen: (id)sender {
	BOOL displayFullscreenWarning = [[PrefController sharedController] displayFullScreenWarning];

	if (displayFullscreenWarning) {
		NSBeginAlertSheet(@"Your connection is entering fullscreen mode", @"Fullscreen", @"Cancel", nil, window, self, nil, @selector(connectionWillGoFullscreen: returnCode: contextInfo: ), nil, @"You may return to windowed mode by pressing the proper key equivalent at any time.  You can change this key equivalent in the Preferences if necessary.");
	} else {
		[self connectionWillGoFullscreen:nil returnCode:NSAlertDefaultReturn contextInfo:nil]; 
	}
}

- (void)installMouseMovedTrackingRect
{
	NSPoint mousePoint = [rfbView convertPoint: [window convertScreenToBase: [NSEvent mouseLocation]] fromView: nil];
	BOOL mouseInVisibleRect = [rfbView mouse: mousePoint inRect: [rfbView visibleRect]];
	_mouseMovedTrackingTag = [rfbView addTrackingRect: [rfbView visibleRect] owner: self userData: nil assumeInside: mouseInVisibleRect];
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
	aRect = NSMakeRect(minX, minY, kTrackingRectThickness, height);
	_leftTrackingTag = [scrollView addTrackingRect:aRect owner:self userData:nil assumeInside: NO];
	aRect = NSMakeRect(minX, minY, width, kTrackingRectThickness);
	_topTrackingTag = [scrollView addTrackingRect:aRect owner:self userData:nil assumeInside: NO];
	aRect = NSMakeRect(maxX - kTrackingRectThickness - (horizontalScroll ? scrollWidth : 0.0), minY, kTrackingRectThickness, height);
	_rightTrackingTag = [scrollView addTrackingRect:aRect owner:self userData:nil assumeInside: NO];
	aRect = NSMakeRect(minX, maxY - kTrackingRectThickness - (verticalScroll ? scrollWidth : 0.0), width, kTrackingRectThickness);
	_bottomTrackingTag = [scrollView addTrackingRect:aRect owner:self userData:nil assumeInside: NO];
}

- (void)removeMouseMovedTrackingRect
{
	[rfbView removeTrackingRect: _mouseMovedTrackingTag];
	[window setAcceptsMouseMovedEvents: NO];
}

- (void)removeFullscreenTrackingRects {
	[self endFullscreenScrolling];
	[scrollView removeTrackingRect: _leftTrackingTag];
	[scrollView removeTrackingRect: _topTrackingTag];
	[scrollView removeTrackingRect: _rightTrackingTag];
	[scrollView removeTrackingRect: _bottomTrackingTag];
}

- (void)mouseEntered:(NSEvent *)theEvent {
	NSTrackingRectTag trackingNumber = [theEvent trackingNumber];
	
	if (trackingNumber == _mouseMovedTrackingTag)
		[window setAcceptsMouseMovedEvents: YES];
	else {
		_currentTrackingTag = trackingNumber;
            if ([self connectionIsFullscreen]) {
		[self beginFullscreenScrolling];
            }
	}
}

- (void)mouseExited:(NSEvent *)theEvent {
	NSTrackingRectTag trackingNumber = [theEvent trackingNumber];

	if (trackingNumber == _mouseMovedTrackingTag)
		[window setAcceptsMouseMovedEvents: NO];
	else
		[self endFullscreenScrolling];
}

- (void)beginFullscreenScrolling {
	[self endFullscreenScrolling];
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

	if (_currentTrackingTag == _leftTrackingTag)
		[contentView scrollToPoint: [contentView constrainScrollPoint: NSMakePoint(origin.x - autoscrollIncrement, origin.y)]];
	else if (_currentTrackingTag == _topTrackingTag)
		[contentView scrollToPoint: [contentView constrainScrollPoint: NSMakePoint(origin.x, origin.y + autoscrollIncrement)]];
	else if (_currentTrackingTag == _rightTrackingTag)
		[contentView scrollToPoint: [contentView constrainScrollPoint: NSMakePoint(origin.x + autoscrollIncrement, origin.y)]];
	else if (_currentTrackingTag == _bottomTrackingTag)
		[contentView scrollToPoint: [contentView constrainScrollPoint: NSMakePoint(origin.x, origin.y - autoscrollIncrement)]];
	else
        {
		NSLog(@"Illegal tracking rectangle of %d", _currentTrackingTag);
            return;
        }
    [scrollView reflectScrolledClipView: contentView];
}

- (float)frameBufferUpdateSeconds {
	return _frameBufferUpdateSeconds;
}

- (void)setFrameBufferUpdateSeconds: (float)seconds {
	_frameBufferUpdateSeconds = seconds;
	_hasManualFrameBufferUpdates = _frameBufferUpdateSeconds >= [[PrefController sharedController] maxPossibleFrameBufferUpdateSeconds];
		
}

- (void)manuallyUpdateFrameBuffer: (id)sender
{
	[self _queueUpdateRequest];
}

@end
