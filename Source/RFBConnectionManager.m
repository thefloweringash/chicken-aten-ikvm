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

#import "RFBConnectionManager.h"
#import "RFBConnection.h"
#import "ProfileManager.h"
#import "Profile.h"
// #import <signal.h> // jason removed signal handler
#import "rfbproto.h"

#import "GrayScaleFrameBuffer.h"
#import "LowColorFrameBuffer.h"
#import "HighColorFrameBuffer.h"
#import "TrueColorFrameBuffer.h"

#define RFBColorModel		@"RFBColorModel"
#define RFBGammaCorrection	@"RFBGammaCorrection"
#define RFBLastHost		@"RFBLastHost"

#define RFBHostInfo		@"HostPreferences"
#define RFBLastDisplay		@"Display"
#define RFBLastProfile		@"Profile"

static RFBConnectionManager*	sharedManager = nil;

@implementation RFBConnectionManager

// Jason added the +initialize method
+ (void)initialize {
    id ud = [NSUserDefaults standardUserDefaults];
	id dict = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects: @"128", @"10000", [NSNumber numberWithFloat: 26.0], [NSNumber numberWithFloat: 0.0], nil] forKeys: [NSArray arrayWithObjects: @"PS_MAXRECTS", @"PS_THRESHOLD", @"FullscreenAutoscrollIncrement", @"FullscreenScrollbars", nil]];
	[ud registerDefaults: dict];
}

- (void)awakeFromNib
{
    int i;
    NSString* s;
    id ud = [NSUserDefaults standardUserDefaults];

	sigblock(sigmask(SIGPIPE));
	connections = [[NSMutableArray alloc] init];
	sharedManager = self;
	[NSApp setDelegate:self];
	[profileManager wakeup];
    i = [ud integerForKey:RFBColorModel];
    if(i == 0) {
        NSWindowDepth d = [[NSScreen mainScreen] depth];
        if(NSNumberOfColorComponents(NSColorSpaceFromDepth(d)) == 1) {
            i = 1;
        } else {
            int bps = NSBitsPerSampleFromDepth(d);

            if(bps < 4)		i = 2;
            else if(bps < 8)	i = 3;
            else		i = 4;
        }
    }
    [colorModelMatrix selectCellWithTag:i - 1];
    if((s = [ud objectForKey:RFBGammaCorrection]) == nil) {
        s = [gamma stringValue];
    }
    [gamma setFloatingPointFormat:NO left:1 right:2];
    [gamma setFloatValue:[s floatValue]];
	// jason added the following because, well, it was missing
	[psThreshold setStringValue: [ud stringForKey: @"PS_THRESHOLD"]];
	[psMaxRects setStringValue: [ud stringForKey: @"PS_MAXRECTS"]];
    [autoscrollIncrement setFloatValue: [ud floatForKey:@"FullscreenAutoscrollIncrement"]];
    [fullscreenScrollbars setFloatValue: [ud boolForKey:@"FullscreenScrollbars"]];
	// end jason
    [self updateProfileList:nil];
    if((s = [ud objectForKey:RFBLastHost]) != nil) {
        [hostName setStringValue:s];
    }
    [self updateLoginPanel];
    [loginPanel makeKeyAndOrderFront:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProfileList:) name:ProfileAddDeleteNotification object:nil];
}

- (void)dealloc
{
    [connections release];
    [super dealloc];
}

- (void)savePrefs
{
    id ud = [NSUserDefaults standardUserDefaults];

    [ud setInteger:[[colorModelMatrix selectedCell] tag] + 1 forKey:RFBColorModel];
    [ud setObject:[gamma stringValue] forKey:RFBGammaCorrection];
    [ud setObject:[psMaxRects stringValue] forKey:@"PS_MAXRECTS"];
    [ud setObject:[psThreshold stringValue] forKey:@"PS_THRESHOLD"];
	// jason added the rest
    [ud setFloat: floor([autoscrollIncrement floatValue] + 0.5) forKey:@"FullscreenAutoscrollIncrement"];
    [ud setBool:[fullscreenScrollbars floatValue] forKey:@"FullscreenScrollbars"];
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

- (void)updateLoginPanel
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* hi = [ud objectForKey:RFBHostInfo];
    NSDictionary* h = [hi objectForKey:[hostName stringValue]];

	[hostName removeAllItems];
    if(h != nil) {
		NSEnumerator *hostEnumerator = [hi keyEnumerator];
		NSString *host;
		
        [display setStringValue:[h objectForKey:RFBLastDisplay]];
        [profilePopup selectItemWithTitle:[h objectForKey:RFBLastProfile]];
		while (host = [hostEnumerator nextObject]) {
			[hostName addItemWithObjectValue: host];
		}
    }
}

