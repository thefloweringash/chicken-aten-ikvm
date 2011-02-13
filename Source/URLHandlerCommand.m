//
//  URLHandlerCommand.m
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sun Feb 01 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "URLHandlerCommand.h"
#import "ServerDataViewController.h"
#import "ServerBase.h"
#import "RFBConnectionManager.h"
#import "ServerStandAlone.h"

#define HLSAssert(condition, errno, desc) \
if (!(condition)) return [self scriptError: (errno) description: (desc)];
#define HLSAssert1(condition, errno, desc, arg1) \
if (!(condition)) return [self scriptError: (errno) description: \
	[NSString stringWithFormat: (desc), (arg1)]];

@implementation URLHandlerCommand

- (id)scriptError:(int)errorNumber description:(NSString *)description {
    [self setScriptErrorNumber: errorNumber];
    [self setScriptErrorString: description];
    return nil;
}

// Perform somewhat redundant checks here.
// The NSScriptClassDescription should do this as well, but there may be
// pathological cases where it is unable to do so, someone has modified
// the script suite, etc.

- (id)performDefaultImplementation
{
	[[RFBConnectionManager sharedManager] setLaunchedByURL:YES];
	
    NSString *command = [[self commandDescription] commandName];
    NSString *verb = nil;
    NSString *urlString = [self directParameter];
    NSURL *url;
    
    // XXX should be read from .scriptTerminology, but Cocoa provides no way to do this
    if ([command isEqualToString: @"GetURL"]) {
        verb = @"get URL";
    } else if ([command isEqualToString: @"OpenURL"]) {
        verb = @"open URL";
    }
    HLSAssert1(verb != nil, errAEEventNotHandled,
               @"HostLauncher does not respond to R%@S.", command);
	
    // XXX should ignore arguments instead, if the GURL/OURL is coming from a Web browser?
    HLSAssert1([self arguments] == nil || [[self arguments] count] == 0, errAEParamMissed,
               @"Cannot handle arguments for %@", verb);
    HLSAssert(urlString != nil, errAEParamMissed, @"No URL to open was specified.");
    
	url = [NSURL URLWithString: urlString];
    
	ServerDataViewController* viewCtrlr = [[ServerDataViewController alloc] initWithReleaseOnCloseOrConnect];
	
	[[RFBConnectionManager sharedManager] setLaunchedByURL:YES];
	
	ServerStandAlone* server = [[ServerStandAlone alloc] init];
	NSNumber *portNumber = [url port];

    [server setHost:[url host]];
	if (portNumber)
        [server setPort: [portNumber intValue]];
	[server setPassword:[url password]];
	
	[viewCtrlr setServer:server];
	[[viewCtrlr window] makeKeyAndOrderFront:self];
    [server release];
	
	// XXX CFURLCreateStringByAddingPercentEscapes is more permissive
    // wrt URL formats; may want to use it instead (see release notes)
    HLSAssert(url != nil, kURLInvalidURLError,
              @"URL format is invalid; must be fully qualified (scheme://host...).");
	
    return nil;
}

@end
