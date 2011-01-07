//
//  KeyChain.m
//  Fire
//
//  Created by Colter Reed on Thu Jan 24 2002.
//  Copyright (c) 2002 Colter Reed. All rights reserved.
//  Released under GPL.  You know how to get a copy.
//

#import "KeyChain.h"
#import "Security/Security.h"

static KeyChain* defaultKeyChain = nil;

@interface KeyChain (KeyChainPrivate)

-(SecKeychainItemRef)_genericPasswordReferenceForService:(NSString *)service account:(NSString*)account;

@end

@implementation KeyChain

+ (KeyChain*) defaultKeyChain {
    if (defaultKeyChain == nil)
        defaultKeyChain = [[self alloc] init];
    return defaultKeyChain;
}

- (BOOL)setGenericPassword:(NSString*)password forService:(NSString *)service account:(NSString*)account
{
    OSStatus ret;
    SecKeychainItemRef itemref;
    
    if ([service length] == 0 || [account length] == 0) {
        return NO;
    }
    
    if (!password || [password length] == 0) {
        [self removeGenericPasswordForService:service account:account];
        return TRUE;
    } else {
        const char  *pass = [password UTF8String];

        if (itemref = [self _genericPasswordReferenceForService:service account:account])
            ret = SecKeychainItemModifyContent(itemref, NULL, strlen(pass), pass);
        else {
            const char  *serv = [service UTF8String];
            const char  *acc = [account UTF8String];
            ret = SecKeychainAddGenericPassword(NULL, strlen(serv), serv,
                        strlen(acc), acc, strlen(pass), pass, NULL);
        }
        if (ret)
            NSLog(@"Couldn't save to keychain: %d", ret);
        return ret == 0;
    }
}

- (NSString*)genericPasswordForService:(NSString *)service account:(NSString*)account
{
    OSStatus ret;
    UInt32 length;
    void *p = NULL;
    NSString *string = @"";
    const char  *serv = [service UTF8String];
    const char  *acc = [account UTF8String];
    
    if ([service length] == 0 || [account length] == 0) {
        free(p);
        return @"";
    }
    
    ret = SecKeychainFindGenericPassword(NULL, strlen(serv), serv, strlen(acc),
                acc, &length, &p, NULL);

    if (!ret) {
        string = [[NSString alloc] initWithBytes:p length:length
                encoding:NSUTF8StringEncoding];
        [string autorelease];
    }
    if (p)
        SecKeychainItemFreeContent(NULL, p);
    return string;
}

- (void)removeGenericPasswordForService:(NSString *)service account:(NSString*)account
{
    SecKeychainItemRef itemref;
    if (itemref = [self _genericPasswordReferenceForService:service account:account])
        SecKeychainItemDelete(itemref);
}

@end

@implementation KeyChain (KeyChainPrivate)

- (SecKeychainItemRef)_genericPasswordReferenceForService:(NSString *)service account:(NSString*)account
{
    const char  *serv = [service UTF8String];
    const char  *acc = [account UTF8String];
    SecKeychainItemRef itemref = NULL;
    OSStatus    ret;

    ret = SecKeychainFindGenericPassword(NULL, strlen(serv), serv, strlen(acc), acc,
            NULL, NULL, &itemref);
    return itemref;
}

@end
