//
//  ServerFromPrefs.h
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sun May 1 2004.
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


#import "ServerDataViewController.h"
#import "AppDelegate.h"
#import "ConnectionWaiter.h"
#import "IServerData.h"
#import "ProfileDataManager.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "ServerBase.h"
#import "ServerDataManager.h"
#import "ServerStandAlone.h"
#import "ServerFromPrefs.h"
#import "SshWaiter.h"

#define DISPLAY_MAX 50 // numbers >= this are interpreted as a port

@implementation ServerDataViewController

- (id)init
{
	if (self = [super init])
	{
		[NSBundle loadNibNamed:@"ServerDisplay.nib" owner:self];
		
		selfTerminate = NO;
		removedSaveCheckbox = NO;
		
		[connectIndicatorText setStringValue:@""];
		[box setBorderType:NSNoBorder];

        connectionWaiter = nil;
		
		[self loadProfileIntoView];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(updateProfileView:)
													 name:ProfileListChangeMsg
												   object:(id)[ProfileDataManager sharedInstance]];
	}
	
	return self;
}

- (id)initWithServer:(id<IServerData>)server
{
	if (self = [self init])
	{
		[self setServer:server];
	}
	
	return self;
}

- (id)initWithReleaseOnCloseOrConnect
{
	if (self = [self init])
	{
		selfTerminate = YES;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:(id)[self window]];
	}
	
	return self;
}

- (void)dealloc
{
	[(id)mServer release];
	if( YES == removedSaveCheckbox )
	{
		[save release];
	}
	
    [connectionWaiter cancel];
    [connectionWaiter release];
	[super dealloc];
		
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:ProfileListChangeMsg
												  object:(id)[ProfileDataManager sharedInstance]];
}

- (void)setServer:(id<IServerData>)server
{
	if( nil != mServer )
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:ServerChangeMsg
													  object:(id)mServer];
		[(id)mServer autorelease];
	}
	
	mServer = [(id)server retain];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateView:)
												 name:ServerChangeMsg
											   object:(id)mServer];
	
	[self updateView:nil];
}
	
- (void)updateView:(id)notification
{	
	// Set properties in dialog box
    if (mServer != nil)
	{
        NSString    *str;
        int         port = [mServer port];

        if( NO == removedSaveCheckbox && NO == [mServer respondsToSelector:@selector(setAddToServerListOnConnect:)] )
		{
            [self setSaveCheckboxIsVisible: NO];
		}
		
		[hostName setEnabled: YES];
		[password setEnabled: YES];
		[shared setEnabled: YES];
		[profilePopup setEnabled: YES];
		
        if (port < DISPLAY_MAX) {
            // Low port numbers have to be encoded as host:port so they won't be
            // interpreted as display numbers
            NSString *host = [mServer host];
            NSRange  colon = [host rangeOfString:@":"];
            NSString *fmt;
            NSString *hostAndPort;

            fmt = colon.location == NSNotFound ? @"%@:%d" : @"[%@]:%d";
            hostAndPort = [NSString stringWithFormat:fmt, host, port];
            [hostName setStringValue:hostAndPort];
            [display setStringValue:@""];
            [display setEnabled:NO];
            str = [NSString stringWithFormat:NSLocalizedString(@"PortNum", nil),
                    port];
        } else {
            [hostName setStringValue:[mServer host]];
            if (port >= PORT_BASE && port < PORT_BASE + DISPLAY_MAX) {
                NSString    *fmt = NSLocalizedString(@"DisplayIsPort", nil);

                [display setIntValue:port - PORT_BASE];
                str = [NSString stringWithFormat:fmt, port - PORT_BASE, port];
            } else {
                [display setIntValue:port];
                str = [NSString stringWithFormat:NSLocalizedString(@"PortNum", nil),
                        port];
            }
            [display setEnabled: YES];
        }
        [displayDescription setStringValue:str];

            /* It's important to do password before rememberPwd so that
             * the latter will reflect a failure to retrieve the
             * passsword from the key chain. */
		[password setStringValue:[mServer password]];
        [rememberPwd setIntValue:[mServer rememberPassword]];
        [shared setIntValue:[mServer shared]];
		[fullscreen setIntValue:[mServer fullscreen]];
		[viewOnly setIntValue:[mServer viewOnly]];
		[self setProfilePopupToProfile: [mServer profile]];
        if ([mServer sshHost] == nil) {
            [useSshTunnel setIntValue:NO];
            [sshHost setStringValue:@""];
        } else {
            [useSshTunnel setIntValue:YES];
            [sshHost setStringValue:[mServer sshString]];
        }
		
		[hostName    setEnabled: [mServer doYouSupport:EDIT_ADDRESS]];
		[display     setEditable:[mServer doYouSupport:EDIT_PORT]];
		[password    setEnabled: [mServer doYouSupport:EDIT_PASSWORD]];
		[rememberPwd setEnabled: [mServer respondsToSelector:@selector(setRememberPassword:)]];
        [sshHost     setEnabled: [mServer sshHost] != nil];
		[connectBtn  setEnabled: [mServer doYouSupport:CONNECT]];

        [viewOnly setEnabled: YES];
        [fullscreen setEnabled: YES];
    }
	else
	{
		[hostName setEnabled: NO];
		[password setEnabled: NO];
		[rememberPwd setEnabled: NO];
		[display setEnabled: NO];
		[shared setEnabled: NO];
		[profilePopup setEnabled: NO];
		[connectBtn setEnabled: NO];
        [useSshTunnel setEnabled: NO];
        [sshHost setEnabled: NO];

		[hostName setStringValue:@""];
		[password setStringValue:@""];
		[rememberPwd setIntValue:0];
		[display setStringValue:@""];
		[shared setIntValue:0];
		[fullscreen setIntValue:0];
		[viewOnly setIntValue:0];
        [useSshTunnel setIntValue:0];
        [sshHost setStringValue:@""];
		[self setProfilePopupToProfile: nil];

        [displayDescription setStringValue:@""];
	}
}


