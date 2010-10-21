//
//  CursorPseudoEncodingReader.m
//  Chicken of the VNC
//
//  Created by Alex Wray on 9/24/08.
//

#import "CursorPseudoEncodingReader.h"
#import "ByteBlockReader.h"
#import "FrameBufferUpdateReader.h"
#import "RFBConnection.h"

@implementation CursorPseudoEncodingReader

- (id)initWithUpdater: (FrameBufferUpdateReader *)aUpdater
        connection: (RFBConnection *)aConnection
{
    if (self = [super initWithUpdater: aUpdater connection: aConnection]) {
        cursorReader = [[ByteBlockReader alloc] initTarget:self action:@selector(setCursor:)];
        bytesPerRow = 0;
        bytesPixels = 0;
    }
    return self;
}

- (void)dealloc
{
    [cursorReader release];
    [super dealloc];
}

- (void)readEncoding
{
    bytesPixels = frame.size.height * frame.size.width * [frameBuffer bytesPerPixel];
    bytesPerRow = (frame.size.width + 7)/8; //padding

        // number of bytes for the mask
    unsigned int bytesMask = bytesPerRow * frame.size.height;
    unsigned int bufferSizeRequired = bytesMask + bytesPixels;

    if (bytesPixels == 0) {
        /* Bail if we get to here: Does this actually occur? */
        [updater didRect: self];
        return;
    }

    [cursorReader setBufferSize:bufferSizeRequired];
    [connection setReader:cursorReader];
}

/* Uses cursor data to set the current cursor. */
- (void)setCursor:(NSData*)pixels
{
    NSImage     *image = [self imageFromCursorData: pixels];

    if (image) {
        NSCursor    *cursor = [[NSCursor alloc] initWithImage:image hotSpot:frame.origin];
        [connection setCursor: cursor];
        [cursor release];
    } else
        [connection setCursor: nil];

    [updater didRect: self];
}

/* Extracts an image, including alpha channel, from cursor data sent by the
 * server.
 *
 * Note that this duplicates some of the functionality of the pixel decoding
 * routines from the FrameBuffer family of classes. However, it seems simpler
 * not to involve the full complexity of that section of code, especially since
 * we have to handle the mask at the same time. */
- (NSImage *)imageFromCursorData: (NSData *)pixels
{
    NSBitmapImageRep    *bitmap;
    int                 width = (int) frame.size.width;
    int                 height = (int) frame.size.height;
    unsigned char       *buff = (unsigned char *)[pixels bytes];
    int                 i, j;
    rfbPixelFormat      *pixf = [frameBuffer pixelFormat];
    unsigned int        redMult = 255 / pixf->redMax;
    unsigned int        greenMult = 255 / pixf->greenMax;
    unsigned int        blueMult = 255 / pixf->blueMax;
    unsigned int        bytesPerPixel = pixf->bitsPerPixel / 8;

    if (!pixf->trueColour) {
        NSLog(@"Can't handle cursor with non-true color pixel");
        return nil;
    }

    bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
            pixelsWide:width pixelsHigh:height bitsPerSample:8
            samplesPerPixel:4 hasAlpha:YES isPlanar:NO
            colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];

    unsigned char       *destData = [bitmap bitmapData];
    int                 rowBytes = [bitmap bytesPerRow];

    /* Extract cursor image and mask from buff */
    for (i=0; i<height; i++) {
        for (j=0; j<width; j++) {
            int             whichBit, whichByte, sourcePos;
            unsigned char   maskVal;
            unsigned char   *dst = destData + i * rowBytes + j * 4;
            unsigned int    pixel;

            whichBit = j % 8; // bit position for mask, 0 is most significant
            whichByte = i * bytesPerRow + j / 8; // byte position for mask
            maskVal = (buff[bytesPixels + whichByte] >> (7 - whichBit)) & 1;

            sourcePos = (i * width + j) * bytesPerPixel;
            if (bytesPerPixel == 1)
                pixel = buff[sourcePos];
            else if (bytesPerPixel == 2) {
                if (pixf->bigEndian)
                    pixel = PIX16BIG(buff + sourcePos);
                else
                    pixel = PIX16LITTLE(buff + sourcePos);
            } else if (bytesPerPixel == 4) {
                if (pixf->bigEndian)
                    pixel = PIX32BIG(buff + sourcePos);
                else
                    pixel = PIX32LITTLE(buff + sourcePos);
            } else {
                NSLog(@"Illegal number of bits per pixel");
                [bitmap release];
                return nil;
            }

            if (maskVal) {
                dst[0] = ((pixel >> pixf->redShift) & pixf->redMax) * redMult;
                dst[1] = ((pixel >> pixf->greenShift) & pixf->greenMax) * greenMult;
                dst[2] = ((pixel >> pixf->blueShift) & pixf->blueMax) * blueMult;
                dst[3] = 255; // mask
            } else {
                /* masked values */
                dst[0] = dst[1] = dst[2] = dst[3] = 0;
            }
        }
    }

    NSImage *image = [[NSImage alloc] initWithSize:frame.size];
    [image addRepresentation:bitmap];
    [bitmap release];
    return [image autorelease];
}

@end
