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
#import "CARD32Reader.h"
#import "ByteBlockReader.h"
#import "RFBStringReader.h"

@implementation RFBHandshaker

- (id)initTarget:(id)aTarget action:(SEL)anAction
{
    authTypeReader = [[CARD32Reader alloc] initTarget:self action:@selector(setAuthType:)];
    connFailedReader = [[RFBStringReader alloc] initTarget:self action:@selector(connFailed:)];
    challengeReader = [[ByteBlockReader alloc] initTarget:self action:@selector(challenge:)
                                                     size:CHALLENGESIZE];
    authResultReader = [[CARD32Reader alloc] initTarget:self action:@selector(setAuthResult:)];
    serverInitReader = [[RFBServerInitReader alloc] initTarget:self action:@selector(setServerInit:)];
    return [super initTarget:aTarget action:anAction];
}

- (void)dealloc
{
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

    sprintf(clientData, rfbProtocolVersionFormat, rfbProtocolMajorVersion, rfbProtocolMinorVersion);
    [target writeBytes:(unsigned char*)clientData length:sz_rfbProtocolVersionMsg];
    [target setReader:authTypeReader];
}

- (void)sendClientInit
{
    unsigned char shared = [target connectShared] ? 1 : 0;

    [target writeBytes:&shared length:1];
    [target setReader:serverInitReader];
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
            [target terminateConnection:[NSString stringWithFormat:@"Unknown authType %@", authType]];
            break;
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
    switch([theResult unsignedIntValue]) {
        case rfbVncAuthOK:
            [self sendClientInit];
            break;
        case rfbVncAuthFailed:
            [target terminateConnection:@"Authentication Failed"];
            break;
        case rfbVncAuthTooMany:
            [target terminateConnection:@"Authentication Failed (too many failures)"];
            break;
        default:
            [target terminateConnection:[NSString stringWithFormat:@"Unknown authResult %@",
                theResult]];
            break;
    }
}

- (void)setServerInit:(ServerInitMessage*)serverMsg
{
    [target performSelector:action withObject:serverMsg];
}

- (void)connFailed:(NSString*)theReason
{
    [target terminateConnection:theReason];
}

@end
