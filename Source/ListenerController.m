//
//  ListenerController.h
//  Chicken of the VNC
//
//  Created by Mark Lentczner on Sat Oct 23 2004.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//


#import "ListenerController.h"
#import "AppDelegate.h"
#import "ProfileDataManager.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "ServerFromConnection.h"

// imports required for socket initialization
#include <sys/socket.h>
#include <netinet/in.h>
#include <poll.h>
#include <unistd.h>

// --- Preference Keys --- //
NSString *kPrefs_ListenerPort_Key       = @"ListenerPort";
NSString *kPrefs_ListenerLocal_Key      = @"ListenerLocal";
NSString *kPrefs_ListenerProfile_Key    = @"ListenerProfile";
NSString *kPrefs_ListenerFullscreen_Key = @"ListenerFullscreen";

@interface ListenerController ( private )
+ (void)initPrefs;
- (void)loadPrefs;
- (void)savePrefs;

- (void)loadProfileIntoView;
- (void)updateUI;
@end

#pragma mark -

@implementation ListenerController

#pragma mark Life Cycle

+ (void)initialize
{
    [self initPrefs];
}


+ (ListenerController*)sharedController
{
	static id sInstance = nil;
	if ( ! sInstance )
	{
		sInstance = [[self alloc] init];
		NSParameterAssert( sInstance != nil );
	}
	return sInstance;
}


- (id)init
{
	if (self = [super initWithWindowNibName:@"ListenDialog"]) {
        [self setWindowFrameAutosaveName:@"vnc_listen"];
        
        listeningSockets[0] = nil;
        listeningSockets[1] = nil;

        fileHandles = [[NSMutableArray alloc] init];
    }
	
	return self;
}


- (void)dealloc
{	
    [self closeLingering:nil];
    [self stopListener];
    [self savePrefs];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

    [fileHandles release];
    [closeTimer invalidate];
    [closeTimer release];
    [resetErrorTimer invalidate];
    [resetErrorTimer release];
	
	[super dealloc];
}

- (void)windowDidLoad
{
    [self loadProfileIntoView];
    [self loadPrefs];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateProfileView:)
                                                 name:ProfileListChangeMsg
                                               object:(id)[ProfileDataManager sharedInstance]];
    
    [self updateUI];
    [self setStatus:NSLocalizedString(@"listenStopped", nil)];
}


#pragma mark -
#pragma mark Window Controls

- (void)actionPressed:(id)sender
{
    [self closeLingering:nil];

    if (!listeningSockets[0]) {
        // listen
        ProfileManager* pm = [ProfileManager sharedManager];
        
        int port = [portText intValue];
        Profile* profile = [pm profileNamed: [profilePopup titleOfSelectedItem]];
        BOOL local = [localOnlyBtn state] == NSOnState;
        
        [self startListenerOnPort:port withProfile:profile localOnly:local];
    }
    else
        [self stopListener];
}

- (void)valueChanged:(id)sender
{
    if (sender == profilePopup
            && [sender indexOfSelectedItem] == [sender numberOfItems] - 1) {
        NSString    *profile = [[NSUserDefaults standardUserDefaults]
                                    stringForKey: kPrefs_ListenerProfile_Key];

        [self setProfilePopupToProfile:profile];
        [[ProfileManager sharedManager] showWindowWithProfile:profile];
    }
    [self savePrefs];
}

- (void)updateUI
{
    BOOL active = listeningSockets[0] != nil;
    
    if (![self isWindowLoaded])
        return;
    
    [actionBtn setTitle: NSLocalizedString(
        !active ? @"listenStart" : @"listenStop", nil)];
        
    [portText     setEnabled: !active];
    [localOnlyBtn setEnabled: !active];
    [profilePopup setEnabled: !active];
    [fullscreen   setEnabled: !active];
}

- (void)setDisplaysFullscreen:(BOOL)aFullscreen
{
    [fullscreen setState:aFullscreen];
    [self savePrefs];
}

#pragma mark -
#pragma mark Socket Listener

