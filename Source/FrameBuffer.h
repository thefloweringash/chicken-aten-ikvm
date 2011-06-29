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

#ifndef __FRAMEBUFFER_H_INCLUDED__
#define __FRAMEBUFFER_H_INCLUDED__

#import <AppKit/AppKit.h>
#import "rfbproto.h"

#define SCRATCHPAD_SIZE			(384*384)

typedef union _FrameBufferColor {
    unsigned char	_u8;
    unsigned short	_u16;
    unsigned int	_u32;
} FrameBufferColor;

typedef unsigned char	FrameBufferPaletteIndex;

/* Stores the current frame buffer. The putXXX, fillXXX are used to update the
 * buffer from server messages. The drawRect message then renders this on
 * screen. */
@interface FrameBuffer : NSObject
{
    BOOL		isBig;
    NSSize		size;
    int			bytesPerPixel;
    
@public
    unsigned int	redClut[256];
    unsigned int	greenClut[256];
    unsigned int	blueClut[256];
    rfbPixelFormat	pixelFormat;
    unsigned int    redShiftFromFull;   // bits to shift when converting from
    unsigned int    greenShiftFromFull; // 8-bit to framebuffer values
    unsigned int    blueShiftFromFull;
    unsigned int	rshift, gshift, bshift;
    unsigned int	samplesPerPixel, maxValue;
    unsigned int	bitsPerColor;

#if 0
    unsigned		fillRectCount;
    unsigned		drawRectCount;
    unsigned		copyRectCount;
    unsigned		putRectCount;
    unsigned		fillPixelCount;
    unsigned		drawPixelCount;
    unsigned		copyPixelCount;
    unsigned		putPixelCount;
#endif

    BOOL			forceServerBigEndian;
    BOOL            serverIsBigEndian;
	unsigned int	*tightBytesPerPixelOverride;
}

+ (BOOL)bigEndian;
+ (void)getPixelFormat:(rfbPixelFormat*)pf;

- (id)initWithSize:(NSSize)aSize andFormat:(rfbPixelFormat*)theFormat;
- (unsigned int)bytesPerPixel;
- (unsigned int)tightBytesPerPixel;
- (void)setTightBytesPerPixelOverride: (unsigned int)count;
- (BOOL)bigEndian;
- (BOOL)serverIsBigEndian;
- (void)setCurrentReaderIsTight: (BOOL)flag;
- (void)setServerMajorVersion: (int)major minorVersion: (int)minor;
- (NSColor*)nsColorFromPixel:(unsigned char*)pixValue;
- (void)getRGB:(float*)rgb fromPixel:(unsigned char*)pixValue;
- (NSSize)size;
- (void)setPixelFormat:(rfbPixelFormat*)theFormat;
- (rfbPixelFormat *)pixelFormat;

- (void)fillColor:(FrameBufferColor*)fbc
        fromPixel:(const unsigned char*)pixValue;
- (void)fillRect:(NSRect)aRect withPixel:(const unsigned char*)pixValue;
- (void)fillRect:(NSRect)aRect withFbColor:(FrameBufferColor*)fbc;
- (void)copyRect:(NSRect)aRect to:(NSPoint)aPoint;
- (void)putRect:(NSRect)aRect fromData:(const unsigned char*)data;
- (void)drawRect:(NSRect)aRect at:(NSPoint)aPoint;

- (void)fillColor:(FrameBufferColor*)fbc
   fromTightPixel:(const unsigned char*)pixValue;
- (void)fillRect:(NSRect)aRect tightPixel:(const unsigned char*)pixValue;
- (void)putRect:(NSRect)aRect fromTightData:(const unsigned char*)data;
- (void)getMaxValues:(int*)m;
- (void)splitRGB:(unsigned char*)pixValue pixels:(unsigned)length into:(int*)rgb;
- (void)combineRGB:(int*)rgb pixels:(unsigned)length into:(unsigned char*)pixValue;

- (void)putRect:(NSRect)aRect withColors:(FrameBufferPaletteIndex*)data fromPalette:(FrameBufferColor*)palette;
- (void)putRun:(FrameBufferColor*)fbc ofLength:(int)length at:(NSRect)aRect pixelOffset:(int)offset;
- (void)putRect:(NSRect)aRect fromRGBBytes:(unsigned char*)rgb;

@end

// macros to read from pointers to big-endian data to host format
#ifdef __ppc__
#define PIX16BIG(v) (*(CARD16 *)(v))
#define PIX32BIG(v) (*(CARD32 *)(v))
#else
#define PIX16BIG(v) (((v)[0] << 8) | (v)[1])
#define PIX32BIG(v) (((v)[0] << 24) | ((v)[1] << 16) | ((v)[2] << 8) | (v)[3])
#endif
#define PIX24BIG(v) (((v)[0] << 16) | ((v)[1] << 8) | (v)[2])

// macros to read from pointers to little-endian data to host format
#ifdef __i386__
#define PIX16LITTLE(v) (*(CARD16 *)(v))
#define PIX32LITTLE(v) (*(CARD32 *)(v))
#else
#define PIX16LITTLE(v) ((v)[0] | ((v)[1] << 8))
#define PIX32LITTLE(v) ((v)[0] | ((v)[1] << 8) | ((v)[2] << 16) | ((v)[3] <<24))
#endif
#define PIX24LITTLE(v) ((v)[0] | ((v)[1] << 8) | ((v)[2] << 16))

#endif /* __FRAMEBUFFER_H_INCLUDED__ */

 
