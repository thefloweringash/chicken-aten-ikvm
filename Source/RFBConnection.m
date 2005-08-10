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
#import "EventFilter.h"
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
#import "TightEncodingReader.h"
#include <unistd.h>
#include <libc.h>

#define	F1_KEYCODE		0xffbe
#define F2_KEYCODE		0xffbf
#define	F3_KEYCODE		0xffc0
#define CAPSLOCK		0xffe5
#define kPrintKeyCode	0xff61
#define kExecuteKeyCode	0xff62
#define kPauseKeyCode	0xff13
#define kBreakKeyCode	0xff6b
#define kInsertKeyCode	0xff63
#define kDeleteKeyCode	0xffff
#define kEscapeKeyCode	0xff1b


// jason added a check for Jaguar
BOOL gIsJaguar;


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
    0xff52, 0xff54, 0xff51, 0xff53, 0xffbe, 0xffbf, 0xffc0, 0xffc1, 0xffc2, 0xffc3, 0xffc4, 0xffc5, 0xffc6, 0xffc7, 0xffc8, 0xffc9,
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
	NSString *ok = NSLocalizedString( @"Okay", nil );
    NSRunAlertPanel(theAction, s, ok, NULL, NULL, NULL);
}

// jason added for Jaguar check
+ (void)initialize {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithFloat: 0.0], @"FrameBufferUpdateSeconds", nil];
	
	[standardUserDefaults registerDefaults: dict];
	gIsJaguar = [NSString instancesRespondToSelector: @selector(decomposedStringWithCanonicalMapping)];
}


// mark refactored init methods
- (void)_prepareWithServer:(id<IServerData>)server profile:(Profile*)p owner:(id)owner
{
    _profile = [p retain];
    _owner = owner; // jason added for fullscreen display
    _isFullscreen = NO; // jason added for fullscreen display

    if((host = [server host]) == nil) {
        host = [DEFAULT_HOST retain];
    } else {
        [host retain];
    }
}

- (void)_finishInitWithFileHandle:(NSFileHandle*)file server:(id<IServerData>)server
{
    [NSBundle loadNibNamed:@"RFBConnection.nib" owner:self];
    server_ = [(id)server retain];
	
	_eventFilter = [[EventFilter alloc] init];
	[_eventFilter setConnection: self];

    versionReader = [[NLTStringReader alloc] initTarget:self action:@selector(setServerVersion:)];
    [self setReader:versionReader];

    socketHandler = [file retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readData:) 	name:NSFileHandleReadCompletionNotification object:socketHandler];
    [socketHandler readInBackgroundAndNotify];
    [rfbView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];

    if ([server fullscreen]) {
        [self makeConnectionFullscreen: self];
    }
}


// jason changed for fullscreen display
- (id)initWithServer:(id<IServerData>)server profile:(Profile*)p owner:(id)owner
{
    if (self = [super init]) {
		struct sockaddr_in	remote;
		int sock, port;

        [self _prepareWithServer:server profile:p owner:owner];

		if((sock = socket(PF_INET, SOCK_STREAM, 0)) < 0) {
			NSString *actionStr = NSLocalizedString( @"OpenConnection", nil );
			[self perror:actionStr call:@"socket()"];
			[self release];
			return nil;
		}
		port = [server port];
		socket_address(&remote, host, port);
		if( INADDR_NONE == remote.sin_addr.s_addr ) {
			NSString *actionStr = NSLocalizedString( @"NoNamedServer", nil );
			[self perror: [NSString stringWithFormat:actionStr, host] call:@"connect()"];
			[self release];
			return nil;
		}
		if(connect(sock, (struct sockaddr *)&remote, sizeof(remote)) < 0) {
			NSString *actionStr = NSLocalizedString( @"NoConnection", nil );
			actionStr = [NSString stringWithFormat:actionStr, host, port];
			[self perror:actionStr call:@"connect()"];
			[self release];
			return nil;
		}
        
        [self _finishInitWithFileHandle:
            [[[NSFileHandle alloc] initWithFileDescriptor:sock closeOnDealloc: YES] autorelease]
            server:server];
	}
    return self;
}