- (NSFileHandle *)listenAtAddress:(struct sockaddr *)listenAddress
    ofLength:(socklen_t)addressLen
{
        // In order to use NSFileHandle's acceptConnectionInBackgroundAndNotify method, we need to create a file descriptor that is itself a socket, bind that socket, and then set it up for listening. At this point, it's ready to be handed off to acceptConnectionInBackgroundAndNotify.
    int yes = 1;
    int fdForListening;
    NSFileHandle    *handle;

    if((fdForListening = socket(listenAddress->sa_family, SOCK_STREAM, 0)) <= 0)
        return nil;
    
    if (
        setsockopt(fdForListening, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes))
    ||  bind(fdForListening, listenAddress, addressLen)
    ||  listen(fdForListening, 1)
    ) {
        int e = errno;
        if ([self isWindowLoaded]) {
            NSError* errObj = [NSError errorWithDomain:NSPOSIXErrorDomain code:e userInfo:nil];
            [self setStatus: [errObj localizedDescription]];
        }
        
        close(fdForListening);
        return nil;
    }

    handle = [[NSFileHandle alloc]
        initWithFileDescriptor:fdForListening
        closeOnDealloc:YES];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(connectionReceived:)
        name:NSFileHandleConnectionAcceptedNotification
        object:handle];
        
    [handle acceptConnectionInBackgroundAndNotify];

    return [handle autorelease];
}

- (void)stopListeningForNdx:(int)ndx
{
    [listeningSockets[ndx] closeFile];

    [[NSNotificationCenter defaultCenter]
        removeObserver:self
        name:NSFileHandleConnectionAcceptedNotification
        object:listeningSockets[ndx]];
    
    [listeningSockets[ndx] release]; listeningSockets[ndx] = nil;
}

- (BOOL)startListenerOnPort:(int)port withProfile:(Profile*)profile localOnly:(BOOL)local;
{
    struct sockaddr_in listenAddress;
    struct sockaddr_in6 listenAddress6;

    if (listeningSockets[0])
        return YES;
        
    memset(&listenAddress, 0, sizeof(listenAddress));
    listenAddress.sin_family = AF_INET;
    listenAddress.sin_addr.s_addr = htonl(local ? INADDR_LOOPBACK : INADDR_ANY);
    listenAddress.sin_port = htons(port);
    listeningSockets[0] = [self listenAtAddress: (struct sockaddr *)&listenAddress
                                       ofLength:sizeof(listenAddress)];
    [listeningSockets[0] retain];
    if (!listeningSockets[0])
        return NO;

    memset(&listenAddress6, 0, sizeof(listenAddress6));
    listenAddress6.sin6_family = AF_INET6;
    listenAddress6.sin6_addr = local ? in6addr_loopback : in6addr_any;
    listenAddress6.sin6_port = htons(port);
    listeningSockets[1] = [self listenAtAddress:(struct sockaddr *)&listenAddress6
                                       ofLength:sizeof(listenAddress6)];
    [listeningSockets[1] retain];
    if (!listeningSockets[1]) {
        [self stopListeningForNdx: 0];
        return NO;
    }

    listeningProfile = [profile retain];

    [self updateUI];
    [self setStatus: NSLocalizedString(@"listenRunning", nil)];
    
    return YES;
}

- (void)stopListener
{
    int     i;

    for (i = 0; i < 2; i++) {
        if (listeningSockets[i])
            [self stopListeningForNdx: i];
    }

    [listeningProfile release]; listeningProfile = nil;
    
    [self updateUI];
    [self setStatus: NSLocalizedString(@"listenStopped", nil)];
}

- (void)setStatus:(NSString *)str;
{
    [statusText setStringValue:str];

    [resetErrorTimer invalidate];
    [resetErrorTimer release];
    resetErrorTimer = nil;
}

- (void)clearError:(NSTimer *)timer
{
    NSString    *status;

    if ([fileHandles count] > 0)
        status = NSLocalizedString(@"listenConnected", nil);
    else
        status = NSLocalizedString(@"listenRunning", nil);

    [self setStatus:status];
}

// Connection management

- (void)connectionReceived:(NSNotification *)aNotification {
    NSFileHandle * incomingConnection = [[aNotification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];

    /* We've received a connection. However, we want to wait to see if it sends
     * any data before we start a connection and stop listening. */
    [fileHandles addObject:incomingConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(dataReceived:)
            name:NSFileHandleDataAvailableNotification
            object:incomingConnection];
    [incomingConnection waitForDataInBackgroundAndNotify];

    [self setStatus:NSLocalizedString(@"listenConnected", nil)];
    [listeningSockets[0] acceptConnectionInBackgroundAndNotify];
    [listeningSockets[1] acceptConnectionInBackgroundAndNotify];
}

- (void)dataReceived:(NSNotification *)notif
{
    NSFileHandle            *fh = [notif object];
    ServerFromConnection    *server;
    RFBConnectionManager    *cm = [RFBConnectionManager sharedManager];
    struct pollfd           pfd;
    int                     numev;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil
            object:fh];
    [fileHandles removeObject:fh];

    /* We've received a notification that either the socket has received data or
     * it's been closed. We use a non-blocking call to poll to distinguish these
     * two cases. */
    pfd.fd = [fh fileDescriptor];
    pfd.events = POLLERR | POLLHUP | POLLIN;
    numev = poll(&pfd, 1, 0);
    if (numev < 1 || pfd.revents & (POLLERR | POLLHUP)) {
        // Display an error message, but clear we'll clear it a little later
        [self setStatus:NSLocalizedString(@"listenClosed", nil)];
        resetErrorTimer = [NSTimer scheduledTimerWithTimeInterval:3*60
                                target:self selector:@selector(clearError:)
                                userInfo:nil repeats:NO];
        [resetErrorTimer retain];
        return;
    }

    server = [[ServerFromConnection alloc] initFromConnection:fh];
    [server setFullscreen: [NSApp isActive] && [fullscreen state]];
    [server setProfile:listeningProfile];
    [cm createConnectionWithFileHandle:fh server:server];
    [server release];

    [self stopListener];
    if (closeTimer == nil && [fileHandles count] > 0) {
        /* We may have received multiple connections during the time we were
         * waiting for data. We close any extra connections which aren't sending
         * data. */
        closeTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                selector:@selector(closeLingering:)
                                userInfo:nil repeats:NO];
        [closeTimer retain];
    }
}

