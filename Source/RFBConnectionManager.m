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

#import "KeyChain.h"
#import "RFBConnectionManager.h"
#import "RFBConnection.h"
#import "PrefController.h"
#import "ProfileManager.h"
#import "Profile.h"
#import "rfbproto.h"
#import "vncauth.h"
#import "ServerDataViewController.h"
#import "ServerBase.h"
#import "ServerDataManager.h"

@implementation RFBConnectionManager

+ (id)sharedManager
{ 
	static id sInstance = nil;
	if ( ! sInstance )
	{
		sInstance = [[self alloc] initWithWindowNibName: @"ConnectionDialog"];
		NSParameterAssert( sInstance != nil );
	}
	return sInstance;
}


- (void)wakeup
{
	// make sure our window is loaded
	[self window];
	
	mDisplayGroups = false;
	
	mServerCtrler = [[ServerDataViewController alloc] init];
	[mServerCtrler setConnectionDelegate:self];

    sigblock(sigmask(SIGPIPE));
    connections = [[NSMutableArray alloc] init];
    [[ProfileManager sharedManager] wakeup];
    
	NSBox *serverCtrlerBox = [mServerCtrler box];
	[serverCtrlerBox retain];
	[serverCtrlerBox removeFromSuperview];
	
	// I'm hardcoding the border so that I can use a real border at design time so it can be seen easily
	[serverDataBoxLocal setBorderType:NSNoBorder];
	[serverDataBoxLocal setContentView:serverCtrlerBox];
	[serverCtrlerBox release];
	
	[serverListBox retain];
	[serverListBox removeFromSuperview];
	[serverListBox setBorderType:NSNoBorder];
	[splitView addSubview:serverListBox];
	// we now own serverListBox and are responsible for releasing it
	
	[serverGroupBox retain];
	[serverGroupBox removeFromSuperview];
	[serverGroupBox setBorderType:NSNoBorder];
	// we now own serverGroupBox and are responsible for releasing it
	
	[splitView adjustSubviews];
	[self useRendezvous: [[PrefController sharedController] usesRendezvous]];
}

- (BOOL)runFromCommandLine
{
    NSProcessInfo *procInfo = [NSProcessInfo processInfo];
    NSArray *args = [procInfo arguments];
    int i, argCount = [args count];
    NSString *arg;
	
	ServerBase* cmdlineServer = [[[ServerBase alloc] init] autorelease];
	Profile* profile = nil;
	ProfileManager *profileManager = [ProfileManager sharedManager];
	
	// Check our arguments.  Args start at 0, which is the application name
	// so we start at 1.  arg count is the number of arguments, including
	// the 0th argument.
    for (i = 1; i < argCount; i++)
	{
		arg = [args objectAtIndex:i];
		
		if ([arg hasPrefix:@"-psn"])
		{
			// Called from the finder.  Do nothing.
			continue;
		} 
		else if ([arg hasPrefix:@"--PasswordFile"])
		{
			if (i + 1 >= argCount) [self cmdlineUsage];
			NSString *passwordFile = [args objectAtIndex:++i];
			char *decrypted_password = vncDecryptPasswdFromFile((char*)[passwordFile cString]);
			if (decrypted_password == NULL)
			{
				NSLog(@"Cannot read password from file.");
				exit(1);
			} 
			else
			{
				[cmdlineServer setPassword: [NSString stringWithCString:decrypted_password]];
				free(decrypted_password);
			}
		}
		else if ([arg hasPrefix:@"--FullScreen"])
			[cmdlineServer setFullscreen: YES];
		else if ([arg hasPrefix:@"--Profile"])
		{
			if (i + 1 >= argCount) [self cmdlineUsage];
			NSString *profileName = [args objectAtIndex:++i];
			if ( ! [profileManager profileWithNameExists: profileName] )
			{
				NSLog(@"Cannot find a profile with the given name: \"%@\".", profileName);
				exit(1);
			}
			profile = [profileManager profileNamed: profileName];
		}
		else if ([arg hasPrefix:@"-"])
			[self cmdlineUsage];
		else
		{
			/* No dash, host:display */
			NSArray *listItems = [arg componentsSeparatedByString:@":"];
			NSString *cmdlineHost = [listItems objectAtIndex: 0];
			[cmdlineServer setHost: cmdlineHost];
			
			mRunningFromCommandLine = YES;
			
			int cmdlineDisplay;
			if ( ! [cmdlineHost isEqualToString: arg] )
			{
				/* Found : */
				cmdlineDisplay = [[listItems objectAtIndex:1] intValue];
			}
			else
			{
				/* No colon, assume :0 as default */
				cmdlineDisplay = 0;
			}
			[cmdlineServer setDisplay: cmdlineDisplay];
		} 
    }
	
	if ( mRunningFromCommandLine )
	{
		if ( nil == profile )
			profile = [profileManager defaultProfile];	
		[self createConnectionWithServer:cmdlineServer profile:profile owner:self];
		return YES;
	}
	return NO;
}

