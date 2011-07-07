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

#import "Session.h"
#import "AppDelegate.h"
#import "IServerData.h"
#import "FullscreenWindow.h"
#import "KeyEquivalent.h"
#import "KeyEquivalentManager.h"
#import "KeyEquivalentScenario.h"
#import "PrefController.h"
#import "ProfileManager.h"
#import "RFBConnection.h"
#import "RFBConnectionManager.h"
#import "RFBView.h"
#import "SshWaiter.h"
#define XK_MISCELLANY
#include <X11/keysymdef.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
@interface NSAlert(AvailableInLeopard)
    - (void)setShowsSuppressionButton:(BOOL)flag;
    - (NSButton *)suppressionButton;
@end
#endif

@interface Session(Private)

- (void)startTimerForReconnectSheet;

@end

@implementation Session

- (id)initWithConnection:(RFBConnection *)aConnection
{
    connection = [aConnection retain];
    server_ = [[connection server] retain];
    host = [[server_ host] retain];
    sshTunnel = [[connection sshTunnel] retain];

    _isFullscreen = NO; // jason added for fullscreen display

    [NSBundle loadNibNamed:@"RFBConnection.nib" owner:self];
    [rfbView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];

    password = [[connection password] retain];

    _reconnectWaiter = nil;
    _reconnectSheetTimer = nil;

    _horizScrollFactor = 0;
    _vertScrollFactor = 0;

    _connectionStartDate = [[NSDate alloc] init];

    [connection setSession:self];
    [connection setRfbView:rfbView];

    return self;
}

- (void)dealloc
{
    if (_isFullscreen) {
        if (CGDisplayRelease(kCGDirectMainDisplay) != kCGErrorSuccess) {
            NSLog( @"Couldn't release the main display!" );
            /* If we can't release the main display, then we're probably about
             * to leave the computer in an unusable state. */
            [NSApp terminate:self];
        }
        [self endFullscreenScrolling];
    }

    [connection setSession:nil];
    [connection release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[titleString release];
	[(id)server_ release];
	[host release];
    [password release];
    [sshTunnel close];
    [sshTunnel release];
	[realDisplayName release];
    [_reconnectSheetTimer invalidate];
    [_reconnectSheetTimer release];
    [_reconnectWaiter cancel];
    [_reconnectWaiter release];

	[newTitlePanel orderOut:self];
	[optionPanel orderOut:self];
	
	[window close];
    [windowedWindow close];
    [_connectionStartDate release];
    [super dealloc];
}

- (BOOL)viewOnly
{
    return [server_ viewOnly];
}

/* Begin a reconnection attempt to the server. */
- (void)beginReconnect
{
    if (sshTunnel) {
        /* Reuse the same SSH tunnel if we have one. */
        _reconnectWaiter = [[SshWaiter alloc] initWithServer:server_
                                                    delegate:self
                                                      window:window
                                                   sshTunnel:sshTunnel];
    } else {
        _reconnectWaiter = [[ConnectionWaiter waiterForServer:server_
                                                     delegate:self
                                                       window:window] retain];
    }
    NSString *templ = NSLocalizedString(@"NoReconnection", nil);
    NSString *err = [NSString stringWithFormat:templ, host];
    [_reconnectWaiter setErrorStr:err];
}

- (void)startTimerForReconnectSheet
{
    _reconnectSheetTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5
            target:self selector:@selector(createReconnectSheet:)
            userInfo:nil repeats:NO] retain];
}

- (void)connectionTerminatedSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	/* One might reasonably argue that this should be handled by the connection manager. */
	switch (returnCode) {
		case NSAlertDefaultReturn:
			break;
		case NSAlertAlternateReturn:
            [self beginReconnect];
            return;
		default:
			NSLog(@"Unknown alert returnvalue: %d", returnCode);
			break;
	}
    [[RFBConnectionManager sharedManager] removeConnection:self];
}

- (void)connectionProblem
{
    [connection closeConnection];
    [connection release];
    connection = nil;
}

- (void)endSession
{
    [self endFullscreenScrolling];
    [sshTunnel close];
    [[RFBConnectionManager sharedManager] removeConnection:self];
}