- (void)closeLingering:(NSTimer *)timer
{
    int     i;

    for (i = 0; i < [fileHandles count]; i++) {
        [[fileHandles objectAtIndex: i] closeFile];
    }
    [fileHandles removeAllObjects];

    [closeTimer invalidate];
    [closeTimer release];
    closeTimer = nil;
}

#pragma mark -
#pragma mark Preferences

+ (void)initPrefs
{
    [[NSUserDefaults standardUserDefaults] registerDefaults: 
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt: 5500], kPrefs_ListenerPort_Key,
            @"NO",                          kPrefs_ListenerLocal_Key,
            NSLocalizedString(@"defaultProfileName", nil),
                                            kPrefs_ListenerProfile_Key,
            @"NO",                          kPrefs_ListenerFullscreen_Key,
            nil, nil]];
}

- (void)loadPrefs
{
    NSUserDefaults* user = [NSUserDefaults standardUserDefaults];

    if (![self isWindowLoaded]) return;
    
    [portText setIntValue:
        [user integerForKey: kPrefs_ListenerPort_Key]];
    [localOnlyBtn setState:
        [user boolForKey: kPrefs_ListenerLocal_Key] ? NSOnState : NSOffState];

    {
        NSString* profileName = [user stringForKey: kPrefs_ListenerProfile_Key];
        
        [self setProfilePopupToProfile: profileName];
    }

    [fullscreen setState: [user boolForKey: kPrefs_ListenerFullscreen_Key]];
}

- (void)savePrefs
{
    NSUserDefaults* user = [NSUserDefaults standardUserDefaults];
    
    if (![self isWindowLoaded]) return;
    
    [user setInteger:[portText intValue] forKey: kPrefs_ListenerPort_Key];
    [user setBool:([localOnlyBtn state] == NSOnState) forKey: kPrefs_ListenerLocal_Key];
    [user setValue:[profilePopup titleOfSelectedItem] forKey: kPrefs_ListenerProfile_Key];
    [user setBool:[fullscreen state] forKey: kPrefs_ListenerFullscreen_Key];
}


#pragma mark -
# pragma mark Profile Management

- (void)updateProfileView:(id)notification
{
	[self loadProfileIntoView];
}


/* Selects a given profile from the popup. In order to save the connection, use
 * changeProfileTo: instead. */
- (void)setProfilePopupToProfile: (NSString *)profileName
{
	ProfileManager *pm = [ProfileManager sharedManager];
	if ( profileName && [pm profileWithNameExists: profileName] )
		[profilePopup selectItemWithTitle: profileName];
	else
		[profilePopup selectItemWithTitle: [[pm defaultProfile] profileName]];
}


// Changes the current listener profile and saves the selection to Preferences.
- (void)changeProfileTo:(Profile *)profile
{
    [self setProfilePopupToProfile:[profile profileName]];
    [self savePrefs];
}


// Loads the list of profiles into the popup
- (void)loadProfileIntoView
{
    NSString* lastProfile = [[profilePopup titleOfSelectedItem] retain];

	[profilePopup removeAllItems];
	[profilePopup addItemsWithTitles:
         [[ProfileDataManager sharedInstance] sortedKeyArray]];
    [[profilePopup menu] addItem: [NSMenuItem separatorItem]];
    [profilePopup addItemWithTitle:NSLocalizedString(@"EditProfiles", nil)];
	
	[self setProfilePopupToProfile: lastProfile];
    [lastProfile release];
}

- (IBAction)showProfileManager:(id)sender
{
    [[ProfileManager sharedManager] showWindowWithProfile:
            [profilePopup titleOfSelectedItem]];
}


@end