- (NSString*)translateDisplayName:(NSString*)aName forHost:(NSString*)aHost
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* hi = [ud objectForKey:RFBHostInfo];
    NSDictionary* h = [hi objectForKey:aHost];
    NSDictionary* names = [h objectForKey:@"NameTranslations"];
    NSString* news;
	
    if((news = [names objectForKey:aName]) == nil) {
        news = aName;
    }
    return news;
}

- (void)setDisplayNameTranslation:(NSString*)translation forName:(NSString*)aName forHost:(NSString*)aHost
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* hi, *h, *names;

    hi = [[[ud objectForKey:RFBHostInfo] mutableCopy] autorelease];
    if(hi == nil) {
        hi = [NSMutableDictionary dictionary];
    }
    h = [[[hi objectForKey:aHost] mutableCopy] autorelease];
    if(h == nil) {
        h = [NSMutableDictionary dictionary];
    }
    names = [[[h objectForKey:@"NameTranslations"] mutableCopy] autorelease];
    if(names == nil) {
        names = [NSMutableDictionary dictionary];
    }
    [names setObject:translation forKey:aName];
    [h setObject:names forKey:@"NameTranslations"];
    [hi setObject:h forKey:aHost];
    [ud setObject:hi forKey:RFBHostInfo];
}

- (void)removeConnection:(id)aConnection
{
    [aConnection retain];
    [connections removeObject:aConnection];
    [aConnection autorelease];
}

- (void)connect:(id)sender
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSDictionary* d;
    NSMutableDictionary* hi, *h;
    Profile* profile;

    [ud setObject:[hostName stringValue] forKey:RFBLastHost];
    hi = [[[ud objectForKey:RFBHostInfo] mutableCopy] autorelease];
    if(hi == nil) {
        hi = [NSMutableDictionary dictionary];
    }
    h = [[[hi objectForKey:[hostName stringValue]] mutableCopy] autorelease];
    if(h == nil) {
        h = [NSMutableDictionary dictionary];
    }
    [hi setObject:h forKey:[hostName stringValue]];
    [h setObject:[display stringValue] forKey:RFBLastDisplay];
    [h setObject:[profilePopup titleOfSelectedItem] forKey:RFBLastProfile];
    [ud setObject:hi forKey:RFBHostInfo];
    
    d = [NSDictionary dictionaryWithObjectsAndKeys:
        [hostName stringValue],			RFB_HOST,
        [passWord stringValue],			RFB_PASSWORD,
        [display stringValue],			RFB_DISPLAY,
        [shared intValue] ? @"1" : @"0" ,	RFB_SHARED,
        NULL, NULL];
    if(![rememberPwd intValue]) {
        [passWord setStringValue:@""];
    }
    profile = [profileManager profileNamed:[profilePopup titleOfSelectedItem]];
    [self createConnectionWithDictionary:d profile:profile owner:self];
    [loginPanel orderOut:self];
	[self updateLoginPanel];
}

/* Do the work of creating a new connection and add it to the list of connections. */
- (void)createConnectionWithDictionary:(NSDictionary *) someDict profile:(Profile *) someProfile owner:(id) someOwner
{
    RFBConnection* theConnection;

    theConnection = [[[RFBConnection alloc] initWithDictionary:someDict profile:someProfile owner:someOwner] autorelease];
    //    theConnection = [[[RFBConnection alloc] initWithDictionary:d andProfile:profile] autorelease];
    if(theConnection) {
        [theConnection setManager:self];
        [connections addObject:theConnection];
    }
}

- (void)preferencesChanged:(id)sender
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

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    [self updateLoginPanel];
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

@end
