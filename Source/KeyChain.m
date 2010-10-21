//
//  KeyChain.m
//  Fire
//
//  Created by Colter Reed on Thu Jan 24 2002.
//  Copyright (c) 2002 Colter Reed. All rights reserved.
//  Released under GPL.  You know how to get a copy.
//

#import "KeyChain.h"

static KeyChain* defaultKeyChain = nil;

@interface KeyChain (KeyChainPrivate)

-(KCItemRef)_genericPasswordReferenceForService:(NSString *)service account:(NSString*)account;

@end

@implementation KeyChain

+ (KeyChain*) defaultKeyChain {
	return ( defaultKeyChain ? defaultKeyChain : [[[self alloc] init] autorelease] );
}

- (id)init
{
    self = [super init];
    maxPasswordLength = 127;
    return self;
}

- (void)setGenericPassword:(NSString*)password forService:(NSString *)service account:(NSString*)account
{
    OSStatus ret;
    KCItemRef itemref = NULL;
    
    if ([service length] == 0 || [account length] == 0) {
        return ;
    }
    
    if (!password || [password length] == 0) {
        [self removeGenericPasswordForService:service account:account];
    } else {
        if (itemref = [self _genericPasswordReferenceForService:service account:account])
        KCDeleteItem(itemref);
        ret = kcaddgenericpassword([service UTF8String], [account UTF8String],
                [password lengthOfBytesUsingEncoding: NSUTF8StringEncoding],
                [password UTF8String], NULL);
    }
}

- (NSString*)genericPasswordForService:(NSString *)service account:(NSString*)account
{
    OSStatus ret;
    UInt32 length;
    char *p = (char *)malloc(maxPasswordLength+1);
    NSString *string = @"";
    
    if ([service length] == 0 || [account length] == 0) {
        free(p);
        return @"";
    }
    
    ret = kcfindgenericpassword([service UTF8String], [account UTF8String],
            maxPasswordLength, p, &length, nil);

    if (!ret) {
        string = [[NSString alloc] initWithBytes:p length:length
                encoding:NSUTF8StringEncoding];
        [string autorelease];
    }
    free(p); 
    return string;
}

- (void)removeGenericPasswordForService:(NSString *)service account:(NSString*)account
{
    KCItemRef itemref = nil ;
    if (itemref = [self _genericPasswordReferenceForService:service account:account])
        KCDeleteItem(itemref);
}

- (void)setMaxPasswordLength:(unsigned)length
{
    if (![self isEqual:defaultKeyChain]) {
        maxPasswordLength = length ;
    }
}

- (unsigned)maxPasswordLength
{
    return maxPasswordLength;
}

@end

@implementation KeyChain (KeyChainPrivate)

- (KCItemRef)_genericPasswordReferenceForService:(NSString *)service account:(NSString*)account
{
    KCItemRef itemref = nil;
    kcfindgenericpassword([service UTF8String],[account UTF8String],0,nil,nil,&itemref);
    return itemref;
}

@end
