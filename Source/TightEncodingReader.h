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
#import <zlib.h>

#define NUM_ZSTREAMS		4
#define Z_BUFSIZE		4096
#define TIGHT_BUFSIZE		16384
#define TIGHT_MIN_TO_COMPRESS	12

@interface TightEncodingReader : EncodingReader
{
    id		controlReader;
    id		backPixReader;
    id		filterIdReader;
    id		unzippedDataReader;
    id		zipLengthReader;
    id		zippedDataReader;
    
    id		currentFilter;
    id		copyFilter;
    id		paletteFilter;
    id		gradientFilter;
    int		pixelBits;
    int		compressedLength;
    int		rowSize;
    int		rowsDone;
    
    CARD8	cntl;
    BOOL	zStreamActive[NUM_ZSTREAMS];
    z_stream	zStream[NUM_ZSTREAMS];

    id		zBuffer;
    int		zBufPos;
    id		connection;
}

@end