/* Some kind of connection failure. Decide whether to try to reconnect. */
- (void)terminateConnection:(NSString*)aReason
{
    if (!connection)
        return;

    [self connectionProblem];
    [self endFullscreenScrolling];

    if ([passwordSheet isVisible]) {
        /* User is in middle of entering password. */
        if ([server_ doYouSupport:CONNECT]) {
            NSLog(@"Will reconnect to server when password entered. Reason for disconnect was: %@", aReason);
            return;
        } else {
            /* Server doesn't support reconnect, so we have to interrupt the
             * password sheet to show an error*/
            [NSApp endSheet:passwordSheet];

            NSBeginAlertSheet(NSLocalizedString(@"ConnectionTerminated", nil),
                    NSLocalizedString(@"Okay", nil), nil, nil, window, self,
                    @selector(connectionTerminatedSheetDidEnd:returnCode:contextInfo:),
                    nil, nil, aReason);
        }
    } else {
        if(aReason) {
            NSTimeInterval timeout = [[PrefController sharedController] intervalBeforeReconnect];
            BOOL supportReconnect = [server_ doYouSupport:CONNECT];

            [_reconnectReason setStringValue:aReason];
			if (supportReconnect
                    && -[_connectionStartDate timeIntervalSinceNow] > timeout) {
                NSLog(@"Automatically reconnecting to server.  The connection was closed because: \"%@\".", aReason);
				// begin reconnect
                [self beginReconnect];
			}
			else {
				// Ask what to do
				NSString *header = NSLocalizedString( @"ConnectionTerminated", nil );
				NSString *okayButton = NSLocalizedString( @"Okay", nil );
				NSString *reconnectButton =  NSLocalizedString( @"Reconnect", nil );
				NSBeginAlertSheet(header, okayButton, supportReconnect ? reconnectButton : nil, nil, window, self, @selector(connectionTerminatedSheetDidEnd:returnCode:contextInfo:), nil, nil, aReason);
			}
        } else {
            [[RFBConnectionManager sharedManager] removeConnection:self];
        }
    }
}

/* Authentication failed: give the user a chance to re-enter password. */
- (void)authenticationFailed:(NSString *)aReason
{
    if (connection == nil)
        return;

    if (![server_ doYouSupport:CONNECT])
        [self terminateConnection:NSLocalizedString(@"AuthenticationFailed", nil)];

    [self connectionProblem];
    [authMessage setStringValue: aReason];
    [self promptForPassword];
}

- (void)promptForPassword
{
    if ([server_ respondsToSelector:@selector(setRememberPassword:)])
        [rememberNewPassword setState: [server_ rememberPassword]];
    else
        [rememberNewPassword setHidden:YES];
    [NSApp beginSheet:passwordSheet modalForWindow:window
           modalDelegate:self
           didEndSelector:@selector(passwordEnteredFor:returnCode:contextInfo:)
           contextInfo:nil];
}

/* User entered new password */
- (IBAction)reconnectWithNewPassword:(id)sender
{
    [password release];
    password = [[passwordField stringValue] retain];
    if ([rememberNewPassword state])
        [server_ setPassword: password];
    if ([server_ respondsToSelector:@selector(setRememberPassword:)]) {
        [server_ setRememberPassword: [rememberNewPassword state]];
        [[NSNotificationCenter defaultCenter] postNotificationName:ServerChangeMsg
                                                            object:server_];
    }

    [_reconnectReason setStringValue:@""];
    if (connection)
        [connection setPassword:password];
    else
        [self beginReconnect];
    [NSApp endSheet:passwordSheet];
}

/* User cancelled chance to enter new password */
- (IBAction)dontReconnect:(id)sender
{
    [NSApp endSheet:passwordSheet];
    [self connectionProblem];
    [self endSession];
}

- (void)passwordEnteredFor:(NSWindow *)wind returnCode:(int)retCode
            contextInfo:(void *)info
{
    [passwordSheet orderOut:self];
}

/* Close the connection and then reconnect */
- (IBAction)forceReconnect:(id)sender
{
    if (connection == nil)
        return;

    [self connectionProblem];
    [_reconnectReason setStringValue:@""];

    // Force ourselves to use a new SSH tunnel
    [sshTunnel close];
    [sshTunnel release];
    sshTunnel = nil;

    [self beginReconnect];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
    if ([item action] == @selector(forceReconnect:))
        // we only enable Force Reconnect menu item if server supports it
        return [server_ doYouSupport:CONNECT];
    else
        return [self respondsToSelector:[item action]];
}