- (void)runNormally
{
    NSString* lastHostName = [[PrefController sharedController] lastHostName];

	if( nil != lastHostName )
	    [serverList setStringValue: lastHostName];
	[self selectedHostChanged];
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver: self 
		   selector: @selector(updateProfileList:) 
			   name: ProfileAddDeleteNotification 
			 object: nil];
	[nc addObserver: self 
		   selector: @selector(serverListDidChange:) 
			   name: ServerListChangeMsg 
			 object: nil];
	
	// So we can tell when the serverList finished changing
	[nc addObserver:self 
		   selector: @selector(cellTextDidEndEditing:) 
			   name: NSControlTextDidEndEditingNotification 
			 object: serverList];
	[nc addObserver:self 
		   selector: @selector(cellTextDidBeginEditing:) 
			   name: NSControlTextDidBeginEditingNotification 
			 object: serverList];

	[self showConnectionDialog: nil];
}

- (void)cmdlineUsage
{
    fprintf(stderr, "\nUsage: Chicken of the VNC [options] [host:display]\n\n");
    fprintf(stderr, "options:\n\n");
    fprintf(stderr, "--PasswordFile <password-file>\n");
    fprintf(stderr, "--Profile <profile-name>\n");
    fprintf(stderr, "--FullScreen\n");
    exit(1);
}

- (void)showConnectionDialog: (id)sender
{
	[[self window] makeFirstResponder: serverListBox];
	[[self window] makeKeyAndOrderFront:self];
}

- (void)dealloc
{
	[[NSUserDefaults standardUserDefaults] synchronize];
    [connections release];
	[mServerCtrler release];
	[serverListBox release];
	[serverGroupBox release];
    [super dealloc];
}

- (id<IServerData>)selectedServer
{
	return [[ServerDataManager sharedInstance] getServerAtIndex:[serverList selectedRow]];
	
	/*NSTextFieldCell* textField = [serverList  selectedCell];
	if( nil != textField )
	{
		NSString* serverName = [textField stringValue];
		return [[ServerDataManager sharedInstance] getServerWithName:serverName];
	}*/
	
	return nil;
}

- (void)selectedHostChanged
{	
	NSParameterAssert( mServerCtrler != nil );

	id<IServerData> selectedServer = [self selectedServer];
	[mServerCtrler setServer:selectedServer];
	
	
	[serverDeleteBtn setEnabled: [selectedServer doYouSupport:DELETE]];
}

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost
{
	/* change */
    NSDictionary* hostDictionaryList = [[PrefController sharedController] hostInfo];
    NSDictionary* hostDictionary = [hostDictionaryList objectForKey:aHost];
    NSDictionary* names = [hostDictionary objectForKey:@"NameTranslations"];
    NSString* news;
	
    if((news = [names objectForKey:aName]) == nil) {
        news = aName;
    }
    return news;
}

