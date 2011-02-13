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
#import "ConnectionWaiter.h"
#import "rfbproto.h"

@class ByteBlockReader;
@class ByteReader;
@class EventFilter;
@class FrameBuffer;
@class Profile;
@class RFBHandshaker;
@class RFBProtocol;
@class RFBView;
@class ServerInitMessage;
@class Session;
@class SshTunnel;
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

@interface RFBConnection : NSObject
{
    Session     *session;
    IBOutlet RFBView *rfbView;
    FrameBuffer *frameBuffer;
    NSFileHandle    *socketHandler;
	EventFilter     *_eventFilter;
    ByteReader      *currentReader;
    RFBHandshaker	*handshaker;
    id<IServerData> server_;
    NSString        *password;
    RFBProtocol     *rfbProtocol;
    CARD16  lastMouseX; // location of last mouse position we sent
    CARD16  lastMouseY;
    NSDate  *lastMouseMovement;
    unichar highSurrogate[2];

    SshTunnel   *sshTunnel;
    Profile *_profile;

	NSTrackingRectTag _mouseMovedTrackingTag;
	float _frameBufferUpdateSeconds; // how much to delay update requests
	NSTimer *_frameUpdateTimer; // timer for update request
    NSDate  *_lastUpdateRequestDate; // time of last update request

    BOOL isReceivingUpdate; // middle of receiving frame buffer update?
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

- (void)closeConnection;
- (id<IServerData>)server;

- (void)setRfbView:(RFBView *)view;
- (void)setSession:(Session *)aSession;
- (void)setPassword:(NSString *)password;
- (void)setSshTunnel:(SshTunnel *)tunnel;
- (void)setReader:(ByteReader*)aReader;

- (BOOL)pasteFromPasteboard:(NSPasteboard*)pb;
- (void)setServerVersion:(NSData*)aVersion;
- (void)setCursor: (NSCursor *)aCursor;
- (void)terminateConnection:(NSString*)aReason;
- (void)authenticationFailed:(NSString *)aReason;
- (void)sizeDisplay:(NSSize)aSize withPixelFormat:(rfbPixelFormat*)pixf;
- (void)setDisplayName:(NSString*)aName;

- (void)start:(ServerInitMessage*)info;
- (void)invalidateRect:(NSRect)aRect;
- (void)frameBufferUpdateBeginning;
- (void)frameBufferUpdateComplete;
- (void)frameBufferUpdateCompleteWithResize:(NSSize)newSize;
- (void)queueUpdateRequest;
- (IBAction)requestFrameBufferUpdate:(id)sender;
- (void)requestUpdate:(NSRect)frame incremental:(BOOL)aFlag;
- (void)serverMovedMouseTo:(NSPoint)pos;

    // events sent to server
- (void)mouseClickedAt:(NSPoint)thePoint buttons:(unsigned int)mask;
- (void)mouseAt:(NSPoint)thePoint buttons:(unsigned int)mask;
- (void)sendKey:(unichar)key pressed:(BOOL)pressed;
- (void)sendModifier:(unsigned int)m pressed:(BOOL)pressed;
- (void)sendKeyCode:(CARD32)key pressed:(BOOL)pressed;
- (void)writeBytes:(unsigned char*)bytes length:(unsigned int)length;
- (void)writeBufferedBytes:(unsigned char*)bytes length:(unsigned int)length;
- (void)writeRFBString:(NSString *)aString;
- (void)writeBuffer;

- (Profile*)profile;
- (int) protocolMajorVersion;
- (int) protocolMinorVersion;
- (NSString*)password;
- (BOOL)connectShared;
- (BOOL)viewOnly;
- (EventFilter *)eventFilter;
- (Session *)session;
- (SshTunnel *)sshTunnel;

- (void)viewFrameDidChange:(NSNotification *)aNotification;
- (NSString *)statisticsString;
- (NSString *)infoString;

- (void)installMouseMovedTrackingRect;
- (void)removeMouseMovedTrackingRect;
- (void)mouseDragged:(NSEvent *)theEvent;

- (void)setFrameBufferUpdateSeconds: (float)seconds;

@end
