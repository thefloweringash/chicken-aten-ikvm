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
#import "ConnectionWaiter.h"
#import "ListenerController.h"
#import "PrefController.h"
#import "ProfileManager.h"
#import "Profile.h"
#import "rfbproto.h"
#import "vncauth.h"
#import "ServerDataViewController.h"
#import "ServerFromPrefs.h"
#import "ServerStandAlone.h"
#import "ServerDataManager.h"

static NSString *kPrefs_LastHost_Key = @"RFBLastHost";

@implementation RFBConnectionManager

+ (id)sharedManager
{ 
	static id sInstance = nil;
	if ( ! sInstance )
	{
		sInstance = [[self alloc] initWithWindowNibName: @"ConnectionDialog"];
		NSParameterAssert( sInstance != nil );
		
		[sInstance wakeup];
		
		[[NSNotificationCenter defaultCenter] addObserver:sInstance
												 selector:@selector(applicationWillTerminate:)
													 name:NSApplicationWillTerminateNotification object:NSApp];
	}
	return sInstance;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)reloadServerArray
{
    ServerDataManager   *manager = [ServerDataManager sharedInstance];
    [mOrderedServerNames release];
    mOrderedServerNames = [[manager sortedServerNames] retain];
}

- (void)wakeup
{
	// make sure our window is loaded
	[self window];
	[self setWindowFrameAutosaveName: @"login"];
	
	mDisplayGroups = NO;
	mLaunchedByURL = NO;
	
	mOrderedServerNames = nil;
	[self reloadServerArray];
	
	mServerCtrler = [[ServerDataViewController alloc] init];

    signal(SIGPIPE, SIG_IGN);
    connections = [[NSMutableArray alloc] init];
    [[ProfileManager sharedManager] wakeup];
    
	NSBox *serverCtrlerBox = [mServerCtrler box];
	[serverCtrlerBox retain];
	[serverCtrlerBox removeFromSuperview];
    [mServerCtrler setSuperController: self];
	
    // figure out whether the size has changed in order to ease localization
    NSSize originalSize = [serverDataBoxLocal frame].size;
    NSSize newSize = [serverCtrlerBox frame].size;
    NSSize deltaSize = NSMakeSize( newSize.width - originalSize.width, newSize.height - originalSize.height );
    
	// I'm hardcoding the border so that I can use a real border at design time so it can be seen easily
	[serverDataBoxLocal setBorderType:NSNoBorder];
    [serverDataBoxLocal setFrameSize: newSize];
	[serverDataBoxLocal setContentView:serverCtrlerBox];
	[serverCtrlerBox release];
	
    // resize our window if necessary
    NSWindow *window = [serverDataBoxLocal window];
    NSRect oldFrame = [window frame];
    NSSize newFrameSize = {oldFrame.size.width + deltaSize.width, oldFrame.size.height + deltaSize.height };
    NSRect newFrame = { oldFrame.origin, newFrameSize };
    NSView *contentView = [window contentView];
    BOOL didAutoresize = [contentView autoresizesSubviews];
    [contentView setAutoresizesSubviews: NO];
    [window setFrame: newFrame display: NO];
    [contentView setAutoresizesSubviews: didAutoresize];

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

    connectionWaiter = nil;
    lockedSelection = -1;
}

