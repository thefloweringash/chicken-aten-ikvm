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
// #import <signal.h> // jason removed signal handler
#import "rfbproto.h"
#import "vncauth.h"

#import "GrayScaleFrameBuffer.h"
#import "LowColorFrameBuffer.h"
#import "HighColorFrameBuffer.h"
#import "TrueColorFrameBuffer.h"

static RFBConnectionManager*	sharedManager = nil;

@implementation RFBConnectionManager

// Jason added the +initialize method
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

    sigblock(sigmask(SIGPIPE));
    connections = [[NSMutableArray alloc] init];
    cmdlineHost = nil;
    cmdlineDisplay = nil;
    cmdlinePassword = @"";
    cmdlineFullscreen = @"0";
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

    [self updateProfileList:nil];

    if (cmdlineHost) {
	/* Connect without GUI */
	Profile* profile;
	NSDictionary* connectionDictionary;

	connectionDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            cmdlineHost, RFB_HOST,
            cmdlinePassword, RFB_PASSWORD,
            @"0", RFB_SHARED,
            cmdlineDisplay, RFB_DISPLAY,
            cmdlineFullscreen, RFB_FULLSCREEN,
            NULL, NULL];

	profile = [profileManager profileNamed:[profilePopup titleOfSelectedItem]];	
	[self createConnectionWithDictionary:connectionDictionary profile:profile owner:self];

    } else {
	if((s = [ud objectForKey:RFB_LAST_HOST]) != nil) {
	    [hostName setStringValue:s];
	    [self selectedHostChanged:s];
	}
	
        [self updateLoginPanel];
        [loginPanel makeKeyAndOrderFront:self];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProfileList:) name:ProfileAddDeleteNotification object:nil];

	// So we can tell when the hostName finished changing
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(cellTextDidEndEditing:) name: NSControlTextDidEndEditingNotification object: hostName];
	[[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(cellTextDidBeginEditing:) name: NSControlTextDidBeginEditingNotification object: hostName];
    }
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
			cmdlineFullscreen = @"1";
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
				cmdlineDisplay = [listItems objectAtIndex:1];
			} else {
				/* No colon, assume :0 as default */
				cmdlineDisplay = @"0";
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
    [connections release];
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

- (void)updateProfileList:(id)notification
{
	// Jason changed the following line because the original was a reference
    NSString* current = [[[profilePopup titleOfSelectedItem] copy] autorelease];
//    NSString* current = [profilePopup titleOfSelectedItem];
    
    [profilePopup removeAllItems];
    [profilePopup addItemsWithTitles:[profileManager profileNames]];
    [profilePopup selectItemWithTitle:current];
}

/* Used to update the list of hosts in the combo box. */
- (void)updateLoginPanel
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* hostDictionaryList = [ud objectForKey:RFB_HOST_INFO];
    NSDictionary* hostDictionary = [self selectedHostDictionary];

    [hostName removeAllItems];
    if(hostDictionary != nil) {
        NSEnumerator *hostEnumerator = [hostDictionaryList keyEnumerator];
        NSString *host;

        [display setStringValue:[hostDictionary objectForKey:RFB_LAST_DISPLAY]];
        [profilePopup selectItemWithTitle:[hostDictionary objectForKey:RFB_LAST_PROFILE]];
        while (host = [hostEnumerator nextObject]) {
            [hostName addItemWithObjectValue: host];
        }
    }
}

- (IBAction)hostSelectionDidChange:(id)sender
{
    NSString *newSelection = [hostName objectValueOfSelectedItem];
    
    [self selectedHostChanged:newSelection];
}

- (void)selectedHostChanged:(NSString *) newHostName
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* hostDictionaryList = [ud objectForKey:RFB_HOST_INFO];
    NSDictionary* selectedHostDict = [hostDictionaryList objectForKey:newHostName];

    [passWord setStringValue:@""];
    [rememberPwd setIntValue:0];
    [display setStringValue:@""];
    [shared setIntValue:0];
    if (selectedHostDict != nil) {
        [rememberPwd setIntValue:[[selectedHostDict objectForKey:RFB_REMEMBER] intValue]];
        [display setStringValue:[selectedHostDict objectForKey:RFB_DISPLAY]];
        [shared setIntValue:[[selectedHostDict objectForKey:RFB_SHARED] intValue]];
        if ([rememberPwd intValue]) {
            [passWord setStringValue:[[KeyChain defaultKeyChain] genericPasswordForService:KEYCHAIN_SERVICE_NAME account:[hostName stringValue]]];
        }
    }
}