- (void)setSize:(NSSize)aSize
{
    _maxSize = aSize;
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

/* Sets up window. */
- (void)setupWindow
{
    NSRect wf;
	NSRect screenRect;
	NSClipView *contentView;
	NSString *serverName;

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
	
    // :TOFIX: this doesn't work for unnamed servers
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

- (void)frameBufferUpdateComplete
{
    if ([optionPanel isVisible])
        [statisticField setStringValue:[connection statisticsString]];
}

- (void)resize:(NSSize)size
{
    NSSize  maxSize;
    NSRect  frame;

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

- (void)requestFrameBufferUpdate:(id)sender
{
    [connection requestFrameBufferUpdate:sender];
}

- (void)sendCmdOptEsc: (id)sender
{
    [connection sendKeyCode: XK_Alt_L pressed: YES];
    [connection sendKeyCode: XK_Meta_L pressed: YES];
    [connection sendKeyCode: XK_Escape pressed: YES];
    [connection sendKeyCode: XK_Escape pressed: NO];
    [connection sendKeyCode: XK_Meta_L pressed: NO];
    [connection sendKeyCode: XK_Alt_L pressed: NO];
    [connection writeBuffer];
}

- (void)sendCtrlAltDel: (id)sender
{
    [connection sendKeyCode: XK_Control_L pressed: YES];
    [connection sendKeyCode: XK_Alt_L pressed: YES];
    [connection sendKeyCode: XK_Delete pressed: YES];
    [connection sendKeyCode: XK_Delete pressed: NO];
    [connection sendKeyCode: XK_Alt_L pressed: NO];
    [connection sendKeyCode: XK_Control_L pressed: NO];
    [connection writeBuffer];
}

- (void)sendPauseKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Pause pressed: YES];
    [connection sendKeyCode: XK_Pause pressed: NO];
    [connection writeBuffer];
}

- (void)sendBreakKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Break pressed: YES];
    [connection sendKeyCode: XK_Break pressed: NO];
    [connection writeBuffer];
}

- (void)sendPrintKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Print pressed: YES];
    [connection sendKeyCode: XK_Print pressed: NO];
    [connection writeBuffer];
}

- (void)sendExecuteKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Execute pressed: YES];
    [connection sendKeyCode: XK_Execute pressed: NO];
    [connection writeBuffer];
}

- (void)sendInsertKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Insert pressed: YES];
    [connection sendKeyCode: XK_Insert pressed: NO];
    [connection writeBuffer];
}

- (void)sendDeleteKeyCode: (id)sender
{
    [connection sendKeyCode: XK_Delete pressed: YES];
    [connection sendKeyCode: XK_Delete pressed: NO];
    [connection writeBuffer];
}