- (BOOL)runFromCommandLine
{
    NSProcessInfo *procInfo = [NSProcessInfo processInfo];
    NSArray *args = [procInfo arguments];
    int i, argCount = [args count];
    NSString *arg;
	
	ServerStandAlone* cmdlineServer = [[[ServerStandAlone alloc] init] autorelease];
    id<IServerData> savedServ = nil;
	Profile* profile = nil;
	ProfileManager *profileManager = [ProfileManager sharedManager];
    BOOL listen = NO;
	
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
			char *decrypted_password = vncDecryptPasswdFromFile((char*)[passwordFile UTF8String]);
			if (decrypted_password == NULL)
			{
				NSLog(@"Cannot read password from file.");
				exit(1);
			} 
			else
			{
				[cmdlineServer setPassword: [NSString stringWithUTF8String:decrypted_password]];
				free(decrypted_password);
			}
		}
		else if ([arg hasPrefix:@"--FullScreen"])
			[cmdlineServer setFullscreen: YES];
		else if ([arg hasPrefix:@"--ViewOnly"])
			[cmdlineServer setViewOnly: YES];
		else if ([arg hasPrefix:@"--Display"])
		{
			if (i + 1 >= argCount) [self cmdlineUsage];
			int display = [[args objectAtIndex:++i] intValue];
			[cmdlineServer setDisplay: display];
		}
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
        else if ([arg isEqualToString:@"--Shared"])
            [cmdlineServer setShared:YES];
        else if ([arg isEqualToString:@"--Listen"])
            mRunningFromCommandLine = listen = YES;
		else if ([arg hasPrefix:@"-"])
			[self cmdlineUsage];
		else if ([arg hasPrefix:@"-?"] || [arg hasPrefix:@"-help"] || [arg hasPrefix:@"--help"])
			[self cmdlineUsage];
		else
		{
            savedServ = [[ServerDataManager sharedInstance] getServerWithName:arg];

            if (savedServ == nil)
                [cmdlineServer setHostAndPort: arg];
			
			mRunningFromCommandLine = YES;
		} 
    }
	
	if ( mRunningFromCommandLine )
	{
        if (listen) {
            ListenerController *l = [ListenerController sharedController];
            [l showWindow:nil];
            if (profile)
                [l changeProfileTo:profile];
            if ([cmdlineServer fullscreen])
                [l setDisplaysFullscreen:YES];
            [l actionPressed:nil];
        } else {
            // :TORESOLVE: currently no way to cancel without killing program
            ConnectionWaiter    *cw;
            id<IServerData> server = savedServ ? savedServ : cmdlineServer;

            if ( nil == profile )
                profile = [profileManager defaultProfile];	
        
            cw = [[ConnectionWaiter alloc] initWithServer:server
                    profile:profile delegate:self window:nil];
            [cw release];
        }
        return YES;
	}
	return NO;
}

- (void)runNormally
{
    NSString* lastHostName = [[NSUserDefaults standardUserDefaults] objectForKey: kPrefs_LastHost_Key];

	if( nil != lastHostName )
        [self selectServerByName: lastHostName];
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
    fprintf(stderr, "\nUsage: Chicken [options] [host:port]\n\n");
    fprintf(stderr, "options:\n\n");
    fprintf(stderr, "--PasswordFile <password-file>\n");
    fprintf(stderr, "--Profile <profile-name>\n");
    fprintf(stderr, "--Display <display-number>\n");
    fprintf(stderr, "--FullScreen\n");
    fprintf(stderr, "--Shared\n");
	fprintf(stderr, "--ViewOnly\n");
    fprintf(stderr, "--Listen\n");
    exit(1);
}

/* Connection initiated from the command-line succeeded */
- (void)connectionSucceeded:(RFBConnection *)conn
{
    [self successfulConnection:conn toServer: nil];
}

/* Connection initiated from command-line failed */
- (void)connectionFailed
{
    [NSApp terminate:self];
}

- (void)showNewConnectionDialog:(id)sender
{
	ServerDataViewController* viewCtrlr = [[ServerDataViewController alloc] initWithReleaseOnCloseOrConnect];
	
	ServerStandAlone* server = [[[ServerStandAlone alloc] init] autorelease];
	
	[viewCtrlr setServer:server];
	[[viewCtrlr window] makeKeyAndOrderFront:self];
}

- (void)showConnectionDialog: (id)sender
{
	[[self window] makeFirstResponder: serverListBox];
	[[self window] makeKeyAndOrderFront:self];
}

- (void)showProfileManager: (id)sender
{
    [mServerCtrler showProfileManager:sender];
}

- (NSString *)selectedServerName
{
    return [mOrderedServerNames objectAtIndex:[serverList selectedRow]];
}

- (id<IServerData>)selectedServer
{
	return [[ServerDataManager sharedInstance] getServerWithName:[self selectedServerName]];
}

// Selects a server by name. Returns whether or not it found the named server
- (BOOL)selectServerByName:(NSString *)aName
{
	NSEnumerator *serverEnumerator = [mOrderedServerNames objectEnumerator];
	int index = 0;
	NSString *name;

	while ( name = [serverEnumerator nextObject] )
	{
		if ( name && [name isEqualToString: aName] )
		{
            NSIndexSet  *set = [[NSIndexSet alloc] initWithIndex: index];
			[serverList selectRowIndexes: set byExtendingSelection: NO];
            [set release];

            if (lockedSelection >= 0)
                lockedSelection = index;
			return YES;
		}
		index++;
	}
    return NO;
}

- (void)selectedHostChanged
{	
	NSParameterAssert( mServerCtrler != nil );

	id<IServerData> selectedServer = [self selectedServer];
	[mServerCtrler setServer:selectedServer];
	
    [self setControlsEnabled:YES];
}

