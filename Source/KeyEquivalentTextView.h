//
//  KeyEquivalentTextView.h
//  Chicken of the VNC
//
//  Created by Bob Newhart on Thu Apr 08 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class KeyEquivalent;


@interface KeyEquivalentTextView : NSTextView
{
	KeyEquivalent *mKeyEquivalent;
}

- (KeyEquivalent *)keyEquivalent;

@end
