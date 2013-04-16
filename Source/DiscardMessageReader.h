#import <Foundation/Foundation.h>

#import "RFBProtocol.h"
#import "RFBConnection.h"

@interface DiscardMessageReader : NSObject {
    RFBProtocol *_protocol;
    RFBConnection *_connection;
    id _discardReader;
}

- (id)initWithProtocol: (RFBProtocol *)aProtocol connection: (RFBConnection *)aConnection messageLength:(int)aLength;
- (void) readMessage;
@end