- (void)setDisplayNameTranslation:(NSString*)translation forName:(NSString*)aName forHost:(NSString*)aHost
{
    PrefController* prefController = [PrefController sharedController];
    NSMutableDictionary* hostDictionaryList, *hostDictionary, *names;

    hostDictionaryList = [[[prefController hostInfo] mutableCopy] autorelease];
    if(hostDictionaryList == nil) {
        hostDictionaryList = [NSMutableDictionary dictionary];
    }
    hostDictionary = [[[hostDictionaryList objectForKey:aHost] mutableCopy] autorelease];
    if(hostDictionary == nil) {
        hostDictionary = [NSMutableDictionary dictionary];
    }
    names = [[[hostDictionary objectForKey:@"NameTranslations"] mutableCopy] autorelease];
    if(names == nil) {
        names = [NSMutableDictionary dictionary];
    }
    [names setObject:translation forKey:aName];
    [hostDictionary setObject:names forKey:@"NameTranslations"];
    [hostDictionaryList setObject:hostDictionary forKey:aHost];
    [prefController setHostInfo:hostDictionaryList];
}

- (void)removeConnection:(id)aConnection
{
    [aConnection retain];
    [connections removeObject:aConnection];
    [aConnection autorelease];
    if ( mRunningFromCommandLine ) 
		[NSApp terminate:self];
}

- (void)connect:(id<IServerData>)server;
{
    Profile* profile = [[ProfileManager sharedManager] profileNamed:[server lastProfile]];
    
    // Only close the open dialog of the connection was successful
    if( YES == [self createConnectionWithServer:server profile:profile owner:self] )
	{
        [[self window] orderOut:self];
    }
}

/* Do the work of creating a new connection and add it to the list of connections. */
- (BOOL)createConnectionWithServer:(id<IServerData>) server profile:(Profile *) someProfile owner:(id) someOwner
{
	/* change */
    RFBConnection* theConnection;
    bool returnVal = YES;

    theConnection = [[[RFBConnection alloc] initWithServer:server profile:someProfile owner:someOwner] autorelease];
    if(theConnection) {
        [theConnection setManager:self];
        [connections addObject:theConnection];
    }
    else {
        returnVal = NO;
    }
    
    return returnVal;
}

- (IBAction)addServer:(id)sender
{
	ServerDataManager *serverDataManager = [ServerDataManager sharedInstance];
	id<IServerData> newServer = [serverDataManager createServerByName:NSLocalizedString(@"RFBDefaultServerName", nil)];
	NSString *newName = [newServer name];
	NSParameterAssert( newName != nil );
	
	int index = 0;
	NSEnumerator *serverEnumerator = [serverDataManager getServerEnumerator];
	id<IServerData> server;
	
	while ( server = [serverEnumerator nextObject] )
	{
		NSString *name = [server name];
		if ( name && [name isEqualToString: newName] )
		{
			[serverList selectRow: index byExtendingSelection: NO];
			[serverList editColumn: 0 row: index withEvent: nil select: YES];
			break;
		}
		index++;
	}
}

- (IBAction)deleteSelectedServer:(id)sender
{
	[[ServerDataManager sharedInstance] removeServer:[self selectedServer]];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
//jshprefs    [self savePrefs];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    // Don't bother caching - this won't happen often enough to matter.
    // If you  want to cache this, make a class so we can refactor it from everywhere else
    BOOL gIsJaguar = [NSString instancesRespondToSelector: @selector(decomposedStringWithCanonicalMapping)];

    // [[NSApp windows] count] is the best option, but it don't work pre-jaguar
    if ((gIsJaguar && ([[NSApp windows] count] == 0)) || ((!gIsJaguar) && (![self haveAnyConnections]))) {
        [[self window] makeKeyAndOrderFront:self];
    }
}

- (void)cellTextDidEndEditing:(NSNotification *)notif {
    [self selectedHostChanged];
}

- (void)cellTextDidBeginEditing:(NSNotification *)notif {
    [self selectedHostChanged];
}

