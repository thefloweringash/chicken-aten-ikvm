/*
 *  debug.h
 *  Chicken of the VNC
 *
 *  Created by Kurt Werle on Thu Dec 19 2002.
 *  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
 *
 */

#import <Foundation/NSString.h>

//#define FULL_DEBUG

#ifdef FULL_DEBUG
#define FULLDebug NSLog
#else
#define FULLDebug DoNothing
#endif

void DoNothing(NSString *format, ...);
