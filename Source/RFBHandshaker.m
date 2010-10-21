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

/* This handles the handshaking messages from the server. */
@implementation RFBHandshaker

- (id)initWithConnection: (RFBConnection *)aConnection;
{
	if (self = [super init]) {
        connection = aConnection;
        connFailedReader = [[RFBStringReader alloc] initTarget:self action:@selector(connFailed:) connection:connection];
		challengeReader = [[ByteBlockReader alloc] initTarget:self action:@selector(challenge:) size:CHALLENGESIZE];
		authResultReader = [[CARD32Reader alloc] initTarget:self action:@selector(setAuthResult:)];
        serverInitReader = nil;
	}
    return self;
}

- (void)dealloc
{
    [connFailedReader release];
    [challengeReader release];
    [authResultReader release];
    [serverInitReader release];
    [super dealloc];
}

- (void)handshake
{
    char clientData[sz_rfbProtocolVersionMsg + 1];
	int protocolMinorVersion = [connection protocolMinorVersion];

	sprintf(clientData, rfbProtocolVersionFormat, rfbProtocolMajorVersion, protocolMinorVersion);
    [connection writeBytes:(unsigned char*)clientData length:sz_rfbProtocolVersionMsg];
		
	if (protocolMinorVersion >= 7) {
        CARD8Reader *authCountReader;

		authCountReader = [[CARD8Reader alloc] initTarget:self action:@selector(setAuthCount:)];
		[connection setReader:authCountReader];
        [authCountReader release];
    } else {
        CARD32Reader    *authTypeReader;

		authTypeReader = [[CARD32Reader alloc] initTarget:self action:@selector(setAuthType:)];
		[connection setReader:authTypeReader];
        [authTypeReader release];
    }
}

- (void)sendClientInit
{
    unsigned char shared = [connection connectShared] ? 1 : 0;

    [connection writeBytes:&shared length:1];
    [serverInitReader release];
    serverInitReader = [[RFBServerInitReader alloc] initWithConnection: connection andHandshaker: self];
    [serverInitReader readServerInit];
}

// Protocol 3.7+
- (void)setAuthCount:(NSNumber*)authCount {
	if ([authCount intValue] == 0) {
        [connFailedReader readString];
	}
	else {
        ByteBlockReader *authTypeArrayReader;
		authTypeArrayReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setAuthArray:) size:[authCount intValue]];
		[connection setReader:authTypeArrayReader];
        [authTypeArrayReader release];
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
				[connection writeBytes:&availableAuthType length:1];
				
				if ([connection protocolMinorVersion] >= 8) // For 3.8+ we need to get a result back from the server
					[connection setReader: authResultReader];
				else // For 3.7 we continue on with Client Init
					[self sendClientInit];
				
				return;
			}
			case rfbVncAuth: {
				[connection writeBytes:&availableAuthType length:1];
				[connection setReader:challengeReader];
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
	NSLog(@"%s", errorStr);
	availableAuthType= 0;
	[connection writeBytes:&availableAuthType length:1];
	[connection terminateConnection:errorStr];
}

- (void)setAuthType:(NSNumber*)authType
{
    switch([authType unsignedIntValue]) {
        case rfbConnFailed:
            [connFailedReader readString];
            break;
        case rfbNoAuth:
            [self sendClientInit];
            break;
        case rfbVncAuth:
            [connection setReader:challengeReader];
            break;
        default:
		{
			NSString *errorStr = NSLocalizedString( @"UnknownAuthType", nil );
			errorStr = [NSString stringWithFormat:errorStr, authType];
            [connection terminateConnection:errorStr];
            break;
		}
    }
}

- (void)challenge:(NSData*)theChallenge
{
    unsigned char bytes[CHALLENGESIZE];

    [theChallenge getBytes:bytes length:CHALLENGESIZE];
    vncEncryptBytes(bytes, (char*)[[connection password] UTF8String]);
    [connection writeBytes:bytes length:CHALLENGESIZE];
    [connection setReader:authResultReader];
}

- (void)setAuthResult:(NSNumber*)theResult
{
    NSString *errorStr;

    switch([theResult unsignedIntValue]) {
        case rfbVncAuthOK:
            [self sendClientInit];
            return;
        case rfbVncAuthFailed:
            if ([connection protocolMinorVersion] >= 8) {
                 // 3.8+ We get an error return string (unlocalized)
                [connFailedReader readString];
                return;
            }
            else {
                errorStr = @"";
            }
            break;
        case rfbVncAuthTooMany:
            errorStr = NSLocalizedString( @"AuthenticationFailedTooMany", nil );
            break;
        default:
            errorStr = NSLocalizedString( @"UnknownAuthResult", nil );
            errorStr = [NSString stringWithFormat:errorStr, theResult];
            break;
    }
    [connection authenticationFailed:errorStr];
}

- (void)setServerInit:(ServerInitMessage*)serverMsg
{
    [connection start:serverMsg];
}

- (void)connFailed:(NSString*)theReason
{
    NSString *errorStr;

    errorStr = [NSString stringWithFormat:@"%@:%@",
                        NSLocalizedString(@"ServerReports", nil),
                        theReason];
    [connection authenticationFailed:errorStr];
}

@end
