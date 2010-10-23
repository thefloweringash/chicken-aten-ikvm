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
        NSString    *str = @"";

        if( NO == removedSaveCheckbox && NO == [mServer respondsToSelector:@selector(setAddToServerListOnConnect:)] )
		{
            [self setSaveCheckboxIsVisible: NO];
		}
		
		[hostName setEnabled: YES];
		[password setEnabled: YES];
		[display setEnabled: YES];
		[shared setEnabled: YES];
		[profilePopup setEnabled: YES];
		
		[hostName setStringValue:[mServer hostAndPort]];
		[password setStringValue:[mServer password]];
        [rememberPwd setIntValue:[mServer rememberPassword]];
        [display setIntValue:[mServer display]];
        [shared setIntValue:[mServer shared]];
		[fullscreen setIntValue:[mServer fullscreen]];
		[viewOnly setIntValue:[mServer viewOnly]];
		[self setProfilePopupToProfile: [mServer lastProfile]];
		
		[hostName    setEnabled: [mServer doYouSupport:EDIT_ADDRESS]];
		[display     setEditable:[mServer doYouSupport:EDIT_PORT]];
		[password    setEnabled: [mServer doYouSupport:EDIT_PASSWORD]];
		[rememberPwd setEnabled: [mServer doYouSupport:SAVE_PASSWORD]];
		[connectBtn  setEnabled: [mServer doYouSupport:CONNECT]];

        [viewOnly setEnabled: YES];
        [fullscreen setEnabled: YES];
		
		if ( [mServer isPortSpecifiedInHost] ) {
			[display setEnabled: NO];
            [displayDescription setStringValue:@""];
            str = [NSString stringWithFormat:NSLocalizedString(@"PortNum", nil),
                    [mServer port]];
        } else {
            int         val = [mServer display];

            if (val < DISPLAY_MAX)
                str = [NSString stringWithFormat:NSLocalizedString(@"DisplayIsPort", nil),
                        val, val + PORT_BASE];
            else if (val >= PORT_BASE && val < PORT_BASE + DISPLAY_MAX)
                str = [NSString stringWithFormat:NSLocalizedString(@"PortIsDisplay", nil),
                        val, val - PORT_BASE];
            else
                str = [NSString stringWithFormat:NSLocalizedString(@"PortNum", nil),
                        val];
        }
        [displayDescription setStringValue:str];
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

		[hostName setStringValue:@""];
		[password setStringValue:@""];
		[rememberPwd setIntValue:0];
		[display setStringValue:@""];
		[shared setIntValue:0];
		[fullscreen setIntValue:0];
		[viewOnly setIntValue:0];
		[self setProfilePopupToProfile: nil];

        [displayDescription setStringValue:@""];
	}
}


- (void)updateProfileView:(id)notification
{
	[self loadProfileIntoView];
}

- (void)setProfilePopupToProfile: (NSString *)profileName
{
	ProfileManager *profiles = [ProfileManager sharedManager];
	if ( profileName && [profiles profileNamed: profileName] )
		[profilePopup selectItemWithTitle: profileName];
	else
		[profilePopup selectItemWithTitle: [[profiles defaultProfile] profileName]];
}

- (void)loadProfileIntoView
{
	[profilePopup removeAllItems];
	
	NSArray* profileKeys = [NSArray arrayWithArray:[[ProfileDataManager sharedInstance] sortedKeyArray]];
	
	[profilePopup addItemsWithTitles:profileKeys];
    [[profilePopup menu] addItem: [NSMenuItem separatorItem]];
    [profilePopup addItemWithTitle:NSLocalizedString(@"EditProfiles", nil)];
	
	[self setProfilePopupToProfile: [mServer lastProfile]];
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

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSControl* sender = [aNotification object];
	
	if( display == sender )
	{
		if( nil != mServer && [mServer doYouSupport:EDIT_PORT] )
		{
			[mServer setDisplay:[sender intValue]];
		}
	}
	else if( hostName == sender )
	{
		if( nil != mServer && [mServer doYouSupport:EDIT_ADDRESS] )
		{
			[mServer setHostAndPort:[sender stringValue]];
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
		[mServer setRememberPassword:![mServer rememberPassword]];
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
        // :TORESOLVE: this flickers the popup in the "Edit" state
        //          how to prevent this? some way to reject selection change?
        [self setProfilePopupToProfile: [mServer lastProfile]];
        // open profile manager window
        [[NSApp delegate] showProfileManager: nil];
    }
    else if( nil != mServer )
	{
		[mServer setLastProfile:[sender titleOfSelectedItem]];
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

- (IBAction)addServerChanged:(id)sender
{
	if( nil != mServer )
	{
		[(id)mServer setAddToServerListOnConnect:![mServer addToServerListOnConnect]];
	}
}

- (NSBox*)box
{
	return box;
}

- (IBAction)connectToServer:(id)sender
{
    NSWindow *window;

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
	
    Profile* profile = [[ProfileManager sharedManager] profileNamed:[mServer lastProfile]];
    
    // Asynchronously creates a connection to the server
    window = superController ? [superController window] : [self window];
    connectionWaiter = [[ConnectionWaiter alloc] initWithServer:mServer
                            profile:profile delegate:self window:window];
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

    if (superController)
        [[superController window] orderOut:self];
    [self connectionAttemptEnded];

    if( [mServer addToServerListOnConnect] )
    {
        [[ServerDataManager sharedInstance] addServer:mServer];
    }

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
