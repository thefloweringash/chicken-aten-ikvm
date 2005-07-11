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
#import "ByteReader.h"
#import "FrameBuffer.h"
#import "Profile.h"
#import "rfbproto.h"
#import "RFBProtocol.h"

@class EventFilter;
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

@interface RFBConnection : ByteReader
{
    id rfbView;
    NSWindow *window;
    FrameBuffer* frameBuffer;
    id manager;
    id socketHandler;
	EventFilter *_eventFilter;
    id currentReader;
    id versionReader;
    id handshaker;
    id<IServerData> server_;
    id serverVersion;
    RFBProtocol *rfbProtocol;
    id scrollView;
    id newTitleField;
    NSPanel *newTitlePanel;
    NSString *titleString;
    id statisticField;
    BOOL terminating;
    NSPoint	_mouseLocation;
	unsigned int _lastMask;
    NSSize _maxSize;

    BOOL	horizontalScroll;
    BOOL	verticalScroll;

    id optionPanel;
    id infoField;
    Profile *_profile;

    BOOL updateRequested;				// Has someone already requested an update?
    
    NSString *realDisplayName;
    NSString *host;
	
	id _owner; // jason added for fullscreen display
	BOOL _isFullscreen; // jason added for fullscreen display
	NSRect _windowedFrame; // jason added for fullscreen display
	unsigned int _styleMask; // jason added for fullscreen display
	NSTrackingRectTag _leftTrackingTag; // jason added for fullscreen display
	NSTrackingRectTag _topTrackingTag; // jason added for fullscreen display
	NSTrackingRectTag _rightTrackingTag; // jason added for fullscreen display
	NSTrackingRectTag _bottomTrackingTag; // jason added for fullscreen display
	NSTrackingRectTag _currentTrackingTag; // jason added for fullscreen display
	NSTimer *_autoscrollTimer; // jason added for fullscreen display
	NSTrackingRectTag _mouseMovedTrackingTag;
	float _frameBufferUpdateSeconds;
	NSTimer *_frameUpdateTimer;
	BOOL _hasManualFrameBufferUpdates;
	
	int serverMajorVersion;
	int serverMinorVersion;
}

// jason added 'owner' for fullscreen display
- (id)initWithServer:(id<IServerData>)server profile:(Profile*)p owner:(id)owner;
- (id)initWithFileHandle:(NSFileHandle*)file server:(id<IServerData>)server profile:(Profile*)p owner:(id)owner;

- (void)setManager:(id)aManager;
- (void)dealloc;

- (void)paste:(id)sender;
- (BOOL)pasteFromPasteboard:(NSPasteboard*)pb;
- (void)setServerVersion:(NSString*)aVersion;
- (void)terminateConnection:(NSString*)aReason;
- (void)setDisplaySize:(NSSize)aSize andPixelFormat:(rfbPixelFormat*)pixf;
- (void)openNewTitlePanel:(id)sender;
- (void)setNewTitle:(id)sender;
- (void)setDisplayName:(NSString*)aName;
- (void)ringBell;

- (void)drawRectFromBuffer:(NSRect)aRect;
- (void)drawRectList:(id)aList;
- (void)pauseDrawing;
- (void)flushDrawing;
- (void)queueUpdateRequest;
- (void)requestFrameBufferUpdate:(id)sender;
- (void)cancelFrameBufferUpdateRequest;

- (void)clearAllEmulationStates;
- (void)mouseAt:(NSPoint)thePoint buttons:(unsigned int)mask;
- (void)sendKey:(unichar)key pressed:(BOOL)pressed;
- (void)sendModifier:(unsigned int)m pressed:(BOOL)pressed;
- (void)writeBytes:(unsigned char*)bytes length:(unsigned int)length;
- (void)writeRFBString:(NSString *)aString;

- (id)connectionHandle;
- (Profile*)profile;
- (NSString*)serverVersion;
- (int) serverMajorVersion;
- (int) serverMinorVersion;
- (NSString*)password;
- (BOOL)connectShared;
- (NSRect)visibleRect;
- (id)frameBuffer;
- (NSWindow *)window;
- (EventFilter *)eventFilter;

- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignKey:(NSNotification *)aNotification;
- (void)windowDidDeminiaturize:(NSNotification *)aNotification;
- (void)windowDidMiniaturize:(NSNotification *)aNotification;
- (void)windowWillClose:(NSNotification *)aNotification;
- (void)windowDidResize:(NSNotification *)aNotification;
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;

- (void)openOptions:(id)sender;
- (void)updateStatistics:(id)sender;

// Jason added the following for full-screen windows
- (BOOL)connectionIsFullscreen;
- (IBAction)toggleFullscreenMode: (id)sender;
- (IBAction)makeConnectionWindowed: (id)sender;
- (IBAction)makeConnectionFullscreen: (id)sender;
- (void)installMouseMovedTrackingRect;
- (void)installFullscreenTrackingRects;
- (void)removeFullscreenTrackingRects;
- (void)removeMouseMovedTrackingRect;
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;
- (void)beginFullscreenScrolling;
- (void)endFullscreenScrolling;
- (void)scrollFullscreenView: (NSTimer *)timer;

- (float)frameBufferUpdateSeconds;
- (void)setFrameBufferUpdateSeconds: (float)seconds;
- (void)manuallyUpdateFrameBuffer: (id)sender;

@end
