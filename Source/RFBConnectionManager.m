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
#import "ProfileManager.h"
#import "Profile.h"
#import "rfbproto.h"
#import "vncauth.h"
#import "ServerDataViewController.h"
#import "ServerBase.h"

#import "GrayScaleFrameBuffer.h"
#import "LowColorFrameBuffer.h"
#import "HighColorFrameBuffer.h"
#import "TrueColorFrameBuffer.h"
#import "ServerDataManager.h"

#define RENDEZVOUS_SETTINGS @"Rendezvous Setting"

static RFBConnectionManager*	sharedManager = nil;

@implementation RFBConnectionManager

+ (void)initialize {
    id ud = [NSUserDefaults standardUserDefaults];
	id dict = [NSDictionary dictionaryWithObjectsAndKeys:
		@"128", @"PS_MAXRECTS",
		@"10000", @"PS_THRESHOLD",
		[NSNumber numberWithFloat: 26.0], @"FullscreenAutoscrollIncrement",
		[NSNumber numberWithFloat: 0.0],  @"FullscreenScrollbars",
		[NSNumber numberWithFloat: 0.0], @"FrontFrameBufferUpdateSeconds",
		[NSNumber numberWithFloat: 0.9], @"OtherFrameBufferUpdateSeconds",
		[NSNumber numberWithBool: YES], @"DisplayFullscreenWarning",
					   nil];
	[ud registerDefaults: dict];
}

- (void)awakeFromNib
{
    int i;
    NSString* s;
    id ud = [NSUserDefaults standardUserDefaults];
    float updateDelay;
	mDisplayGroups = false;
	
	mServerCtrler = [[ServerDataViewController alloc] init];
	[mServerCtrler setConnectionDelegate:self];

    sigblock(sigmask(SIGPIPE));
    connections = [[NSMutableArray alloc] init];
    cmdlineHost = nil;
    cmdlineDisplay = 0;
    cmdlinePassword = @"";
    cmdlineFullscreen = NO;
    sharedManager = self;
    [NSApp setDelegate:self];
    [profileManager wakeup];
    i = [ud integerForKey:RFB_COLOR_MODEL];
    if(i == 0) {
        NSWindowDepth windowDepth = [[NSScreen mainScreen] depth];
        if(NSNumberOfColorComponents(NSColorSpaceFromDepth(windowDepth)) == 1) {
            i = 1;
        } else {
            int bps = NSBitsPerSampleFromDepth(windowDepth);

            if(bps < 4)		i = 2;
            else if(bps < 8)	i = 3;
            else		i = 4;
        }
    }
    [colorModelMatrix selectCellWithTag:i - 1];
    if((s = [ud objectForKey:RFB_GAMMA_CORRECTION]) == nil) {
        s = [gamma stringValue];
    }
    [gamma setFloatingPointFormat:NO left:1 right:2];
    [gamma setFloatValue:[s floatValue]];
    
    [psThreshold setStringValue: [ud stringForKey: @"PS_THRESHOLD"]];
    [psMaxRects setStringValue: [ud stringForKey: @"PS_MAXRECTS"]];
    
    [autoscrollIncrement setFloatValue: [ud floatForKey:@"FullscreenAutoscrollIncrement"]];
    
    [fullscreenScrollbars setFloatValue: [ud boolForKey:@"FullscreenScrollbars"]];
    
    updateDelay = [ud floatForKey: @"FrontFrameBufferUpdateSeconds"];
    updateDelay = (float)[frontInverseCPUSlider maxValue] - updateDelay;
    [frontInverseCPUSlider setFloatValue: updateDelay];
    updateDelay = [ud floatForKey: @"OtherFrameBufferUpdateSeconds"];
    updateDelay = (float)[otherInverseCPUSlider maxValue] - updateDelay;
    [otherInverseCPUSlider setFloatValue: updateDelay];
	[displayFullscreenWarning setState: [ud boolForKey:@"DisplayFullscreenWarning"]];
    
    // end jason

    [self processArguments];

    if (cmdlineHost) {
	/* Connect without GUI */
	Profile* profile;
		
	ServerBase* cmdlineServer = [[[ServerBase alloc] init] autorelease];
	[cmdlineServer setHost:cmdlineHost];
	[cmdlineServer setPassword:cmdlinePassword];
	[cmdlineServer setDisplay:cmdlineDisplay];
	[cmdlineServer setFullscreen:cmdlineFullscreen];

	profile = [profileManager profileNamed:DefaultProfile];	
	
	[self createConnectionWithServer:cmdlineServer profile:profile owner:self];

    } else {
	if((s = [ud objectForKey:RFB_LAST_HOST]) != nil) {
	    [serverList setStringValue:s];
	    [self selectedHostChanged];
	}
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProfileList:) name:ProfileAddDeleteNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverListDidChange:) name:ServerListChangeMsg object:nil];

	// So we can tell when the serverList finished changing
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(cellTextDidEndEditing:) name: NSControlTextDidEndEditingNotification object: serverList];
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(cellTextDidBeginEditing:) name: NSControlTextDidBeginEditingNotification object: serverList];
    }
		
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

	[loginPanel makeFirstResponder: serverListBox];
	[loginPanel makeKeyAndOrderFront:self];
	
	[self useRendezvous:[[NSUserDefaults standardUserDefaults] boolForKey:RENDEZVOUS_SETTINGS]];
	
	[mInfoVersionNumber setStringValue: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];
}