- (void)updateProfileView:(id)notification
{
	[self loadProfileIntoView];
}

- (void)setProfilePopupToProfile: (Profile *)profile
{
	if ( profile )
		[profilePopup selectItemWithTitle: [profile profileName]];
	else {
        ProfileDataManager *profiles = [ProfileDataManager sharedInstance];
		[profilePopup selectItemWithTitle: [profiles defaultProfileName]];
    }
}

- (void)loadProfileIntoView
{
	[profilePopup removeAllItems];
	
	NSArray* profileKeys = [NSArray arrayWithArray:[[ProfileDataManager sharedInstance] sortedKeyArray]];
	
	[profilePopup addItemsWithTitles:profileKeys];
    [[profilePopup menu] addItem: [NSMenuItem separatorItem]];
    [profilePopup addItemWithTitle:NSLocalizedString(@"EditProfiles", nil)];
	
	[self setProfilePopupToProfile: [mServer profile]];
}

- (void)setSaveCheckboxIsVisible:(BOOL)visible
{
    if ( visible && removedSaveCheckbox )
    {
        removedSaveCheckbox = NO;
        [[box contentView] addSubview: save];
        [save release];
    }
    else if ( ! visible && ! removedSaveCheckbox )
    {
        removedSaveCheckbox = YES;
        [save retain];
        [save removeFromSuperview];
        [(NSView *)[box contentView] display];
    }
}

- (void)setSuperController:(RFBConnectionManager *)aSuperController
{
    superController = aSuperController;
}

- (id<IServerData>)server
{
	return mServer;
}

- (void)takePortFromDisplay
{
    int         val = [display intValue];
    NSString    *str;

    if (val > DISPLAY_MAX) {
        NSString    *fmt = NSLocalizedString(@"PortNum", nil);

        str = [NSString stringWithFormat:fmt, val];
        [mServer setPort:val];
    } else {
        NSString    *fmt = NSLocalizedString(@"DisplayIsPort", nil);

        str = [NSString stringWithFormat:fmt, val, val + PORT_BASE];
        [mServer setDisplay:val];
    }
    [displayDescription setStringValue:str];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSControl* sender = [aNotification object];
	
	if( display == sender )
	{
		if( nil != mServer && [mServer doYouSupport:EDIT_PORT] )
		{
            [self takePortFromDisplay];
		}
	}
	else if( hostName == sender )
	{
		if( nil != mServer && [mServer doYouSupport:EDIT_ADDRESS] )
		{
            BOOL setSsh = [[sshHost stringValue] isEqualToString:[mServer host]];
			BOOL portSpec = [mServer setHostAndPort:[sender stringValue]];

            [display setEnabled:!portSpec];
            if (portSpec) {
                NSString    *fmt = NSLocalizedString(@"PortNum", nil);
                NSString    *str;

                str = [NSString stringWithFormat:fmt, [mServer port]];
                [displayDescription setStringValue:str];
            } else
                [self takePortFromDisplay];

            if (setSsh) {
                [mServer setSshHost:[mServer host]];
                [sshHost setStringValue:[mServer host]];
            }
		}
	}
	else if( password == sender )
	{
		if( nil != mServer && [mServer doYouSupport:EDIT_PASSWORD] )
		{
			[mServer setPassword:[sender stringValue]];
		}
	}
}

- (IBAction)rememberPwdChanged:(id)sender
{
	if( nil != mServer )
	{
        if ([mServer respondsToSelector:@selector(setRememberPassword:)])
            [mServer setRememberPassword:[sender state]];
	}
}

- (IBAction)fullscreenChanged:(id)sender
{
	if( nil != mServer )
	{
		[mServer setFullscreen:![mServer fullscreen]];
	}
}