// Jason added the following for full-screen windows
- (void)makeAllConnectionsWindowed {
	NSEnumerator *connectionEnumerator = [connections objectEnumerator];
	RFBConnection *thisConnection;

	while (thisConnection = [connectionEnumerator nextObject]) {
		if ([thisConnection connectionIsFullscreen])
			[thisConnection makeConnectionWindowed: self];
	}
}

- (BOOL)haveMultipleConnections {
    return [connections count] > 1;
}

- (BOOL)haveAnyConnections {
    return [connections count] > 0;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if( serverList == aTableView )
	{
		if( mDisplayGroups )
		{
			NSString* groupName = [(NSTextFieldCell*)[groupList selectedCell] stringValue];
			[[[[ServerDataManager sharedInstance] getServerEnumeratorForGroupName:groupName] allObjects] count];
		}
		else
		{
			return [[ServerDataManager sharedInstance] serverCount];
		}
	}
	else if( groupList == aTableView )
	{
		return [[ServerDataManager sharedInstance] groupCount];
	}
	
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if( serverList == aTableView )
	{
		return [[[ServerDataManager sharedInstance] getServerAtIndex:rowIndex] name];
	}
	else if( groupList == aTableView )
	{
		// note - this isn't very efficient - jason
		return [[[[ServerDataManager sharedInstance] getGroupNameEnumerator] allObjects] objectAtIndex:rowIndex];
	}
	
	return NULL;	
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if( serverList == aTableView )
	{
		id<IServerData> server = [[ServerDataManager sharedInstance] getServerAtIndex:row];
		
		return [server doYouSupport:EDIT_NAME];
	}
	else if( groupList == aTableView )
	{
		return NO;
	}
	
	return NO;	
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if( serverList == aTableView )
	{
		NSString* serverName = object;
		id<IServerData> server = [[ServerDataManager sharedInstance] getServerAtIndex:row];
		[server setName:serverName];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSTableView *view = [aNotification object];
	if( serverList == view )
	{
		[self selectedHostChanged];
	}
	else if( groupList == view )
	{
		[serverList reloadData];
	}
}

- (void)updateProfileList:(NSNotification*)notification
{
	[mServerCtrler updateView: notification];
}

- (void)serverListDidChange:(NSNotification*)notification
{
	[serverList reloadData];
	[self selectedHostChanged];
}

- (void)useRendezvous:(BOOL)useRendezvous
{
	[[ServerDataManager sharedInstance] useRendezvous: useRendezvous];
	
	NSParameterAssert( [[ServerDataManager sharedInstance] getUseRendezvous] == useRendezvous );
}

- (void)displayGroups:(bool)display
{
	if( display != mDisplayGroups )
	{
		mDisplayGroups = display;
		
		if( display )
		{
			[splitView addSubview:serverGroupBox positioned:NSWindowBelow relativeTo:serverListBox];
		}
		else
		{	
			[serverGroupBox removeFromSuperview];
		}
		
		[splitView adjustSubviews];
	}
}


- (void)setFrontWindowUpdateInterval: (NSTimeInterval)interval
{
	NSEnumerator *connectionEnumerator = [connections objectEnumerator];
	RFBConnection *thisConnection;
	NSWindow *keyWindow = [NSApp keyWindow];
	
	while (thisConnection = [connectionEnumerator nextObject]) {
		if ([thisConnection window] == keyWindow) {
			[thisConnection setFrameBufferUpdateSeconds: interval];
			break;
		}
	}
}


- (void)setOtherWindowUpdateInterval: (NSTimeInterval)interval
{
	NSEnumerator *connectionEnumerator = [connections objectEnumerator];
	RFBConnection *thisConnection;
	NSWindow *keyWindow = [NSApp keyWindow];
	
	while (thisConnection = [connectionEnumerator nextObject]) {
		if ([thisConnection window] != keyWindow) {
			[thisConnection setFrameBufferUpdateSeconds: interval];
		}
	}
}

@end
