//
//  KeyEquivalent.m
//  Chicken of the VNC
//
//  Created by Jason Harris on Sun Mar 21 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "KeyEquivalent.h"
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>


@implementation KeyEquivalent

- (id)initWithCharacters: (NSString *)characters modifiers: (unsigned int)modifiers
{
	if ( self = [super init] )
	{
		mCharacters = [characters retain];
		mModifiers = modifiers;
	}
	return self;
}

- (void)dealloc
{
	[mCharacters release];
	[super dealloc];
}

- (BOOL)isEqual:(id)anObject
{  return [self isEqualToKeyEquivalent: anObject];  }

- (BOOL)isEqualToKeyEquivalent: (KeyEquivalent *)anObject
{
	if ( ! anObject )
		return NO;
	return (mModifiers == anObject->mModifiers) && ([mCharacters isEqualToString: anObject->mCharacters]);
}

- (unsigned)hash
{
	return [mCharacters hash] + mModifiers;
}

- (id)copyWithZone:(NSZone *)zone
{  return [[KeyEquivalent allocWithZone: zone] initWithCharacters: mCharacters modifiers: mModifiers];  }

- (NSString *)description
{  return [NSString stringWithFormat: @"0x%0.8x (%@)", mModifiers, mCharacters];  }

- (NSString *)characters
{  return mCharacters ? mCharacters : @"";  }

- (unsigned int)modifiers
{  return mModifiers;  }


- (NSAttributedString *)userString
{
	if ( ! mCharacters || [mCharacters length] == 0 ) 
		return [[[NSAttributedString alloc] initWithString: @""] autorelease];
	NSMutableString *string = [NSMutableString string];
	NSRange foundRange = [mCharacters rangeOfCharacterFromSet: [NSCharacterSet uppercaseLetterCharacterSet]];
	if (mModifiers & NSShiftKeyMask || foundRange.location != NSNotFound)
		[string appendString: [NSString stringWithUTF8String: "⇧"]];
	if (mModifiers & NSControlKeyMask)
		[string appendString: [NSString stringWithUTF8String: "⌃"]];
	if (mModifiers & NSAlternateKeyMask)
		[string appendString: [NSString stringWithUTF8String: "⌥"]];
	if (mModifiers & NSCommandKeyMask)
		[string appendString: [NSString stringWithUTF8String: "⌘"]];
	
	NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] initWithString: string] autorelease];
	
	NSString *chars = [mCharacters uppercaseString];
	unsigned i, length = [chars length];
	for (i = 0; i < length; ++i)
	{
		unichar c = [chars characterAtIndex: i];
		NSMutableAttributedString *newAttrString = nil;
		if ( c == kBackspaceCharCode )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "⌫"]] autorelease];
		else if ( c == kTabCharCode )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "⇥"]] autorelease];
		else if ( c == kEnterCharCode )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "⌅"]] autorelease];
		else if ( c == NSHomeFunctionKey )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "↖"]] autorelease];
		else if ( c == NSEndFunctionKey )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "↘"]] autorelease];
		else if ( c == NSPageUpFunctionKey )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "⇞"]] autorelease];
		else if ( c == NSPageDownFunctionKey )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "⇟"]] autorelease];
		else if ( c == kReturnCharCode )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "↩"]] autorelease];
		else if ( c == kEscapeCharCode )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "⎋"]] autorelease];
		else if ( c == kClearCharCode )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "⌧"]] autorelease];
		else if ( c == NSLeftArrowFunctionKey )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "←"]] autorelease];
		else if ( c == NSRightArrowFunctionKey )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "→"]] autorelease];
		else if ( c == NSUpArrowFunctionKey )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "↑"]] autorelease];
		else if ( c == NSDownArrowFunctionKey )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "↓"]] autorelease];
		else if ( c == kSpaceCharCode )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "␣"]] autorelease];
		else if ( c == kDeleteCharCode )
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: [NSString stringWithUTF8String: "⌦"]] autorelease];
		else if ( c == NSDeleteFunctionKey )
			return [[[NSAttributedString alloc] initWithString: @""] autorelease];
		else if (c >= NSF1FunctionKey && c <= NSF15FunctionKey)
		{
			unsigned int cid = 1173 + c - NSF1FunctionKey;
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: @" "] autorelease];
			NSRange rangeOfStringToBeOverriden = {0, 1};
			NSString *baseString = [[newAttrString string] substringWithRange: rangeOfStringToBeOverriden];
			NSGlyphInfo *glyphInfo = [NSGlyphInfo glyphInfoWithCharacterIdentifier: cid
																		collection: NSIdentityMappingCharacterCollection
																		baseString: baseString];
			[newAttrString addAttribute: NSGlyphInfoAttributeName
								  value: glyphInfo
								  range: rangeOfStringToBeOverriden];
		}
		if (newAttrString == nil)
		{
			NSString *newString = [[[NSString alloc] initWithBytes: &c length: sizeof(c) encoding: [mCharacters fastestEncoding]] autorelease];
			newAttrString = [[[NSMutableAttributedString alloc] initWithString: newString] autorelease];
		}
		[attrString appendAttributedString: newAttrString];
	}
	return attrString;
}

- (NSString *)string
{
    /* Produces a string representation of the key equivalent. It's just a hack
     * to cover the one case where we can't just use the underlying string of
     * userString actually uses an attribute. */
    if ([mCharacters length] > 0) {
        unichar c = [mCharacters characterAtIndex:0];
        if (c >= NSF1FunctionKey && c <= NSF15FunctionKey)
            return [NSString stringWithFormat:@"F%d", c - NSF1FunctionKey + 1];
    }
    return [[self userString] string];
}

@end
