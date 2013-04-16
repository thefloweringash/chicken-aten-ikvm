#import "AtenEncodingReader.h"
#import "ByteBlockReader.h"
#import "FrameBufferUpdateReader.h"

const int kAtenEncodingSubrects = 0;
const int kAtenEncodingRaw = 1;

struct AtenSubrect {
    uint16_t a;
    uint16_t b;
    uint8_t y;
    uint8_t x;
    unsigned char data[512];
} __attribute__((packed));

@implementation AtenEncodingReader

- (id)initWithUpdater:(FrameBufferUpdateReader *)aUpdater connection:(RFBConnection *)aConnection {
    if (self = [super initWithUpdater:aUpdater connection:aConnection]) {
        headerReader = [[ByteBlockReader alloc] initTarget:self
                                                    action:@selector(setHeader:)
                                                      size:sizeof(struct AtenEncodingHeader)];
        dataReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setData:)];
    }
    return self;
}

- (void)dealloc {
    [headerReader release];
    [dataReader release];
    [super dealloc];
}

- (void)readEncoding {
    [connection setReader:headerReader];
}

- (void)setRectangle:(NSRect)aRect {
    rectangle = aRect;
    [super setRectangle:aRect];
}

- (void)setHeader:(NSData*)type {
    memcpy(&header, [type bytes], sizeof(header));
    if (header.type == kAtenEncodingRaw) {
        [dataReader setBufferSize:ntohl(header.raw.totalLength) - sizeof(struct AtenEncodingHeader)];
        [connection setReader:dataReader];
    }
    else if (header.type == kAtenEncodingSubrects) {
        uint32_t len = ntohl(header.subrects.totalLength);
        if (len != sizeof(struct AtenEncodingHeader)) {
            [dataReader setBufferSize:ntohl(header.subrects.totalLength) - sizeof(struct AtenEncodingHeader)];
            [connection setReader:dataReader];
        }
        else {
            [updater didRect:self];
        }
    }
    else {
        NSLog(@"Unknown Aten encoding: %i", header.type);
    }
}

- (void)setData:(NSData*)data {
    if (header.type == kAtenEncodingRaw) {
        [frameBuffer putRect:rectangle fromData:[data bytes]];
    }
    else if (header.type == kAtenEncodingSubrects) {
        const uint32_t segments = ntohl(header.subrects.totalSegments);
        const struct AtenSubrect *subrect = (const struct AtenSubrect*)[data bytes];
        const struct AtenSubrect *end = subrect + segments;
        while (subrect < end) {
            NSRect screenRect = NSMakeRect(subrect->x * 16, subrect->y * 16, 16, 16);
            [frameBuffer putRect:screenRect fromData:&subrect->data[0]];
            ++subrect;
        }
    }
    [updater didRect:self];
}

@end
