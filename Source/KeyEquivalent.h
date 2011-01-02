//
//  KeyEquivalent.h
//  Chicken of the VNC
//
//  Created by Jason Harris on Sun Mar 21 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

/* Encapsulates key press with modifiers. This is mapped to a menu event by
 * KeyEquivalentScenario. */
@interface KeyEquivalent : NSObject <NSCopying> {
	NSString *mCharacters;
	unsigned int mModifiers;
}

- (id)initWithCharacters: (NSString *)characters modifiers: (unsigned int)modifiers;
- (BOOL)isEqualToKeyEquivalent: (KeyEquivalent *)anObject;
- (NSString *)characters;
- (unsigned int)modifiers;
- (NSAttributedString *)userString;
- (NSString *)string;

@end