/* Returns the dictionary that corresponds to the currently selected host, or nil if there is none. */
- (NSDictionary *) selectedHostDictionary
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* hostDictionaryList = [ud objectForKey:RFB_HOST_INFO];
    NSDictionary* hostDictionary = [hostDictionaryList objectForKey:[hostName stringValue]];
    return hostDictionary;
}

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost
{
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

- (IBAction)connect:(id)sender
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* connectionDictionary;
    NSMutableDictionary* hostDictionaryList, *hostDictionary;
    Profile* profile;

    [ud setObject:[hostName stringValue] forKey:RFB_LAST_HOST];
    hostDictionaryList = [[[ud objectForKey:RFB_HOST_INFO] mutableCopy] autorelease];
    if(hostDictionaryList == nil) {
        hostDictionaryList = [NSMutableDictionary dictionary];
    }
    hostDictionary = [[[hostDictionaryList objectForKey:[hostName stringValue]] mutableCopy] autorelease];
    if(hostDictionary == nil) {
        hostDictionary = [NSMutableDictionary dictionary];
    }
    [hostDictionaryList setObject:hostDictionary forKey:[hostName stringValue]];
    [hostDictionary setObject:[display stringValue] forKey:RFB_LAST_DISPLAY];
    [hostDictionary setObject:[profilePopup titleOfSelectedItem] forKey:RFB_LAST_PROFILE];
    [hostDictionary setObject:[rememberPwd stringValue] forKey:RFB_REMEMBER];
    [hostDictionary setObject:[shared stringValue] forKey:RFB_SHARED];
    [ud setObject:hostDictionaryList forKey:RFB_HOST_INFO];
    
    connectionDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        [hostName stringValue],			RFB_HOST,
        [passWord stringValue],			RFB_PASSWORD,
        [shared intValue] ? @"1" : @"0",	RFB_SHARED,
        [display stringValue],			RFB_DISPLAY,
        NULL, NULL];
    if(![rememberPwd intValue]) {
        [passWord setStringValue:@""];
        [[KeyChain defaultKeyChain] removeGenericPasswordForService:KEYCHAIN_SERVICE_NAME account:[hostName stringValue]];
    } else {
        [[KeyChain defaultKeyChain] setGenericPassword:[passWord stringValue] forService:KEYCHAIN_SERVICE_NAME account:[hostName stringValue]]; // How do I find my freakin' app name?
    }
    profile = [profileManager profileNamed:[profilePopup titleOfSelectedItem]];
    
    // Only close the open dialog of the connection was successful
    if( YES == [self createConnectionWithDictionary:connectionDictionary profile:profile owner:self] ) {
		if(![rememberPwd intValue]) {
			[passWord setStringValue:@""];
			[[KeyChain defaultKeyChain] removeGenericPasswordForService:KEYCHAIN_SERVICE_NAME account:[hostName stringValue]];
		} else {
			[[KeyChain defaultKeyChain] setGenericPassword:[passWord stringValue] forService:KEYCHAIN_SERVICE_NAME account:[hostName stringValue]]; // How do I find my freakin' app name?
		}
        [loginPanel orderOut:self];
    }

    [self updateLoginPanel];
}

/* Do the work of creating a new connection and add it to the list of connections. */
- (BOOL)createConnectionWithDictionary:(NSDictionary *) someDict profile:(Profile *) someProfile owner:(id) someOwner
{
    RFBConnection* theConnection;
    bool returnVal = YES;

    theConnection = [[[RFBConnection alloc] initWithDictionary:someDict profile:someProfile owner:someOwner] autorelease];
    //    theConnection = [[[RFBConnection alloc] initWithDictionary:connectionDictionary andProfile:profile] autorelease];
    if(theConnection) {
        [theConnection setManager:self];
        [connections addObject:theConnection];
    }
    else {
        returnVal = NO;
    }
    
    return returnVal;
}

- (IBAction)preferencesChanged:(id)sender
{
    [self savePrefs];
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

/* Neither is this needed, nor is it called (until now that I've set the app delegate)
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}
*/

/*
- (void)controlTextDidChange:(NSNotification *)aNotification
{
    NSString *newSelection = [hostName objectValueOfSelectedItem];

    [self selectedHostChanged:newSelection];
}
*/

- (void)cellTextDidEndEditing:(NSNotification *)notif {
    NSString *newSelection = [hostName stringValue];

    [self selectedHostChanged:newSelection];
}

- (void)cellTextDidBeginEditing:(NSNotification *)notif {
    [self selectedHostChanged:nil];
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

@end
