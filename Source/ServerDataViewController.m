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

- (void)dealloc
{	
	[super dealloc];
		
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:ProfileListChangeMsg
												  object:(id)[ProfileDataManager sharedInstance]];}

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
		[self setProfilePopupToProfile: [mServer lastProfile]];
		
		[hostName    setEditable:[mServer doYouSupport:EDIT_ADDRESS]];
		[display     setEditable:[mServer doYouSupport:EDIT_PORT]];
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

- (void)setConnectionDelegate:(id)delegate
{
	mDelegate = delegate;
}

- (void)hostChanged:(id)sender
{
	if( nil != mServer && [mServer doYouSupport:EDIT_ADDRESS] )
	{
		[mServer setHost:[sender stringValue]];
	}
}

- (void)passwordChanged:(id)sender
{
	if( nil != mServer )
	{
		[mServer setPassword:[sender stringValue]];
	}
}

- (IBAction)rememberPwdChanged:(id)sender
{
	if( nil != mServer )
	{
		[mServer setRememberPassword:![mServer rememberPassword]];
	}
}

- (IBAction)displayChanged:(id)sender
{
	if( nil != mServer && [mServer doYouSupport:EDIT_PORT] )
	{
		[mServer setDisplay:[sender intValue]];
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

- (NSBox*)box
{
	return box;
}

- (IBAction)connectToServer:(id)sender
{
	[connectIndicator startAnimation:self];
	[connectIndicatorText setStringValue:NSLocalizedString(@"Connecting...", @"Connect in process notification string")];
	[connectIndicatorText display];
	
	[mDelegate connect:mServer];
	
	[connectIndicator stopAnimation:self];
	[connectIndicatorText setStringValue:@""];
	[connectIndicatorText display];
}

@end