- (void)processArguments
{
    int i;
    NSProcessInfo *procInfo = [NSProcessInfo processInfo];
    NSArray *args = [procInfo arguments];
    NSString *arg;
    NSString *passwordFile;
    char *decrypted_password;

	// Check our arguments.  Args start at 0, which is the application name
	// so we start at 1.  arg count is the number of arguments, including
	// the 0th argument.
    for (i = 1; i < [args count]; i++) {
		arg = [args objectAtIndex:i];
		
		if ([arg hasPrefix:@"-psn"]) {
			// Called from the finder.  Do nothing.
			//if (i + 1 >= [args count]) [self cmdlineUsage];
			//i++;
		} else if ([arg hasPrefix:@"--PasswordFile"]) {
			if (i + 1 >= [args count]) [self cmdlineUsage];
			passwordFile = [args objectAtIndex:++i];
			decrypted_password = vncDecryptPasswdFromFile((char*)[passwordFile cString]);
			if (decrypted_password == NULL) {
				fprintf(stderr, "Cannot read password from file.\n");
			} else {
				cmdlinePassword = [[NSString alloc] initWithCString:decrypted_password];
				free(decrypted_password);
			}
		} else if ([arg hasPrefix:@"--FullScreen"]) {
			cmdlineFullscreen = YES;
			// FIXME: Support -FullScreen=0 etc
			//if (i + 1 >= [args count]) [self cmdlineUsage];
			//cmdlinePasswordFile = [args objectAtIndex:i+1];
		} else if ([arg hasPrefix:@"-"]) {
			[self cmdlineUsage];
		} else {
			/* No dash, host:display */
			NSArray *listItems = [arg componentsSeparatedByString:@":"];
			cmdlineHost = [listItems objectAtIndex:0];
			
			if (![cmdlineHost isEqualToString:arg]) {
				/* Found : */
				cmdlineDisplay = [[listItems objectAtIndex:1] intValue];
			} else {
				/* No colon, assume :0 as default */
				cmdlineDisplay = 0;
			}
		} 
    }
}