- (void)paste:(id)sender
{
    [connection pasteFromPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)sendPasteboardToServer:(id)sender
{
    [connection sendPasteboardToServer:[NSPasteboard generalPasteboard]];
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

/* Window delegate methods */

- (void)windowDidDeminiaturize:(NSNotification *)aNotification
{
    float s = [[PrefController sharedController] frontFrameBufferUpdateSeconds];

    [connection setFrameBufferUpdateSeconds:s];
	[connection installMouseMovedTrackingRect];
}

- (void)windowDidMiniaturize:(NSNotification *)aNotification
{
    float s = [[PrefController sharedController] maxPossibleFrameBufferUpdateSeconds];

    [connection setFrameBufferUpdateSeconds:s];
	[connection removeMouseMovedTrackingRect];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    // dealloc closes the window, so we have to null it out here
    // The window will autorelease itself when closed.  If we allow terminateConnection
    // to close it again, it will get double-autoreleased.  Bummer.
    window = NULL;
    [self endSession];
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
	[connection installMouseMovedTrackingRect];
	[connection setFrameBufferUpdateSeconds: [[PrefController sharedController] frontFrameBufferUpdateSeconds]];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	[connection removeMouseMovedTrackingRect];
	[connection setFrameBufferUpdateSeconds: [[PrefController sharedController] otherFrameBufferUpdateSeconds]];
	
	//Reset keyboard state on remote end
	[[connection eventFilter] clearAllEmulationStates];
}

- (void)openOptions:(id)sender
{
    [infoField setStringValue: [connection infoString]];
    [statisticField setStringValue:[connection statisticsString]];
    [optionPanel setTitle:titleString];
    [optionPanel makeKeyAndOrderFront:self];
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
	[connection viewFrameDidChange: nil];
    [rfbView setUseTint:YES];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                name:NSApplicationWillHideNotification object:nil];
}

- (void)connectionWillGoFullscreen:(NSAlert *)sheet
                        returnCode:(int)returnCode
                       contextInfo:(void *)contextInfo
{
	int windowLevel;
	NSRect screenRect;

    if ([sheet respondsToSelector:@selector(suppressionButton)]) {
        if ([[sheet suppressionButton] state]) // only in 10.5+
            [[PrefController sharedController] setDisplayFullScreenWarning:NO];
    }

	if (returnCode == NSAlertFirstButtonReturn) {
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

        [rfbView setUseTint:NO];

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

        [[connection eventFilter] synthesizeRemainingEvents];

        [reason appendString: NSLocalizedString( @"FullscreenReason1", nil )];

            // Use the default KeyEquivalentManager to get the key equivalents
            // for the fullscreen scenario
        scen = [[KeyEquivalentManager defaultManager] keyEquivalentsForScenarioName: kConnectionFullscreenScenario]; 
        menuItem = [[[NSApplication sharedApplication] delegate] getFullScreenMenuItem];
        
        if (scen && menuItem) {
            KeyEquivalent *keyEquiv = [scen keyEquivalentForMenuItem: menuItem];
            NSString      *keyStr = [keyEquiv string];

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

        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:header];
        [alert setInformativeText:reason];
        if ([alert respondsToSelector:@selector(setShowsSuppressionButton:)])
            [alert setShowsSuppressionButton:YES]; // only in 10.5+
        [alert addButtonWithTitle:NSLocalizedString(@"Fullscreen", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        [alert beginSheetModalForWindow:window modalDelegate:self
                         didEndSelector:@selector(connectionWillGoFullscreen:returnCode:contextInfo:)
                            contextInfo:NULL];
        [alert release];
	} else {
		[self connectionWillGoFullscreen:nil returnCode:NSAlertFirstButtonReturn contextInfo:nil]; 
	}
}

- (void)applicationWillHide:(NSNotification *)notif
{
    [self makeConnectionWindowed:self];
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

- (void)mouseExited:(NSEvent *)theEvent {
	NSTrackingRectTag trackingNumber = [theEvent trackingNumber];

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

- (void)setFrameBufferUpdateSeconds: (float)seconds
{
    // miniaturized windows should keep update seconds set at maximum
    if (![window isMiniaturized])
        [connection setFrameBufferUpdateSeconds:seconds];
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
    [self endSession];
}

- (void)reconnectEnded:(id)sender returnCode:(int)retCode
           contextInfo:(void *)info
{
    [_reconnectPanel orderOut:self];
}

- (void)connectionPrepareForSheet
{
    [NSApp endSheet:_reconnectPanel];
    [_reconnectSheetTimer invalidate];
    [_reconnectSheetTimer release];
    _reconnectSheetTimer = nil;
}

- (void)connectionSheetOver
{
    [self startTimerForReconnectSheet];
}

/* Reconnect attempt has failed */
- (void)connectionFailed
{
    [self endSession];
}

/* Reconnect attempt has succeeded */
- (void)connectionSucceeded:(RFBConnection *)newConnection
{
    [NSApp endSheet:_reconnectPanel];
    [_reconnectSheetTimer invalidate];
    [_reconnectSheetTimer release];
    _reconnectSheetTimer = nil;

    if (_isFullscreen)
        [self makeConnectionWindowed:self];

    connection = [newConnection retain];
    [connection setSession:self];
    [connection setRfbView:rfbView];
    [connection setPassword:password];
    [connection installMouseMovedTrackingRect];
    if (sshTunnel == nil)
        sshTunnel = [[connection sshTunnel] retain];

    [_connectionStartDate release];
    _connectionStartDate = [[NSDate alloc] init];

    [_reconnectWaiter release];
    _reconnectWaiter = nil;
}

- (IBAction)showProfileManager:(id)sender
{
    [[ProfileManager sharedManager] showWindowWithProfile:
        [[server_ profile] profileName]];
}

@end
