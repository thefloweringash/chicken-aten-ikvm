/* TightEncodingReader.h created by helmut on 31-Oct-2000 */

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

#import <AppKit/AppKit.h>
#import "EncodingReader.h"
#import "RFBConnection.h"
#import <zlib.h>

#import "../libjpeg-turbo/jpeglib.h"

#define NUM_ZSTREAMS		4
//#define Z_BUFSIZE		4096
#define TIGHT_BUFSIZE		16384
#define Z_BUFSIZE		TIGHT_BUFSIZE
#define TIGHT_MIN_TO_COMPRESS	12

@class ByteBlockReader;
@class CARD8Reader;
@class FilterReader, PaletteFilter, GradientFilter;
@class ZipLengthReader;

@interface TightEncodingReader : EncodingReader
{
    CARD8Reader     *controlReader;
    ByteBlockReader *backPixReader;
    CARD8Reader     *filterIdReader;
    ByteBlockReader *unzippedDataReader;
    ZipLengthReader *zipLengthReader;
    ByteBlockReader *zippedDataReader;
    
    FilterReader    *currentFilter;
    FilterReader    *copyFilter;
    PaletteFilter   *paletteFilter;
    GradientFilter  *gradientFilter;

    int		pixelBits;
    int		compressedLength;
    int		rowSize;
    int		rowsDone;
    
    CARD8	cntl; /* Subencoding type */
    BOOL	zStreamActive[NUM_ZSTREAMS];
    z_stream	zStream[NUM_ZSTREAMS];

    NSMutableData   *zBuffer;
    int		zBufPos;

	struct 	jpeg_source_mgr jpegSrcManager;
}

- (void)filterInitDone;

- (void)uninitializeStream: (int)streamID;

@end
