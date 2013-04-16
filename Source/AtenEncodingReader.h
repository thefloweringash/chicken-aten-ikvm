#import <Foundation/Foundation.h>

#import "EncodingReader.h"

struct AtenEncodingHeader {
    uint8_t type;
    uint8_t padding;
    union {
        struct {
            uint32_t unknown;
            uint32_t totalLength;
        } __attribute__((packed)) raw;
        struct {
            uint32_t totalSegments;
            uint32_t totalLength;
        } __attribute__((packed)) subrects;
    };
} __attribute__((packed));

@interface AtenEncodingReader : EncodingReader {
    id headerReader;
    id dataReader;

    NSRect rectangle;

    struct AtenEncodingHeader header;
}

- (id)initWithUpdater:(FrameBufferUpdateReader *)aUpdater connection:(RFBConnection *)aConnection;


@end