- (IBAction)profileSelectionChanged:(id)sender
{
    if ([sender indexOfSelectedItem] == [sender numberOfItems] - 1) {
        Profile *profile = [mServer profile];

        // :TORESOLVE: this flickers the popup in the "Edit" state
        //          how to prevent this? some way to reject selection change?
        [self setProfilePopupToProfile:profile];

        [[ProfileManager sharedManager] showWindowWithProfile:[profile profileName]];
    }
    else if( nil != mServer )
	{
		[mServer setProfileName:[sender titleOfSelectedItem]];
	}
}

- (IBAction)sharedChanged:(id)sender
{
	if( nil != mServer )
	{
		[mServer setShared:![mServer shared]];
	}
}

- (IBAction)viewOnlyChanged:(id)sender
{
	if( nil != mServer )
	{
		[mServer setViewOnly:![mServer viewOnly]];
	}
}

- (IBAction)useSshTunnelChanged:(id)sender
{
    [mServer setSshTunnel:[sender state]];
    [sshHost setEnabled:[sender state]];
    [sshHost setStringValue:[sender state] ? [mServer sshString] : @""];
}

- (IBAction)sshHostChanged:(id)sender
{
    [mServer setSshString:[sender stringValue]];
}

- (IBAction)addServerChanged:(id)sender
{
    if ([sender state]) {
        [rememberPwd setEnabled:YES];
    } else {
        [rememberPwd setState:NSOffState];
        [rememberPwd setEnabled:NO];
    }
}

- (IBAction)showProfileManager:(id)sender
{
    NSString    *name = [[mServer profile] profileName];
    [[ProfileManager sharedManager] showWindowWithProfile:name];
}

- (NSBox*)box
{
	return box;
}

- (IBAction)connectToServer:(id)sender
{
    NSWindow *window;
    ServerBase  *server;

    saveCheckboxWasVisible = !removedSaveCheckbox;
    [self setSaveCheckboxIsVisible: NO];
	[connectIndicator startAnimation:self];
	[connectIndicatorText setStringValue:NSLocalizedString(@"Connecting...", @"Connect in process notification string")];
	[connectIndicatorText display];

    [self disableControls];
    [connectBtn setTitle: NSLocalizedString(@"Cancel", nil)];
    [connectBtn setAction: @selector(cancelConnect:)];
    [connectBtn setKeyEquivalent:@"."];
    [connectBtn setKeyEquivalentModifierMask:NSCommandKeyMask];

    if( [save state] )
    {
        ServerFromPrefs *s = [[ServerDataManager sharedInstance] addServer:mServer];
        [s setRememberPassword:[rememberPwd state]];
        server = s;
    } else
        server = mServer;
	
    // Asynchronously creates a connection to the server
    window = superController ? [superController window] : [self window];
    connectionWaiter = [[ConnectionWaiter waiterForServer:server
                            profile:[mServer profile] delegate:self
                             window:window] retain];
    [[ServerDataManager sharedInstance] save]; // just in case we crash
    if (connectionWaiter == nil)
        [self connectionFailed];
}

- (IBAction)cancelConnect: (id)sender
{
    [connectionWaiter cancel];
    [self connectionAttemptEnded];
}

- (void)connectionSucceeded: (RFBConnection *)theConnection
{
    if (![mServer rememberPassword])
        [mServer setPassword: @""];
    [[RFBConnectionManager sharedManager] successfulConnection:theConnection
                                                      toServer:mServer];

    [superController connectionDone];
    [self connectionAttemptEnded];

    if( YES == selfTerminate )
    {
        // shouldCloseDocument will trigger the autorelease
        [[self window] performClose:self];
    }
}

- (void)connectionFailed
{
    [self connectionAttemptEnded];
}

/* Update the interface to indicate the end of the connection attempt. */
- (void)connectionAttemptEnded
{
	[connectIndicator stopAnimation:self];
	[connectIndicatorText setStringValue:@""];
	[connectIndicatorText display];
    [self setSaveCheckboxIsVisible: saveCheckboxWasVisible];

    [self updateView:nil];
    [superController setControlsEnabled: YES];
    [connectBtn setTitle: NSLocalizedString(@"Connect", nil)];
    [connectBtn setAction: @selector(connectToServer:)];
    [connectBtn setKeyEquivalent:@"\r"];
    [connectBtn setKeyEquivalentModifierMask:0];

    [connectionWaiter release];
    connectionWaiter = nil;
}

/* Disables or enables controls as part of connection attempt */
- (void)disableControls
{
    [display setEnabled: NO];
    [hostName setEnabled: NO];
    [password setEnabled: NO];
    [profilePopup setEnabled: NO];
    [rememberPwd setEnabled: NO];
    [fullscreen setEnabled: NO];
    [shared setEnabled: NO];
    [viewOnly setEnabled: NO];
    [superController setControlsEnabled: NO];
}

- (void)windowClose:(id)notification
{	
	if([notification object] == [self window])
	{
		if( YES == selfTerminate )
		{
			[self autorelease];
		}
	}
}

@end
