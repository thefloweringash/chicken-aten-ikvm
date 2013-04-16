#import "DiscardMessageReader.h"
#import "ByteBlockReader.h"

@implementation DiscardMessageReader
- (id)initWithProtocol: (RFBProtocol *)aProtocol connection: (RFBConnection *)aConnection messageLength:(int)aLength {
    if (self = [super init]) {
        _connection = aConnection;
        _protocol = aProtocol;
        _discardReader = [[ByteBlockReader alloc] initTarget:self action:@selector(done:) size:aLength];
    }
    return self;
}

- (void)dealloc {
    [_discardReader release];
    [super dealloc];
}

- (void)readMessage {
    [_connection setReader:_discardReader];
}

- (void)done:(NSData*)data {
    NSLog(@"Discarded %i bytes:", [data length]);
    NSLog(@"%@", data);
    [_protocol messageReaderDone];
}

@end
