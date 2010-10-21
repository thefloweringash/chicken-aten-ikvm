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
//#import "ByteReader.h"
#import "ConnectionWaiter.h"
#import "rfbproto.h"
//#import "RFBProtocol.h"

@class ByteBlockReader;
@class ByteReader;
@class EventFilter;
@class FrameBuffer;
@class Profile;
@class RFBHandshaker;
@class RFBProtocol;
@class RFBView;
@class ServerInitMessage;
@protocol IServerData;

#define RFB_HOST		@"Host"
#define RFB_PASSWORD		@"Password"
#define RFB_REMEMBER		@"RememberPassword"
#define RFB_DISPLAY		@"Display"
#define RFB_SHARED		@"Shared"
#define RFB_FULLSCREEN          @"Fullscreen"
#define RFB_PORT		5900

#define	DEFAULT_HOST	@"localhost"

#define NUM_BUTTON_EMU_KEYS	2

// jason added the following constants for fullscreen display
#define kTrackingRectThickness		10.0
#define kAutoscrollInterval			0.05

@interface RFBConnection : NSObject <ConnectionWaiterDelegate>
{
    IBOutlet RFBView *rfbView;
    NSWindow    *window;
    FrameBuffer *frameBuffer;
    NSFileHandle    *socketHandler;
	EventFilter     *_eventFilter;
    ByteReader      *currentReader;
    RFBHandshaker	*handshaker;
    id<IServerData> server_;
    NSString        *password;
    RFBProtocol     *rfbProtocol;
    id      scrollView;
    id      newTitleField;
    NSPanel *newTitlePanel;
    NSString    *titleString;
    id      statisticField;
    BOOL    terminating;
    CARD16  lastMouseX; // location of last mouse position we sent
    CARD16  lastMouseY;
    NSDate  *lastMouseMovement;
    unichar highSurrogate[2];

    NSSize _maxSize;

    BOOL	horizontalScroll;
    BOOL	verticalScroll;

    id optionPanel;
    id infoField;
    Profile *_profile;
		
    NSString *realDisplayName;
    NSString *host;

    IBOutlet NSPanel *passwordSheet;
    IBOutlet NSTextField *passwordField;
    IBOutlet NSTextField *authMessage;
    IBOutlet NSButton *rememberNewPassword;

        // for reconnection attempts
    IBOutlet NSPanel                *_reconnectPanel;
    IBOutlet NSProgressIndicator    *_reconnectIndicator;
    NSDate                          *_connectionStartDate;
    NSTimer                         *_reconnectSheetTimer;
    ConnectionWaiter                *_reconnectWaiter;

        // instance variables for managing the fullscreen display
	BOOL _isFullscreen;
	//NSRect _windowedFrame;   // saved for return to windowed
	//unsigned int _styleMask; // saved for return to windowed
    NSWindow *windowedWindow;
	NSTrackingRectTag _leftTrackingTag;
	NSTrackingRectTag _topTrackingTag;
	NSTrackingRectTag _rightTrackingTag;
	NSTrackingRectTag _bottomTrackingTag;
    int         _horizScrollFactor;
    int         _vertScrollFactor;
	NSTimer *_autoscrollTimer;

	NSTrackingRectTag _mouseMovedTrackingTag;
	float _frameBufferUpdateSeconds; // how much to delay update requests
	NSTimer *_frameUpdateTimer; // timer for update request
    NSDate  *_lastUpdateRequestDate; // time of last update request

    BOOL isReceivingUpdate; // middle of receiving frame buffer update?
    BOOL isStopped;
    BOOL shouldUpdate;
	BOOL _hasManualFrameBufferUpdates;
    double    bytesReceived; // number of framebuffer update bytes received
	
	int serverMajorVersion;
	int serverMinorVersion;

    unsigned char   *writeBuffer;
    int             bufferLen;
    int             lastBufferedIsMouseMovement;
}

- (id)initWithFileHandle:(NSFileHandle*)file server:(id<IServerData>)server profile:(Profile*)p;