- (void)cmdlineUsage
{
    fprintf(stderr, "\nUsage: Chicken of the VNC [options] [host:display]\n\n");
    fprintf(stderr, "options:\n\n");
    fprintf(stderr, "--PasswordFile <password-file>\n");
    fprintf(stderr, "--FullScreen\n");
    exit(1);
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

- (void)savePrefs
{
    id ud = [NSUserDefaults standardUserDefaults];

    [ud setInteger:[[colorModelMatrix selectedCell] tag] + 1 forKey:RFB_COLOR_MODEL];
    [ud setObject:[gamma stringValue] forKey:RFB_GAMMA_CORRECTION];
    [ud setObject:[psMaxRects stringValue] forKey:@"PS_MAXRECTS"];
    [ud setObject:[psThreshold stringValue] forKey:@"PS_THRESHOLD"];
	// jason added the rest
    [ud setFloat: floor([autoscrollIncrement floatValue] + 0.5) forKey:@"FullscreenAutoscrollIncrement"];
    [ud setBool:[fullscreenScrollbars floatValue] forKey:@"FullscreenScrollbars"];
    [ud setBool:[displayFullscreenWarning state] forKey:@"DisplayFullscreenWarning"];
}

- (IBAction)preferencesChanged:(id)sender
{
	[self savePrefs];
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
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* hostDictionaryList = [ud objectForKey:RFB_HOST_INFO];
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
	/* change */
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* hostDictionaryList, *hostDictionary, *names;

    hostDictionaryList = [[[ud objectForKey:RFB_HOST_INFO] mutableCopy] autorelease];
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
    [ud setObject:hostDictionaryList forKey:RFB_HOST_INFO];
}

- (void)removeConnection:(id)aConnection
{
    [aConnection retain];
    [connections removeObject:aConnection];
    [aConnection autorelease];
    if (cmdlineHost) 
	[NSApp terminate:self];
}

- (void)connect:(id<IServerData>)server;
{
    Profile* profile = [profileManager profileNamed:[server lastProfile]];
    
    // Only close the open dialog of the connection was successful
    if( YES == [self createConnectionWithServer:server profile:profile owner:self] )
	{
        [loginPanel orderOut:self];
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
	[[ServerDataManager sharedInstance] createServerByName:NSLocalizedString(@"RFBDefaultServerName", nil)];
}

- (IBAction)deleteSelectedServer:(id)sender
{
	[[ServerDataManager sharedInstance] removeServer:[self selectedServer]];
}

- (id)defaultFrameBufferClass
{
    switch([[colorModelMatrix selectedCell] tag]) {
        case 0: return [GrayScaleFrameBuffer class];
        case 1: return [LowColorFrameBuffer class];
        case 2: return [HighColorFrameBuffer class];
        case 3: return [TrueColorFrameBuffer class];
        default: return [TrueColorFrameBuffer class];
    }
}

+ (void)getLocalPixelFormat:(rfbPixelFormat*)pf
{
    id fbc = [sharedManager defaultFrameBufferClass];

    [fbc getPixelFormat:pf];
}

+ (float)gammaCorrection
{
    return [sharedManager->gamma floatValue];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self savePrefs];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    // Don't bother caching - this won't happen often enough to matter.
    // If you  want to cache this, make a class so we can refactor it from everywhere else
    BOOL gIsJaguar = [NSString instancesRespondToSelector: @selector(decomposedStringWithCanonicalMapping)];

    // [[NSApp windows] count] is the best option, but it don't work pre-jaguar
    if ((gIsJaguar && ([[NSApp windows] count] == 0)) || ((!gIsJaguar) && (![self haveAnyConnections]))) {
        [loginPanel makeKeyAndOrderFront:self];
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

- (IBAction)frontInverseCPUSliderChanged: (NSSlider *)sender
{
	NSEnumerator *connectionEnumerator = [connections objectEnumerator];
	RFBConnection *thisConnection;
	NSWindow *keyWindow = [NSApp keyWindow];
	float updateDelay = [sender floatValue];
	
	updateDelay = (float)[sender maxValue] - updateDelay;
	[[NSUserDefaults standardUserDefaults] setFloat: updateDelay forKey: @"FrontFrameBufferUpdateSeconds"];
	while (thisConnection = [connectionEnumerator nextObject]) {
		if ([thisConnection window] == keyWindow) {
			[thisConnection setFrameBufferUpdateSeconds: updateDelay];
			break;
		}
	}
}

- (IBAction)otherInverseCPUSliderChanged: (NSSlider *)sender
{
	NSEnumerator *connectionEnumerator = [connections objectEnumerator];
	RFBConnection *thisConnection;
	NSWindow *keyWindow = [NSApp keyWindow];
	float updateDelay = [sender floatValue];

	updateDelay = (float)[sender maxValue] - updateDelay;
	[[NSUserDefaults standardUserDefaults] setFloat: updateDelay forKey: @"OtherFrameBufferUpdateSeconds"];
	while (thisConnection = [connectionEnumerator nextObject]) {
		if ([thisConnection window] != keyWindow) {
			[thisConnection setFrameBufferUpdateSeconds: updateDelay];
		}
	}
}

- (float)maxPossibleFrameBufferUpdateSeconds;
{
	return [frontInverseCPUSlider maxValue];
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

- (IBAction)changeRendezvousUse:(id)sender
{
	[self useRendezvous:![[ServerDataManager sharedInstance] getUseRendezvous]];
}

- (void)useRendezvous:(bool)useRendezvous
{
	[[ServerDataManager sharedInstance] useRendezvous: useRendezvous];
	
	assert( [[ServerDataManager sharedInstance] getUseRendezvous] == useRendezvous );
	
	[rendezvousMenuItem setState:useRendezvous ? NSOnState : NSOffState];
	
	[[NSUserDefaults standardUserDefaults] setBool:useRendezvous forKey:RENDEZVOUS_SETTINGS];
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

@end