- (id)initWithFileHandle:(NSFileHandle*)file server:(id<IServerData>)server profile:(Profile*)p owner:(id)owner
{
    if (self = [super init]) {
        [self _prepareWithServer:server profile:p owner:owner];
        [self _finishInitWithFileHandle:(NSFileHandle*)file server:server];
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
    return _profile;
}

- (void)ringBell
{
    NSBeep();
}

- (NSString*)serverVersion
{
    return serverVersion;
}

- (int) serverMajorVersion {
	return serverMajorVersion;
}

- (int) serverMinorVersion {
	return serverMinorVersion;
}

- (void)setReader:(ByteReader*)aReader
{
    currentReader = aReader;
	[frameBuffer setCurrentReaderIsTight: currentReader && [currentReader isKindOfClass: [TightEncodingReader class]]];
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
	sscanf([serverVersion cString], rfbProtocolVersionFormat, &serverMajorVersion, &serverMinorVersion);
	
    NSLog(@"Server reports Version %@\n", aVersion);
	// ARD sends this bogus 889 version#, at least for ARD 2.2 they actually comply with version 003.007 so we'll force that
	if (serverMinorVersion == 889) {
		NSLog(@"\tBogus RFB Protocol Version Number from AppleRemoteDesktop, switching to protocol 003.007\n");
		serverMinorVersion = 7;
	}
	
	[handshaker autorelease];
    handshaker = [[RFBHandshaker alloc] initTarget:self action:@selector(start:)];
    [self setReader:handshaker];
}

- (void)connectionHasTerminated
{
	[manager removeConnection:self];

	[socketHandler release];	socketHandler = nil;
	[_eventFilter release];		_eventFilter = nil;
	[titleString release];		titleString = nil;
	[manager release];			manager = nil;
	[versionReader release];	versionReader = nil;
	[handshaker release];		handshaker = nil;
	[(id)server_ release];		server_ = nil;
	[serverVersion release];	serverVersion = nil;
	[rfbProtocol release];		rfbProtocol = nil;
	[frameBuffer release];		frameBuffer = nil;
	[_profile release];			_profile = nil;
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
			[_owner createConnectionWithServer:server_ profile:_profile owner:_owner];
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

		// Ignore our timer (It's invalid)
		[self resetReconnectTimer];

		if (_isFullscreen)
			[self makeConnectionWindowed: self];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		[self cancelFrameBufferUpdateRequest];
		[self endFullscreenScrolling];
		[self clearAllEmulationStates];
		[_eventFilter synthesizeRemainingEvents];
		[_eventFilter sendAllPendingQueueEntriesNow];

        if(aReason) {
			if ( _autoReconnect ) {
                NSLog(@"Automatically reconnecting to server.  The connection was closed because: \"%@\".", aReason);
				// Just auto-reconnect (by reinstantiating ourselves)
				[_owner createConnectionWithServer:server_ profile:_profile owner:_owner];
				// And ending (by falling through)
			}
			else {
				// Ask what to do
				NSString *header = NSLocalizedString( @"ConnectionTerminated", nil );
				NSString *okayButton = NSLocalizedString( @"Okay", nil );
				NSString *reconnectButton =  NSLocalizedString( @"Reconnect", nil );
				NSBeginAlertSheet(header, okayButton, [server_ doYouSupport:CONNECT] ? reconnectButton : nil, nil, window, self, @selector(connectionTerminatedSheetDidEnd:returnCode:contextInfo:), nil, nil, aReason);
				return;
			}
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
    if(aSize.width < _maxSize.width) {
        horizontalScroll = YES;
    }
    if(aSize.height < _maxSize.height) {
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
	NSString *serverName;

    frameBufferClass = [[PrefController sharedController] defaultFrameBufferClass];
	[frameBuffer autorelease];
    frameBuffer = [[frameBufferClass alloc] initWithSize:aSize andFormat:pixf];
	[frameBuffer setServerMajorVersion: serverMajorVersion minorVersion: serverMinorVersion];
	
    [rfbView setFrameBuffer:frameBuffer];
    [rfbView setDelegate:self];
	[_eventFilter setView: rfbView];

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
	_maxSize = wf.size;
	
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
	[self startReconnectTimer];
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

- (BOOL)viewOnly
{
	return [server_ viewOnly];
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
		NSString *reason = NSLocalizedString( @"ServerClosed", nil );
        [self terminateConnection:reason];
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

- (void)clearAllEmulationStates
{
	[_eventFilter clearAllEmulationStates];
	_lastMask = 0;
}

- (void)mouseAt:(NSPoint)thePoint buttons:(unsigned int)mask
{
    rfbPointerEventMsg msg;
    NSRect b = [rfbView bounds];
    NSSize s = [frameBuffer size];
	
    if(thePoint.x < 0) thePoint.x = 0;
    if(thePoint.y < 0) thePoint.y = 0;
    if(thePoint.x >= s.width) thePoint.x = s.width - 1;
    if(thePoint.y >= s.height) thePoint.y = s.height - 1;
    if((_mouseLocation.x != thePoint.x) || (_mouseLocation.y != thePoint.y) || (_lastMask != mask)) {
        //NSLog(@"here %d", mask);
        _mouseLocation = thePoint;
		_lastMask = mask;
        msg.type = rfbPointerEvent;
        msg.buttonMask = mask;
        msg.x = thePoint.x; msg.x = htons(msg.x);
        msg.y = b.size.height - thePoint.y; msg.y = htons(msg.y);
        [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    }
    [self queueUpdateRequest];
}

- (void)sendModifier:(unsigned int)m pressed: (BOOL)pressed
{
/*	NSString *modifierStr =nil;
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
        msg.key = htonl(CAPSLOCK);
    else if(NSHelpKeyMask == m)		// this is F1
        msg.key = htonl(F1_KEYCODE);
	else if (NSNumericPadKeyMask == m) // don't know how to handle, eat it
		return;
	
	[self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
}

/* --------------------------------------------------------------------------------- */
- (void)sendKey:(unichar)c pressed:(BOOL)pressed
{
    rfbKeyEventMsg msg;
    int kc;

    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = pressed;
	if(c < 256) {
        kc = page0[c & 0xff];
    } else if((c & 0xff00) == 0xf700) {
        kc = pagef7[c & 0xff];
    } else {
		kc = c;
    }

/*	unichar _kc = (unichar)kc;
	NSString *keyStr = [NSString stringWithCharacters: &_kc length: 1];
	NSLog(@"key '%@' %s", keyStr, pressed ? "pressed" : "released"); */

	msg.key = htonl(kc);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
}

- (void)sendCmdOptEsc: (id)sender
{
    rfbKeyEventMsg msg;
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kAltKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kMetaKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kEscapeKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kEscapeKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kMetaKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kAltKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
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
	msg.key = htonl(kDeleteKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kDeleteKeyCode);
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

- (void)sendPauseKeyCode: (id)sender
{
    rfbKeyEventMsg msg;
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kPauseKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kPauseKeyCode);
}

- (void)sendBreakKeyCode: (id)sender
{
    rfbKeyEventMsg msg;
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kBreakKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kBreakKeyCode);
}

- (void)sendPrintKeyCode: (id)sender
{
    rfbKeyEventMsg msg;
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kPrintKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kPrintKeyCode);
}

- (void)sendExecuteKeyCode: (id)sender
{
    rfbKeyEventMsg msg;
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kExecuteKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kExecuteKeyCode);
}

- (void)sendInsertKeyCode: (id)sender
{
    rfbKeyEventMsg msg;
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kInsertKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kInsertKeyCode);
}

- (void)sendDeleteKeyCode: (id)sender
{
    rfbKeyEventMsg msg;
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = YES;
	msg.key = htonl(kDeleteKeyCode);
    [self writeBytes:(unsigned char*)&msg length:sizeof(msg)];
	
    memset(&msg, 0, sizeof(msg));
    msg.type = rfbKeyEvent;
    msg.down = NO;
	msg.key = htonl(kDeleteKeyCode);
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
- (id)frameBuffer
{
    return frameBuffer;
}

- (NSWindow *)window;
{
	return window;
}


- (EventFilter *)eventFilter
{  return _eventFilter;  }


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

- (void)writeRFBString:(NSString *)aString {
	unsigned int stringLength=htonl([aString cStringLength]);
	[self writeBytes:(unsigned char *)&stringLength length:4];
	[self writeBytes:(unsigned char *)[aString cString] length:[aString cStringLength]];
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
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	//NSLog(@"Not Key\n");
	[self removeMouseMovedTrackingRect];
	[self setFrameBufferUpdateSeconds: [[PrefController sharedController] otherFrameBufferUpdateSeconds]];
	
	//Reset keyboard state on remote end
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
        [NSString stringWithFormat: @"VNC Protocol Version: %@\nVNC Screensize: %dx%d\nProtocol Parameters\n\tBits Per Pixel: %d\n\tDepth: %d\n\tByteorder: %s\n\tTruecolor: %s\n\tMaxValues (r/g/b): %d/%d/%d\n\tShift (r/g/b): %d/%d/%d", serverVersion, (int)[frameBuffer size].width, (int)[frameBuffer size].height, frameBuffer->pixelFormat.bitsPerPixel, frameBuffer->pixelFormat.depth, [frameBuffer serverIsBigEndian] ? "big-endian" : "little-endian", frameBuffer->pixelFormat.trueColour ? "yes" : "no", frameBuffer->pixelFormat.redMax, frameBuffer->pixelFormat.greenMax, frameBuffer->pixelFormat.blueMax, frameBuffer->pixelFormat.redShift, frameBuffer->pixelFormat.greenShift, frameBuffer->pixelFormat.blueShift]
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
		NSString *header = NSLocalizedString( @"FullscreenHeader", nil );
		NSString *fullscreenButton = NSLocalizedString( @"Fullscreen", nil );
		NSString *cancelButton = NSLocalizedString( @"Cancel", nil );
		NSString *reason = NSLocalizedString( @"FullscreenReason", nil );
		NSBeginAlertSheet(header, fullscreenButton, cancelButton, nil, window, self, nil, @selector(connectionWillGoFullscreen: returnCode: contextInfo: ), nil, reason);
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

// Timers for connection
- (void)resetReconnectTimer
{
//	NSLog(@"resetReconnectTimer called.\n");
	[_reconnectTimer invalidate];
	[_reconnectTimer release];
	_reconnectTimer = nil;
}

- (void)startReconnectTimer
{
//	NSLog(@"startReconnectTimer called.\n");
	[self resetReconnectTimer];

	if ( ! [[PrefController sharedController] autoReconnect] )
		return;
	
	NSTimeInterval timeout = [[PrefController sharedController] intervalBeforeReconnect];
	if ( 0.0 == timeout )
		_autoReconnect = YES;
	else
		_reconnectTimer = [[NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(reconnectTimerTimeout:) userInfo:nil repeats:NO] retain];
}

- (void)reconnectTimerTimeout:(id)sender
{
//	NSLog(@"reconnectTimerTimeout called.\n");
	[self resetReconnectTimer];
	_autoReconnect = YES;
}
	
@end