- (void)dealloc;

- (void)setReader:(ByteReader*)aReader;

- (void)paste:(id)sender;
- (BOOL)pasteFromPasteboard:(NSPasteboard*)pb;
- (void)setServerVersion:(NSData*)aVersion;
- (void)setCursor: (NSCursor *)aCursor;
- (void)terminateConnection:(NSString*)aReason;
- (void)authenticationFailed:(NSString *)aReason;
- (IBAction)reconnectWithNewPassword:(id)sender;
- (IBAction)dontReconnect:(id)sender;
- (IBAction)forceReconnect:(id)sender;
- (void)sizeDisplay:(NSSize)aSize withPixelFormat:(rfbPixelFormat*)pixf;
- (void)setupWindow;
- (void)openNewTitlePanel:(id)sender;
- (void)setNewTitle:(id)sender;
- (void)setDisplayName:(NSString*)aName;

- (void)start:(ServerInitMessage*)info;
- (void)invalidateRect:(NSRect)aRect;
- (void)frameBufferUpdateBeginning;
- (void)frameBufferUpdateComplete;
- (void)frameBufferUpdateCompleteWithResize:(NSSize)newSize;
- (void)queueUpdateRequest;
- (IBAction)requestFrameBufferUpdate:(id)sender;
- (void)requestUpdate:(NSRect)frame incremental:(BOOL)aFlag;
- (void)cancelFrameBufferUpdateTimer;
- (void)serverMovedMouseTo:(NSPoint)pos;

    // events sent to server
- (void)mouseClickedAt:(NSPoint)thePoint buttons:(unsigned int)mask;
- (void)mouseAt:(NSPoint)thePoint buttons:(unsigned int)mask;
- (void)sendKey:(unichar)key pressed:(BOOL)pressed;
- (void)sendModifier:(unsigned int)m pressed:(BOOL)pressed;
- (void)writeBytes:(unsigned char*)bytes length:(unsigned int)length;
- (void)writeBufferedBytes:(unsigned char*)bytes length:(unsigned int)length;
- (void)writeRFBString:(NSString *)aString;
- (void)writeBuffer;

//- (id)connectionHandle;
- (Profile*)profile;
- (int) protocolMajorVersion;
- (int) protocolMinorVersion;
- (NSString*)password;
- (void)setPassword:(NSString *)aPassword;
- (BOOL)connectShared;
- (BOOL)viewOnly;
//- (id)frameBuffer;
//- (NSWindow *)window;
- (BOOL)hasKeyWindow;
- (EventFilter *)eventFilter;

    //window delegate messages
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignKey:(NSNotification *)aNotification;
- (void)windowDidDeminiaturize:(NSNotification *)aNotification;
- (void)windowDidMiniaturize:(NSNotification *)aNotification;
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidResize:(NSNotification *)aNotification;
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;

- (void)openOptions:(id)sender;
- (void)updateInfoField;
- (void)updateStatistics:(id)sender;

// Full-screen mode
- (BOOL)connectionIsFullscreen;
- (IBAction)toggleFullscreenMode: (id)sender;
- (IBAction)makeConnectionWindowed: (id)sender;
- (IBAction)makeConnectionFullscreen: (id)sender;
- (void)applicationWillHide:(NSNotification*)notif;

- (void)installMouseMovedTrackingRect;
- (void)installFullscreenTrackingRects;
- (void)removeFullscreenTrackingRects;
- (void)removeMouseMovedTrackingRect;
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;
- (void)beginFullscreenScrolling;
- (void)endFullscreenScrolling;
- (void)scrollFullscreenView: (NSTimer *)timer;

//- (float)frameBufferUpdateSeconds;
- (void)setFrameBufferUpdateSeconds: (float)seconds;

// For reconnect
- (void)createReconnectSheet:(id)sender;
- (IBAction)reconnectCancelled:(id)sender; // returnCode:(int)retCode
    //contextInfo:(void *)contextInfo;

@end
