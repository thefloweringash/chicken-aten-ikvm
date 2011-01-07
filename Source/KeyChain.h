//
//  KeyChain.h
//  Fire
//
//  Created by Colter Reed on Thu Jan 24 2002.
//  Copyright (c) 2002 Colter Reed. All rights reserved.
//  Released under GPL.  You know how to get a copy.
//

#import <Foundation/Foundation.h>

@interface KeyChain : NSObject {
}

+ (KeyChain*)defaultKeyChain;

- (BOOL)setGenericPassword:(NSString*)password forService:(NSString*)service account:(NSString*)account;
- (NSString*)genericPasswordForService:(NSString*)service account:(NSString*)account;
- (void)removeGenericPasswordForService:(NSString *)service account:(NSString*)account;

@end
