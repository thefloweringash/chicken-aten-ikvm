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
#import "ProfileDataManager.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "ServerFromConnection.h"

// imports required for socket initialization
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

// --- Preference Keys --- //
NSString *kPrefs_ListenerPort_Key       = @"ListenerPort";
NSString *kPrefs_ListenerLocal_Key      = @"ListenerLocal";
NSString *kPrefs_ListenerProfile_Key    = @"ListenerProfile";

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
        
        listeningSocket = nil;
    }
	
	return self;
}


- (void)dealloc
{	
    if (listeningSocket) {
        [self stopListener];
    }
    [self savePrefs];
	[super dealloc];
		
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:ProfileListChangeMsg
												  object:(id)[ProfileDataManager sharedInstance]];
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
}


#pragma mark -
#pragma mark Window Controls

- (void)actionPressed:(id)sender
{
    if (!listeningSocket) {
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
    [self savePrefs];
}

- (void)updateUI
{
    BOOL active = listeningSocket != nil;
    
    if (![self isWindowLoaded])
        return;
    
    [actionBtn setTitle: NSLocalizedString(
        !active ? @"listenStart" : @"listenStop", nil)];
    [statusText setStringValue: NSLocalizedString(
        !active ? @"listenStopped" : @"listenRunning", nil)];
        
    [portText     setEnabled: !active];
    [localOnlyBtn setEnabled: !active];
    [profilePopup setEnabled: !active];
}


#pragma mark -
#pragma mark Socket Listener

- (BOOL)startListenerOnPort:(int)port withProfile:(Profile*)profile localOnly:(BOOL)local;
{
    int fdForListening;
    struct sockaddr_in serverAddress;
    int yes = 1;

    if (listeningSocket)
        return YES;
        
        // In order to use NSFileHandle's acceptConnectionInBackgroundAndNotify method, we need to create a file descriptor that is itself a socket, bind that socket, and then set it up for listening. At this point, it's ready to be handed off to acceptConnectionInBackgroundAndNotify.
    if((fdForListening = socket(AF_INET, SOCK_STREAM, 0)) <= 0)
        return NO;
    
    memset(&serverAddress, 0, sizeof(serverAddress));
    serverAddress.sin_family = AF_INET;
    serverAddress.sin_addr.s_addr = htonl(local ? INADDR_LOOPBACK : INADDR_ANY);
    serverAddress.sin_port = htons(port);

    if (
        setsockopt(fdForListening, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes))
    ||  bind(fdForListening, (struct sockaddr *)&serverAddress, sizeof(serverAddress))
    ||  listen(fdForListening, 1)
    ) {
        int e = errno;
        if ([self isWindowLoaded]) {
            NSError* errObj = [NSError errorWithDomain:NSPOSIXErrorDomain code:e userInfo:nil];
            [statusText setStringValue: [errObj localizedDescription]];
        }
        
        close(fdForListening);
        return NO;
    }

    listeningSocket = [[NSFileHandle alloc]
        initWithFileDescriptor:fdForListening
        closeOnDealloc:YES];
    listeningProfile = [profile retain];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(connectionReceived:)
        name:NSFileHandleConnectionAcceptedNotification
        object:listeningSocket];
        
    [listeningSocket acceptConnectionInBackgroundAndNotify];
    
    [self updateUI];
    
    return YES;
}

- (void)stopListener
{
    if (!listeningSocket)
        return;
        
    [listeningSocket closeFile];
    
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
        name:NSFileHandleConnectionAcceptedNotification
        object:listeningSocket];
        
    [listeningSocket release];  listeningSocket = nil;
    [listeningProfile release]; listeningProfile = nil;
    
    [self updateUI];
}


- (void)connectionReceived:(NSNotification *)aNotification {
    NSFileHandle * incomingConnection = [[aNotification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
    [[aNotification object] acceptConnectionInBackgroundAndNotify];
    
    RFBConnectionManager* cm = [RFBConnectionManager sharedManager];
    [cm createConnectionWithFileHandle:incomingConnection 
        server:[ServerFromConnection createFromConnection:incomingConnection]
        profile:listeningProfile
        owner:cm];
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
        ProfileManager *pm = [ProfileManager sharedManager];
        NSString* profileName = [user stringForKey: kPrefs_ListenerProfile_Key];
        
        if ( profileName && [pm profileWithNameExists: profileName] )
            [profilePopup selectItemWithTitle: profileName];
        else
            [profilePopup selectItemWithTitle: [[pm defaultProfile] profileName]];
    }
}

- (void)savePrefs
{
    NSUserDefaults* user = [NSUserDefaults standardUserDefaults];
    
    if (![self isWindowLoaded]) return;
    
    [user setInteger:[portText intValue] forKey: kPrefs_ListenerPort_Key];
    [user setBool:([localOnlyBtn state] == NSOnState) forKey: kPrefs_ListenerLocal_Key];
    [user setValue:[profilePopup titleOfSelectedItem] forKey: kPrefs_ListenerProfile_Key];
}


#pragma mark -
#pragma mark Profile Management

- (void)updateProfileView:(id)notification
{
	[self loadProfileIntoView];
}


- (void)setProfilePopupToProfile: (NSString *)profileName
{
	ProfileManager *pm = [ProfileManager sharedManager];
	if ( profileName && [pm profileWithNameExists: profileName] )
		[profilePopup selectItemWithTitle: profileName];
	else
		[profilePopup selectItemWithTitle: [[pm defaultProfile] profileName]];
}


- (void)loadProfileIntoView
{
    NSString* lastProfile = [[profilePopup titleOfSelectedItem] retain];

	[profilePopup removeAllItems];
	[profilePopup addItemsWithTitles:
        [[ProfileDataManager sharedInstance] sortedKeyArray]];
	
	[self setProfilePopupToProfile: lastProfile];
    [lastProfile release];
}


@end