// Disable and enable controls. Controls are disabled during a connection
// attempt and enabled afterwords.
- (void)setControlsEnabled:(BOOL)enabled
{
    ServerBase  *server = [self selectedServer];

    lockedSelection = enabled ? -1 : [serverList selectedRow];

    [serverDeleteBtn setEnabled: enabled
            && [[ServerDataManager sharedInstance] saveableCount] > 1
                // can only delete servers which can be saved
            && [server respondsToSelector:@selector(encodeWithCoder:)]];
    [serverAddBtn setEnabled: enabled];
}

// We're done with the connecting to a server with the dialog
- (void)connectionDone
{
    NSString    *host;

    host = [mOrderedServerNames objectAtIndex:[serverList selectedRow]];
    [[NSUserDefaults standardUserDefaults] setObject:host
                                              forKey:kPrefs_LastHost_Key];
    [[self window] orderOut:self];
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
	if ( 0 == [connections count] ) {
        if ( mRunningFromCommandLine ) 
            [NSApp terminate:self];
        else
            [self showConnectionDialog:nil];
    }
}

/* Creates a connection from an already connected file handle */
- (BOOL)createConnectionWithFileHandle:(NSFileHandle*)file server:(id<IServerData>) server profile:(Profile *) someProfile
{
	/* change */
    RFBConnection* theConnection;

    theConnection = [[RFBConnection alloc] initWithFileHandle:file server:server profile:someProfile];
    if(theConnection) {
        [connections addObject:theConnection];
        [theConnection release];
        return YES;
    }
    else {
        return NO;
    }
}

/* Registers a successful connection using an already-created RFBConnection
 * object. */
- (void)successfulConnection: (RFBConnection *)theConnection
        toServer: (id<IServerData>)server
{
    [connections addObject:theConnection];
}

- (IBAction)addServer:(id)sender
{
	ServerDataManager *serverDataManager = [ServerDataManager sharedInstance];
	id<IServerData> newServer = [serverDataManager createServerByName:NSLocalizedString(@"RFBDefaultServerName", nil)];
	NSString *newName = [newServer name];
	NSParameterAssert( newName != nil );
	
	[self reloadServerArray];
	
    [self selectServerByName: newName];
}

- (IBAction)deleteSelectedServer:(id)sender
{
	[[ServerDataManager sharedInstance] removeServer:[self selectedServer]];
	
	[self reloadServerArray];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    if ([[NSApp windows] count] == 0) {
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
		return [mOrderedServerNames count];
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
		return [mOrderedServerNames objectAtIndex:rowIndex];
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
    if (lockedSelection != -1)
        return NO;

	if( serverList == aTableView )
	{
		id<IServerData> server = [[ServerDataManager sharedInstance] getServerWithName:[mOrderedServerNames objectAtIndex:row]];
		
		return [server doYouSupport:EDIT_NAME];
	}
	else if( groupList == aTableView )
	{
		return NO;
	}
	
	return NO;	
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)row
{
    // prevent the user from changing the selection during a connection attempt
    return lockedSelection == -1 || lockedSelection == row;
}

- (void)afterSort:(id<IServerData>)server
{
	[[self window] makeFirstResponder:[self window]];
	
	[self reloadServerArray];
	
    [self selectServerByName: [server name]];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	if( serverList == aTableView )
	{
		NSString* serverName = object;
		id<IServerData> server = [[ServerDataManager sharedInstance] getServerWithName:[mOrderedServerNames objectAtIndex:row]];
		
		if( NO == [serverName isEqualToString:[server name]] )
		{
			[[self window] makeFirstResponder:[self window]];
			[server setName:serverName];
			
			// This insanity overrides the default select next behavior in the table
			[self performSelector:@selector(afterSort:) withObject:server afterDelay:0.0];
		}
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
    NSString    *name = [self selectedServerName];
	[self reloadServerArray];
	[serverList reloadData];
    if (![self selectServerByName:name])
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
	
	while (thisConnection = [connectionEnumerator nextObject]) {
		if ([thisConnection hasKeyWindow]) {
			[thisConnection setFrameBufferUpdateSeconds: interval];
			break;
		}
	}
}

- (void)setOtherWindowUpdateInterval: (NSTimeInterval)interval
{
	NSEnumerator *connectionEnumerator = [connections objectEnumerator];
	RFBConnection *thisConnection;
	
	while (thisConnection = [connectionEnumerator nextObject]) {
		if ([thisConnection hasKeyWindow]) {
			[thisConnection setFrameBufferUpdateSeconds: interval];
		}
	}
}

- (BOOL)launchedByURL
{
	return mLaunchedByURL;
}

- (void)setLaunchedByURL:(bool)launchedByURL
{
	mLaunchedByURL = launchedByURL;
}

@end
