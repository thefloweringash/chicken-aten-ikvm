//
//  KeyEquivalent.h
//  Chicken of the VNC
//
//  Created by Jason Harris on Sun Mar 21 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface KeyEquivalent : NSObject <NSCopying> {
	NSString *mCharacters;
	unsigned int mModifiers;
}

- (id)initWithCharacters: (NSString *)characters modifiers: (unsigned int)modifiers;
- (BOOL)isEqualToKeyEquivalent: (KeyEquivalent *)anObject;
- (NSString *)characters;
- (unsigned int)modifiers;
- (NSAttributedString *)userString;

@end
