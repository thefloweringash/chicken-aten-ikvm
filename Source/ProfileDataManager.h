//
//  ProfileDataManager.h
//  Chicken of the VNC
//
//  Created by Jared McIntyre on 8/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/** This message indicates that the profile list has changed */
#define ProfileListChangeMsg @"ProfileListChangeMsg"

@interface ProfileDataManager : NSObject {

@private
	NSMutableDictionary *mProfiles;
}

/**
 *  Accessor method to fetch the singleton instance for this class. Use this method
 *  instead of creating an instance of your own.
 *  @return Shared singleton instance of the ProfileDataManager class. */
+ (ProfileDataManager*) sharedInstance;

- (NSMutableDictionary *)defaultProfile;
- (NSString *)defaultProfileName;
- (NSMutableDictionary *)profileForKey:(id) key;
- (void)setProfile:(NSMutableDictionary*) profile forKey:(id) key;
- (void)removeProfileForKey:(id) key;
- (int)count;
- (void)save;
- (NSArray*)sortedKeyArray;
@end
