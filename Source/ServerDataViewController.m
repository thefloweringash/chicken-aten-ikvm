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
#import "IServerData.h"
#import "ProfileDataManager.h"
#import "ProfileManager.h"
#import "ServerDataManager.h"

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
		if( NO == removedSaveCheckbox && NO == [mServer doYouSupport:ADD_SERVER_ON_CONNECT] )
		{
			removedSaveCheckbox = YES;
			[save retain];
			[save removeFromSuperview];
		}
		
		[hostName setEnabled: YES];
		[password setEnabled: YES];
		[display setEnabled: YES];
		[shared setEnabled: YES];
		[profilePopup setEnabled: YES];
		
		[hostName setStringValue:[mServer host]];
		[password setStringValue:[mServer password]];
        [rememberPwd setIntValue:[mServer rememberPassword]];
        [display setIntValue:[mServer display]];
        [shared setIntValue:[mServer shared]];
		[fullscreen setIntValue:[mServer fullscreen]];
		[self setProfilePopupToProfile: [mServer lastProfile]];
		
		[hostName    setEnabled: [mServer doYouSupport:EDIT_ADDRESS]];
		[display     setEditable:[mServer doYouSupport:EDIT_PORT]];
		[password    setEnabled: [mServer doYouSupport:EDIT_PASSWORD]];
		[rememberPwd setEnabled: [mServer doYouSupport:SAVE_PASSWORD]];
		[connectBtn  setEnabled: [mServer doYouSupport:CONNECT]];
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
		[self setProfilePopupToProfile: nil];
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
	
	[self setProfilePopupToProfile: [mServer lastProfile]];
}

- (id<IServerData>)server
{
	return mServer;
}

- (void)setConnectionDelegate:(id<ConnectionDelegate>)delegate
{
	mDelegate = delegate;
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
			[mServer setHost:[sender stringValue]];
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
	if( nil != mServer )
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

- (IBAction)addServerChanged:(id)sender
{
	if( nil != mServer )
	{
		[mServer setAddToServerListOnConnect:![mServer addToServerListOnConnect]];
	}
}

- (NSBox*)box
{
	return box;
}

- (IBAction)connectToServer:(id)sender
{
	[connectIndicator startAnimation:self];
	[connectIndicatorText setStringValue:NSLocalizedString(@"Connecting...", @"Connect in process notification string")];
	[connectIndicatorText display];
	
	bool bConnectSuccess = [mDelegate connect:mServer];
	
	[connectIndicator stopAnimation:self];
	[connectIndicatorText setStringValue:@""];
	[connectIndicatorText display];
	
	if( YES == bConnectSuccess )
	{
		if( YES == [mServer doYouSupport:ADD_SERVER_ON_CONNECT] && [mServer addToServerListOnConnect] )
		{
			[[ServerDataManager sharedInstance] addServer:mServer];
		}
		
		if( YES == selfTerminate )
		{
			// shouldCloseDocument will trigger the autorelease
			[[self window] performClose:self];
		}
	}
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
