/* RFBHandshaker.m created by helmut on Tue 16-Jun-1998 */

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

#import "RFBHandshaker.h"
#import "RFBServerInitReader.h"
#import "CARD8Reader.h"
#import "CARD32Reader.h"
#import "ByteBlockReader.h"
#import "RFBStringReader.h"

@implementation RFBHandshaker

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
	if (self = [super initTarget:aTarget action:anAction]) {
		authCountReader = [[CARD8Reader alloc] initTarget:self action:@selector(setAuthCount:)];
		authTypeReader = [[CARD32Reader alloc] initTarget:self action:@selector(setAuthType:)];
		connFailedReader = [[RFBStringReader alloc] initTarget:self action:@selector(connFailed:)];
		challengeReader = [[ByteBlockReader alloc] initTarget:self action:@selector(challenge:) size:CHALLENGESIZE];
		authResultReader = [[CARD32Reader alloc] initTarget:self action:@selector(setAuthResult:)];
		serverInitReader = [[RFBServerInitReader alloc] initTarget:self action:@selector(setServerInit:)];
	}
    return self;
}

- (void)dealloc
{
	[authCountReader release];
	[authTypeArrayReader release];
    [authTypeReader release];
    [connFailedReader release];
    [challengeReader release];
    [authResultReader release];
    [serverInitReader release];
    [super dealloc];
}

- (void)resetReader
{
    char clientData[sz_rfbProtocolVersionMsg + 1];
	int protocolMinorVersion = MIN(rfbProtocolMinorVersion, [target serverMinorVersion]);

	sprintf(clientData, rfbProtocolVersionFormat, rfbProtocolMajorVersion, protocolMinorVersion);
    [target writeBytes:(unsigned char*)clientData length:sz_rfbProtocolVersionMsg];
		
	if (protocolMinorVersion >= 7)
		[target setReader:authCountReader];
	else
		[target setReader:authTypeReader];
}

- (void)sendClientInit
{
    unsigned char shared = [target connectShared] ? 1 : 0;

    [target writeBytes:&shared length:1];
    [target setReader:serverInitReader];
}

// Protocol 3.7+
- (void)setAuthCount:(NSNumber*)authCount {
	if ([authCount intValue] == 0) {
		[target setReader:connFailedReader];
	}
	else {
		authTypeArrayReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setAuthArray:) size:[authCount intValue]];
		[target setReader:authTypeArrayReader];
	}
}

// Protocol 3.7+
- (void)setAuthArray:(NSData*)authTypeArray {
	// The server is giving us a choice of auth types, we'll take the first one that we can handle
	int index=0;
	const char *bytes=[authTypeArray bytes];
	unsigned char availableAuthType=0;
	NSString *errorStr = nil;
	
	while (index < [authTypeArray length]) {
		unsigned char availableAuthType = bytes[index++];
		
		switch (availableAuthType) {
			case rfbNoAuth: {
				[target writeBytes:&availableAuthType length:1];
				
				if (MIN(rfbProtocolMinorVersion, [target serverMinorVersion]) >= 8) // For 3.8+ we need to get a result back from the server
					[target setReader: authResultReader];
				else // For 3.7 we continue on with Client Init
					[self sendClientInit];
				
				return;
			}
			case rfbVncAuth: {
				[target writeBytes:&availableAuthType length:1];
				[target setReader:challengeReader];
				return;
			}
			default: {
				if (!errorStr)
					errorStr = [NSString stringWithFormat:NSLocalizedString( @"UnknownAuthType", nil ),
						[NSNumber numberWithChar:availableAuthType]]; 
				else
					errorStr = [errorStr stringByAppendingFormat:@",%@", [NSNumber numberWithChar:availableAuthType]];
				if (availableAuthType == 30)
					errorStr = [NSLocalizedString( @"ARDAuthWarning", nil ) stringByAppendingFormat:errorStr];
			}
		}
	}


	// No valid auth type found
	NSLog(errorStr);
	availableAuthType= 0;
	[target writeBytes:&availableAuthType length:1];
	[target terminateConnection:errorStr];
}

- (void)setAuthType:(NSNumber*)authType
{
    switch([authType unsignedIntValue]) {
        case rfbConnFailed:
            [target setReader:connFailedReader];
            break;
        case rfbNoAuth:
            [self sendClientInit];
            break;
        case rfbVncAuth:
            [target setReader:challengeReader];
            break;
        default:
		{
			NSString *errorStr = NSLocalizedString( @"UnknownAuthType", nil );
			errorStr = [NSString stringWithFormat:errorStr, authType];
            [target terminateConnection:errorStr];
            break;
		}
    }
}

- (void)challenge:(NSData*)theChallenge
{
    unsigned char bytes[CHALLENGESIZE];

    [theChallenge getBytes:bytes length:CHALLENGESIZE];
    vncEncryptBytes(bytes, (char*)[[target password] cString]);
    [target writeBytes:bytes length:CHALLENGESIZE];
    [target setReader:authResultReader];
}

- (void)setAuthResult:(NSNumber*)theResult
{
	NSString *errorStr;

    switch([theResult unsignedIntValue]) {
        case rfbVncAuthOK:
            [self sendClientInit];
            break;
        case rfbVncAuthFailed:
			if (MIN(rfbProtocolMinorVersion, [target serverMinorVersion]) >= 8) { // 3.8+ We get an error return string (unlocalized)
				[target setReader:connFailedReader];
			}
			else {
				errorStr = NSLocalizedString( @"AuthenticationFailed", nil );
				[target terminateConnection:errorStr];
			}
            break;
        case rfbVncAuthTooMany:
			errorStr = NSLocalizedString( @"AuthenticationFailedTooMany", nil );
            [target terminateConnection:errorStr];
            break;
        default:
			errorStr = NSLocalizedString( @"UnknownAuthResult", nil );
			errorStr = [NSString stringWithFormat:errorStr, theResult];
            [target terminateConnection:errorStr];
            break;
    }
}

- (void)setServerInit:(ServerInitMessage*)serverMsg
{
    [target performSelector:action withObject:serverMsg];
}

- (void)connFailed:(NSString*)theReason
{
    [target terminateConnection:[NSString stringWithFormat:@"%@ - %@:\n%@",
		NSLocalizedString( @"AuthenticationFailed", nil ),
		NSLocalizedString(@"ServerReports", nil) , 
		theReason]];
}

@end
